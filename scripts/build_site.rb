#!/usr/bin/env ruby
# frozen_string_literal: true

# Build the static G 18 registry site into _site/.
#
# Reads data/ (per-term YAML produced by scripts/migrate_from_vocab.rb) and
# tc-sc/publications.yaml (bibliography + TC/SC), renders templates/ into
# _site/ via lib/g18/site.rb.

require "optparse"
require_relative "../lib/g18"

repo_root = File.expand_path("..", __dir__)
options = {
  data_dir: ENV.fetch("DATA_DIR", File.join(repo_root, "data")),
  bib_path: ENV.fetch("TC_SC_PATH", File.join(repo_root, "tc-sc", "publications.yaml")),
  templates_dir: ENV.fetch("TEMPLATES_DIR", File.join(repo_root, "templates")),
  static_dir: ENV.fetch("STATIC_DIR", File.join(repo_root, "static")),
  output_dir: ENV.fetch("OUTPUT_DIR", File.join(repo_root, "_site")),
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--data-dir DIR", String) { |v| options[:data_dir] = v }
  opts.on("--bib-path PATH", String) { |v| options[:bib_path] = v }
  opts.on("--templates-dir DIR", String) { |v| options[:templates_dir] = v }
  opts.on("--static-dir DIR", String) { |v| options[:static_dir] = v }
  opts.on("--output-dir DIR", String) { |v| options[:output_dir] = v }
  opts.on("-h", "--help") { puts opts; exit 0 }
end.parse!

dataset = G18::Site.load_dataset(data_dir: options[:data_dir], bib_path: options[:bib_path])
renderer = G18::Site::Renderer.new(
  dataset: dataset,
  templates_dir: options[:templates_dir],
  static_dir: options[:static_dir],
  output_dir: options[:output_dir],
)
renderer.render_all

puts "Site built at #{options[:output_dir]}."
puts "  Terms: #{dataset.term_count}"
puts "  Publications: #{dataset.publication_count}"
puts "  TC/SC groups: #{dataset.tcscs.size}"
puts "  Divergent terms: #{dataset.divergent_term_count}"
