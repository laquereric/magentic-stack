# frozen_string_literal: true

RSpec.describe Vv::Mobile::Spec do
  let(:valid) do
    {
      "module" => "SharedKit",
      "base_url" => "https://api.example.com",
      "models" => [
        { "name" => "User", "properties" => [{ "name" => "id", "type" => "String" }, { "name" => "name", "type" => "String" }] }
      ],
      "repositories" => [
        { "name" => "UserRepository", "model" => "User", "collection_path" => "/users", "member_path" => "/users/{id}" }
      ]
    }
  end

  it "parses a valid hash" do
    r = described_class.parse(valid)
    expect(r[:ok]).to eq(true)
    expect(r[:spec].module_name).to eq("SharedKit")
    expect(r[:spec].models.size).to eq(1)
  end

  it "parses the example YAML file" do
    path = File.expand_path("../../../examples/user.yml", __dir__)
    r = described_class.parse(path)
    expect(r[:ok]).to eq(true)
    expect(r[:spec].repositories.first["model"]).to eq("User")
  end

  it "returns a never-raise envelope for a missing model" do
    bad = valid.merge("repositories" => [{ "name" => "X", "model" => "Ghost" }])
    r = described_class.parse(bad)
    expect(r[:ok]).to eq(false)
    expect(r[:reason]).to eq("invalid_spec")
    expect(r[:because]).to match(/Ghost/)
  end

  it "rejects a non-identifier module name" do
    r = described_class.parse(valid.merge("module" => "not-ok"))
    expect(r).to include(ok: false, reason: "invalid_spec")
  end
end
