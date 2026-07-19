# frozen_string_literal: true

module Vv
  module Graph
    # Store -- THE HARD GATE on graph storage. The hard rule: every triple written to the graph must carry
    # an AR REFERENCE (a Model CLASS or an INSTANCE of a Model class). Store accepts reified
    # Vv::Graph::TripleModel::Triple objects (which always answer #ar_ref) and REFUSES ungrounded input --
    # a triple whose ar_ref is nil, or a raw N-Triple string with no ar_ref at all.
    #
    # Enforcement is STAGED via the VV_GRAPH_TRIPLE_GATE env (so flipping the gate does not brick a substrate
    # mid-migration):
    #   "strict" -- refuse the write when any triple is ungrounded (write only the grounded ones is NOT done;
    #               an ungrounded batch is a programming error and returns {ok:false}).
    #   "warn"   -- (default, interim) log the violation but still write, so legacy paths keep working while
    #               the app migrates onto TripleModel.
    #   "off"    -- write silently, no grounding check (escape hatch).
    #
    # The actual write delegates to Vv::Graph::Sparql.execute (INSERT DATA). Never-raise -> envelope.
    module Store
      GATE_ENV       = "VV_GRAPH_TRIPLE_GATE"
      DEFAULT_MODE   = "warn"
      MODES          = %w[strict warn off].freeze

      module_function

      def mode
        m = (::ENV[GATE_ENV] || DEFAULT_MODE).to_s.downcase
        MODES.include?(m) ? m : DEFAULT_MODE
      end

      # A triple is GROUNDED iff it carries a non-nil ar_ref (a Model class or instance) -- the hard rule.
      def grounded?(triple)
        triple.respond_to?(:ar_ref) && !triple.ar_ref.nil?
      end

      # Write reified triples through the gate. `triples` = a Triple, an Array of Triple, or a model that
      # answers #statements / #class_statements. Returns { ok:, count:, refused:, grounded: }.
      def write(triples, graph: nil)
        list = normalize(triples)
        return { ok: true, count: 0, refused: 0, grounded: 0, note: "nothing to write" } if list.empty?

        grounded, ungrounded = list.partition { |t| grounded?(t) }

        if ungrounded.any?
          because = "#{ungrounded.size} triple(s) lack an AR reference " \
                    "(Vv::Graph hard rule: every stored triple is grounded by a Model class or instance)"
          case mode
          when "strict"
            return { ok: false, reason: :ungrounded_triple, because: because,
                     refused: ungrounded.size, grounded: grounded.size }
          when "warn"
            ::Kernel.warn("[Vv::Graph::Store] #{because}")
          end
        end

        # strict writes ONLY grounded triples; warn/off write everything routed in (legacy interim).
        writable = (mode == "strict") ? grounded : list
        return { ok: true, count: 0, refused: ungrounded.size, grounded: grounded.size } if writable.empty?

        nt  = writable.map { |t| t.respond_to?(:to_nt) ? t.to_nt : t.to_s }.join("\n")
        res = ::Vv::Graph::Sparql.execute("INSERT DATA { #{nt} }", graph: graph)
        ok  = res.is_a?(::Hash) ? res.fetch(:ok, false) : true
        { ok: ok, count: (res.is_a?(::Hash) ? res[:count] : writable.size),
          refused: ungrounded.size, grounded: grounded.size, write: res }
      rescue ::StandardError => e
        { ok: false, reason: :store_failed, because: "#{e.class}: #{e.message}" }
      end

      # Coerce the argument into a flat Array of triple objects. A model answering #statements /
      # #class_statements contributes those; anything else is wrapped as-is (and will be gated on ar_ref).
      def normalize(arg)
        case arg
        when ::Array
          arg.flat_map { |a| normalize(a) }
        else
          if arg.respond_to?(:statements)
            ::Kernel.Array(arg.statements)
          elsif arg.respond_to?(:class_statements)
            ::Kernel.Array(arg.class_statements)
          else
            [arg].compact
          end
        end
      end
    end
  end
end
