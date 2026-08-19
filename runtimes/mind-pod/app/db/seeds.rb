Note.create!(title: "Welcome", body: "This note was written through BACK's /_cpcp seam.") if Note.count.zero?
RailsOsiLevel8::Fixtures.seed_demo_narrative! if defined?(RailsOsiLevel8::Fixtures)
