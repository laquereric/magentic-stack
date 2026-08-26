require_relative "lib/mmg/acia_crud/version"
Gem::Specification.new do |s|
  s.name="mmg-acia-crud"; s.version=Mmg::AciaCrud::VERSION
  s.summary="Derive deterministic ACIA CRUD skeletons (form/table/details/action) from a resolved AR model's schema; field input_types mapped from column types, never invented."
  s.authors=["Eric Laquer"]; s.files=Dir["lib/**/*.rb"]; s.required_ruby_version=">= 3.2"
end
