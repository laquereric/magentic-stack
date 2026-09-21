# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Bridge do
  let(:transports) { {} }
  let(:approvals) { [] }

  # One fake seam per configured seam, answering note.list and
  # note.create the way the demo stub does.
  def factory
    lambda do |seam|
      payload = seam.cid_payload
      transports[seam.name] = Vv::CpcpHarness::FakeTransport.new(cid_payload: payload) do |call|
        case call[:method]
        when "note.list"
          exchange(200, ok_envelope({ "@graph" => [{ "type" => "Note", "title" => "hello" }] }))
        when "note.create"
          exchange(200, ok_envelope({ "type" => "Note", "id" => "note:1",
                                      "title" => call[:params]["title"] }))
        else
          exchange(200, nested_refusal("unknown_operation", "no CPCP operation #{call[:method]}"))
        end
      end
    end
  end

  def bridge(**options)
    result = Vv::CpcpHarness.bridge(
      seams: [seam(name: "reads", payload: pull_cid, include: ["note.list"]),
              seam(name: "writes", payload: push_cid, include: ["note.create"])],
      transport_factory: factory,
      approver: ->(request) { approvals << request and { approved: true, by: "user:eric" } },
      **options
    )
    expect(result[:ok]).to be true
    result[:result]
  end

  it "publishes one tool per allowlisted operation, on both faces" do
    tools = bridge.tools

    expect(tools.map(&:name)).to contain_exactly("reads_note_list", "writes_note_create")
    expect(bridge.tool("reads_note_list").read_only?).to be true
  end

  it "reads through the seam and renders the sentence before the node" do
    result = bridge.execute("reads_note_list")

    expect(result[:ok]).to be true
    expect(result[:text]).to eq "note.list succeeded with 1 item."
    expect(result[:ld]["result"]["@graph"].first["title"]).to eq "hello"
    expect(result[:iri]).to eq "https://w3id.org/cpcp/osi8/demo#note.list"
  end

  it "writes through the seam, minting and carrying the operationId" do
    b = bridge
    result = b.execute("writes_note_create", { "title" => "hello", "body" => "posted" })

    expect(result[:ok]).to be true
    expect(result[:operation_id]).to match(/\Anote-create-[0-9a-f]{16}\z/)
    expect(transports["writes"].calls.first[:operation_id]).to eq result[:operation_id]
    expect(approvals.first[:iri]).to eq "https://w3id.org/cpcp/osi8/demo#note.create"
  end

  it "refuses locally what the closed shape does not admit, without a round trip" do
    b = bridge
    result = b.execute("writes_note_create", { "title" => "hello" })

    expect(result[:reason]).to eq :harness_input_rejected
    expect(result[:text]).to include "body is required"
    expect(transports["writes"].calls).to be_empty
  end

  it "journals the write and keeps the id as the join key" do
    entries = []
    b = bridge(journal_sink: ->(e) { entries << e })
    result = b.execute("writes_note_create", { "title" => "a", "body" => "b" },
                       context: Vv::CpcpHarness::Context.new(session_id: "8c1e", backend: "claude"))

    expect(entries.last["operationId"]).to eq result[:operation_id]
    expect(entries.last["approvedBy"]).to eq "user:eric"
    expect(entries.last["seam"]).to eq "writes"
  end

  it "generates from a committed snapshot on disk, pinned by digest" do
    path = File.join(Vv::CpcpHarness::SpecHelpers::FIXTURES, "demo-push-note.cid.json")
    digest = Vv::CpcpHarness::Cid.load(path)[:result].digest

    result = Vv::CpcpHarness.bridge(
      seams: [{ name: "back", endpoint: "https://back.example/_cpcp", cid_snapshot: path,
                cid_digest: digest, include: ["note.create"],
                credential: Vv::CpcpHarness.env("CPCP_BACK_TOKEN") }],
      transport_factory: lambda { |seam|
        transports[seam.name] = Vv::CpcpHarness::FakeTransport.new(cid_payload: push_cid) do |call|
          exchange(200, ok_envelope({ "id" => "note:1", "title" => call[:params]["title"] }))
        end
      },
      approver: ->(_request) { true }
    )

    expect(result[:ok]).to be true
    expect(result[:result].execute("back_note_create", { "title" => "a", "body" => "b" })[:ok]).to be true
  end

  describe "preflight" do
    it "says which credential each seam will use and where it came from, never the value" do
      ENV["CPCP_BACK_TOKEN"] = "s3cret"
      b = bridge(name: "acme-agent-harness")
      report = b.preflight(auth: Vv::CpcpHarness::Auth.api_key(source: "env:ANTHROPIC_API_KEY",
                                                               backend: "claude"))[:result]

      expect(report["role"]).to eq "FRONT"
      expect(report["model_credential"]).to eq({ "mode" => "api_key", "source" => "env:ANTHROPIC_API_KEY",
                                                 "backend" => "claude" })
      expect(report["seams"].map { |s| s["seam"] }).to contain_exactly("reads", "writes")
      expect(JSON.generate(report)).not_to include "s3cret"
    ensure
      ENV.delete("CPCP_BACK_TOKEN")
    end

    it "flags a missing seam credential without failing the report" do
      b = Vv::CpcpHarness.bridge(
        seams: [seam(payload: pull_cid, include: ["note.list"],
                     credential: Vv::CpcpHarness.env("CPCP_ABSENT_TOKEN"))],
        transport_factory: factory
      )[:result]

      line = b.preflight_lines.find { |l| l.start_with?("seam ") }
      expect(line).to include "credential env:CPCP_ABSENT_TOKEN (MISSING)"
    end

    it "warns that an API key in the environment outranks a plan login" do
      ENV["ANTHROPIC_API_KEY"] = "sk-ant-not-real"
      lines = bridge.preflight_lines(auth: Vv::CpcpHarness::Auth.subscription(backend: "claude"))

      expect(lines).to include(a_string_matching(/env:ANTHROPIC_API_KEY — this outranks a plan login/))
      expect(lines.join).not_to include "sk-ant-not-real"
    ensure
      ENV.delete("ANTHROPIC_API_KEY")
    end

    it "fails a shared run closed when the backend would bill a subscription" do
      result = bridge.preflight(auth: Vv::CpcpHarness::Auth.subscription(backend: "claude"), shared: true)

      expect(result[:ok]).to be false
      expect(result[:reason]).to eq :auth_mode_not_permitted
      expect(result[:report]["seams"]).not_to be_empty
    end

    it "fails a shared run that does not say how it authenticates" do
      expect(bridge.preflight(shared: true)[:reason]).to eq :auth_mode_not_permitted
    end

    it "lets an individual's interactive run go on its own plan" do
      result = bridge.preflight(auth: Vv::CpcpHarness::Auth.subscription(backend: "claude"))

      expect(result[:ok]).to be true
    end
  end

  it "records which account paid for the call in the journal" do
    entries = []
    b = bridge(journal_sink: ->(e) { entries << e })
    b.execute("writes_note_create", { "title" => "a", "body" => "b" },
              context: Vv::CpcpHarness::Context.new(
                backend: "claude", model: "claude-opus-5",
                auth_mode: Vv::CpcpHarness::Auth.api_key(source: "env:ANTHROPIC_API_KEY")
              ))

    expect(entries.last["authMode"]).to eq "api_key"
    expect(JSON.generate(entries.last)).not_to include "ANTHROPIC_API_KEY"
  end

  it "refuses to build when the snapshot does not match the pinned digest" do
    result = Vv::CpcpHarness.bridge(
      seams: [seam(payload: push_cid, cid_digest: "sha256-not-this")],
      transport_factory: factory
    )

    expect(result[:ok]).to be false
    expect(result[:reason]).to eq :snapshot_digest_mismatch
  end

  it "fails sync when a seam has moved on from its snapshot" do
    moved = pull_cid.merge("description" => "changed under us")
    result = Vv::CpcpHarness.bridge(
      seams: [seam(name: "reads", payload: pull_cid, include: ["note.list"])],
      transport_factory: lambda { |seam|
        Vv::CpcpHarness::FakeTransport.new(cid_payload: moved) { |_c| exchange(200, ok_envelope({})) }
      }
    )
    b = result[:result]

    expect(b.sync[:reason]).to eq :contract_superseded
    expect(b.execute("reads_note_list")[:reason]).to eq :contract_superseded
  end

  it "grounds a native tool without serving a seam" do
    b = bridge
    b.ground(name: "run_tests", description: "Run the suite.",
             cpcp: { iri: Vv::CpcpHarness.iri("harness", "tests.run"), face: :pull }) do |_args, _ctx|
      { text: "3 passed, 0 failed.", ld: { "type" => "TestRun", "passed" => 3, "failed" => 0 } }
    end

    result = b.execute("run_tests")
    expect(result[:text]).to eq "3 passed, 0 failed."
    expect(result[:ld]["type"]).to eq "TestRun"
  end

  it "declares itself a FRONT and names what it depends on" do
    b = bridge(name: "acme-agent-harness", unit: "acme", contract_rev: "a" * 40)

    package = b.manifest
    expect(package["kind"]).to eq "cpcp-application"
    expect(package["role"]).to eq({ "name" => "FRONT", "of" => "acme" })
    expect(package["bindings"]["harness"]["reasons"]).to include "seam_unreachable"

    depends = b.dependency_manifest["depends_on"]
    expect(depends.map { |d| d["operations"] }.flatten).to contain_exactly("note.list", "note.create")
    expect(depends.map { |d| d["status"] }.uniq).to eq ["published"]
  end

  it "records an operation the seam does not publish yet as unbuilt" do
    entry = Vv::CpcpHarness::Manifest.depends_on(
      Vv::CpcpHarness::Seam.new(**seam(include: %w[note.create note.delete])),
      cid: Vv::CpcpHarness::Cid.from(push_cid)[:result]
    )

    expect(entry["status"]).to eq "unbuilt"
    expect(entry["because"]).to include "note.delete"
  end

  it "describes its native tools in one CID that names a binding, not an endpoint" do
    b = bridge
    b.ground(name: "run_tests", description: "",
             cpcp: { iri: Vv::CpcpHarness.iri("harness", "tests.run"), face: :pull }) { { text: "ok" } }

    cid = b.harness_cid
    expect(cid["kind"]).to eq "binding"
    expect(cid).to have_key "endpoint"
    expect(cid["endpoint"]).to be_nil
    expect(cid["operations"].map { |o| o["iri"] }).to include "https://w3id.org/cpcp/osi8/harness#tests.run"
  end

  it "writes the manifest files CI reads" do
    b = bridge
    Dir.mktmpdir do |dir|
      written = Vv::CpcpHarness::Manifest.write(dir: dir, bridge: b, examples: ["spec/conformance_spec.rb"])

      expect(written[:ok]).to be true
      expect(File.exist?(File.join(dir, ".cpcp", "package.json"))).to be true
      expect(File.exist?(File.join(dir, ".cpcp", "dependency", "package.json"))).to be true
      expect(JSON.parse(File.read(File.join(dir, "cpcp", "harness.cid.json")))["binding"]).to eq "harness"
    end
  end
end
