# frozen_string_literal: true

RSpec.describe Vv::Mobile do
  let(:spec) { File.expand_path("../../../examples/user.yml", __dir__) }

  it "has a version" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    expect(described_class::ANDROID_SDK).to eq("aarch64-unknown-linux-android28")
  end

  it "emits a UI-free Swift package with Envelope + actor repository" do
    Dir.mktmpdir do |dir|
      result = described_class.generate(spec: spec, output_dir: dir)
      expect(result[:ok]).to eq(true), result[:because].to_s
      expect(result[:android_sdk]).to eq("aarch64-unknown-linux-android28")
      expect(result[:count]).to be >= 6

      pkg = File.read(File.join(dir, "SharedKit", "Package.swift"))
      expect(pkg).to include("swift-tools-version: 6.3")
      expect(pkg).to include("aarch64-unknown-linux-android28")
      expect(pkg).to include("type: .dynamic")
      expect(pkg).not_to include("import SwiftUI")

      user = File.read(File.join(dir, "SharedKit", "Sources", "SharedKit", "Models", "User.swift"))
      expect(user).to include("public struct User: Codable, Sendable, Equatable, Hashable, Identifiable")
      expect(user).to include("public let id: String")
      expect(user).not_to include("import SwiftUI")
      expect(user).not_to include("import UIKit")

      repo = File.read(File.join(dir, "SharedKit", "Sources", "SharedKit", "Repositories", "UserRepository.swift"))
      expect(repo).to include("public actor UserRepository")
      expect(repo).to include("Envelope<[User]>")
      expect(repo).to include("Envelope<User>")

      envelope = File.read(File.join(dir, "SharedKit", "Sources", "SharedKit", "Envelope.swift"))
      expect(envelope).to include("case ok(T)")
      expect(envelope).to include("case fail(Failure)")
      expect(envelope).to include("public let reason: String")
      expect(envelope).to include("public let because: String")

      catalog = File.read(File.join(dir, "SharedKit", "Sources", "SharedKit", "Acia", "Catalog.swift"))
      expect(catalog).to include("public enum AciaComponent")
      expect(catalog).to include("public enum AiuxIntention")
      %w[PageShell PanelFrame SemanticText StatusBadge MetricStrip ContextBanner DrillDownCard DataList Timeline EvidencePanel DecisionForm ActionControl Disclosure FilterBar TabSet EmptyState RefusalNotice ScopeTrail ReferentBridge].each do |kind|
        expect(catalog).to include("= \"#{kind}\"")
      end
      %w[task.table task.form task.date task.confirm task.status task.error task.empty task.approval task.preview task.choice task.progress_steps task.citation].each do |kind|
        expect(catalog).to include("= \"#{kind}\"")
      end
      expect(catalog).not_to include("import SwiftUI")

      compiler = File.read(File.join(dir, "SharedKit", "Sources", "SharedKit", "Acia", "AiuxCompiler.swift"))
      expect(compiler).to include("date_kind_missing")
      expect(compiler).to include("kind_not_in_catalog")
      expect(compiler).to include("information_model_required")

      http = File.read(File.join(dir, "SharedKit", "Sources", "SharedKit", "Networking", "HTTPClient.swift"))
      expect(http).to include("URLSession.shared.data")
      expect(http).to include("async -> Envelope<T>")
    end
  end

  it "does not raise on a bad spec" do
    r = described_class.generate(spec: { "module" => "not-ok" }, output_dir: "/tmp")
    expect(r[:ok]).to eq(false)
    expect(r).to include(:reason, :because)
  end

  it "refuses an empty output_dir" do
    r = described_class.generate(spec: spec, output_dir: "  ")
    expect(r).to include(ok: false, reason: "invalid_output")
  end
end
