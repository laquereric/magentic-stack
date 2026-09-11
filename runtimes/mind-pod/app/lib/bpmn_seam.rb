# frozen_string_literal: true

# The bpmn.* read logic, as plain Ruby over ActiveRecord.
#
# Deliberately NOT in the gem. plan_vv-bpmn-bbo.md opens by saying what it is
# and is not: "This file is the database design. Not the parser, not the BBO
# lift, not the CPCP face, not a graph mapping." The gem is schema-only, so the
# CPCP face lives here, in the pod app that owns the database -- ADR 0056 puts
# domain state on BACK.
#
# Deliberately NOT in the controller either. A controller needs a booted Rails
# to exercise, which would have made the gate structural: "the route exists,
# the method names are declared". Structure is not behaviour. As a plain class
# this is driven against an in-memory SQLite with the gem's own migration, so
# check_bpmn.py proves that a missing version REFUSES and an unrun one reports
# zero -- rather than proving that a file mentions both words.
#
# THE RULE THIS IS BUILT AROUND (plan §14):
#
#     Neither store is a place to mint identity.
#     (definition_key, version, element_id) and integer PKs are.
#
# Every lookup resolves by that grain. `spec_iri` is returned because callers
# want it, DERIVED on the way out by SpecIri, and never accepted as input. A
# seam that took an IRI as a key would be minting identity on the read path,
# and an identifier this seam did not author is one it cannot keep correct.
class BpmnSeam
  # A definition with ten thousand nodes is a legitimate thing to have and an
  # illegitimate thing to return in one envelope. The cap is declared so a
  # truncated answer can say it was truncated instead of looking complete.
  MAX_NODES = 500

  # Keys a caller might send hoping to look a row up by IRI. Refused by name:
  # see above.
  MINTED_KEYS = %w[spec_iri iri graph_iri uri].freeze

  def initialize(max_nodes: MAX_NODES)
    @max_nodes = max_nodes
  end

  def call(method, params)
    params = params || {}
    guard = refuse_minted_identity(params)
    return guard if guard

    case method
    when "bpmn.definitions" then definitions
    when "bpmn.definition" then definition(params)
    when "bpmn.node" then node(params)
    when "bpmn.run.stat" then run_stat(params)
    when "bpmn.deploy" then undecided_write(:deploy)
    when "bpmn.run.start" then undecided_write(:run_start)
    else
      fail_with(400, "unknown_operation", { "method" => method, "known" => self.class.methods_known })
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    # The engine's migrations have not run in this database. That is a
    # different answer from "no definitions exist", and collapsing them tells
    # an operator their model is empty when it is actually absent.
    fail_with(503, "bpmn_tables_missing", { "because" => e.message.to_s[0, 200] })
  end

  def self.methods_known
    %w[bpmn.definitions bpmn.definition bpmn.node bpmn.run.stat bpmn.deploy bpmn.run.start]
  end

  private

  def refuse_minted_identity(params)
    found = MINTED_KEYS.select { |k| params.key?(k) }
    return nil if found.empty?

    fail_with(400, "identity_not_minted_here",
              { "params" => found,
                "because" => "a row is named by (definition_key, version, element_id), not by an " \
                             "IRI. spec_iri is derived on the way out and is not a key; accepting " \
                             "one would make this seam the author of an identifier it does not own" })
  end

  # Every package and the versions under it. `is_latest` is reported rather
  # than assumed: two versions of one definition_key coexisting is the property
  # the schema exists for (§19.2), so a list showing only one would hide the
  # interesting part.
  def definitions
    rows = Vv::BpmnBbo::Package.order(:definition_key).map do |pkg|
      {
        "definition_key" => pkg.definition_key,
        "versions" => pkg.definition_versions.sort_by(&:version).map do |ver|
          { "version" => ver.version, "is_latest" => !!ver.is_latest,
            "source_digest" => ver.source_digest }
        end,
      }
    end
    ok("definitions" => rows)
  end

  def definition(params)
    pkg, ver, bad = resolve(params)
    return bad if bad

    nodes = flow_nodes_for(ver)
    total = nodes.count

    ok(
      "definition_key" => pkg.definition_key,
      "version" => ver.version,
      "is_latest" => !!ver.is_latest,
      "source_digest" => ver.source_digest,
      "processes" => ver.processes.order(:id).map { |p| { "element_id" => p.element_id, "name" => p.name } },
      "node_count" => total,
      "truncated" => total > @max_nodes,
      "nodes" => nodes.limit(@max_nodes).map { |n| node_row(n) },
    )
  end

  def node(params)
    element_id = params["element_id"].to_s
    return missing_param("element_id") if element_id.empty?

    pkg, ver, bad = resolve(params)
    return bad if bad

    found = flow_nodes_for(ver).where(element_id: element_id).first
    if found.nil?
      # An element that is not in THIS version may well be in another one, and
      # saying which versions exist is the difference between a dead end and a
      # next step.
      return fail_with(404, "element_missing",
                       { "definition_key" => pkg.definition_key, "version" => ver.version,
                         "element_id" => element_id })
    end

    ok("node" => node_row(found, detail: true))
  end

  # Absent is not empty. A version nobody has run reports zero instances; a
  # version that does not exist refuses. Same distinction rag.stat keeps
  # between a missing collection and an empty one, and for the same reason:
  # they are different answers and a caller is entitled to tell them apart.
  def run_stat(params)
    if params["definition_key"].to_s.empty?
      return ok(
        "process_instances" => Vv::BpmnBbo::Run::ProcessInstance.count,
        "activity_instances" => Vv::BpmnBbo::Run::ActivityInstance.count,
        "incidents" => Vv::BpmnBbo::Run::Incident.count,
      )
    end

    pkg, ver, bad = resolve(params)
    return bad if bad

    instances = Vv::BpmnBbo::Run::ProcessInstance.where(process_id: ver.processes.select(:id))
    ok(
      "definition_key" => pkg.definition_key,
      "version" => ver.version,
      "process_instances" => instances.count,
      "activity_instances" => Vv::BpmnBbo::Run::ActivityInstance
                                .where(process_instance_id: instances.select(:id)).count,
    )
  end

  # Declared and refused. An implementation that guessed would look decided.
  def undecided_write(op)
    because = {
      deploy: "v1 is schema-only by owner decision: there is no XML importer, so rows arrive " \
              "from migrations and seeds rather than from a file this seam parses. Deploying " \
              "here would mean inventing the importer plan_vv-bpmn-bbo.md §18 defers.",
      run_start: "the bpmn_bbo_run_* tables are a RECORD of execution, not an engine. Nothing " \
                 "advances a token, so starting an instance would write a process instance that " \
                 "never moves -- worse than refusing, because it looks like it worked.",
    }.fetch(op)

    fail_with(409, "bpmn_write_undecided", { "operation" => op.to_s, "because" => because })
  end

  # ---- helpers -------------------------------------------------------------

  def resolve(params)
    key = params["definition_key"].to_s
    return [nil, nil, missing_param("definition_key")] if key.empty?

    pkg = Vv::BpmnBbo::Package.find_by(definition_key: key)
    if pkg.nil?
      return [nil, nil, fail_with(404, "definition_key_missing",
                                  { "definition_key" => key, "known" => known_keys })]
    end

    requested = params["version"].to_s
    ver = if requested.empty?
            pkg.definition_versions.find_by(is_latest: true) ||
              pkg.definition_versions.order(:version).last
          else
            pkg.definition_versions.find_by(version: requested)
          end

    if ver.nil?
      return [nil, nil, fail_with(404, "version_missing",
                                  { "definition_key" => key, "version" => requested,
                                    "known" => pkg.definition_versions.map(&:version).sort })]
    end

    [pkg, ver, nil]
  end

  def flow_nodes_for(ver)
    Vv::BpmnBbo::FlowNode.joins(:process)
                         .where(bpmn_bbo_processes: { definition_version_id: ver.id })
                         .order(:id)
  end

  # spec_iri is DERIVED here, on the way out, by the gem's SpecIri concern. It
  # is never read from a column -- §19.7 plants that no graph_iri column
  # exists, and this is the read-path half of the same rule.
  def node_row(node, detail: false)
    row = {
      "element_id" => node.element_id,
      "type" => node.type,
      "name" => node.name,
      "spec_iri" => node.spec_iri,
    }
    return row unless detail

    row.merge(
      "gateway_direction" => node.gateway_direction,
      "default_flow" => node.default_flow&.element_id,
      "called_definition_key" => (node.called_definition_key if node.respond_to?(:called_definition_key)),
      "called_process_resolved" => !node.called_process_id.nil?,
      "outgoing" => node.outgoing.order(:id).map do |f|
        { "element_id" => f.element_id, "target" => f.target&.element_id,
          "is_default" => f.id == node.default_flow_id,
          "has_condition" => !f.condition_expression_id.nil? }
      end,
      "incoming" => node.incoming.order(:id).map do |f|
        { "element_id" => f.element_id, "source" => f.source&.element_id }
      end,
    )
  end

  def known_keys
    Vv::BpmnBbo::Package.order(:definition_key).pluck(:definition_key)
  end

  def ok(fields)
    { status: 200, json: { "ok" => true, "result" => fields } }
  end

  def missing_param(name)
    fail_with(400, "param_required", { "param" => name })
  end

  def fail_with(status, reason, because)
    { status: status, json: { "ok" => false, "reason" => reason, "because" => because } }
  end
end
