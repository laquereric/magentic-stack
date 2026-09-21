# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Schema do
  let(:shape) { Vv::CpcpHarness::Shacl.parse(push_cid["shapes"]).first }
  let(:schema) { described_class.from_shape(shape) }

  it "requires what sh:minCount requires" do
    expect(schema.validate({ "title" => "a", "body" => "b" })).to be_nil
    expect(schema.validate({ "title" => "a" })).to eq "body is required"
  end

  it "checks datatypes" do
    expect(schema.validate({ "title" => 7, "body" => "b" })).to eq "title must be a string"
  end

  it "closes a closed shape, but never against what the bridge supplies" do
    expect(schema.validate({ "title" => "a", "body" => "b", "colour" => "red" }))
      .to eq "colour not in the closed shape"
    expect(schema.validate({ "title" => "a", "body" => "b", "@context" => {},
                             "operationId" => "note-create-1" })).to be_nil
  end

  it "refuses params that are not an object, rather than coercing them" do
    expect(schema.validate([])).to match(/must be an object/)
    expect(schema.validate(nil)).to match(/must be an object/)
  end

  it "declares operationId as an optional string on a PUSH" do
    with_id = schema.with_operation_id

    expect(with_id.field("operationId").required).to be false
    expect(with_id.validate({ "title" => "a", "body" => "b" })).to be_nil
    expect(with_id.validate({ "title" => "a", "body" => "b", "operationId" => 7 }))
      .to eq "operationId must be a string"
    expect(with_id.with_operation_id.fields.count { |f| f.name == "operationId" }).to eq 1
  end

  it "falls back to the informal params when there is no usable shape" do
    schema = described_class.from_params({ "title" => "string (required)", "limit" => "integer" })

    expect(schema.validate({})).to eq "title is required"
    expect(schema.validate({ "title" => "a", "limit" => "many" })).to eq "limit must be an integer"
    expect(schema.warnings.first).to match(/informal params/)
    expect(schema.validate({ "title" => "a", "extra" => true })).to be_nil
  end

  it "checks enums, patterns and lengths" do
    ttl = <<~TTL
      @prefix sh: <http://www.w3.org/ns/shacl#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      @prefix cpcp: <https://w3id.org/cpcp/ns#> .

      cpcp:TicketShape a sh:NodeShape ;
        sh:property [ sh:path cpcp:state ; sh:datatype xsd:string ; sh:maxCount 1 ;
                      sh:in ( "draft" "open" ) ] ;
        sh:property [ sh:path cpcp:key ; sh:datatype xsd:string ; sh:maxCount 1 ;
                      sh:pattern "^[A-Z]+-[0-9]+$" ; sh:maxLength 6 ] .
    TTL
    schema = described_class.from_shape(Vv::CpcpHarness::Shacl.parse(ttl).first)

    expect(schema.validate({ "state" => "closed" })).to match(/must be one of draft, open/)
    expect(schema.validate({ "key" => "abc-1" })).to match(/must match/)
    expect(schema.validate({ "key" => "ABC-12345" })).to match(/at most 6 characters/)
    expect(schema.validate({ "state" => "open", "key" => "ABC-12" })).to be_nil
  end

  it "emits a JSON Schema for whichever adapter needs one" do
    json = schema.with_operation_id.json_schema

    expect(json["type"]).to eq "object"
    expect(json["required"]).to contain_exactly("title", "body")
    expect(json["additionalProperties"]).to be false
    expect(json["properties"]["operationId"]["type"]).to eq "string"
  end
end
