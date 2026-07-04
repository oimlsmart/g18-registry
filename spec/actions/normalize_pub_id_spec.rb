# frozen_string_literal: true

# Ruby-side test for publication ID normalization — mirrors the
# normalizePubId logic in useSuggestedActions.ts. Ensures both sides
# agree on the canonical form.

RSpec.describe "publication ID normalization" do
  # Mirrors the normalizePubId logic from useSuggestedActions.ts
  def normalize(id)
    id.to_s
      .gsub(/OIML\s+([RDGB])\s*/i, 'OIML \1')
      .gsub(/\s+/, " ")
      .strip
  end

  it "compacts spaced format (vocab style)" do
    expect(normalize("OIML R 76-1:2006")).to eq("OIML R76-1:2006")
    expect(normalize("OIML D 9:2004")).to eq("OIML D9:2004")
  end

  it "preserves compact format (bibliography style)" do
    expect(normalize("OIML R076-1:2006")).to eq("OIML R076-1:2006")
    expect(normalize("OIML D009:2004")).to eq("OIML D009:2004")
  end

  it "handles OIML B-series" do
    expect(normalize("OIML B 10-1:2004")).to eq("OIML B10-1:2004")
  end

  it "strips excess whitespace" do
    expect(normalize(" OIML  R  76-1:2006 ")).to eq("OIML R76-1:2006")
  end

  it "handles nil" do
    expect(normalize(nil)).to eq("")
  end
end
