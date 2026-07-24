# frozen_string_literal: true

require_relative "../../lib/g18"

RSpec.describe G18::Export::Renderer do
  describe ".render_stem" do
    it "returns non-String input unchanged" do
      expect(described_class.render_stem(nil)).to be_nil
      expect(described_class.render_stem(42)).to eq(42)
    end

    it "returns strings without stem:[] unchanged" do
      expect(described_class.render_stem("hello world")).to eq("hello world")
    end

    it "renders stem:[...] markup (when plurimath is available)" do
      out = described_class.render_stem("alpha + stem:[beta] gamma")
      if G18::Export::Renderer::PLURIMATH_AVAILABLE
        expect(out).to include("<math")
        expect(out).to_not include("stem:[beta]")
      else
        expect(out).to include("<code>stem:[beta]</code>")
      end
    end
  end

  describe ".render_stem_deep" do
    it "recurses into Hash values" do
      h = { "a" => "stem:[x]", "b" => "plain" }
      result = described_class.render_stem_deep(h)
      expect(result["b"]).to eq("plain")
      expect(result["a"]).to_not eq("stem:[x]") if G18::Export::Renderer::PLURIMATH_AVAILABLE
    end

    it "recurses into Array values" do
      arr = ["stem:[x]", "plain", { nested: "stem:[y]" }]
      result = described_class.render_stem_deep(arr)
      expect(result[1]).to eq("plain")
    end

    it "returns primitives unchanged" do
      expect(described_class.render_stem_deep(42)).to eq(42)
      expect(described_class.render_stem_deep(true)).to eq(true)
    end
  end
end
