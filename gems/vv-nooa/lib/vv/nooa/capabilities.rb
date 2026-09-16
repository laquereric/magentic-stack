# frozen_string_literal: true

require_relative "capability"

module Vv
  module Nooa
    # The six model-facing capabilities NVIDIA argues a serious agent harness
    # needs (NVIDIA Object-Oriented Agents, "NOOA"), each mapped to its
    # magentic-stack realization.
    #
    # This is doctrine-as-data, not an adapter. The pinned Python harness lives
    # at upstreams/nooa and is reached only through gems/adapters/ (ADR 0020)
    # and runtimes/mind-pod. Grounding: https://github.com/NVIDIA-NeMo/labs-OO-Agents
    module Capabilities
      module_function

      ALL = [
        Capability.new(key: :typed_io, title: "Typed input & output",
          nvidia: "Action arguments are typed; return values are validated against a contract, the way a normal function signature works.",
          mm: "CPCP never-raise envelopes ({ ok: true, .. } | { ok: false, reason:, because: }) at /_cpcp; typed contracts are closed SHACL shapes (OSI Level 8). LinkML is the shape source (ADR 0069).",
          steal: "Keep deterministic validation deterministic -- a contract is not a prompt."),
        Capability.new(key: :pass_by_reference, title: "Pass-by-reference",
          nvidia: "A large tool result stays alive in the runtime; the model receives a typed, bounded PREVIEW, not the full payload, and the object stays addressable.",
          mm: "Profile 2 (ADR 0023): a JSON-RPC-LD @id is a pass-by-reference handle; the model reads Context by reference with typed bounded previews. Blobs are CID-grounded (ADR 0012, ADR 0016).",
          steal: "Return an ID + bounded preview, not the whole object -- and protect the prefix cache."),
        Capability.new(key: :code_as_action, title: "Code as action",
          nvidia: "The model expresses multi-step logic as real code (loops, conditionals, intermediate variables) inside ONE action instead of a long chain of tool calls.",
          mm: "MIND runs the pinned NOOA harness; the model writes Python as CodeAct. Isolation is Monty (ADR 0071), not AST checks. Distroless is the container boundary. This gem does not execute code.",
          steal: "One expressive coded action beats N brittle single-tool turns."),
        Capability.new(key: :programmable_loop, title: "Programmable loop engineering",
          nvidia: "The orchestration loop is ordinary code the developer -- and the model -- can inspect and modify, not hidden framework internals.",
          mm: "NOOA's loop is ordinary Python in the pinned harness. MIND wraps CodeAct via intercept and does not replace NOOA (ADR 0071). The loop is inspectable source, not a hidden framework.",
          steal: "Own your loop; make it inspectable."),
        Capability.new(key: :explicit_object_state, title: "Explicit object state",
          nvidia: "Persistent state lives as typed fields on the object; the harness does not reconstruct it by re-reading the chat history every turn.",
          mm: "Durable admission truth is the operation journal (ADR 0052). Three kinds of state (ADR 0057). RDF named graphs must be persisted entries (ADR 0011). NOOA session memory is the mind-nooa-data volume, not the chat transcript.",
          steal: "Treat conversation history as a log, not a database."),
        Capability.new(key: :model_callable_apis, title: "Model-callable harness APIs",
          nvidia: "The model can inspect and manage its OWN context -- keep, discard, summarize -- instead of leaving that entirely to the harness.",
          mm: "Cyborg Channel Context/Effect (ADR 0004, ADR 0005) as CPCP PULL/PUSH. MIND methods are the model-callable harness APIs; the agent curates its own context through the pinned NOOA harness, not by rereading chat.",
          steal: "Give the model APIs to manage its own context."),
      ].freeze

      KEYS = ALL.map(&:key).freeze

      def all = ALL
      def keys = KEYS
      def count = ALL.size

      # never-raise lookup
      def fetch(key)
        cap = ALL.find { |c| c.key == key.to_s.to_sym }
        return { ok: false, reason: :unknown_capability, because: "no NOOA capability #{key.inspect}; known: #{KEYS.join(', ')}" } unless cap
        { ok: true, capability: cap }
      end
    end
  end
end
