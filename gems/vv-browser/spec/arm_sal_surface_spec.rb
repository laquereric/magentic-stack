# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "rspec"
require "tmpdir"
require "fileutils"
require_relative "../lib/vv/browser"

RSpec.describe Vv::Browser, ".arm_sal_surface" do
  it "arms a local HTML file without spawning" do
    dir = Dir.mktmpdir
    path = File.join(dir, "page.html")
    File.write(path, "<html><body>hi</body></html>")
    res = described_class.arm_sal_surface(path: path, title: "t", spawn: false)
    expect(res[:ok]).to be true
    expect(res[:armed]).to be true
    expect(res[:spawn]).to be false
    expect(res[:path]).to eq(path)
    expect(res[:url]).to start_with("file://")
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  it "writes html= body when path missing" do
    res = described_class.arm_sal_surface(html: "<html><body>x</body></html>", title: "x", spawn: false)
    expect(res[:ok]).to be true
    expect(File.file?(res[:path])).to be true
    expect(File.read(res[:path])).to include("body")
  end

  it "refuses when neither path nor html" do
    res = described_class.arm_sal_surface(spawn: false)
    expect(res[:ok]).to be false
    expect(res[:reason]).to eq(:no_surface_file)
  end
end
