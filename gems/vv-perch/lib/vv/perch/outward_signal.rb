# frozen_string_literal: true

module Vv
  module Perch
    # Stage 2. The outward signal is the only evidence a receiver's aim was met.
    #
    # perchv2 §12.1 is the rule the rest of this file exists to hold:
    #
    #   "Integration signals are necessary. A whole is complete only when an
    #    OUTWARD signal shows its receiver's aim was achieved."
    #
    # Three states, closed. The first version named them and computed none of
    # them: maturity was `readings.where.not(matured_at: nil).exists?`, which
    # had two holes. It never read `delay_iso8601`, so `pending` meant "nobody
    # stamped a column" rather than "the delay has not elapsed" -- and S2's
    # signal is `no re-contact within 7 days`, so the delay IS the measurement.
    # And it did not filter signal_class, so a matured INWARD reading -- a test
    # pass, an eval gate -- made a slice done. That inverts §12.1 with a missing
    # WHERE clause.
    class OutwardSignal < Record
      # ISO 8601 duration, the subset a signal window needs. `P7D` is the one
      # perchv2 uses. Deliberately not months or years: those are not fixed
      # durations, and a signal window that changes length by month is not a
      # window. Anything else is refused rather than guessed at.
      DELAY = /\AP(?!\z)(?:(\d+)W)?(?:(\d+)D)?(?:T(?!\z)(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?\z/
      UNITS = [604_800, 86_400, 3_600, 60, 1].freeze

      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id
      has_many :readings, class_name: "Vv::Perch::SignalReading", dependent: :destroy

      validate :delay_is_parseable

      # nil means "no window": a reading is mature the moment it is observed.
      # Returns :invalid rather than 0 for junk, because a window nobody can
      # read is not a window of length zero.
      def delay_seconds
        raw = delay_iso8601.to_s.strip
        return nil if raw.empty?

        m = DELAY.match(raw)
        return :invalid unless m

        m.captures.each_with_index.sum { |v, i| v.to_i * UNITS[i] }
      end

      def window_valid? = delay_seconds != :invalid

      # When THIS reading's window closes. Absent observed_at means the reading
      # never happened, which is not a window that has closed.
      def matures_at(reading)
        secs = delay_seconds
        return nil if secs == :invalid || reading.observed_at.nil?

        reading.observed_at + secs.to_i
      end

      def matured?(reading, now: Time.now.utc)
        at = matures_at(reading)
        !at.nil? && at <= now
      end

      # Outward only. An inward reading is real evidence about a different
      # question and is never evidence about the receiver's aim.
      def outward_readings = readings.where(signal_class: "outward")

      def matured_readings(now: Time.now.utc)
        outward_readings.select { |r| matured?(r, now: now) }
      end

      def maturity(now: Time.now.utc)
        return :not_instrumented if instrumented_at.nil?
        return :pending unless window_valid?
        return :reporting if matured_readings(now: now).any?

        :pending
      end

      # Stamps the record of WHEN a window was observed to have closed. The
      # authority is still the computation -- this is a note, not the truth,
      # which is why maturity never reads it.
      def mature!(reading, now: Time.now.utc)
        if reading.signal_class.to_s != "outward"
          return Envelope.refuse(
            Refusals::INWARD_IS_NOT_OUTWARD,
            "reading #{reading.id} is #{reading.signal_class.inspect}; only an outward reading " \
            "is evidence the receiver's aim was met"
          )
        end
        if delay_seconds == :invalid
          return Envelope.refuse(
            Refusals::SIGNAL_DELAY_UNPARSEABLE,
            "delay_iso8601 #{delay_iso8601.inspect} is not a duration this gem reads"
          )
        end
        unless matured?(reading, now: now)
          at = matures_at(reading)
          return Envelope.refuse(
            Refusals::SIGNAL_NOT_MATURED,
            at.nil? ? "reading #{reading.id} has no observed_at, so its window never opened"
                    : "window closes #{at.iso8601}; it is #{now.iso8601}. Pending is not a failed aim"
          )
        end

        reading.update!(matured_at: now)
        Envelope.ok(reading_id: reading.id, matured_at: now)
      end

      private

      def delay_is_parseable
        return if delay_seconds != :invalid

        errors.add(:delay_iso8601, Refusals::SIGNAL_DELAY_UNPARSEABLE)
      end
    end
  end
end
