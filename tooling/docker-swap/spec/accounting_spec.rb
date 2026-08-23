# frozen_string_literal: true
RSpec.describe Vv::DockerSwap::Accounting do
  AImg = Vv::DockerSwap::Accounting::Image

  # One common parent (base 800MB + gems 400MB) plus a 50MB code layer each.
  def family(n)
    (1..n).map do |i|
      AImg.new(name: "svc#{i}", layers: { "base" => 800, "gems" => 400, "code#{i}" => 50 })
    end
  end

  it "counts each distinct layer exactly once" do
    r = described_class.total_disk(family(10))
    expect(r[:bytes]).to eq(800 + 400 + (50 * 10))
    expect(r[:layer_count]).to eq(12)
  end

  it "exposes the naive sum as the trap it is" do
    expect(described_class.naive_sum(family(10))[:bytes]).to eq(1250 * 10)
  end

  it "quantifies the overcount so the win does not read as a loss" do
    r = described_class.overcount(family(10))
    expect(r[:real]).to eq(1700)
    expect(r[:naive]).to eq(12_500)
    expect(r[:bytes]).to eq(10_800)
    expect(r[:ratio]).to eq(7.35)
  end

  it "reports shared bytes as the layers more than one image references" do
    expect(described_class.shared_bytes(family(10))[:bytes]).to eq(1200)
  end

  it "reports unique bytes per image" do
    fam = family(3)
    expect(described_class.unique_bytes(fam.first, fam)[:bytes]).to eq(50)
  end

  it "agrees with docker: displayed SIZE is SHARED + UNIQUE" do
    fam = family(3)
    img = fam.first
    shared_for_img = img.layers.sum { |id, sz| fam.count { |o| o.layers.key?(id) } > 1 ? sz : 0 }
    unique_for_img = described_class.unique_bytes(img, fam)[:bytes]
    expect(shared_for_img + unique_for_img).to eq(img.layers.values.sum)
  end

  it "finds no sharing when every image has its own parent" do
    solo = (1..3).map { |i| AImg.new(name: "s#{i}", layers: { "base#{i}" => 800, "code#{i}" => 50 }) }
    expect(described_class.shared_bytes(solo)[:bytes]).to eq(0)
    expect(described_class.overcount(solo)[:bytes]).to eq(0)
  end

  it "refuses inconsistent layer sizes instead of silently picking one" do
    bad = [AImg.new(name: "a", layers: { "base" => 800 }),
           AImg.new(name: "b", layers: { "base" => 900 })]
    expect(described_class.total_disk(bad)).to include(ok: false, reason: :inconsistent_layer_size)
  end

  it "refuses an empty image set" do
    expect(described_class.total_disk([])).to include(ok: false, reason: :no_images)
  end

  it "refuses unique_bytes for an image outside the set" do
    r = described_class.unique_bytes(AImg.new(name: "ghost", layers: {}), family(2))
    expect(r).to include(ok: false, reason: :image_not_in_set)
  end
end
