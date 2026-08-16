# frozen_string_literal: true
module RailsCpcp
  # Pluggable idempotency store keyed by operationId. Default is in-memory
  # (single process). For production, back it with a DB table or Redis so PUSH
  # retries return the SAME receipt across processes/pods.
  class MemoryIdempotency
    def initialize; @store = {}; end
    def get(key); @store[key]; end
    def put(key, value); @store[key] = value; value; end
  end

  module_function
  def idempotency_store; @idempotency_store ||= MemoryIdempotency.new; end
  def idempotency_store=(store); @idempotency_store = store; end
end
