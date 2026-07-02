#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract TC/SC attribution from relaton-data-oiml and update the
# g18-registry bibliography. Reads the contributor→organization→subdivision
# field from each relaton YAML to determine which TC/SC owns each publication.
#
# Usage:
#   scripts/sync_tc_sc_from_relaton.rb [--relaton-dir DIR] [--bib-path PATH]

require "yaml"
require "optparse"
require "fileutils"

repo_root = File.expand_path("..", __dir__)
options = {
  relaton_dir: File.expand_path("../../relaton/relaton-data-oiml/data", repo_root),
  bib_path: File.join(repo_root, "tc-sc", "publications.yaml"),
}

OptionParser.new { |opts|
  opts.on("--relaton-dir DIR", String) { |v| options[:relaton_dir] = v }
  opts.on("--bib-path PATH", String) { |v| options[:bib_path] = v }
}.parse!

abort "Relaton data dir not found: #{options[:relaton_dir]}" unless Dir.exist?(options[:relaton_dir])

# Load existing bibliography
bib = if File.exist?(options[:bib_path])
  YAML.safe_load(File.read(options[:bib_path]), aliases: true) || []
else
  []
end
bib_by_id = bib.each_with_object({}) { |e, h| h[e["id"]] = e if e.is_a?(Hash) }

# Scan relaton files for TC/SC data
tc_sc_map = {}
scanned = 0
with_tc = 0

Dir.glob(File.join(options[:relaton_dir], "*.yaml")).sort.each do |path|
  # Skip language variants — use the base file only (no _eng/_fra suffix)
  next if path =~ /_(eng|fra|spa|fas)\.yaml$/

  docs = YAML.safe_load_stream(File.read(path), filename: path, aliases: true)
  doc = docs.find { |d| d.is_a?(Hash) && d["docidentifier"] }
  next unless doc

  identifiers = doc["docidentifier"] || []
  id_entry = identifiers.find { |i| i["type"] == "OIML" } || identifiers.first
  next unless id_entry && id_entry["content"]

  # Normalize to g18-registry format: "OIML D 11:2004" → "OIML D011:2004"
  # Multiple strategies since the source isn't consistent.
  raw_id = id_entry["content"].sub(/\s*\(E\)|\s*\(F\)/, "").strip
  variants = Set.new([raw_id])
  # Strategy 1: collapse "OIML X NN" → "OIML X0NN" (zero-pad to 3 digits)
  if raw_id =~ /^OIML\s+([A-Z])\s*(\d+)(.*)$/
    letter, num, rest = $1, $2, $3
    padded = format("OIML %s%03d%s", letter, num.to_i, rest)
    variants.add(padded)
    variants.add(raw_id.sub(/OIML\s+([A-Z])\s*/, 'OIML \1'))
  end
  # Strategy 2: just remove all spaces after "OIML X"
  variants.add(raw_id.gsub(/\s+/, ""))
  # Strategy 3: "OIML B 10-1:2004" → "OIML B010-1:2004"
  variants.add(raw_id.sub(/OIML\s+([A-Z])\s*/, 'OIML \1'))

  # Extract TC/SC from contributor → organization → subdivision
  contributors = doc["contributor"] || []
  tc = nil
  sc = nil
  contributors.each do |c|
    org = c["organization"]
    next unless org
    subdivisions = org["subdivision"]
    next unless subdivisions
    subdivisions.each do |sub|
      type = sub["type"]
      idents = sub["identifier"] || []
      ident = idents.find { |i| i.is_a?(Hash) } || idents.first
      ident_str = ident.is_a?(Hash) ? ident["content"] : ident.to_s
      if type == "technical-committee"
        tc = ident_str || sub.dig("name", 0, "content")
      elsif type == "subcommittee"
        sc = ident_str || sub.dig("name", 0, "content")
      end
    end
  end

  next unless tc
  with_tc += 1

  tc_sc_str = tc
  tc_sc_str += "/#{sc}" if sc

  variants.each { |v| tc_sc_map[v] = tc_sc_str }
end

scanned = tc_sc_map.size
puts "Scanned #{scanned} publications, #{with_tc} have TC/SC data."

# Update bibliography
updated = 0
new_entries = 0
tc_sc_map.each do |pub_id, tc_sc|
  entry = bib_by_id[pub_id]
  if entry
    old = entry["tc_sc"]
    if old != tc_sc
      entry["tc_sc"] = tc_sc
      updated += 1
    end
  end
end

# Report unmatched g18-registry publications
g18_pub_ids = bib.map { |e| e["id"] }.compact
matched = g18_pub_ids.select { |id| tc_sc_map.key?(id) }
unmatched = g18_pub_ids.reject { |id| tc_sc_map.key?(id) }
puts "Matched: #{matched.size} / #{g18_pub_ids.size} g18-registry publications"
puts "Updated TC/SC: #{updated}"
puts "Unmatched (no relaton entry): #{unmatched.size}"
if unmatched.any?
  puts "  First 10 unmatched: #{unmatched.first(10).join(', ')}"
end

# Write updated bibliography
File.write(options[:bib_path], YAML.dump(bib)) if updated > 0
puts "Wrote #{options[:bib_path]}" if updated > 0
