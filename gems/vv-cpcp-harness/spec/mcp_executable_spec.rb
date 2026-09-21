# frozen_string_literal: true

require "open3"

# The path as a person actually runs it: `claude mcp add cpcp -- ...`.
# Nothing here touches the network — `tools/list` is answered from the
# committed CID snapshot, which is the point of pinning.
RSpec.describe "exe/vv-cpcp-harness-mcp" do
  let(:exe) { File.expand_path("../exe/vv-cpcp-harness-mcp", __dir__) }

  def config_file(dir)
    path = File.join(dir, "cpcp.rb")
    File.write(path, <<~RUBY)
      Vv::CpcpHarness.bridge(
        name: "acme-agent-harness",
        seams: [{
          name: "back",
          endpoint: "https://back.example/_cpcp",
          cid_snapshot: #{File.join(Vv::CpcpHarness::SpecHelpers::FIXTURES, "demo-push-note.cid.json").inspect},
          credential: Vv::CpcpHarness.env("CPCP_BACK_TOKEN"),
          include: ["note.create"]
        }],
        approver: Vv::CpcpHarness::Mcp.client_approval
      )
    RUBY
    path
  end

  def run(input, path)
    Open3.capture3({ "RUBYOPT" => "-I#{File.expand_path("../lib", __dir__)}" },
                   RbConfig.ruby, exe, path, stdin_data: input)
  end

  it "serves the registry over stdio, with diagnostics kept off the stream" do
    Dir.mktmpdir do |dir|
      frames = [
        { "jsonrpc" => "2.0", "id" => 1, "method" => "server/discover", "params" => {} },
        { "jsonrpc" => "2.0", "id" => 2, "method" => "tools/list", "params" => {} }
      ].map { |f| "#{JSON.generate(f)}\n" }.join

      out, err, status = run(frames, config_file(dir))

      expect(status).to be_success
      responses = out.lines.map { |line| JSON.parse(line) }
      expect(responses.first["result"]["supportedVersions"]).to include Vv::CpcpHarness::Mcp::MODERN
      expect(responses.last["result"]["tools"].map { |t| t["name"] }).to eq ["back_note_create"]

      # The preflight is for the human, so it goes to stderr — and it
      # names the credential's source, never its value.
      expect(err).to include "acme-agent-harness (FRONT)"
      expect(err).to include "credential env:CPCP_BACK_TOKEN"
      expect(err).to include "the calling client authenticates for itself"
    end
  end

  it "exits with a diagnostic rather than a half-served stream when the config is wrong" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "bad.rb")
      File.write(path, '"not a bridge"')

      out, err, status = run("", path)

      expect(status).not_to be_success
      expect(out).to be_empty
      expect(err).to include "must end in a Vv::CpcpHarness::Bridge"
    end
  end
end
