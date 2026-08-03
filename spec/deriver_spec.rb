require "active_record"
require "mmg-acia-crud"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :widgets do |t|
    t.string :name, null: false; t.text :notes; t.integer :qty; t.boolean :active
    t.date :due; t.string :owner_email; t.references :category; t.json :meta; t.timestamps
  end
end
class Widget < ActiveRecord::Base; end
RSpec.describe Mmg::AciaCrud::Deriver do
  let(:d) { described_class.new(Widget) }
  it "maps field input_types from column types and excludes id/timestamps" do
    f = d.form(:create)
    expect(f["kind"]).to eq("form")
    by = f["children"].select { |c| c["kind"] == "field" }.each_with_object({}) { |x, h| h[x["name"]] = x["input_type"] }
    expect(by).to include("name" => "text", "notes" => "textarea", "qty" => "number", "active" => "checkbox",
                          "due" => "date", "owner_email" => "email", "category_id" => "select", "meta" => "textarea")
    expect(by.keys).not_to include("id", "created_at", "updated_at")
  end
  it "form ends with exactly one action whose href equals action_path" do
    f = d.form(:create)
    acts = f["children"].select { |c| c["kind"] == "action" }
    expect(acts.size).to eq(1)
    expect(acts.first["href"]).to eq(f["action_path"])
  end
  it "marks non-null columns required" do
    fld = d.form(:create)["children"].find { |c| c["name"] == "name" }
    expect(fld["required"]).to be true
  end
  it "derives table (row of header cells), details, destroy, and a full crud surface" do
    expect(d.table["children"].first["kind"]).to eq("row")
    expect(d.details["kind"]).to eq("details")
    expect(d.destroy_action["kind"]).to eq("action")
    expect(d.crud["kind"]).to eq("surface")
  end
end
