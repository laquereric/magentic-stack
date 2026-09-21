# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Shacl do
  it "reads the demo Note shape" do
    shape = described_class.parse(push_cid["shapes"]).first

    expect(shape.name).to eq "cpcp:NoteShape"
    expect(shape.target_class).to eq "cpcp:Note"
    expect(shape.closed?).to be true
    expect(shape.properties.map(&:name)).to contain_exactly("title", "body")

    title = shape.property("title")
    expect(title.type).to eq :string
    expect(title.required).to be true
    expect(title.array).to be false
  end

  it "reads the constructs in the supported subset" do
    ttl = <<~TTL
      @prefix sh: <http://www.w3.org/ns/shacl#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
      @prefix cpcp: <https://w3id.org/cpcp/ns#> .

      cpcp:TicketShape a sh:NodeShape ;
        sh:targetClass cpcp:Ticket ;
        sh:property [ sh:path cpcp:state ; sh:datatype xsd:string ; sh:minCount 1 ;
                      sh:maxCount 1 ; sh:in ( "draft" "open" ) ] ;
        sh:property [ sh:path cpcp:key ; sh:datatype xsd:string ; sh:maxCount 1 ;
                      sh:pattern "^[A-Z]+-[0-9]+$" ; sh:minLength 3 ; sh:maxLength 12 ] ;
        sh:property [ sh:path cpcp:rank ; sh:datatype xsd:integer ; sh:maxCount 1 ] ;
        sh:property [ sh:path cpcp:tags ; sh:datatype xsd:string ] .
    TTL
    shape = described_class.parse(ttl).first

    expect(shape.closed?).to be false
    expect(shape.property("state").enum).to eq %w[draft open]
    expect(shape.property("key").pattern).to eq "^[A-Z]+-[0-9]+$"
    expect(shape.property("key").min_length).to eq 3
    expect(shape.property("key").max_length).to eq 12
    expect(shape.property("rank").type).to eq :integer
    expect(shape.property("tags").array).to be true
  end

  it "leaves anything outside the subset permissive, and says so" do
    ttl = <<~TTL
      @prefix sh: <http://www.w3.org/ns/shacl#> .
      @prefix cpcp: <https://w3id.org/cpcp/ns#> .

      cpcp:OddShape a sh:NodeShape ;
        sh:property [ sh:path cpcp:owner ; sh:node cpcp:PersonShape ] .
    TTL
    shape = described_class.parse(ttl).first

    expect(shape.property("owner").permissive).to be true
    expect(shape.property("owner").type).to eq :any
    expect(shape.warnings.first).to match(/sh:node/)
  end

  it "does not let a period inside a pattern end a statement" do
    ttl = <<~TTL
      @prefix sh: <http://www.w3.org/ns/shacl#> .
      @prefix cpcp: <https://w3id.org/cpcp/ns#> .

      cpcp:DotShape a sh:NodeShape ;
        sh:property [ sh:path cpcp:host ; sh:pattern "^[a-z]+\\.example\\.com$" ] .
    TTL

    expect(described_class.parse(ttl).length).to eq 1
    expect(described_class.parse(ttl).first.property("host").pattern).to include "example"
  end
end
