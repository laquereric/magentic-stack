# frozen_string_literal: true

RSpec.describe Vv::Android do
  let(:spec) { File.expand_path("../../../../vv-mobile/examples/user.yml", __dir__) }

  it "has a version and the Android SDK triple" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    expect(described_class::ANDROID_SDK).to eq("aarch64-unknown-linux-android28")
  end

  it "emits Swift JNI/@c exports and refuses SwiftUI" do
    Dir.mktmpdir do |dir|
      result = described_class.generate(spec: spec, output_dir: dir)
      expect(result[:ok]).to eq(true), result[:because].to_s
      expect(result[:android_sdk]).to eq("aarch64-unknown-linux-android28")

      pkg = File.read(File.join(dir, "AndroidKit", "Package.swift"))
      expect(pkg).to include("swift-tools-version: 6.3")
      expect(pkg).to include("aarch64-unknown-linux-android28")
      expect(pkg).to include("type: .dynamic")
      expect(pkg).to include('.package(path: "../SharedKit")')
      expect(pkg).not_to include("import SwiftUI")

      reexport = File.read(File.join(dir, "AndroidKit", "Sources", "AndroidKit", "Reexport.swift"))
      expect(reexport).to include("@_exported import SharedKit")
      expect(reexport).not_to include("import SwiftUI")

      bridge = File.read(File.join(dir, "AndroidKit", "Sources", "AndroidKit", "CBridge.swift"))
      expect(bridge).to include("@c")
      expect(bridge).to include("public func vv_android_abi_version() -> Int32")
      expect(bridge).to include("public func vv_android_model_count() -> Int32")
      expect(bridge).not_to include("import SwiftUI")

      pins = File.read(File.join(dir, "AndroidKit", "Sources", "AndroidKit", "ModelPins.swift"))
      expect(pins).to include("vv_android_model_user_name")
      expect(pins).not_to include("import SwiftUI")
      expect(pins).not_to include("import UIKit")

      catalog = File.read(File.join(dir, "AndroidKit", "Sources", "AndroidKit", "CatalogPins.swift"))
      expect(catalog).to include("vv_android_acia_count")
      expect(catalog).to include("vv_android_aiux_count")
      expect(catalog).to include("vv_android_acia_contains")
      expect(catalog).to include("vv_android_aiux_contains")
      %w[PageShell ReferentBridge EmptyState].each { |k| expect(catalog).to include(k.inspect) }
      %w[task.form task.empty task.citation].each { |k| expect(catalog).to include(k.inspect) }
      expect(catalog).not_to include("import SwiftUI")
    end
  end

  it "does not raise on a bad spec" do
    r = described_class.generate(spec: { "module" => "not-ok" }, output_dir: "/tmp")
    expect(r[:ok]).to eq(false)
    expect(r).to include(:reason, :because)
  end
end
