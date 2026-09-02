# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"
require "active_record"
require "sqlite3"

# Gap 69. Does not need Oxigraph: the refusal is about the outbox, not GRAPH.
RSpec.describe "gap 69 outbox schema status" do
  before do
    ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ::ActiveRecord::Base.connection.execute("SELECT 1")
  end

  def schedule
    Vv::Graph::Publisher::Immediate.new.schedule(
      ref: Vv::Graph::Ref.new("NoSuchModel", 1),
      generation: 1,
    )
  end

  it "schema_status is :missing when the table is not installed" do
    expect(Vv::Graph::ProjectionJob.schema_status).to eq(:missing)
    expect(Vv::Graph::ProjectionJob.available?).to be(false)
  end

  it "refuses schedule with :error when the outbox is not installed (does not drain)" do
    expect(Vv::Graph::ProjectionJob.schema_status).to eq(:missing)
    expect(schedule).to eq(:error)
    expect(Vv::Graph::ProjectionJob.schema_status).to eq(:missing)
  end

  it "schema_status is :available after ensure_schema! (specs only)" do
    expect(Vv::Graph::ProjectionJob.ensure_schema!).to be(true)
    expect(Vv::Graph::ProjectionJob.schema_status).to eq(:available)
  end

  it "schema_status is :check_failed when the lookup raises" do
    Vv::Graph::ProjectionJob.ensure_schema!
    allow(Vv::Graph::ProjectionJob.connection).to receive(:data_source_exists?)
      .and_raise(StandardError, "boom")
    expect(Vv::Graph::ProjectionJob.schema_status).to eq(:check_failed)
    expect(schedule).to eq(:error)
  end

  it "drain_pending! is ok:false when the outbox is not installed" do
    result = Vv::Graph::Publisher::Immediate.new.drain_pending!
    expect(result[:ok]).to be(false)
    expect(result[:errors]).to eq(1)
  end
end
