#!/usr/bin/env ruby
# frozen_string_literal: true

# Thin entry point for the G 18 export pipeline. All logic lives in
# G18::Export modules under lib/g18/export/. This file just parses CLI
# options and invokes the pipeline.
#
# Usage:
#   scripts/export_for_vite.rb [--data-dir DIR] [--out-dir DIR] [--vocab-root DIR]
#
# Defaults: data/ and web/src/data/ relative to repo root.

require "optparse"
require_relative "../lib/g18/export"

repo_root = File.expand_path("..", __dir__)
default_vocab_root = File.expand_path("vocab/datasets", File.join(repo_root, ".."))
options = {
  data_dir: File.join(repo_root, "data"),
  out_dir: File.join(repo_root, "web", "src", "data"),
  vocab_root: ENV.fetch("VOCAB_ROOT", default_vocab_root),
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--data-dir DIR", String) { |v| options[:data_dir] = v }
  opts.on("--out-dir DIR", String) { |v| options[:out_dir] = v }
  opts.on("--vocab-root DIR", String) { |v| options[:vocab_root] = v }
end.parse!

G18::Export::Pipeline.new(options).call
