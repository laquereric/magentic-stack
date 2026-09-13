# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1
#
# Cucumber steps are one-liners over Vv::Browser::Procedures / Probe.
# Those methods are the RSpec leaves in spec/vv/browser/procedures_spec.rb.

Given("a live board") do
  url = board_url!
  unless procedures.reachable?(url)
    skip_this_scenario("board not reachable at #{url}")
  end
end

Given("a fixture page that throws {string}") do |message|
  dir = Dir.mktmpdir("vv-browser-cuke-")
  self.fixture_path = File.join(dir, "throw.html")
  File.write(fixture_path, procedures.throw_fixture_html(message))
  open_probe!("file://#{fixture_path}")
end

When("I open the board") do
  open_probe!(board_url!)
end

When("I apply the {string} template") do |name|
  res = probe.apply_template(name)
  probe.wait(0.8)
  val = res[:value]
  ok = val.is_a?(Hash) ? val["ok"] != false : true
  raise "apply #{name.inspect} failed: #{res.inspect}" unless ok
end

When("I click the element {string}") do |id|
  res = probe.click_id(id)
  val = res[:value]
  ok = val.is_a?(Hash) ? val["ok"] != false : true
  raise "click ##{id} failed: #{res.inspect}" unless ok
end

When("I wait {float} seconds") do |seconds|
  probe.wait(seconds)
end

Then("the document title is {string}") do |want|
  snapshot!
  expect(last_snapshot[:title]).to eq(want)
end

Then("fabric is present") do
  snapshot!
  snap = last_snapshot[:snapshot]
  fabric = snap.is_a?(Hash) ? (snap["fabric"] || snap[:fabric]) : nil
  expect(fabric).to eq("object")
end

Then("there are no javascript errors") do
  snapshot!
  errs = last_snapshot[:javascript_errors]
  expect(errs).to eq([]), "javascript errors: #{errs.inspect}"
end

Then("there is no javascript error matching {string}") do |pattern|
  snapshot!
  rx = Regexp.new(pattern, Regexp::IGNORECASE)
  hits = last_snapshot[:javascript_errors].select { |e| (e[:text] || e["text"]).to_s.match?(rx) }
  expect(hits).to eq([]), "matched #{pattern}: #{hits.inspect}"
end

Then("there is no Fabric type-getter error") do
  snapshot!
  hits = last_snapshot[:getter_errors]
  expect(hits).to eq([]), "Fabric type getter: #{hits.inspect}"
end

Then("the canvas has objects") do
  snapshot!
  snap = last_snapshot[:snapshot]
  count = snap.is_a?(Hash) ? (snap["layerCount"] || snap[:layerCount]).to_i : 0
  expect(count).to be > 0
end

Then("the save status is a blob digest") do
  snapshot!
  snap = last_snapshot[:snapshot]
  status = snap.is_a?(Hash) ? (snap["status"] || snap[:status]).to_s : ""
  expect(procedures.status_looks_like_digest?(status)).to eq(true),
    "save status was #{status.inspect} (want sha256:<64 hex>)"
end

Then("no network response is status {int}") do |code|
  snapshot!
  hits = last_snapshot[:network].select { |n| (n[:status] || n["status"]).to_i == code }
  expect(hits).to eq([]), "HTTP #{code}: #{hits.inspect}"
end

Then("javascript errors include {string}") do |fragment|
  snapshot!
  texts = last_snapshot[:javascript_errors].map { |e| (e[:text] || e["text"]).to_s }
  expect(texts.join("\n")).to include(fragment)
end
