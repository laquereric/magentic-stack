# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Auth do
  it "names the kind of credential, never the credential" do
    auth = described_class.api_key(source: "env:ANTHROPIC_API_KEY", backend: "claude")

    expect(auth.to_h).to eq({ "mode" => "api_key", "source" => "env:ANTHROPIC_API_KEY",
                              "backend" => "claude" })
    expect(auth.describe).to eq "claude: api_key from env:ANTHROPIC_API_KEY"
  end

  it "records a subscription without holding anything" do
    auth = described_class.subscription(backend: "claude")

    expect(auth.subscription?).to be true
    expect(auth.source).to eq "the backend's own login"
    expect(auth.to_h.values).not_to include(a_string_matching(/sk-|oauth|token/i))
  end

  it "lets an individual's interactive run use a subscription" do
    expect(described_class.subscription(backend: "claude").check(shared: false)).to be_nil
  end

  it "fails a shared or scheduled run closed when it would use a subscription" do
    refusal = described_class.subscription(backend: "claude").check(shared: true)

    expect(refusal[:reason]).to eq :auth_mode_not_permitted
    expect(refusal[:failure_layer]).to eq :domain
    expect(refusal[:because]).to include "use an API key or a cloud provider credential"
  end

  it "lets a shared run proceed on an API key or a cloud credential" do
    expect(described_class.api_key(backend: "claude").check(shared: true)).to be_nil
    expect(described_class.cloud(source: "bedrock", backend: "claude").check(shared: true)).to be_nil
  end

  it "refuses a mode it does not recognize rather than assuming one" do
    expect(described_class.new(mode: :guess).check[:reason]).to eq :auth_mode_not_permitted
  end

  it "reports what the environment implies, so a stray key is visible" do
    hints = described_class.env_hints({ "ANTHROPIC_API_KEY" => "sk-ant-…",
                                        "CLAUDE_CODE_USE_BEDROCK" => "1",
                                        "PATH" => "/usr/bin" })

    expect(hints).to contain_exactly(
      { mode: :api_key, source: "env:ANTHROPIC_API_KEY" },
      { mode: :cloud, source: "env:CLAUDE_CODE_USE_BEDROCK" }
    )
    expect(described_class.env_hints({})).to be_empty
  end
end
