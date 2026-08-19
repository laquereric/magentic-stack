class Reconciliation < ApplicationRecord
  def as_api
    { "@id" => "#{RailsCpcp.base_iri}/reconciliation/#{id}", "@type" => "Reconciliation",
      "note_count" => note_count, "at" => created_at&.iso8601 }
  end
end
