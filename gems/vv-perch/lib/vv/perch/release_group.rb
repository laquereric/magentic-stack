# frozen_string_literal: true

module Vv
  module Perch
    class ReleaseGroup < Record
      has_many :slices, class_name: "Vv::Perch::Slice"
      has_many :orphans, class_name: "Vv::Perch::Orphan"

      validates :group_key, presence: true, uniqueness: true

      # The only writer of slice.released_at. Refused if any member has
      # not passed its gate. One transaction, every member.
      def release!
        members = slices.reload.to_a
        missing = members.select { |s| s.gate_passed_at.nil? }
        unless missing.empty?
          return Envelope.refuse(
            Refusals::RELEASE,
            "a release-group member has not passed its gate: " \
            "#{missing.map(&:slice_key).join(', ')}"
          )
        end

        now = Time.now.utc
        transaction do
          update!(released_at: now)
          members.each do |s|
            # Handed to the record, for this save only. Not ambient state.
            s.released_by_group = self
            begin
              s.update!(released_at: now)
            ensure
              s.released_by_group = nil
            end
          end
        end
        Envelope.ok(released_at: now, n: members.length)
      end
    end
  end
end
