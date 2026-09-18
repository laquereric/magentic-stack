# frozen_string_literal: true

RSpec.describe Vv::Ios do
  let(:spec) { File.expand_path("../../../../vv-mobile/examples/user.yml", __dir__) }

  it "has a version" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "emits SwiftUI that imports the shared kit and never targets Android" do
    Dir.mktmpdir do |dir|
      result = described_class.generate(spec: spec, output_dir: dir)
      expect(result[:ok]).to eq(true), result[:because].to_s

      pkg = File.read(File.join(dir, "IosApp", "Package.swift"))
      expect(pkg).to include("swift-tools-version: 6.3")
      expect(pkg).to include('.package(path: "../SharedKit")')
      expect(pkg).to include(".iOS(.v17)")
      expect(pkg).not_to include("aarch64-unknown-linux-android")
      expect(pkg).not_to include("--swift-sdk")

      app = File.read(File.join(dir, "IosApp", "Sources", "IosApp", "IosAppApp.swift"))
      expect(app).to include("import SwiftUI")
      expect(app).to include("import SharedKit")
      expect(app).to include("@main")
      expect(app).to include("UserListView()")
      expect(app).to include("CatalogGalleryView()")
      expect(app).to include("TaskSlotView()")

      views = File.read(File.join(dir, "IosApp", "Sources", "IosApp", "Acia", "AciaViews.swift"))
      %w[PageShell PanelFrame SemanticText StatusBadge MetricStrip ContextBanner DrillDownCard DataList Timeline EvidencePanel DecisionForm ActionControl Disclosure FilterBar TabSet EmptyState RefusalNotice ScopeTrail ReferentBridge].each do |kind|
        expect(views).to include("public struct #{kind}View: View")
      end

      renderer = File.read(File.join(dir, "IosApp", "Sources", "IosApp", "Acia", "AciaRenderer.swift"))
      expect(renderer).to include("struct AciaRenderer")
      expect(renderer).to include("kind_not_in_catalog")

      slot = File.read(File.join(dir, "IosApp", "Sources", "IosApp", "Acia", "TaskSlotView.swift"))
      expect(slot).to include("AiuxCompiler.compile")
      expect(slot).to include("AiuxIntention.allCases")

      list = File.read(File.join(dir, "IosApp", "Sources", "IosApp", "Views", "UserListView.swift"))
      expect(list).to include("import SwiftUI")
      expect(list).to include("ContentUnavailableView")
      expect(list).to include("failure.because")

      vm = File.read(File.join(dir, "IosApp", "Sources", "IosApp", "ViewModels", "UserListModel.swift"))
      expect(vm).to include("@Observable")
      expect(vm).to include("@MainActor")
      expect(vm).to include("case .ok(let items):")
      expect(vm).to include("case .fail(let failure):")
    end
  end

  it "does not raise on a bad spec" do
    r = described_class.generate(spec: { "module" => "not-ok" }, output_dir: "/tmp")
    expect(r[:ok]).to eq(false)
    expect(r).to include(:reason, :because)
  end
end
