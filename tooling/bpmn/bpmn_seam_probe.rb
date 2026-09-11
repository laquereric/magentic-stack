#!/usr/bin/env ruby
# frozen_string_literal: true
#
# The bpmn.* seam behaves, against a real database.
#
# plan_vv-bpmn-bbo.md §14 is the rule this gate exists for:
#
#     Neither store is a place to mint identity.
#     (definition_key, version, element_id) and integer PKs are.
#
# So the assertions are about what the seam will and will not accept as a name
# for a row, and about the three distinctions that are cheap to collapse:
#
#   ABSENT != EMPTY        a version that does not exist REFUSES; a version
#                          nobody has run reports zero. Collapsing these tells
#                          an operator their model is empty when it is absent.
#   MIGRATED != EMPTY      un-migrated tables are bpmn_tables_missing, not
#                          "no definitions".
#   DERIVED != STORED      spec_iri is computed on the way out and refused on
#                          the way in.
#
# Run against an in-memory SQLite built from the gem's OWN migration, so this
# is the schema the pod runs rather than a fixture that resembles it. No Rails
# boot: the logic under test is lib/bpmn_seam.rb, which is plain Ruby for
# exactly this reason.

require "json"

ROOT = File.expand_path("../..", __dir__)
$LOAD_PATH.unshift File.join(ROOT, "gems/vv-bpmn-bbo/lib")
$LOAD_PATH.unshift File.join(ROOT, "runtimes/mind-pod/app/lib")

require "active_record"
require "vv-bpmn-bbo"

# The host class the first specialized ar_class names. Supplied by the host in
# production; supplied here so the datatype seed has something real to point at.
module Vv
  module Base
    class Actor < ActiveRecord::Base
      self.table_name = "actors"
    end
  end
end

require "bpmn_seam"

CHECKS = []

def check(name, ok, detail = "")
  CHECKS << { "assertion" => name, "ok" => !!ok, "detail" => detail.to_s[0, 240] }
  ok
end

def build_schema!
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Schema.define do
    create_table :actors do |t|
      t.string :name, null: false
      t.string :role_key, null: false
      t.timestamps
    end
  end
  require File.join(ROOT, "gems/vv-bpmn-bbo/db/migrate/20260911000000_create_vv_bpmn_bbo.rb")
  CreateVvBpmnBbo.new.change
end

# Two versions of one definition_key, because that coexistence is the property
# the schema was built for (§19.2) and the seam has to report it rather than
# quietly serve one.
def seed!
  Vv::BpmnBbo.seed_datatypes
  pkg = Vv::BpmnBbo::Package.create!(definition_key: "orders")

  v1 = Vv::BpmnBbo::DefinitionVersion.create!(package: pkg, version: "1", source_digest: "sha256:aaa")
  v2 = Vv::BpmnBbo::DefinitionVersion.create!(package: pkg, version: "2", source_digest: "sha256:bbb",
                                              is_latest: true)

  [v1, v2].each do |ver|
    proc_row = Vv::BpmnBbo::Process.create!(definition_version: ver, element_id: "Process_1",
                                            name: "Orders")
    gw = Vv::BpmnBbo::ExclusiveGateway.create!(process: proc_row, element_id: "Gateway_1",
                                               name: "Approved?", gateway_direction: "diverging")
    a = Vv::BpmnBbo::UserTask.create!(process: proc_row, element_id: "Task_A", name: "Approve")
    b = Vv::BpmnBbo::UserTask.create!(process: proc_row, element_id: "Task_B", name: "Reject")

    cond = Vv::BpmnBbo::Expression.create!(definition_version: ver, kind: "formal_expression",
                                           body: "amount > 100", language: "feel")
    Vv::BpmnBbo::SequenceFlow.create!(process: proc_row, element_id: "Flow_1", source: gw, target: a,
                                      condition_expression: cond)
    default = Vv::BpmnBbo::SequenceFlow.create!(process: proc_row, element_id: "Flow_2",
                                                source: gw, target: b)
    gw.update!(default_flow: default)
  end
  [pkg, v1, v2]
end

