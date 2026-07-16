#!/usr/bin/env ruby
# frozen_string_literal: true

# Validate tc-sc/publications.yaml against the upstream vocab bibliography
# and report TC/SC coverage. Exits non-zero if the local file is out of sync.

require "optparse"
require_relative "../lib/g18"

repo_root = File.expand_path("..", __dir__)
options = {
  vocab_dir: ENV.fetch("VOCAB_G18_DIR", File.expand_path("vocab/datasets/g18", File.join(repo_root, ".."))),
  local_path: ENV.fetch("TC_SC_PATH", File.join(repo_root, "tc-sc", "publications.yaml")),
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--vocab-dir DIR", String, "Path to vocab datasets/g18") { |v| options[:vocab_dir] = v }
  opts.on("--local PATH", String, "tc-sc/publications.yaml path") { |v| options[:local_path] = v }
  opts.on("-h", "--help") { puts opts; exit 0 }
end.parse!

result = G18::TcSc::Validate.call(vocab_dir: options[:vocab_dir], local_path: options[:local_path])
ok = G18::TcSc::Validate.render_report(result)
exit(ok ? 0 : 1)
