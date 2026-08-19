require "spec_helper"

# gstack review fix #1/#2: private_local canonical homes are never disclosed via intent.* PULLs.
RSpec.describe "P10 canonical-home ledger placement" do
  it "marks a Mission private_local and mission.get never discloses it" do
    pub  = ::Mission.create!(title: "Public mission",  status: "ratified", ledger_placement: "canonical")
    priv = ::Mission.create!(title: "Secret mission",  status: "ratified", ledger_placement: "private_local")
    # by id: private one is not found (treated as not_found, non-disclosing)
    got = RailsOsiLevel8::Intent::Pulls.mission_get("id" => pub.id)
    expect(got["cid"]).to be_a(String)
    expect { RailsOsiLevel8::Intent::Pulls.mission_get("id" => priv.id) }
      .to raise_error(RailsOsiLevel8::KnownRefusal)
    # by cid: the private mission's own CID must not resolve either
    priv_cid = RailsOsiLevel8::Intent::Projection.for(priv)["cid"]
    expect { RailsOsiLevel8::Intent::Pulls.mission_get("cid" => priv_cid) }
      .to raise_error(RailsOsiLevel8::KnownRefusal)
  end

  it "excludes a private_local Persona from persona.list" do
    ::Persona.create!(name: "Public persona", status: "ratified", ledger_placement: "canonical")
    ::Persona.create!(name: "Classified persona", status: "ratified", ledger_placement: "private_local")
    names = RailsOsiLevel8::Intent::Pulls.persona_list({}).map { |p| p["title"] }
    expect(names).to include("Public persona")
    expect(names).not_to include("Classified persona")
  end

  it "projection honors the actual ledger_placement (no blanket-canonical)" do
    m = ::Mission.create!(title: "Sensitive", status: "ratified", ledger_placement: "private_local")
    expect(RailsOsiLevel8::Intent::Projection.for(m)["ledgerPlacement"]).to eq("private_local")
  end
end
