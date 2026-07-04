# frozen_string_literal: true

require "yaml"
require "json"
require "digest"
require "fileutils"
require "net/http"
require "uri"

module G18
  # AI-assisted consistency classification.
  #
  # For each (term, publication) instance that has a VIM/VIML concept
  # reference, classify how the publication's definition compares to the
  # official one:
  #   ok       — semantically equivalent
  #   partial  — mostly equivalent but missing nuance or adding detail
  #   ko       — substantively different or contradictory
  #   pending  — not yet assessed
  #
  # Results are cached in `cache/consistency.jsonl`, keyed by the SHA1 of
  # (official_definition, publication_definition). Re-runs only call the
  # LLM when one of the definitions changes.
  module Consistency
    DEFAULT_MODEL = "claude-haiku-4-5-20251001"
    DEFAULT_BASE_URL = "https://api.anthropic.com"
    DEFAULT_CACHE_DIR = File.expand_path("../../cache", __dir__)
    DEFAULT_CACHE_PATH = File.join(DEFAULT_CACHE_DIR, "consistency.jsonl")

    # Reuse the URN→dataset map so we can locate the official definition
    # file in the sibling vocab checkout.
    URN_TO_DATASET = Migration::URN_TO_DATASET

    # Build the cache key for a (official, publication) pair.
    # Two pairs with identical text produce identical keys, so re-runs
    # only call the LLM when a definition actually changes.
    def cache_key(official_text, publication_text)
      Digest::SHA1.hexdigest("v1\n#{official_text}\n#{publication_text}")
    end

    # Load the cache as a hash keyed by cache_key.
    # Each line is a JSON object; malformed lines are skipped with a warning.
    def load_cache(path)
      return {} unless path && File.exist?(path)
      File.readlines(path, chomp: true).each_with_object({}) do |line, h|
        next if line.strip.empty?
        entry = JSON.parse(line)
        h[entry["cache_key"]] = entry
      rescue JSON::ParserError => e
        warn "Skipping malformed cache line: #{e.message}"
      end
    end

    # Append a single cache entry. JSONL keeps the file append-only and
    # safe under concurrent writers (one line per write).
    def append_cache(path, entry)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") { |f| f.puts(JSON.generate(entry)) }
    end

    # Rewrite the cache from a full hash. Used by --prune to drop entries
    # whose instances no longer exist.
    def write_cache(path, entries)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, entries.values.map { |e| JSON.generate(e) }.join("\n") + "\n")
    end

    # Load a YAML concept file from the vocab repo and extract the English
    # preferred designation + definition. Returns nil if not found.
    def load_official_definition(vocab_dir, dataset, concept_id)
      return nil unless vocab_dir && dataset && concept_id
      path = File.join(vocab_dir, dataset, "concepts", "#{concept_id}.yaml")
      return nil unless File.exist?(path)
      docs = begin
        YAML.safe_load_stream(File.read(path), filename: path, aliases: true)
      rescue Psych::SyntaxError
        nil
      end
      return nil unless docs
      loc = docs.find { |d| d && d.is_a?(Hash) && d.dig("data", "definition") }
      return nil unless loc
      defs = loc.dig("data", "definition") || []
      text = defs.map { |d| d["content"] if d.is_a?(Hash) }.compact.join("\n")
      text.strip
    end

    # Resolve the (dataset, concept_id) for a term's official_concept.
    def resolve_official(official_concept)
      return nil unless official_concept
      urn = official_concept["source"]
      id = official_concept["id"]
      dataset = URN_TO_DATASET[urn]
      return nil unless dataset && id
      [dataset, id]
    end

    # All (term_slug, publication_instance) pairs that have an official
    # concept to compare against. Returns an array of hashes:
    #   { term_slug:, term_name:, g18_entry:, publication_id:,
    #     official_urn:, official_id:, official_text:, publication_text:,
    #     cache_key: }
    def build_work_items(data_dir, vocab_dir)
      Dir.glob(File.join(data_dir, "*.yaml")).sort.map do |file|
        slug = File.basename(file, ".yaml")
        hash = YAML.safe_load(File.read(file), aliases: true) || {}
        data = hash["data"] || {}
        official = data["official_concept"]
        resolved = resolve_official(official)
        next [] unless resolved
        dataset, concept_id = resolved
        official_text = load_official_definition(vocab_dir, dataset, concept_id)
        next [] if official_text.nil? || official_text.strip.empty?
        Array(data["publications"]).map do |pub|
          pub_text = (pub["definition"] || "").strip
          next nil if pub_text.empty?
          {
            term_slug: slug,
            term_name: data["term"],
            g18_entry: pub["g18_entry"],
            publication_id: pub["publication_id"],
            publication: pub["publication"],
            official_urn: official["source"],
            official_id: official["id"],
            official_text: official_text,
            publication_text: pub_text,
            cache_key: cache_key(official_text, pub_text),
          }
        end.compact
      end.flatten
    end

    # Build the LLM prompt for one comparison.
    def build_prompt(official_text, publication_text)
      <<~PROMPT
        You are a metrology terminology editor comparing two definitions of the same concept.

        Official definition (authoritative, from VIM or VIML):
        ---
        #{official_text}
        ---

        Publication's definition (to be assessed):
        ---
        #{publication_text}
        ---

        Ignore minor wording differences, capitalisation, and punctuation.
        Focus on semantic content: Does the publication convey the same meaning?

        Classify as exactly one of:
        - ok: semantically equivalent to the official definition
        - partial: mostly equivalent but missing nuance, dropping a clause, or adding irrelevant detail
        - ko: substantively different, contradictory, or referring to a different concept

        Respond with one line of JSON only, no prose:
        {"classification":"ok|partial|ko","reason":"<at most one short sentence>"}
      PROMPT
    end

    # Call the Anthropic Messages API. Works against any Anthropic-compatible
    # endpoint (e.g. Z.AI's `https://api.z.ai/api/anthropic`). Returns
    # { "classification" => ..., "reason" => ... } on success; raises on
    # HTTP/API error.
    def call_llm(api_key:, model:, official_text:, publication_text:, base_url: DEFAULT_BASE_URL, timeout: 30)
      raise ArgumentError, "api_key required" unless api_key && !api_key.empty?
      uri = URI("#{base_url.chomp('/')}/v1/messages")
      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = api_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = JSON.generate({
        model: model,
        max_tokens: 200,
        system: "You are a precise terminology editor. Reply with JSON only.",
        messages: [{ role: "user", content: build_prompt(official_text, publication_text) }],
      })
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: timeout) do |http|
        http.request(req)
      end
      raise "LLM API #{response.code}: #{response.body[0, 500]}" unless response.is_a?(Net::HTTPSuccess)
      parse_llm_response(response.body)
    end

    # Extract classification + reason from the API response body.
    # Tolerates minor formatting variance (markdown fences, leading prose).
    def parse_llm_response(body)
      parsed = JSON.parse(body)
      text = parsed.dig("content", 0, "text").to_s
      match = text.match(/\{[^{}]*"classification"[^{}]*\}/m)
      raise "No JSON object in LLM response: #{text.inspect}" unless match
      obj = JSON.parse(match[0])
      cls = obj["classification"].to_s.downcase
      raise "Unexpected classification: #{cls.inspect}" unless %w[ok partial ko].include?(cls)
      { "classification" => cls, "reason" => obj["reason"].to_s.strip }
    end

    # Walk every term YAML file and replace the per-instance consistency
    # fields with the values from `results` (keyed by g18_entry).
    def apply_results(data_dir, results_by_g18_entry)
      Dir.glob(File.join(data_dir, "*.yaml")).each do |file|
        hash = YAML.safe_load(File.read(file), aliases: true) || {}
        data = hash["data"] || {}
        pubs = data["publications"] || []
        changed = false
        pubs.each do |pub|
          entry_id = pub["g18_entry"].to_s
          next unless results_by_g18_entry.key?(entry_id)
          result = results_by_g18_entry[entry_id]
          next if pub["consistency"] == result["classification"] &&
                  pub["consistency_reason"] == result["reason"]
          pub["consistency"] = result["classification"]
          pub["consistency_reason"] = result["reason"]
          changed = true
        end
        next unless changed
        File.write(file, serialize_yaml(hash))
      end
    end

    def serialize_yaml(hash)
      yaml = YAML.dump(hash)
      yaml.start_with?("---\n") ? yaml : "---\n" + yaml
    end

    module_function :cache_key, :load_cache, :append_cache, :write_cache,
                    :load_official_definition, :resolve_official,
                    :build_work_items, :build_prompt, :call_llm,
                    :parse_llm_response, :apply_results, :serialize_yaml  end
end
