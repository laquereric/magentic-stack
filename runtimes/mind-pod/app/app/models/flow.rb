# frozen_string_literal: true

# Canonical Flow home — shared by P9 GHIS and P10 INTENT. Not ux_flows / intent_flows.
class Flow < ApplicationRecord
  belongs_to :journey

  validates :title, :status, :journey_id, presence: true
  validates :status, inclusion: { in: %w[draft active archived] }
end
