#!/usr/bin/env ruby
# frozen_string_literal: true

# Migrate oimlsmart/vocab G 18 datasets (2010 + 202X) into per-term files.
#
# Usage:
#   scripts/migrate_from_vocab.rb [--vocab-root DIR] [--output-dir DIR] [--report PATH]
#
# Defaults:
#   --vocab-root  ../vocab/datasets          (sibling checkout of oimlsmart/vocab)
#   --output-dir  data
#   --report      migration-report.md
#
# Editions consumed (in priority order — primary is used for display fields):
#   202X (primary, latest draft)
#   2010 (prior published edition)

require "optparse"
require_relative "../lib/g18/migration"
require_relative "../lib/g18/migration_report"

repo_root = File.expand_path("..", __dir__)
default_vocab_root = File.expand_path("vocab/datasets", File.join(repo_root, ".."))
vocab_root = ENV.fetch("VOCAB_ROOT", default_vocab_root)
options = {
  vocab_root: vocab_root,
  bib_path: nil,
  aliases_path: ENV.fetch("ALIASES_PATH", File.join(repo_root, "tc-sc", "term-aliases.yaml")),
  output_dir: ENV.fetch("OUTPUT_DIR", File.join(repo_root, "data")),
  report_path: ENV.fetch("REPORT_PATH", File.join(repo_root, "migration-report.md")),
  editions: [
    { name: "202X", path: File.join(vocab_root, "g18-current"), primary: true },
    { name: "202X-draft", path: File.join(vocab_root, "g18-202X"), primary: false },
    { name: "2010", path: File.join(vocab_root, "g18-2010"), primary: false },
    { name: "complete", path: File.join(vocab_root, "g18-complete"), primary: false },
  ],
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--vocab-root DIR", String, "Path to vocab/datasets (parent of all G 18 edition dirs)") do |v|
    options[:vocab_root] = v
    options[:editions] = [
      { name: "202X", path: File.join(v, "g18-current"), primary: true },
      { name: "202X-draft", path: File.join(v, "g18-202X"), primary: false },
      { name: "2010", path: File.join(v, "g18-2010"), primary: false },
      { name: "complete", path: File.join(v, "g18-complete"), primary: false },
    ]
  end
  opts.on("--bib-path PATH", String, "Bibliography YAML (defaults to vocab repo bibliographies)") { |v| options[:bib_path] = v }
  opts.on("--aliases-path PATH", String, "Term aliases YAML (defaults to tc-sc/term-aliases.yaml)") { |v| options[:aliases_path] = v }
  opts.on("--output-dir DIR", String, "Output directory for per-term files") { |v| options[:output_dir] = v }
  opts.on("--report PATH", String, "Where to write the migration report") { |v| options[:report_path] = v }
  opts.on("--only-edition NAME", String, "Process only one edition (e.g. '202X' or '2010')") do |v|
    options[:editions] = options[:editions].select { |e| e[:name] == v }.map { |e| e.merge(primary: true) }
  end
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit 0
  end
end.parse!

result = G18::Migration.run(
  editions: options[:editions],
  output_dir: options[:output_dir],
  bib_path: options[:bib_path],
  aliases_path: options[:aliases_path],
  vocab_dir: options[:vocab_root],
)

File.write(options[:report_path], G18::Migration::Report.render(result, source_dir: options[:vocab_root]))

puts "Migration complete."
result.editions.each do |e|
  puts "  Edition #{e[:name]}#{e[:primary] ? ' (primary)' : ''}: #{e[:concept_count]} source concepts"
end
puts "  Output: #{options[:output_dir]} (#{result.unique_term_count} files, #{result.instance_count} publication instances)"
puts "  Related edges preserved: #{result.related_edge_count}"
puts "  Multi-edge terms: #{result.multi_edge_terms.size}"
puts "  Annotations stripped: #{result.annotations_stripped.size}"
puts "  Alias merges: #{result.alias_merges.size}"
puts "  ID conflicts: #{result.id_conflicts.values.sum(&:size)} across #{result.id_conflicts.size} editions"
puts "  Report: #{options[:report_path]}"
