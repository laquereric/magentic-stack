# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Vv::Figma::Assets do
  it "copies the plugin load into an overlay public/" do
    Dir.mktmpdir do |dir|
      r = described_class.install!(dir)
      expect(r[:ok]).to be true
      expect(File.file?(File.join(dir, "vv-figma.js"))).to be true
      expect(File.file?(File.join(dir, "vv-figma.html"))).to be true
      js = File.read(File.join(dir, "vv-figma.js"))
      expect(js).to include("VvFigma")
      expect(js).to include("applyEffect")
      expect(js).not_to include("window.miro")
    end
  end

  it "refuses a blank destination" do
    r = described_class.install!("")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:dest_required)
  end
end
