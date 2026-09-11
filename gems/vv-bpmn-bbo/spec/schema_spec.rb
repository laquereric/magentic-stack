# frozen_string_literal: true

require "spec_helper"

RSpec.describe "vv-bpmn-bbo schema" do
  def tables
    ActiveRecord::Base.connection.tables
  end

  def columns(table)
    ActiveRecord::Base.connection.columns(table).map(&:name)
  end

  it "seeds LinkML builtins and Actor; Boolean is not a name" do
    result = Vv::BpmnBbo.seed_datatypes
    expect(result[:ok]).to eq(true)
    names = Vv::BpmnBbo::Datatype.where(definition_version_id: nil).pluck(:name)
    Vv::BpmnBbo::Datatype::LINKML_BUILTINS.each_key do |n|
      expect(names).to include(n)
    end
    expect(names).to include("Vv::Base::Actor")
    expect(names).not_to include("Boolean")
    actor = Vv::BpmnBbo::Datatype.find_by!(kind: "ar_class", name: "Vv::Base::Actor")
    expect(actor.ar_class_name).to eq("Vv::Base::Actor")
  end

  it "keeps two versions of one definition_key; Flow_1 is two rows" do
    Vv::BpmnBbo.seed_datatypes
    pkg = Vv::BpmnBbo::Package.create!(definition_key: "payments", name: "Payments")
    v1 = Vv::BpmnBbo::DefinitionVersion.create!(
      package: pkg, version: "1", source_digest: "sha256:aaa", is_latest: true
    )
    v2 = Vv::BpmnBbo::DefinitionVersion.create!(
      package: pkg, version: "2", source_digest: "sha256:bbb", is_latest: true
    )
    expect(v1.reload.is_latest).to eq(false)
    expect(v2.reload.is_latest).to eq(true)
    p1 = Vv::BpmnBbo::Process.create!(definition_version: v1, element_id: "Process_1")
    p2 = Vv::BpmnBbo::Process.create!(definition_version: v2, element_id: "Process_1")
    n1 = Vv::BpmnBbo::UserTask.create!(process: p1, element_id: "Flow_1", name: "v1")
    n2 = Vv::BpmnBbo::UserTask.create!(process: p2, element_id: "Flow_1", name: "v2")
    expect(Vv::BpmnBbo::FlowNode.where(element_id: "Flow_1").count).to eq(2)
    expect(n1.spec_iri).to include(":1:Flow_1")
    expect(n2.spec_iri).to include(":2:Flow_1")
  end

  it "stores exclusive-gateway default on the node and condition on the flow" do
    Vv::BpmnBbo.seed_datatypes
    pkg = Vv::BpmnBbo::Package.create!(definition_key: "gw")
    ver = Vv::BpmnBbo::DefinitionVersion.create!(package: pkg, version: "1", source_digest: "sha256:c")
    proc = Vv::BpmnBbo::Process.create!(definition_version: ver, element_id: "P")
    gw = Vv::BpmnBbo::ExclusiveGateway.create!(process: proc, element_id: "Gw")
    a = Vv::BpmnBbo::UserTask.create!(process: proc, element_id: "A")
    b = Vv::BpmnBbo::UserTask.create!(process: proc, element_id: "B")
    expr = Vv::BpmnBbo::Expression.create!(
      definition_version: ver, kind: "formal_expression", body: "amount > 100", language: "feel"
    )
    cond = Vv::BpmnBbo::SequenceFlow.create!(
      process: proc, element_id: "f_cond", source: gw, target: a, condition_expression: expr
    )
    default = Vv::BpmnBbo::SequenceFlow.create!(
      process: proc, element_id: "f_default", source: gw, target: b
    )
    gw.update!(default_flow: default)
    expect(cond.condition_expression.body).to eq("amount > 100")
    expect(default.condition_expression).to be_nil
    expect(gw.reload.default_flow_id).to eq(default.id)
    expect(default.attributes.key?("body")).to eq(false)
  end

  it "grounds Actor as a linked record and refuses a string payload" do
    Vv::BpmnBbo.seed_datatypes
    actor = Vv::Base::Actor.create!(name: "Priya", role_key: "manager")
    dt = Vv::BpmnBbo::Datatype.find_by!(kind: "ar_class", name: "Vv::Base::Actor")
    ok = Vv::BpmnBbo::TypedValue.create!(
      datatype: dt, record_type: "Vv::Base::Actor", record_id: actor.id
    )
    expect(ok).to be_persisted
    bad = Vv::BpmnBbo::TypedValue.new(datatype: dt, string_value: "Priya")
    expect(bad.save).to eq(false)
    expect(bad.errors[:base].join).to match(/ar_class/)

    pkg = Vv::BpmnBbo::Package.create!(definition_key: "actor-task")
    ver = Vv::BpmnBbo::DefinitionVersion.create!(package: pkg, version: "1", source_digest: "sha256:d")
    proc = Vv::BpmnBbo::Process.create!(definition_version: ver, element_id: "P")
    idef = Vv::BpmnBbo::ItemDefinition.create!(
      definition_version: ver, element_id: "Item_actor", item_kind: "information", datatype: dt
    )
    inst = Vv::BpmnBbo::Run::ProcessInstance.create!(process: proc, state: "running")
    var = Vv::BpmnBbo::Run::Variable.create!(
      process_instance: inst, name: "assignee", item_definition: idef, value: ok
    )
    expect(var.value.record_id).to eq(actor.id)
  end

  it "refuses deleting an ItemDefinition a run variable still references" do
    Vv::BpmnBbo.seed_datatypes
    dt = Vv::BpmnBbo::Datatype.find_by!(name: "string")
    val = Vv::BpmnBbo::TypedValue.create!(datatype: dt, string_value: "x")
    pkg = Vv::BpmnBbo::Package.create!(definition_key: "restrict")
    ver = Vv::BpmnBbo::DefinitionVersion.create!(package: pkg, version: "1", source_digest: "sha256:e")
    proc = Vv::BpmnBbo::Process.create!(definition_version: ver, element_id: "P")
    idef = Vv::BpmnBbo::ItemDefinition.create!(
      definition_version: ver, element_id: "I", item_kind: "information", datatype: dt
    )
    inst = Vv::BpmnBbo::Run::ProcessInstance.create!(process: proc, state: "running")
    Vv::BpmnBbo::Run::Variable.create!(
      process_instance: inst, name: "v", item_definition: idef, value: val
    )
    expect { idef.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    expect(Vv::BpmnBbo::ItemDefinition.exists?(idef.id)).to eq(true)
  end

  it "allows CallActivity with a key and a null called_process_id" do
    Vv::BpmnBbo.seed_datatypes
    pkg = Vv::BpmnBbo::Package.create!(definition_key: "caller")
    ver = Vv::BpmnBbo::DefinitionVersion.create!(package: pkg, version: "1", source_digest: "sha256:f")
    proc = Vv::BpmnBbo::Process.create!(definition_version: ver, element_id: "P")
    call = Vv::BpmnBbo::CallActivity.create!(
      process: proc, element_id: "Call_1", called_definition_key: "payments"
    )
    expect(call).to be_persisted
    expect(call.called_process_id).to be_nil
    expect(call.called_definition_key).to eq("payments")
    other = Vv::BpmnBbo::Package.create!(definition_key: "payments")
    over = Vv::BpmnBbo::DefinitionVersion.create!(package: other, version: "1", source_digest: "sha256:g")
    callee = Vv::BpmnBbo::Process.create!(definition_version: over, element_id: "Pay", callable: true)
    call.update!(called_process: callee)
    expect(call.reload.called_definition_key).to eq("payments")
    expect(call.called_process_id).to eq(callee.id)
  end

  it "has no flows table and no graph_iri column" do
    expect(tables).not_to include("flows")
    expect(tables.grep(/^bpmn_bbo_/)).not_to be_empty
    expect(tables.grep(/^bpmn_bbo_run_/)).not_to be_empty
    tables.grep(/^bpmn_bbo/).each do |t|
      expect(columns(t)).not_to include("graph_iri")
    end
  end
end
