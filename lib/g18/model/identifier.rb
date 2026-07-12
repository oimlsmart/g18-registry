# frozen_string_literal: true

require "digest"

module G18
  module Model
    # Identifier helpers shared across the domain model: slugification
    # (for URL-safe keys) and deterministic UUID generation (for stable
    # cross-run identity).
    #
    # All domain entities that produce a URL slug or a stable ID delegate
    # here instead of rolling their own.
    module Identifier
      module_function

      # URL-safe slug: lowercase, non-alphanumerics collapsed to `-`,
      # leading/trailing `-` stripped.
      def slugify(value)
        value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      end

      # Deterministic UUID v5-style identifier from a stable name.
      # Same name always produces the same UUID; migration is reproducible.
      def deterministic_uuid(name, namespace: "concepts-management-term")
        sha1 = Digest::SHA1.digest("#{namespace}:#{name}")
        sha1 = sha1.dup
        sha1.setbyte(6, (sha1.getbyte(6) & 0x0F) | 0x50)
        sha1.setbyte(8, (sha1.getbyte(8) & 0x3F) | 0x80)
        hex = sha1.bytes.first(16).map { |b| format("%02x", b) }.join
        "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
      end
    end
  end
end
