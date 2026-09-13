# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "spec_helper"

RSpec.describe "Chrome BiDi vertical (epic_115)", :chrome do
  before { skip_unless_chrome! }

  it "prove_chrome_vertical! navigates, evaluates, screenshots (skip if no chromedriver)" do
    res = Vv::Browser.prove_chrome_vertical!(js: "document.title")
    skip_if_chrome_unusable!(res)

    expect(res[:ok]).to be(true), "chrome vertical failed: #{res.inspect}"
    expect(res[:engine]).to eq(:chrome)
    expect(res[:session_new_sent]).to eq(false)
    expect(res[:value]).to eq("vv-browser-chrome-proof")
    expect(res[:screenshot_path]).to be_a(String)
    expect(File.file?(res[:screenshot_path])).to be true
    expect(File.size(res[:screenshot_path])).to be > 100
  end

  it "evaluate with engine: :chrome returns computed JS value" do
    dir = Dir.mktmpdir
    path = File.join(dir, "t.html")
    File.write(path, "<!doctype html><html><head><title>T</title></head>" \
                     "<body><script>window.__X=7*6</script></body></html>")
    res = Vv::Browser.evaluate("file://#{path}", "window.__X", engine: :chrome, headless: true, profile: nil)
    skip_if_chrome_unusable!(res)

    expect(res[:ok]).to be(true), res.inspect
    expect(res[:value]).to eq(42)
    expect(res[:session_new_sent]).to eq(false)
  ensure
    FileUtils.rm_rf(dir) if dir
  end
end

RSpec.describe "Firefox regression", :firefox do
  before { skip_unless_firefox! }

  it "evaluate with engine: :firefox still works (skip if no geckodriver)" do
    dir = Dir.mktmpdir
    path = File.join(dir, "t.html")
    File.write(path, "<!doctype html><html><head><title>FF</title></head><body>x</body></html>")
    res = Vv::Browser.evaluate("file://#{path}", "document.title", engine: :firefox, headless: true, profile: nil)
    skip_if_firefox_unusable!(res)

    expect(res[:ok]).to be(true), res.inspect
    expect(res[:value]).to eq("FF")
    expect(res[:engine]).to eq(:firefox)
  ensure
    FileUtils.rm_rf(dir) if dir
  end
end
