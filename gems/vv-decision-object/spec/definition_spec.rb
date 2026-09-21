# frozen_string_literal: true

RSpec.describe Vv::DecisionObject::Definition do
  it "builds a complete six-layer definition" do
    definition = triage_definition
    expect(definition).to be_valid
    expect(definition).to be_complete
    expect(definition.missing_layers).to be_empty
    expect(definition.layers.keys).to eq(Vv::DecisionObject::LAYERS)
  end

  it "names the layers a definition is missing without refusing it" do
    definition = Vv::DecisionObject.define(:half_built) do |d|
      d.intent "Decide something"
      d.noul :risky, instructions: "Is this risky?"
    end[:data]

    expect(definition).to be_valid
    expect(definition).not_to be_complete
    expect(definition.missing_layers).to eq(%i[constraint signal commitment feedback])
  end

  it "refuses a definition with no intent and no evaluation layer" do
    result = Vv::DecisionObject.define(:empty)
    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq(:definition_invalid)
    expect(result[:problems]).to include(a_string_including("an intent is required"))
    expect(result[:problems]).to include(a_string_including("no evaluation layer"))
  end

  it "reports every problem at once rather than the first" do
    result = Vv::DecisionObject.define(:messy) do |d|
      d.intent ""
      d.choice(:route, instructions: "?", criteria: { a: "x", b: "y" })
      d.constraint(:bare, because: "")
    end
    expect(result[:problems].size).to be >= 3
  end

  it "refuses duplicate question names" do
    result = Vv::DecisionObject.define(:dupes) do |d|
      d.intent "Decide"
      d.ask refund_question
      d.ask refund_question
    end
    expect(result[:problems]).to include(a_string_including("duplicate question(s) refund_requested"))
  end

  it "refuses a floor set for a question nobody declared" do
    result = Vv::DecisionObject.define(:stray_floor) do |d|
      d.intent "Decide"
      d.ask refund_question
      d.thresholds floors: { route: 0.9 }
    end
    expect(result[:problems]).to include(a_string_including("floors set for undeclared question(s) route"))
  end

  it "accepts a decision table as the evaluation layer on its own" do
    result = Vv::DecisionObject.define(:rules_only) do |d|
      d.intent "Apply the refund policy"
      d.decision_table(:authority, inputs: %i[amount], outputs: %i[approver],
                                   rules: [{ when: { amount: :any }, then: { approver: "manager" } }])
    end
    expect(result[:ok]).to be(true)
    expect(result[:data].table(:authority)).to be_a(Vv::DecisionObject::Table)
  end

  it "looks up questions by name" do
    definition = triage_definition
    expect(definition.question(:route)).to be_a(Vv::DecisionObject::Choice)
    expect(definition.question(:nope)).to be_nil
    expect(definition.question_names).to eq(%i[route refund_requested])
  end

  describe "#instantiate" do
    it "binds a definition to one situation" do
      result = triage_definition.instantiate(state: clean_state, actor: "agent:triage")
      expect(result[:ok]).to be(true)
      expect(result[:data]).to be_a(Vv::DecisionObject::Decision)
      expect(result[:data].lifecycle).to eq(:instantiated)
      expect(result[:data].id).to start_with("do_")
    end

    it "refuses state the signal layer never declared" do
      result = triage_definition.instantiate(state: clean_state.merge(ssn: "123"))
      expect(result[:ok]).to be(false)
      expect(result[:reason]).to eq(:undeclared_signal)
      expect(result[:undeclared]).to eq([:ssn])
    end

    it "allows any state when no signals are declared" do
      definition = Vv::DecisionObject.define(:open_state) do |d|
        d.intent "Decide"
        d.ask refund_question
      end[:data]
      expect(definition.instantiate(state: { anything: 1 })[:ok]).to be(true)
    end
  end

  it "serializes the whole declaration" do
    h = triage_definition.to_h
    expect(h[:name]).to eq(:route_ticket)
    expect(h[:owner]).to eq("support-platform")
    expect(h[:questions].map { |q| q[:name] }).to eq(%i[route refund_requested])
    expect(h[:layers].values).to all(be(true))
  end
end
