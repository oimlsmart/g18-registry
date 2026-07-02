#!/usr/bin/env ruby
# frozen_string_literal: true

# Migrate oimlsmart/vocab datasets/g18/ (per-instance) into per-term files.
#
# Usage:
#   scripts/migrate_from_vocab.rb [--vocab-dir DIR] [--output-dir DIR] [--report PATH]
#
# Defaults:
#   --vocab-dir  ../vocab/datasets/g18   (sibling checkout of oimlsmart/vocab)
#   --output-dir data
#   --report     migration-report.md

require "optparse"
require_relative "../lib/g18/migration"
require_relative "../lib/g18/migration_report"

repo_root = File.expand_path("..", __dir__)
default_vocab_dir = File.expand_path("vocab/datasets/g18", File.join(repo_root, ".."))
options = {
  vocab_dir: ENV.fetch("VOCAB_G18_DIR", default_vocab_dir),
  bib_path: ENV.fetch("TC_SC_PATH", File.join(repo_root, "tc-sc", "publications.yaml")),
  aliases_path: ENV.fetch("ALIASES_PATH", File.join(repo_root, "tc-sc", "term-aliases.yaml")),
  output_dir: ENV.fetch("OUTPUT_DIR", File.join(repo_root, "data")),
  report_path: ENV.fetch("REPORT_PATH", File.join(repo_root, "migration-report.md")),
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--vocab-dir DIR", String, "Path to vocab datasets/g18") { |v| options[:vocab_dir] = v }
  opts.on("--bib-path PATH", String, "Bibliography YAML (defaults to tc-sc/publications.yaml)") { |v| options[:bib_path] = v }
  opts.on("--aliases-path PATH", String, "Term aliases YAML (defaults to tc-sc/term-aliases.yaml)") { |v| options[:aliases_path] = v }
  opts.on("--output-dir DIR", String, "Output directory for per-term files") { |v| options[:output_dir] = v }
  opts.on("--report PATH", String, "Where to write the migration report") { |v| options[:report_path] = v }
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit 0
  end
end.parse!

result = G18::Migration.run(vocab_dir: options[:vocab_dir], output_dir: options[:output_dir], bib_path: options[:bib_path], aliases_path: options[:aliases_path])

File.write(options[:report_path], G18::Migration::Report.render(result, source_dir: options[:vocab_dir]))

puts "Migration complete."
puts "  Source: #{options[:vocab_dir]}"
puts "  Output: #{options[:output_dir]} (#{result.unique_term_count} files, #{result.instance_count} publication instances)"
puts "  Related edges preserved: #{result.related_edge_count}"
puts "  Multi-edge terms: #{result.multi_edge_terms.size}"
puts "  Annotations stripped: #{result.annotations_stripped.size}"
puts "  Alias merges: #{result.alias_merges.size}"
puts "  Report: #{options[:report_path]}"
