# frozen_string_literal: true

# Canonical Journey home — shared by P9 GHIS and P10 INTENT. Not ux_journeys / intent_journeys.
class Journey < ApplicationRecord
  belongs_to :primary_actor, class_name: "Actor", optional: true
  has_many :flows, dependent: :destroy

  validates :title, :status, presence: true
  validates :status, inclusion: { in: %w[draft active archived] }
end
