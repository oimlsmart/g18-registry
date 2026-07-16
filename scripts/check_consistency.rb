#!/usr/bin/env ruby
# frozen_string_literal: true

# AI-assisted consistency classification (TODO 05).
#
# For every (term, publication) instance whose term has an official VIM/VIML
# concept reference, classify how the publication's definition compares to
# the official one (ok / partial / ko). Caches results in
# cache/consistency.jsonl keyed by hash(official_text, publication_text) so
# re-runs only hit the LLM when a definition changes.
#
# Usage:
#   scripts/check_consistency.rb                      # dry-run: list work
#   scripts/check_consistency.rb --run                # call LLM, update data/
#   scripts/check_consistency.rb --run --term reference-conditions
#   scripts/check_consistency.rb --run --limit 10
#
# Auth: --api-key or ANTHROPIC_API_KEY env var (required for --run).

require "optparse"
require "set"
require_relative "../lib/g18"

repo_root = File.expand_path("..", __dir__)
default_vocab_dir = File.expand_path("vocab/datasets", File.join(repo_root, ".."))
options = {
  vocab_dir: ENV.fetch("VOCAB_ROOT", ENV.fetch("VOCAB_DIR", default_vocab_dir)),
  data_dir: ENV.fetch("DATA_DIR", File.join(repo_root, "data")),
  cache_path: ENV.fetch("CACHE_PATH", G18::Consistency::DEFAULT_CACHE_PATH),
  model: ENV.fetch("CONSISTENCY_MODEL", G18::Consistency::DEFAULT_MODEL),
  base_url: ENV.fetch("LLM_BASE_URL", G18::Consistency::DEFAULT_BASE_URL),
  api_key: ENV.fetch("ANTHROPIC_API_KEY", ""),
  run: false,
  limit: nil,
  term: nil,
  prune: false,
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--vocab-dir DIR", String, "Path to vocab/datasets (for official definitions)") { |v| options[:vocab_dir] = v }
  opts.on("--data-dir DIR", String, "Per-term YAML directory (default: data/)") { |v| options[:data_dir] = v }
  opts.on("--cache PATH", String, "Cache JSONL file (default: cache/consistency.jsonl)") { |v| options[:cache_path] = v }
  opts.on("--model NAME", String, "LLM model (default: #{G18::Consistency::DEFAULT_MODEL})") { |v| options[:model] = v }
  opts.on("--base-url URL", String, "LLM API base URL (default: #{G18::Consistency::DEFAULT_BASE_URL}); for Z.AI use https://api.z.ai/api/anthropic") { |v| options[:base_url] = v }
  opts.on("--api-key KEY", String, "LLM API key (or set ANTHROPIC_API_KEY)") { |v| options[:api_key] = v }
  opts.on("--run", "Actually call the LLM (default: dry-run)") { options[:run] = true }
  opts.on("--limit N", Integer, "Stop after N uncached comparisons") { |v| options[:limit] = v }
  opts.on("--term SLUG", String, "Only process one term (slug)") { |v| options[:term] = v }
  opts.on("--prune", "Drop cache entries whose g18_entry no longer exists in data/") { options[:prune] = true }
  opts.on("-h", "--help") { puts opts; exit 0 }
end.parse!

unless Dir.exist?(options[:vocab_dir])
  warn "vocab-dir not found: #{options[:vocab_dir]}"
  warn "set --vocab-dir or VOCAB_ROOT (or VOCAB_DIR) env var"
  exit 1
end

items = G18::Consistency.build_work_items(options[:data_dir], options[:vocab_dir])
items = items.select { |i| i[:term_slug] == options[:term] } if options[:term]

cache = G18::Consistency.load_cache(options[:cache_path])

# Prune mode: drop orphaned entries and exit.
if options[:prune]
  live_keys = items.map { |i| i[:cache_key] }.to_set
  pruned = cache.select { |k, _| live_keys.include?(k) }
  dropped = cache.size - pruned.size
  G18::Consistency.write_cache(options[:cache_path], pruned)
  puts "Pruned #{dropped} orphaned cache entr#{dropped == 1 ? 'y' : 'ies'} (#{pruned.size} kept)."
  exit 0
end

unprocessed = items.reject { |i| cache.key?(i[:cache_key]) }
puts "Consistency check work summary"
puts "  Vocab dir:        #{options[:vocab_dir]}"
puts "  Data dir:         #{options[:data_dir]}"
puts "  Cache file:       #{options[:cache_path]}"
puts "  Base URL:         #{options[:base_url]}"
puts "  Model:            #{options[:model]}"
puts "  Mode:             #{options[:run] ? 'RUN (will call LLM)' : 'DRY-RUN (no API calls)'}"
puts "  Total instances:  #{items.size}"
puts "  Cached:           #{items.size - unprocessed.size}"
puts "  Uncached:         #{unprocessed.size}"
puts "  Term filter:      #{options[:term] || '(none)'}"
puts "  Limit:            #{options[:limit] || '(none)'}"

exit 0 if items.empty?

# Apply cached results to data/ regardless of --run — even in dry-run we
# want previously-classified instances to surface their cached label
# instead of staying "pending". Only the *uncached* comparisons require --run.
results_by_g18_entry = {}
items.each do |item|
  next if results_by_g18_entry.key?(item[:g18_entry])
  cached = cache[item[:cache_key]]
  next unless cached
  results_by_g18_entry[item[:g18_entry]] = {
    "classification" => cached["classification"],
    "reason"         => cached["reason"],
  }
end

unless options[:run]
  G18::Consistency.apply_results(options[:data_dir], results_by_g18_entry)
  puts
  puts "Applied #{results_by_g18_entry.size} cached results to data/."
  if unprocessed.any?
    puts
    puts "Next uncached comparisons:"
    unprocessed.first(options[:limit] || 10).each_with_index do |i, idx|
      puts "  #{idx + 1}. #{i[:term_name]} (G18 ##{i[:g18_entry]}) — #{i[:publication]}"
    end
    puts "Run with --run to call the LLM and classify these."
  else
    puts "All instances cached. Re-running with --run is a no-op."
  end
  exit 0
end

if options[:api_key].empty?
  warn "ERROR: --api-key (or ANTHROPIC_API_KEY env var) is required for --run"
  exit 1
end

todo = unprocessed.dup
todo = todo.first(options[:limit]) if options[:limit]

puts
puts "Calling LLM for #{todo.size} comparison#{todo.size == 1 ? '' : 's'}..."
results_by_g18_entry = {}
todo.each_with_index do |item, idx|
  print "  [#{idx + 1}/#{todo.size}] #{item[:term_name]} (G18 ##{item[:g18_entry]}) — #{item[:publication]} ... "
  begin
    result = G18::Consistency.call_llm(
      api_key: options[:api_key],
      model: options[:model],
      base_url: options[:base_url],
      official_text: item[:official_text],
      publication_text: item[:publication_text],
    )
    entry = {
      "cache_key"        => item[:cache_key],
      "term_slug"        => item[:term_slug],
      "term_name"        => item[:term_name],
      "g18_entry"        => item[:g18_entry],
      "publication_id"   => item[:publication_id],
      "publication"      => item[:publication],
      "official_urn"     => item[:official_urn],
      "official_id"      => item[:official_id],
      "classification"   => result["classification"],
      "reason"           => result["reason"],
      "model"            => options[:model],
    }
    G18::Consistency.append_cache(options[:cache_path], entry)
    cache[item[:cache_key]] = entry
    results_by_g18_entry[item[:g18_entry]] = result
    puts "#{result['classification']} — #{result['reason']}"
  rescue => e
    puts "FAILED: #{e.message}"
  end
end

# Apply all known results (cached + freshly fetched) back to data/.
items.each do |item|
  next if results_by_g18_entry.key?(item[:g18_entry])
  cached = cache[item[:cache_key]]
  next unless cached
  results_by_g18_entry[item[:g18_entry]] = {
    "classification" => cached["classification"],
    "reason"         => cached["reason"],
  }
end

G18::Consistency.apply_results(options[:data_dir], results_by_g18_entry)

puts
puts "Done. #{results_by_g18_entry.size} instances updated in #{options[:data_dir]}/."
counts = results_by_g18_entry.values.group_by { |r| r["classification"] }.transform_values(&:size)
puts "  Breakdown: #{counts.inspect}"
puts "  Next step: rebuild the site with scripts/build_site.rb."
