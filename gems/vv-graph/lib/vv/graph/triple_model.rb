# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "active_support/concern"

module Vv
  module Graph
    # DEPRECATED (owner 2026-08-11; ADR StorableBootSafe). Vv::Graph::Storable is the sole
    # go-forward graph DSL. TripleModel remains for existing models pending a later
    # plugin-stability-gated migration. Do not add new TripleModel includes.
    #
    # Historical note: TripleModel reifies every triple as a FIRST-CLASS TYPED OBJECT that
    # carries an AR REFERENCE (class or instance). It once claimed to supersede Storable;
    # that supersession is reversed.
    #
    #   triple      / triple_each        -> INSTANCE-grounded (ar_ref = the row): row-level facts.
    #   class_triple / class_triple_each -> CLASS-grounded    (ar_ref = the model class): vocabulary,
    #                                       rdf:type, SHACL shape -- the schema-level facts.
    #
    # Each declaration const_sets a nested `HostModel::Name < Triple`; the nested class NAME is the triple's
    # type ("the triple is of class ArModelName::TripleClassName"). Storage is HARD-GATED through
    # Vv::Graph::Store, which refuses any triple lacking an ar_ref.
    #
    # Subject IRIs are DERIVED FROM THE RUBY CLASS NAME (not free-form DB columns):
    #   class    → urn:mm:class:Mmg::Optimize::DevelopTrace
    #   instance → urn:mm:Mmg::Optimize::DevelopTrace:<id>
    # Overrides (graph_subject block / graph_class_subject) still live on the AR model class.
    # Named graph (where triples are stored) is Model.graph_iri — also class-level, never a row column.
    #
    #   class DevelopTrace < ApplicationRecord
    #     include Vv::Graph::TripleModel
    #     # optional overrides — still on the model, not AR attributes:
    #     # graph_subject { "urn:mm:optimize:develop:#{id}" }
    #     class_triple(:rdf_type, predicate: RDF_TYPE, iri: true) { "urn:mmg:optimize:vocab#DevelopTrace" }
    #     triple(:brief, predicate: "urn:...#brief") { brief_id }
    #     triple_each(:file_read, predicate: "urn:...#fileRead", from: -> { files_read })
    #   end
    #   DevelopTrace.find(1).statements.map(&:class)   # => [DevelopTrace::Brief, DevelopTrace::FileRead, ...]
    #   DevelopTrace.class_statements.map(&:ar_ref)    # => [DevelopTrace]  (the class itself)
    module TripleModel
      extend ::ActiveSupport::Concern

      # ONE reified triple. Carries the (subject, predicate, object) AND the ar_ref it derives from -- a Model
      # INSTANCE (row-level triples) or a Model CLASS (schema-level triples). Nested-subclassed per predicate
      # under the host model. Serialization routes through the gem's canonical TermSerializer.
      class Triple
        attr_reader :ar_ref, :element

        def initialize(ar_ref, element = nil)
          @ar_ref  = ar_ref
          @element = element
        end

        # The hard-rule grounding: true when ar_ref is an INSTANCE, false when it is a Model CLASS.
        def instance_backed? = !ar_ref.is_a?(::Class)

        # Subject IRI ground -- the instance's graph_subject, or the class's graph_class_subject.
        def subject
          instance_backed? ? ar_ref.graph_subject : ar_ref.graph_class_subject
        end
        def predicate = self.class::PREDICATE
        # Object is derived in the ar_ref's own context (row for instance triples, class for class triples);
        # `element` is threaded through for _each triples (default object = the element).
        def object = ar_ref.instance_exec(element, &self.class::OBJECT)
        # Whether the object is an IRI (<...>) rather than a literal (e.g. rdf:type).
        def iri? = self.class::IRI

        # N-Triple string via the gem's canonical TermSerializer (typed literals / IRI dispatch).
        def to_nt
          ts  = ::Vv::Graph::Storable::TermSerializer
          obj = iri? ? ts.iri(object) : ts.object(object)
          "#{ts.iri(subject)} #{ts.predicate(predicate)} #{obj} ."
        end

        # A stable key for the grounding AR ref: "Model#id" (instance) or "Model" (class).
        def ar_ref_key
          instance_backed? ? "#{ar_ref.class.name}##{ar_ref.id}" : ar_ref.name.to_s
        end

        def to_h = { type: self.class.name, subject: subject, predicate: predicate, object: object, ar_ref: ar_ref_key }
        def to_s = to_nt
      end

      class_methods do
        # This model's triple declarations, in order (each model owns its own list; not inherited).
        def triple_defs = (@triple_defs ||= [])
        # The nested triple classes this model defines (HostModel::Brief, ...).
        def triple_classes = triple_defs.map { |d| d[:class] }

        # INSTANCE-grounded scalar triple (ar_ref = the row). Object block runs in the row's context; default
        # = public_send(name). `iri: true` marks an IRI object. A nil object is SKIPPED at emit (optional fact).
        def triple(name, predicate:, iri: false, &object)
          define_triple(name, predicate: predicate, iri: iri, scope: :instance, kind: :scalar, object: object)
        end

        # INSTANCE-grounded per-element triple: one nested-class instance per item `from` yields.
        def triple_each(name, predicate:, from:, iri: false, &object)
          define_triple(name, predicate: predicate, iri: iri, scope: :instance, kind: :each, from: from, object: object)
        end

        # CLASS-grounded scalar triple (ar_ref = this class) -- vocabulary / rdf:type / SHACL shape. Object
        # block runs in the CLASS's context.
        def class_triple(name, predicate:, iri: false, &object)
          define_triple(name, predicate: predicate, iri: iri, scope: :class, kind: :scalar, object: object)
        end

        # CLASS-grounded per-element triple.
        def class_triple_each(name, predicate:, from:, iri: false, &object)
          define_triple(name, predicate: predicate, iri: iri, scope: :class, kind: :each, from: from, object: object)
        end

        # Set the instance subject IRI (block runs in row context).
        # Default (no block): derived from the full Ruby class name + row id —
        #   "urn:mm:Mm::Gem:#{id}"  — NOT a free-form stored column, NOT SimpleName-only.
        def graph_subject(&block)
          @graph_subject_block = block if block
          @graph_subject_block
        end

        # Set the class subject IRI. Default: derived from the full Ruby class name —
        #   "urn:mm:class:Mm::Gem"
        def graph_class_subject(value = nil)
          @graph_class_subject = value if value
          @graph_class_subject || class_derived_iri
        end

        # Class-ground subject IRI: exactly from this model's Ruby class name.
        def class_derived_iri
          "urn:mm:class:#{name}"
        end

        # Instance-ground subject IRI template: full class name + stable id.
        def instance_derived_iri(id)
          "urn:mm:#{name}:#{id}"
        end

        # Named graph IRI for *storage* of this model's triples (class-level declaration).
        # Distinct from subject IRIs. Override in the host model; never a per-row column.
        def graph_iri = nil

        # CLASS-grounded statements (ar_ref = this class) -- instances of the class-scoped nested classes.
        def class_statements
          triple_defs.select { |d| d[:scope] == :class }.flat_map { |d| build_statements(d, self) }
        end
        def class_to_triples = class_statements.map(&:to_nt)

        # Store this class's schema-level triples through the hard gate.
        def project_class!(graph: nil)
          ::Vv::Graph::Store.write(class_statements, graph: graph || graph_iri)
        end

        # Instantiate a declaration's statements against an ar_ref (class or instance). A nil scalar object
        # yields no statement (optional fact); an _each fans out over `from`.
        def build_statements(decl, ar_ref)
          if decl[:kind] == :each
            ::Kernel.Array(ar_ref.instance_exec(&decl[:from])).map { |el| decl[:class].new(ar_ref, el) }
          else
            t = decl[:class].new(ar_ref)
            t.object.nil? ? [] : [t]
          end
        end

        private

        def define_triple(name, predicate:, iri:, scope:, kind:, from: nil, object: nil)
          object ||= (kind == :each ? ->(el) { el } : ->(_el) { public_send(name) })
          cls = ::Class.new(::Vv::Graph::TripleModel::Triple)
          cls.const_set(:PREDICATE, predicate.to_s)
          cls.const_set(:OBJECT, object)
          cls.const_set(:IRI, iri ? true : false)
          cls.const_set(:SCOPE, scope)
          const_set(name.to_s.split(/[_\W]/).map(&:capitalize).join, cls)
          triple_defs << { name: name.to_sym, kind: kind, scope: scope, class: cls, from: from }
          cls
        end
      end

      # INSTANCE-grounded statements (ar_ref = self) -- instances of the instance-scoped nested classes.
      def statements
        self.class.triple_defs.select { |d| d[:scope] == :instance }.flat_map do |d|
          self.class.build_statements(d, self)
        end
      end
      def to_triples = statements.map(&:to_nt)

      # Subject IRI ground for this row.
      # Prefer model-declared graph_subject block; else full Ruby class name + id.
      def graph_subject
        blk = self.class.graph_subject
        return instance_exec(&blk) if blk
        self.class.instance_derived_iri(id)
      end

      # Store this instance's row-level triples through the hard gate.
      # Graph ops stay on the AR model (this method + class project_class!).
      def project!(graph: nil)
        ::Vv::Graph::Store.write(statements, graph: graph || self.class.graph_iri)
      end
    end
  end
end
