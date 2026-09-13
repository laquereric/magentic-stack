# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

ENV["LANG"] ||= "en_US.UTF-8"
ENV["LC_ALL"] ||= "en_US.UTF-8"

require "rspec"
require "tmpdir"
require "fileutils"
require "json"
require "net/http"
require "uri"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv/browser"

module BrowserSpecHelpers
  module_function

  def chrome_available?
    path = Vv::Browser.which("chromedriver")
    return false if path.nil? || path.to_s.empty?
    return false unless File.exist?(path)

    true
  rescue ::StandardError
    false
  end

  def firefox_available?
    path = Vv::Browser.which("geckodriver")
    return false if path.nil? || path.to_s.empty?
    return false unless File.exist?(path)

    true
  rescue ::StandardError
    false
  end

  # Live Chrome/chromedriver environment errors that must not fail CI — skip instead.
  def chrome_env_unusable?(res)
    return true if res.nil?
    return true if res.is_a?(Hash) && (res[:skipped] || res["skipped"])
    return false unless res.is_a?(Hash) && res[:ok] == false

    reason = res[:reason].to_s
    because = res[:because].to_s
    msg = because.downcase
    reason == "no_driver" ||
      reason == "bidi_endpoint_missing" ||
      reason == "driver_not_ready" ||
      reason == "webdriver_session_failed" ||
      reason == "session_failed" ||
      msg.include?("session not created") ||
      msg.include?("only supports chrome version") ||
      msg.include?("chrome failed to start") ||
      msg.include?("chromedriver not in path") ||
      msg.include?("cannot find chrome") ||
      msg.include?("no such file") ||
      msg.include?("connection refused")
  end

  def firefox_env_unusable?(res)
    return true if res.nil?
    return true if res.is_a?(Hash) && (res[:skipped] || res["skipped"])
    return false unless res.is_a?(Hash) && res[:ok] == false

    reason = res[:reason].to_s
    msg = res[:because].to_s.downcase
    reason == "no_driver" ||
      reason == "bidi_endpoint_missing" ||
      reason == "driver_not_ready" ||
      reason == "webdriver_session_failed" ||
      reason == "session_failed" ||
      msg.include?("geckodriver not in path") ||
      msg.include?("session not created") ||
      msg.include?("connection refused")
  end

  def skip_unless_chrome!
    skip "chromedriver not in PATH" unless chrome_available?
  end

  def skip_unless_firefox!
    skip "geckodriver not in PATH" unless firefox_available?
  end

  def skip_if_chrome_unusable!(res)
    return unless chrome_env_unusable?(res)

    skip "chrome live env unavailable: #{res.is_a?(Hash) ? (res[:because] || res[:reason]) : res.inspect}"
  end

  def skip_if_firefox_unusable!(res)
    return unless firefox_env_unusable?(res)

    skip "firefox live env unavailable: #{res.is_a?(Hash) ? (res[:because] || res[:reason]) : res.inspect}"
  end
end

RSpec.configure do |c|
  c.include BrowserSpecHelpers
  c.expect_with(:rspec) { |e| e.syntax = :expect }
end
