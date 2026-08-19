class Note < ApplicationRecord
  validates :title, presence: true
  def as_api
    { "@id" => "#{RailsCpcp.base_iri}/note/#{id}", "@type" => "Note",
      "id" => id, "title" => title, "body" => body, "created_at" => created_at&.iso8601 }
  end
end
