Note.create!(title: "Welcome", body: "This note was written through BACK's /_cpcp seam.") if Note.count.zero?
RailsOsiLevel8::Fixtures.seed_demo_narrative! if defined?(RailsOsiLevel8::Fixtures)

# P10.M1 fixtures — canonical homes (not intent_* duplicates)
#
# ADR 0074 decision 4: the Actor, Journey, Flow and FlowStep rows are data and
# live in db/seed/canonical/p10m1.yml. Mission, Vision and Persona stay here --
# they are not bundle-scoped and the loader does not carry them.
result = Vv::Base::Seeder.load!(
  seed_root: Rails.root.join("db/seed/canonical"),
  bundle_key: "mind-pod"
)
raise "canonical seed refused: #{result[:reason]} -- #{result[:because]}" unless result[:ok]

Mission.find_or_create_by!(title: "Governed Cyborg Accountability") do |m|
  m.body = "Make every committed Effect traceable to a declared purpose and responsible human."
  m.status = "ratified"
end
Vision.find_or_create_by!(title: "Inspectable purpose at the Cyborg boundary") do |v|
  v.body = "Purpose, audience, and value are first-class governed Context."
  v.status = "ratified"
  v.time_horizon = "2027"
end
Persona.find_or_create_by!(name: "Governance Operator") do |p|
  p.summary = "Responsible human who reviews authorization evidence before committing Effects."
  p.status = "ratified"
  p.persona_role = true
end
