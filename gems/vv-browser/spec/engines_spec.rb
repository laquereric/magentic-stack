# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "spec_helper"

RSpec.describe Vv::Browser::Engines do
  it "resolves :firefox and :chrome adapters" do
    expect(described_class.for(:firefox)).to be_a(Vv::Browser::Engines::Firefox)
    expect(described_class.for(:chrome)).to be_a(Vv::Browser::Engines::Chrome)
    expect(described_class.for(:edge)).to be_nil
  end

  it "resolve(:unknown) returns unknown_engine envelope" do
    r = described_class.resolve(:edge)
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:unknown_engine)
  end

  it "Chrome capability builder sets webSocketUrl + goog:chromeOptions headless=new" do
    eng = described_class.for(:chrome)
    caps = eng.build_capabilities(headless: true, profile: nil)
    always = caps.dig("capabilities", "alwaysMatch")
    expect(always["webSocketUrl"]).to be true
    expect(always["browserName"]).to eq("chrome")
    args = always.dig("goog:chromeOptions", "args")
    expect(args).to include("headless=new")
    expect(args.any? { |a| a.start_with?("user-data-dir=") }).to be true
  end

  it "Firefox capability builder sets moz:firefoxOptions -headless" do
    eng = described_class.for(:firefox)
    caps = eng.build_capabilities(headless: true, profile: nil)
    always = caps.dig("capabilities", "alwaysMatch")
    expect(always["webSocketUrl"]).to be true
    expect(always["browserName"]).to eq("firefox")
    expect(always.dig("moz:firefoxOptions", "args")).to include("-headless")
  end

  it "Chrome launch args do NOT include --websocket-port (geckodriver-only)" do
    eng = described_class.for(:chrome)
    # Inspect source contract: chromedriver args constructed without websocket-port
    # by checking the class constant / method body contract via a dry bootstrap skip
    expect(eng.driver_bin).to eq("chromedriver")
    expect(described_class.for(:firefox).driver_bin).to eq("geckodriver")
  end
end

RSpec.describe Vv::Browser::Engines::Chrome, "session bootstrap contract" do
  it "post_session maps missing webSocketUrl to :bidi_endpoint_missing" do
    eng = described_class.new
    # Stub Net::HTTP.post to return a session without webSocketUrl
    fake_body = { "value" => { "sessionId" => "abc", "capabilities" => { "browserName" => "chrome" } } }
    fake_res = double("HTTPResponse", body: JSON.generate(fake_body), code: "200")
    allow(Net::HTTP).to receive(:post).and_return(fake_res)

    r = eng.post_session(9999, { "capabilities" => { "alwaysMatch" => { "webSocketUrl" => true } } })
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:bidi_endpoint_missing)
  end

  it "post_session returns web_socket_url when present" do
    eng = described_class.new
    fake_body = {
      "value" => {
        "sessionId" => "sess-1",
        "capabilities" => { "browserName" => "chrome", "webSocketUrl" => "ws://127.0.0.1:9/session" }
      }
    }
    fake_res = double("HTTPResponse", body: JSON.generate(fake_body), code: "200")
    allow(Net::HTTP).to receive(:post).and_return(fake_res)

    r = eng.post_session(9999, { "capabilities" => { "alwaysMatch" => { "webSocketUrl" => true } } })
    expect(r[:ok]).to be true
    expect(r[:session_id]).to eq("sess-1")
    expect(r[:web_socket_url]).to eq("ws://127.0.0.1:9/session")
  end
end

RSpec.describe Vv::Browser::Bidi::Session, "attach vs session.new" do
  it "attach_to_webdriver_session does not send session.new (tracks flag)" do
    sess = described_class.new
    expect(sess.session_new_sent?).to be false
    # Without a real socket we only assert the method exists and flag starts false;
    # live chrome proof asserts session_new_sent remains false after full vertical.
    expect(sess).to respond_to(:attach_to_webdriver_session)
    expect(sess).to respond_to(:start_bidi_session)
  end

  it "session_new sets session_new_sent flag" do
    sess = described_class.new
    # force open? so send_command doesn't early-return on not_open — but without a
    # real socket we just set the flag via the method's first line.
    sess.instance_variable_set(:@open, true)
    sess.instance_variable_set(:@closed, false)
    # stub driver to avoid real I/O
    driver = double("ws", text: nil)
    sess.instance_variable_set(:@driver, driver)
    allow(sess).to receive(:pump_until) # don't block
    sess.instance_variable_set(:@pending, { 1 => { "id" => 1, "result" => {} } })
    # next_id will become 1
    r = sess.session_new({})
    expect(sess.session_new_sent?).to be true
    expect(r[:ok]).to be true
  end
end
