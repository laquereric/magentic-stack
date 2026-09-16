# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # Offline-friendly triples do..end (design grounding shape).
    # Prefer Vv::Graph::Storable when the host has loaded it; this always
    # provides emit_triples → Array of {s:, p:, o:} for never-raise tests.
    module StorableLocal
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def triples(&block)
          raise ArgumentError, "triples requires a block" unless block

          @__medallion_triple_block = block
        end

        def medallion_triple_block
          @__medallion_triple_block
        end
      end

      # Returns [{s:, p:, o:}, ...] never-raise.
      def emit_triples
        blk = self.class.medallion_triple_block
        return [] unless blk

        rec = Recorder.new(self)
        rec.instance_exec(&blk)
        rec.triples
      rescue ::StandardError
        []
      end

      def as_ntriples
        emit_triples.map { |t|
          o = t[:o].to_s
          obj = o.start_with?("http", "urn:", "https") ? "<#{o}>" : o.dump
          "<#{t[:s]}> <#{t[:p]}> #{obj} ."
        }
      end

      class Recorder
        attr_reader :triples

        def initialize(host)
          @host = host
          @triples = []
        end

        # 3-arg form: triple s, p, o  — or 2-arg form: triple p, o (subject from #iri)
        def triple(a, b = nil, c = nil)
          if c
            @triples << { s: a.to_s, p: b.to_s, o: c.to_s }
          elsif b
            subj = @host.respond_to?(:iri) ? @host.iri : @host.subject_iri
            val = b.respond_to?(:call) ? @host.instance_exec(&b) : b
            @triples << { s: subj.to_s, p: a.to_s, o: val.to_s } if val
          end
          true
        end

        def subject(*)
          # no-op compatibility with Vv::Graph::Storable recorders
        end

        def method_missing(name, *args, &block)
          return @host.public_send(name, *args, &block) if @host.respond_to?(name)

          super
        end

        def respond_to_missing?(name, include_private = false)
          @host.respond_to?(name, include_private) || super
        end
      end
    end
  end
end
