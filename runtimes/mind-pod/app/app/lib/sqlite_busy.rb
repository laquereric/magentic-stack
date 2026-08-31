# frozen_string_literal: true

# A lock timeout under two writers is a refusal (ADR 0054 / 0056): a
# boundary said no, for a reason, and a caller may need to act. Printed
# StandardError is not that record.
module SqliteBusy
  REASON = "sqlite_busy"

  module_function

  def busy?(error)
    return false if error.nil?

    walk(error).any? do |e|
      n = e.class.name.to_s
      next true if n.include?("BusyException")
      next true if n.include?("LockWaitTimeout")
      msg = "#{n}: #{e.message}"
      msg.match?(/SQLITE_BUSY|database is locked|database is busy/i)
    end
  end

  def record!(error, source:)
    return false unless defined?(::RailsCpcp::RefusalLog)

    ::RailsCpcp::RefusalLog.record(
      reason: REASON,
      because: { "class" => error.class.name, "message" => error.message.to_s },
      source: source
    )
  end

  def walk(error)
    out = []
    seen = {}
    cur = error
    while cur && !seen[cur.object_id]
      seen[cur.object_id] = true
      out << cur
      cur = cur.respond_to?(:cause) ? cur.cause : nil
    end
    out
  end
end
