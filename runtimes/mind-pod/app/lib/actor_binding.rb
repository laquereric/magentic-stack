# frozen_string_literal: true

require "json"

# Which Actor is this caller? Answered by the operator, never by the caller.
#
# THE DEFECT THIS CLOSES. bpmn.claim took actor_id from the request body and
# checked only that the Actor existed. Anyone who could reach BACK could claim
# a review as anyone, and the review row would then name a human who never saw
# the diff. For a process whose entire purpose is that someone stood behind the
# change (AiSDLC.md: agent output is a confident junior who has read every
# textbook and worked at none of our companies), that is not a small hole -- it
# is the hole.
#
# WHY NOT callerIri. The obvious binding is params["callerIri"], which several
# P7 handlers already read. It is caller-supplied, so binding actor_id to it
# would move the lie one field to the left and change nothing. A binding is
# only worth anything if the caller cannot assert it.
#
# So this copies vault (ADR 0046, Vault::Allowlist) exactly, because vault is
# where this repo already solved "which caller is this":
#
#   - the bearer is the Authorization HEADER, never a JSON-RPC param
#   - the map is an environment variable the operator controls
#   - there is NO default: absent, empty or unparseable is a refusal, not an
#     anonymous caller
#   - a token collision between two actors is unparseable, because a token that
#     resolves to two people cannot attribute a review to either
#
# BPMN_REVIEW_ACTORS is {"<token>": {"actor_id": <int>, "label": "<who>"}}.
# label is for refusal messages and logs; actor_id is the binding.
class ActorBinding
  ENV_KEY = "BPMN_REVIEW_ACTORS"

  class Error < StandardError
    attr_reader :reason, :because

    def initialize(reason, because)
      @reason = reason
      @because = because
      super(reason)
    end
  end

  # actor_cid carries the SAME binding for callers that speak CIDs rather than
  # AR ids -- profile9 and ui.action journal an actorCid, bpmn/perch claim an
  # actor_id. One map, two spellings of the answer, because G13's move is "do
  # not invent a second identity plane" and a parallel FrontActorBinding would
  # be exactly that.
  Bound = Struct.new(:actor_id, :actor_cid, :label, keyword_init: true)

  def self.from_env(raw = ENV[ENV_KEY])
    parse!(raw)
  end

  def self.parse!(raw)
    if raw.nil? || raw.to_s.strip.empty?
      raise Error.new("review_actors_missing",
                      { "offender" => ENV_KEY,
                        "because" => "no actor binding is configured, so no caller can be " \
                                     "attributed a review. Fail closed: an unbound claim would " \
                                     "name an actor nobody authenticated" })
    end

    data = begin
      JSON.parse(raw)
    rescue JSON::ParserError => e
      raise Error.new("review_actors_unparseable", { "offender" => ENV_KEY, "because" => e.class.name })
    end

    unless data.is_a?(Hash) && !data.empty?
      raise Error.new("review_actors_unparseable",
                      { "offender" => ENV_KEY, "because" => "want a non-empty object" })
    end

    by_token = {}
    seen_actors = {}
    data.each do |token, spec|
      token = token.to_s
      if token.strip.empty?
        raise Error.new("review_actors_unparseable", { "offender" => ENV_KEY, "because" => "empty token" })
      end
      unless spec.is_a?(Hash)
        raise Error.new("review_actors_unparseable",
                        { "offender" => token[0, 6], "because" => "caller spec must be an object" })
      end

      # A spec binds an actor_id, an actor_cid, or both. Requiring actor_id
      # unconditionally would have forced a second map for the CID callers.
      # Requiring NEITHER is still a refusal: a token that names nobody cannot
      # attribute anything, which is the whole point of this class.
      actor_cid = spec["actor_cid"].to_s.strip
      actor_id = spec["actor_id"]
      has_id = actor_id.is_a?(Integer) || (actor_id.is_a?(String) && actor_id.to_s.match?(/\A\d+\z/))

      if !has_id && actor_cid.empty?
        raise Error.new("review_actors_actor_missing",
                        { "offender" => spec["label"] || token[0, 6],
                          "because" => "want actor_id (integer) or actor_cid (string), and got neither" })
      end
      if actor_id && !has_id
        raise Error.new("review_actors_actor_missing",
                        { "offender" => spec["label"] || token[0, 6],
                          "because" => "actor_id must be an integer" })
      end
      actor_id = has_id ? Integer(actor_id) : nil

      # Two tokens for one actor is fine -- a person may hold a laptop token and
      # a CI token. Two ACTORS for one token is not: the review could not be
      # attributed to either of them.
      if by_token.key?(token)
        raise Error.new("review_actors_token_collision", { "offender" => token[0, 6] })
      end

      by_token[token] = Bound.new(
        actor_id: actor_id,
        actor_cid: actor_cid.empty? ? nil : actor_cid,
        label: (spec["label"] || "actor:#{actor_id || actor_cid}").to_s
      )
      (seen_actors[actor_id || actor_cid] ||= []) << token
    end

    new(by_token)
  end

  def initialize(by_token)
    @by_token = by_token
  end

  # The bound Actor for this bearer, or an Error. Never a default.
  def resolve!(token)
    if token.to_s.strip.empty?
      raise Error.new("review_unauthenticated",
                      { "offender" => "Authorization",
                        "because" => "absent. The bearer is a header, never a parameter" })
    end

    bound = @by_token[token.to_s]
    unless bound
      # Deliberately not saying which part was wrong, and not echoing the token.
      raise Error.new("review_unauthenticated", { "offender" => "Authorization", "because" => "unknown" })
    end

    bound
  end

  # The caller MAY restate its own actor_id; it may not name a different one.
  #
  # Same rule as SparqlFun's principal_override_refused, and for the same
  # reason: silently preferring the bound value would train callers to send an
  # actor_id that does nothing, and the first person to read that code will
  # assume it works. Neither side wins quietly.
  def reconcile!(bound, supplied)
    return bound if supplied.nil? || supplied.to_s.strip.empty?

    unless supplied.to_s == bound.actor_id.to_s
      raise Error.new("actor_override_refused",
                      { "supplied" => supplied.to_s, "bound" => bound.actor_id,
                        "because" => "the bearer is bound to a different Actor. The binding is " \
                                     "the operator's; a parameter does not overrule it" })
    end

    bound
  end

  # The CID twin of reconcile!. Same rule, same refusal, different spelling of
  # the answer: a caller MAY restate the actorCid its bearer is bound to, and
  # may not name a different one. Silently preferring the bound value would
  # train callers to send an actorCid that does nothing.
  def reconcile_cid!(bound, supplied)
    if bound.actor_cid.to_s.strip.empty?
      raise Error.new("actor_cid_unbound",
                      { "offender" => bound.label,
                        "because" => "this bearer is bound to an actor_id but no actor_cid, and " \
                                     "this seam journals a CID. Bind one in the operator map " \
                                     "rather than letting the caller supply it" })
    end
    return bound if supplied.nil? || supplied.to_s.strip.empty?

    unless supplied.to_s == bound.actor_cid.to_s
      raise Error.new("actor_override_refused",
                      { "supplied" => supplied.to_s, "bound" => bound.actor_cid,
                        "because" => "the bearer is bound to a different Actor. The binding is " \
                                     "the operator's; a parameter does not overrule it" })
    end

    bound
  end

  def size = @by_token.size
end
