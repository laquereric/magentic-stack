# frozen_string_literal: true

RSpec.describe Vv::Mobile::Catalog do
  it "ships 19 ACIA components and 12 AIUX intentions" do
    expect(described_class::ACIA_COMPONENTS.size).to eq(19)
    expect(described_class::AIUX_INTENTIONS.size).to eq(12)
    expect(described_class::ACIA_COMPONENTS).to include("PageShell", "ReferentBridge", "EmptyState")
    expect(described_class.aiux_intentions.map { |i| i["kind"] }).to eq(%w[
      task.table task.form task.date task.confirm task.status task.error
      task.empty task.approval task.preview task.choice task.progress_steps task.citation
    ])
  end

  it "refuses unknown kinds" do
    expect(described_class.acia_kind?("DateInput")).to eq(false)
    expect(described_class.acia_kind?("DateInput", version: described_class::GHIS_20)).to eq(true)
    expect(described_class.aiux_kind?("task.draw")).to eq(false)
    expect(described_class.aiux_kind?("task.form")).to eq(true)
  end
end

RSpec.describe Vv::Mobile::Compiler do
  it "compiles task.empty to PageShell + EmptyState" do
    r = described_class.compile(task_kind: "task.empty")
    expect(r[:ok]).to eq(true)
    expect(r[:document]["root"]["componentKind"]).to eq("PageShell")
    kinds = r[:document]["root"]["children"].map { |c| c["componentKind"] }
    expect(kinds).to include("EmptyState")
  end

  it "refuses date on ghis-19" do
    r = described_class.compile(task_kind: "task.date", catalog_version: "ghis-19@1")
    expect(r).to include(ok: false, reason: "date_kind_missing")
  end

  it "refuses unknown AIUX kinds" do
    r = described_class.compile(task_kind: "task.draw")
    expect(r).to include(ok: false, reason: "kind_not_in_catalog")
  end

  it "refuses task.form without fields" do
    r = described_class.compile(task_kind: "task.form")
    expect(r).to include(ok: false, reason: "information_model_required")
  end

  it "compiles task.form with fields" do
    r = described_class.compile(task_kind: "task.form", fields: [{ "name" => "decision", "datatype" => "enum" }])
    expect(r[:ok]).to eq(true)
    kinds = r[:document]["root"]["children"].map { |c| c["componentKind"] }
    expect(kinds).to include("DecisionForm", "ActionControl")
  end
end
