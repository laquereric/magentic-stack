# frozen_string_literal: true

module Vv
  module CodeRepo
    Operation = Struct.new(:name, :direction, :notes, keyword_init: true)

    # CPCP surface declared as data. No dispatcher lives here.
    module Operations
      ALL = [
        Operation.new(name: "procedure.put", direction: :push,
                      notes: "Land a revision. DEV only. Bytes already in blob.put."),
        Operation.new(name: "procedure.get", direction: :pull,
                      notes: "By slug or digest. Envelope + bindings, not eval."),
        Operation.new(name: "procedure.list", direction: :pull,
                      notes: "Catalog; Gold-first in PROD."),
        Operation.new(name: "procedure.bind", direction: :push,
                      notes: "Attach {language, digest, entrypoint} to a revision."),
        Operation.new(name: "procedure.conform", direction: :push,
                      notes: "Bronze → Silver. LinkML + SHACL. BACKJOB."),
        Operation.new(name: "procedure.promote", direction: :push,
                      notes: "Silver → Gold. Contract + eval. BACKJOB. Not PROD."),
        Operation.new(name: "procedure.graph.get", direction: :pull,
                      notes: "Localized PG neighborhood. PROD default 2-hop. Graph frozen."),
        Operation.new(name: "procedure.serve", direction: :pull,
                      notes: "Gold only. FRONT/MIND consume."),
        Operation.new(name: "procedure.reject", direction: :push,
                      notes: "Failed ΔG into rejection memory. DEV.")
      ].freeze

      BY_NAME = ALL.each_with_object({}) { |op, h| h[op.name] = op }.freeze

      module_function

      def names = ALL.map(&:name)

      def named(name) = BY_NAME[name.to_s]

      def pushes = ALL.select { |o| o.direction == :push }
    end
  end
end