def main
  seam = BpmnSeam.new

  # MIGRATED != EMPTY. Before any schema exists the seam must say the tables
  # are absent, not that the model is empty.
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  r = seam.call("bpmn.definitions", {})
  check("unmigrated-is-not-empty",
        r[:json]["ok"] == false && r[:json]["reason"] == "bpmn_tables_missing",
        r[:json].to_json)

  build_schema!
  seed!

  # Both versions are visible, and the latest is named rather than guessed.
  r = seam.call("bpmn.definitions", {})
  defs = r[:json].dig("result", "definitions")
  versions = defs&.first&.dig("versions")&.map { |v| v["version"] }
  check("both-versions-listed", versions == %w[1 2], versions.inspect)
  check("latest-is-reported",
        defs&.first&.dig("versions")&.find { |v| v["is_latest"] }&.dig("version") == "2",
        defs.to_json[0, 160])

  # Omitting the version resolves to latest AND says which one it resolved to.
  r = seam.call("bpmn.definition", { "definition_key" => "orders" })
  check("default-version-is-latest-and-named",
        r[:json].dig("result", "version") == "2", r[:json].to_json[0, 160])

  # An explicit older version is served as itself.
  r = seam.call("bpmn.definition", { "definition_key" => "orders", "version" => "1" })
  check("explicit-version-served", r[:json].dig("result", "version") == "1")
  check("nodes-returned", r[:json].dig("result", "node_count") == 3,
        r[:json].dig("result", "node_count").inspect)

  # ABSENT != EMPTY, on both axes.
  r = seam.call("bpmn.definition", { "definition_key" => "nope" })
  check("missing-key-refuses", r[:json]["reason"] == "definition_key_missing", r[:json].to_json[0, 120])

  r = seam.call("bpmn.definition", { "definition_key" => "orders", "version" => "99" })
  check("missing-version-refuses", r[:json]["reason"] == "version_missing", r[:json].to_json[0, 120])

  r = seam.call("bpmn.run.stat", { "definition_key" => "orders" })
  check("unrun-version-reports-zero",
        r[:json]["ok"] == true && r[:json].dig("result", "process_instances") == 0,
        r[:json].to_json[0, 140])

  r = seam.call("bpmn.run.stat", { "definition_key" => "nope" })
  check("run-stat-missing-key-refuses", r[:json]["reason"] == "definition_key_missing")

  # DERIVED != STORED. spec_iri comes out; it does not go in.
  r = seam.call("bpmn.node", { "definition_key" => "orders", "version" => "1",
                               "element_id" => "Gateway_1" })
  iri = r[:json].dig("result", "node", "spec_iri")
  check("spec-iri-is-derived-on-the-way-out", iri == "urn:mm:bpmn:orders:1:Gateway_1", iri.inspect)

  # The same element in the other version is a DIFFERENT row and a different
  # IRI -- the grain is (key, version, element_id), not element_id alone.
  r2 = seam.call("bpmn.node", { "definition_key" => "orders", "version" => "2",
                                "element_id" => "Gateway_1" })
  check("same-element-id-two-versions-two-iris",
        r2[:json].dig("result", "node", "spec_iri") == "urn:mm:bpmn:orders:2:Gateway_1" && iri != r2[:json].dig("result", "node", "spec_iri"))

  for key in %w[spec_iri iri graph_iri uri]
    r = seam.call("bpmn.node", { key => "urn:mm:bpmn:orders:1:Gateway_1" })
    check("refuses-#{key}-as-a-key",
          r[:json]["reason"] == "identity_not_minted_here", r[:json].to_json[0, 120])
  end

  # The gateway's shape: default on the NODE, condition on the FLOW (§19.3).
  node = seam.call("bpmn.node", { "definition_key" => "orders", "version" => "1",
                                  "element_id" => "Gateway_1" })[:json].dig("result", "node")
  outgoing = node["outgoing"] || []
  default = outgoing.find { |f| f["is_default"] }
  conditional = outgoing.find { |f| f["has_condition"] }
  check("default-flow-on-the-node", default && default["element_id"] == "Flow_2", default.inspect)
  check("condition-on-the-flow", conditional && conditional["element_id"] == "Flow_1", conditional.inspect)
  check("default-flow-carries-no-condition", default && default["has_condition"] == false)

  # A missing element in a version that DOES exist is its own refusal.
  r = seam.call("bpmn.node", { "definition_key" => "orders", "version" => "1",
                               "element_id" => "Nope_1" })
  check("missing-element-refuses", r[:json]["reason"] == "element_missing", r[:json].to_json[0, 120])

  r = seam.call("bpmn.node", { "definition_key" => "orders", "version" => "1" })
  check("element-id-required", r[:json]["reason"] == "param_required")

  # WRITES ARE DECLARED AND REFUSED BY NAME.
  %w[bpmn.deploy bpmn.run.start].each do |m|
    r = seam.call(m, { "definition_key" => "orders" })
    check("#{m}-refuses",
          r[:json]["reason"] == "bpmn_write_undecided" && r[:status] == 409,
          r[:json].to_json[0, 120])
  end

  r = seam.call("bpmn.nonsense", {})
  check("unknown-method-refuses", r[:json]["reason"] == "unknown_operation")

  # Truncation announces itself rather than looking complete.
  tiny = BpmnSeam.new(max_nodes: 1)
  r = tiny.call("bpmn.definition", { "definition_key" => "orders", "version" => "1" })
  check("truncation-is-announced",
        r[:json].dig("result", "truncated") == true &&
          r[:json].dig("result", "node_count") == 3 &&
          r[:json].dig("result", "nodes").length == 1,
        r[:json].dig("result", "truncated").inspect)

  # §19.7, enforced against the live schema rather than against the migration
  # source: a table named flows, or a graph_iri column anywhere, is the shape
  # this design refused.
  tables = ActiveRecord::Base.connection.tables
  check("no-flows-table", !tables.include?("flows"), tables.grep(/flow/).inspect)
  strays = tables.flat_map do |t|
    ActiveRecord::Base.connection.columns(t).map(&:name).grep(/graph_iri|spec_iri/).map { |c| "#{t}.#{c}" }
  end
  check("no-stored-iri-columns", strays.empty?, strays.inspect)
  spec_tables = tables.select { |t| t.start_with?("bpmn_bbo_") }
  check("every-bpmn-table-is-prefixed", spec_tables.length >= 20, spec_tables.length.to_s)

  ok = CHECKS.all? { |c| c["ok"] }
  CHECKS.each { |c| puts format("  %s %s -- %s", c["ok"] ? "ok" : "FAIL", c["assertion"], c["detail"]) }
  puts "population: #{CHECKS.length} examined, 0 skipped"
  puts "bpmn seam: #{ok ? 'OK' : 'FAIL'}"
  exit(ok ? 0 : 1)
end

main
