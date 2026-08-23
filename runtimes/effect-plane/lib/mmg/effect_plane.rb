# frozen_string_literal: true
require_relative "effect_plane/version"
require_relative "effect_plane/vocabulary"
require_relative "effect_plane/placement"
require_relative "effect_plane/classifier"
require_relative "effect_plane/snapshot"
require_relative "effect_plane/fork"
require_relative "effect_plane/reference"

module Mmg
  # PLANE C -- materialized effect state.
  #
  #   Plane A  execution registration  -- reversible by teardown (Cordis undo)
  #   Plane B  domain truth            -- append-only; corrected by a new fact
  #   Plane C  materialized effect     -- THIS: which immutable materialization
  #                                       is active, and how it got there
  #
  # Rollback on Plane C is legitimate ONLY as an explicit fork-and-activate that
  # appends an EffectForkActivated fact. It is never a rewind of domain truth.
  # "The prior digest still exists" is an accounting trick if the live system
  # silently abandons domain facts that lived only in the abandoned image or
  # volume -- so C1 (authoritative-history retention) is a precondition, not a
  # nicety.
  #
  # ONE JOB: classify the landing place and rollback class of an effect, then
  # validate and describe durable materialization snapshots and explicit fork
  # activations.
  #
  # Deliberately absent: any Docker client, `docker commit` wrapper, Kubernetes
  # client, OCI signer, RES writer, store-specific SQLite/oxigraph code, volume
  # copier, image GC, or policy engine. The integration point is EVIDENCE
  # VALIDATION and a stable vocabulary -- never command execution.
  #
  # Design: docs/MmgEffectPlaneDesign.md.
  module EffectPlane
  end
end
