#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerate tc-sc/publications.yaml from the vocab bibliography, preserving
# any existing tc_sc values. Run after the vocab bibliography changes or
# when new TC/SC attributions are confirmed.

require "optparse"
require_relative "../lib/g18"

repo_root = File.expand_path("..", __dir__)
options = {
  vocab_dir: ENV.fetch("VOCAB_G18_DIR", File.expand_path("vocab/datasets/g18", File.join(repo_root, ".."))),
  output_path: ENV.fetch("TC_SC_PATH", File.join(repo_root, "tc-sc", "publications.yaml")),
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--vocab-dir DIR", String, "Path to vocab datasets/g18") { |v| options[:vocab_dir] = v }
  opts.on("--output PATH", String, "Output YAML path") { |v| options[:output_path] = v }
  opts.on("-h", "--help") { puts opts; exit 0 }
end.parse!

result = G18::TcSc.sync(vocab_dir: options[:vocab_dir], output_path: options[:output_path])
puts "Synced #{result[:total]} publications to #{result[:path]}."
puts "  TC/SC populated: #{result[:populated]}"
puts "  TC/SC blank (awaiting OIML confirmation): #{result[:blank]}"
