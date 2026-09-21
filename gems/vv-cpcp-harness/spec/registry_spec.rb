# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Registry do
  let(:journal) { Vv::CpcpHarness::Journal.new(pull_sample: 1) }
  let(:approvals) { [] }
  let(:approver) { ->(request) { approvals << request and true } }

  def registry(**extra)
    described_class.new(journal: journal, **extra)
  end

  def note_schema
    Vv::CpcpHarness::Schema.from_params({ "title" => "string (required)" })
  end

  def push_tool(name: "notes_write", store: nil, **extra, &handler)
    handler ||= ->(args, ctx) { { text: "wrote #{args["title"]}", ld: { "operationId" => ctx.operation_id } } }
    Vv::CpcpHarness.define_tool(
      name: name, description: "Write a note.", schema: note_schema,
      cpcp: { iri: "https://w3id.org/cpcp/osi8/harness##{name}", face: :push }, **extra, &handler
    )
  end

  def pull_tool(&handler)
    handler ||= ->(_args, _ctx) { { text: "3 passed", ld: { "type" => "TestRun", "passed" => 3 } } }
    Vv::CpcpHarness.define_tool(
      name: "run_tests", description: "Run the suite.",
      cpcp: { iri: "https://w3id.org/cpcp/osi8/harness#tests.run", face: :pull }, &handler
    )
  end

  it "refuses to register two tools claiming the same name or IRI" do
    reg = registry
    expect(reg.register(pull_tool)[:ok]).to be true
    expect(reg.register(pull_tool)[:reason]).to eq :tool_name_taken

    same_iri = Vv::CpcpHarness.define_tool(
      name: "run_tests_again", description: "",
      cpcp: { iri: "https://w3id.org/cpcp/osi8/harness#tests.run", face: :pull }
    ) { { text: "" } }
    expect(reg.register(same_iri)[:reason]).to eq :iri_taken
  end

  it "allows a PULL by default and asks about a PUSH" do
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: approver))
    reg.register(pull_tool)
    reg.register(push_tool)

    reg.execute("run_tests")
    expect(approvals).to be_empty

    reg.execute("notes_write", { "title" => "a" })
    expect(approvals.first[:iri]).to end_with "#notes_write"
    expect(approvals.first[:operation_id]).to start_with "notes-write-"
  end

  it "reports a declined approval as user_declined, in the domain layer" do
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: ->(_r) { false }))
    reg.register(push_tool)

    result = reg.execute("notes_write", { "title" => "a" })

    expect(result[:ok]).to be false
    expect(result[:reason]).to eq :user_declined
    expect(result[:failure_layer]).to eq :domain
    expect(result[:operation_id]).not_to be_nil
  end

  it "declines a PUSH when no approver is configured" do
    reg = registry
    reg.register(push_tool)

    expect(reg.execute("notes_write", { "title" => "a" })[:reason]).to eq :user_declined
  end

  it "mints an operationId once per call and hands it to the handler" do
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: approver))
    seen = []
    reg.register(push_tool { |_args, ctx| seen << ctx.operation_id and { text: "ok" } })

    result = reg.execute("notes_write", { "title" => "a" })

    expect(seen.first).to match(/\Anotes-write-[0-9a-f]{16}\z/)
    expect(result[:operation_id]).to eq seen.first
  end

  it "accepts the model's operationId and records who named it" do
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: approver))
    reg.register(push_tool)

    reg.execute("notes_write", { "title" => "a", "operationId" => "notes-write-deadbeefdeadbeef" })

    entry = journal.entries.last
    expect(entry["operationId"]).to eq "notes-write-deadbeefdeadbeef"
    expect(entry["operationIdSource"]).to eq "model"
  end

  it "refuses a reused operationId that carries different arguments" do
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: approver))
    reg.register(push_tool)

    first = reg.execute("notes_write", { "title" => "a", "operationId" => "notes-write-1" })
    second = reg.execute("notes_write", { "title" => "b", "operationId" => "notes-write-1" })

    expect(first[:ok]).to be true
    expect(second[:reason]).to eq :harness_input_rejected
    expect(second[:text]).to include "different arguments"
  end

  it "refuses arguments the local schema rejects, without running the handler" do
    ran = false
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: approver))
    reg.register(push_tool { |_a, _c| ran = true and { text: "ok" } })

    result = reg.execute("notes_write", {})

    expect(result[:reason]).to eq :harness_input_rejected
    expect(result[:failure_layer]).to eq :http_request
    expect(ran).to be false
  end

  it "replays a native PUSH under a repeated operationId instead of running it twice" do
    runs = 0
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: approver),
                   receipts: Vv::CpcpHarness::Receipts::FileStore.new(Dir.mktmpdir))
    reg.register(push_tool { |_a, _c| runs += 1 and { text: "wrote #{runs}" } })

    first = reg.execute("notes_write", { "title" => "a", "operationId" => "notes-write-7" })
    second = reg.execute("notes_write", { "title" => "a", "operationId" => "notes-write-7" })

    expect(runs).to eq 1
    expect(second[:text]).to eq first[:text]
  end

  it "says so when the receipt store makes no durable promise" do
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: approver),
                   receipts: Vv::CpcpHarness::Receipts::MemoryStore.new)
    reg.register(push_tool)

    result = reg.execute("notes_write", { "title" => "a" })

    expect(result[:text]).to include "does not outlive the process"
  end

  it "replaces a reason outside the taxonomy and keeps the original in the sentence" do
    reg = registry
    reg.register(pull_tool { |_a, _c| { error: "the suite is missing", reason: "no_suite_here" } })

    result = reg.execute("run_tests")

    expect(result[:reason]).to eq :harness_tool_refused
    expect(result[:text]).to include "unregistered reason no_suite_here"
  end

  it "keeps a reason the contract does name" do
    reg = registry
    reg.register(pull_tool { |_a, _c| { error: "shape catalog is empty", reason: "shape_catalog_empty" } })

    expect(reg.execute("run_tests")[:reason]).to eq :shape_catalog_empty
  end

  it "turns a handler that raises into data" do
    reg = registry
    reg.register(pull_tool { |_a, _c| raise ArgumentError, "boom" })

    result = reg.execute("run_tests")

    expect(result[:reason]).to eq :harness_tool_refused
    expect(result[:failure_layer]).to eq :infrastructure
    expect(result[:text]).to include "ArgumentError: boom"
  end

  it "times a native tool out as a refusal" do
    reg = registry
    tool = Vv::CpcpHarness.define_tool(
      name: "slow", description: "", timeout: 0.01,
      cpcp: { iri: "https://w3id.org/cpcp/osi8/harness#slow", face: :pull }
    ) { |_a, _c| sleep 0.5 }
    reg.register(tool)

    expect(reg.execute("slow")[:reason]).to eq :harness_timeout
  end

  it "answers an unknown tool with the contract's own reason" do
    expect(registry.execute("nope")[:reason]).to eq :unknown_operation
  end

  it "journals every PUSH with the session and the human behind it" do
    reg = registry(permissions: Vv::CpcpHarness::Permissions.new(approver: ->(_r) { { approved: true, by: "user:eric" } }))
    reg.register(push_tool)
    context = Vv::CpcpHarness::Context.new(session_id: "8c1e", backend: "claude",
                                           model: "claude-opus-5", agent: "build", rpc_id: "toolu_01H")

    reg.execute("notes_write", { "title" => "a" }, context: context)
    entry = journal.entries.last

    expect(entry["iri"]).to end_with "#notes_write"
    expect(entry["backend"]).to eq "claude"
    expect(entry["model"]).to eq "claude-opus-5"
    expect(entry["sessionId"]).to eq "8c1e"
    expect(entry["rpcId"]).to eq "toolu_01H"
    expect(entry["approvedBy"]).to eq "user:eric"
    expect(entry["outcome"]).to include("ok" => true)
  end

  it "emits the runner's tool_result event" do
    reg = registry
    reg.register(pull_tool)
    rendered = reg.execute("run_tests")
    event = reg.event(rendered, call_id: "toolu_01H", backend: "opencode")

    expect(event[:type]).to eq "tool_result"
    expect(event[:tool]).to eq "run_tests"
    expect(event[:is_error]).to be false
    expect(event[:iri]).to end_with "#tests.run"
    expect(event[:output]).to include "3 passed"
  end
end
