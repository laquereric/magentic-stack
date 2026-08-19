Note.create!(title: "Welcome", body: "This note was written through BACK's /_cpcp seam.") if Note.count.zero?
RailsOsiLevel8::Fixtures.seed_demo_narrative! if defined?(RailsOsiLevel8::Fixtures)

# P10.M1 fixtures — canonical homes (not intent_* duplicates)
actor = Actor.find_or_create_by!(role_key: "accountable-operator") do |a|
  a.name = "Accountable Operator"
end
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
journey = Journey.find_or_create_by!(title: "Assure an effect is authorized") do |j|
  j.goal = "Commit or safely refuse a proposed Effect on valid delegation."
  j.scenario = "Workstation governance review"
  j.status = "active"
  j.primary_actor = actor
end
Flow.find_or_create_by!(title: "Review and decide authorization", journey: journey) do |f|
  f.task_goal = "Inspect authority and submit exactly one closed decision."
  f.status = "active"
end
