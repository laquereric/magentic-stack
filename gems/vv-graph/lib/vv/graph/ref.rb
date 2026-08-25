# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv; end

module Vv::Graph
  # Stable identity for a Storable row used by Publisher#schedule.
  # ADR StorableBootSafe S1 — the Storable-facing seam carries
  # identity + generation, not serialized triples.
  #
  #   Vv::Graph::Ref.new("Mm::CuratedApp", 42)
  #   Vv::Graph::Ref.new(Mm::CuratedApp, record.id)
  class Ref
    attr_reader :type, :id

    # @param type [String, Class] fully-qualified model class name or class
    # @param id   [Object] primary key
    def initialize(type, id)
      @type = type.is_a?(Module) ? type.name : type.to_s
      @id   = id
      freeze
    end

    def ==(other)
      other.is_a?(self.class) && other.type == type && other.id == id
    end
    alias eql? ==

    def hash
      [self.class, type, id].hash
    end

    # Resolve to an AR instance, or nil if the class/row is gone.
    def resolve
      klass = type.constantize
      return nil unless klass.respond_to?(:find_by)

      klass.find_by(id: id)
    rescue NameError
      nil
    end

    def to_s
      "Vv::Graph::Ref(#{type}:#{id})"
    end
  end
end
