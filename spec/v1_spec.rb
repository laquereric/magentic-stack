# frozen_string_literal: true

require "spec_helper"

RSpec.describe "vv-html-components V1" do
  let(:root) { Vv::Html::Components::AssetPath.gem_root }
  let(:js) { File.read(Vv::Html::Components::AssetPath.js) }

  it "exposes VERSION and a real static asset" do
    expect(Vv::Html::Components::VERSION).to eq("0.2.0")
    expect(File).to be_file(Vv::Html::Components::AssetPath.js)
    expect(Vv::Html::Components::AssetPath.include_tag).to include(
      'src="/assets/vv-html-components/vv-html-components.js"'
    )
    expect(Vv::Html::Components::AssetPath.include_tag).to include("defer")
  end

  it "registers one runtime custom element and 19 attribute-selected adapters" do
    expect(js).to include("vv-component-runtime")
    expect(js).to include("customElements.define")
    expect(js).to include('attachShadow({ mode: "closed" })')
    %w[
      PageShell PanelFrame SemanticText StatusBadge MetricStrip
      ContextBanner DrillDownCard DataList Timeline EvidencePanel
      DecisionForm ActionControl Disclosure FilterBar TabSet
      EmptyState RefusalNotice ScopeTrail ReferentBridge
    ].each { |kind| expect(js).to include(%("#{kind}")) }
    expect(js).to include("data-ux-component-kind")
    expect(js).to include(".ux-render-root")
    expect(js).to include("data-vv-template-registry")
  end

  it "ships light and dark tokens via prefers-color-scheme" do
    expect(js).to include("prefers-color-scheme")
    expect(js).to include("--vv-canvas")
    expect(js).to include("--vv-ink")
    expect(js).to include("--vv-accent")
  end

  it "does not fetch, open shadow on visuals, or rewrite data-ux-* keys" do
    expect(js).not_to match(/\bfetch\s*\(/)
    expect(js).not_to match(/XMLHttpRequest/)
    expect(js).not_to include('attachShadow({ mode: "open" })')
    expect(js).not_to match(/removeAttribute\(\s*["']data-ux-/)
  end

  it "keeps include-absent fixture readable with original data-ux-* attributes" do
    html = File.read(root.join("test-fixtures/profile9-no-include.html"))
    expect(html).not_to include("vv-html-components.js")
    expect(html).to include('data-ux-component-kind="PageShell"')
    expect(html).to include("data-ux-node-id")
    expect(html).to include("data-ux-acia-digest")
  end

  it "degrades in jsdom: empty page, unknown 20th kind, no reparent (when jsdom is installed)" do
    test = root.join("test/v1.mjs").to_s
    jsdom = root.join("test/node_modules/jsdom")
    skip "jsdom not installed (cd test && npm install)" unless jsdom.directory?
    out = IO.popen(["node", test], chdir: root.to_s, err: [:child, :out], &:read)
    expect($?.success?).to eq(true), out
    expect(out).to include("V1 ok")
  end
end

RSpec.describe "vv-html-components V2" do
  let(:root) { Vv::Html::Components::AssetPath.gem_root }
  let(:js) { File.read(Vv::Html::Components::AssetPath.js) }

  it "parses data-ux-acia-document and requires document.rootNode" do
    expect(js).to include("data-ux-acia-document")
    expect(js).to include("application/ld+json")
    expect(js).to include("rootNode")
    expect(js).to include("aciaDigest")
    expect(js).to include("no-block")
    expect(js).to include("malformed")
    expect(js).to include("mismatch")
  end

  it "does not fetch payload" do
    expect(js).not_to match(/\bfetch\s*\(/)
  end

  it "runs the three gate tests plus matching join (when jsdom is installed)" do
    jsdom = root.join("test/node_modules/jsdom")
    skip "jsdom not installed (cd test && npm install)" unless jsdom.directory?
    out = IO.popen(["node", root.join("test/v2.mjs").to_s], chdir: root.to_s, err: [:child, :out], &:read)
    expect($?.success?).to eq(true), out
    expect(out).to include("NO BLOCK")
    expect(out).to include("MALFORMED BLOCK")
    expect(out).to include("DIGEST MISMATCH")
    expect(out).to include("matching block")
    expect(out).to include("V2 ok")
  end
end
