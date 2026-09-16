# frozen_string_literal: true

require "spec_helper"
require "digest"

RSpec.describe "vv-perch schema" do
  def digest(text = "uc")
    "sha256:#{Digest::SHA256.hexdigest(text)}"
  end

  def use_case(uc_id: "UC1")
    Vv::Perch::UseCase.create!(uc_id: uc_id, text_sha256: digest(uc_id), aim: "pay an invoice")
  end

  def actor(role_key:, name: role_key)
    Vv::Base::Actor.create!(name: name, role_key: role_key)
  end

  it "creates exactly fifteen perch_ tables" do
    names = ActiveRecord::Base.connection.tables.select { |t| t.start_with?("perch_") }.sort
    expect(names).to eq(Vv::Perch::TABLES.sort)
    expect(names.length).to eq(15)
  end

  it "keeps T1–T5 as a closed named list" do
    expect(Vv::Perch::Refusals::FLOOR.keys).to contain_exactly(:t1, :t2, :t3, :t4, :t5)
    expect(Vv::Perch::Refusals::T5).to eq("slices_are_one_whole")
    expect(Vv::Perch::Refusals::T1).to eq("receiver_did_not_predate_the_cut")
  end

  describe "T1 receiver predates the cut" do
    it "accepts an actor already in the catalog" do
      clerk = actor(role_key: "accounts_payable", name: "AP clerk")
      uc = use_case
      s = Vv::Perch::Slice.create!(use_case: uc, slice_key: "S1", receiver: clerk,
                                   terminates_at: "the invoice is paid")
      expect(s).to be_persisted
    end

    it "refuses a Perch/Fledge/gate/building-team receiver" do
      uc = use_case
      %w[perch:sizer fledge:distill gate building_team datamodeling].each do |role|
        bad = actor(role_key: role)
        s = Vv::Perch::Slice.new(use_case: uc, slice_key: "S-#{role}", receiver: bad)
        expect(s.save).to eq(false), role
        expect(s.errors[:receiver_id]).to include(Vv::Perch::Refusals::T1), role
      end
    end
  end

  describe "T2 terminating aim is outward" do
    it "refuses a workshop state as Terminates at" do
      uc = use_case
      s = Vv::Perch::Slice.new(use_case: uc, slice_key: "S2", terminates_at: "merged to main")
      expect(s.save).to eq(false)
      expect(s.errors[:terminates_at]).to include(Vv::Perch::Refusals::T2)
    end
  end

  describe "T5 requires is acyclic" do
    it "refuses two slices requiring each other as slices_are_one_whole" do
      uc = use_case
      a = Vv::Perch::Slice.create!(use_case: uc, slice_key: "SA")
      b = Vv::Perch::Slice.create!(use_case: uc, slice_key: "SB")
      Vv::Perch::SliceRequirement.create!(sized_slice: a, requires_slice: b)
      cycle = Vv::Perch::SliceRequirement.new(sized_slice: b, requires_slice: a)
      expect(cycle.save).to eq(false)
      expect(cycle.errors[:requires_slice_id]).to include(Vv::Perch::Refusals::T5)
    end
  end

  describe "release is not minted on the slice" do
    it "refuses assigning released_at on the slice itself" do
      uc = use_case
      s = Vv::Perch::Slice.create!(use_case: uc, slice_key: "S1")
      s.released_at = Time.now.utc
      expect(s.save).to eq(false)
      expect(s.errors[:released_at]).to include(Vv::Perch::Refusals::RELEASE)
    end

    it "writes every member in one transaction from ReleaseGroup#release!" do
      group = Vv::Perch::ReleaseGroup.create!(group_key: "G1")
      uc = use_case
      a = Vv::Perch::Slice.create!(use_case: uc, slice_key: "S1", release_group: group)
      b = Vv::Perch::Slice.create!(use_case: uc, slice_key: "S2", release_group: group)
      a.pass_gate!
      refused = group.release!
      expect(refused[:ok]).to eq(false)
      expect(refused[:reason]).to eq(Vv::Perch::Refusals::RELEASE)

      b.pass_gate!
      ok = group.release!
      expect(ok[:ok]).to eq(true)
      expect(a.reload.released_at).to eq(b.reload.released_at)
      expect(a.released_at).not_to be_nil
      expect(a.ready_waiting_on_group?).to eq(false)
    end

    # The capability is handed to the record, not read from ambient state.
    # The first version gated on Thread.current[:perch_releasing], which any
    # caller could set before writing the column.
    it "refuses a release stamped by a group that does not own the slice" do
      mine = Vv::Perch::ReleaseGroup.create!(group_key: "G-mine")
      theirs = Vv::Perch::ReleaseGroup.create!(group_key: "G-theirs")
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1", release_group: mine)

      s.released_by_group = theirs
      s.released_at = Time.now.utc
      expect(s.save).to eq(false)
      expect(s.errors[:released_at]).to include(Vv::Perch::Refusals::RELEASE)
    end

    it "refuses a release stamped on a slice that is in no group at all" do
      group = Vv::Perch::ReleaseGroup.create!(group_key: "G-orphan")
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")

      s.released_by_group = group
      s.released_at = Time.now.utc
      expect(s.save).to eq(false)
      expect(s.errors[:released_at]).to include(Vv::Perch::Refusals::RELEASE)
    end

    it "shows ready, waiting on group when the gate passed and the group has not released" do
      group = Vv::Perch::ReleaseGroup.create!(group_key: "G2")
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1", release_group: group)
      s.pass_gate!
      expect(s.ready_waiting_on_group?).to eq(true)
      expect(s.done?).to eq(false)
    end
  end

  describe "outward signal maturity" do
    it "does not treat a pending signal as a failing one" do
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")
      sig = Vv::Perch::OutwardSignal.create!(
        sized_slice: s, text: "no re-contact in 7 days", delay_iso8601: "P7D",
        instrumented_at: Time.now.utc
      )
      expect(sig.maturity).to eq(:pending)
      reading = Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "outward", value: nil, observed_at: Time.now.utc
      )
      expect(reading.value).to be_nil
      expect(sig.maturity).to eq(:pending)
      expect(s.done?).to eq(false)
    end

    it "computes done from released + instrumented + reporting, not a column" do
      group = Vv::Perch::ReleaseGroup.create!(group_key: "G3")
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1", release_group: group)
      s.pass_gate!
      group.release!
      sig = Vv::Perch::OutwardSignal.create!(
        sized_slice: s, text: "paid", instrumented_at: Time.now.utc
      )
      expect(s.reload.done?).to eq(false)
      Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "outward", value: "0",
        observed_at: Time.now.utc, matured_at: Time.now.utc
      )
      expect(sig.maturity).to eq(:reporting)
      expect(s.reload.done?).to eq(true)
      expect(s.attributes).not_to have_key("done")
    end
  end

  # Stage 2. S2's signal in perchv2 is "no re-contact within 7 days", so the
  # DELAY is the measurement -- a slice released three days ago has no verdict
  # yet, and that is pending, not failure.
  describe "the outward signal window" do
    def released_slice(key)
      group = Vv::Perch::ReleaseGroup.create!(group_key: "G-#{key}")
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: key, release_group: group)
      s.pass_gate!
      group.release!
      s.reload
    end

    let(:now) { Time.utc(2026, 9, 15, 12, 0, 0) }

    it "stays pending inside the window, and pending is not a failed aim" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.create!(
        sized_slice: s, text: "no re-contact", delay_iso8601: "P7D", instrumented_at: now
      )
      Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "outward", observed_at: now
      )

      three_days_later = now + (3 * 86_400)
      expect(sig.maturity(now: three_days_later)).to eq(:pending)
      expect(s.done?(now: three_days_later)).to eq(false)
      expect(s.signal_state(now: three_days_later)).to eq(:pending)
    end

    it "reports once the window closes" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.create!(
        sized_slice: s, text: "no re-contact", delay_iso8601: "P7D", instrumented_at: now
      )
      r = Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "outward", observed_at: now
      )

      eight_days = now + (8 * 86_400)
      expect(sig.matures_at(r)).to eq(now + (7 * 86_400))
      expect(sig.maturity(now: eight_days)).to eq(:reporting)
      expect(s.done?(now: eight_days)).to eq(true)
    end

    # THE INVERTED RULE. The first cut matched every reading with a matured_at,
    # so a matured INWARD verdict -- a test pass -- finished the slice. §12.1
    # says integration signals are necessary and not sufficient.
    it "never lets an inward reading finish a slice, however matured" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.create!(
        sized_slice: s, text: "no re-contact", delay_iso8601: "P7D", instrumented_at: now
      )
      inward = Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "inward", value: "pass", observed_at: now
      )
      # update_column on purpose: this reproduces the exact row the old code
      # matched -- a reading with matured_at set and no class filter above it.
      # Going through the model would refuse it, which would test the
      # validation instead of the query it is meant to protect.
      inward.update_column(:matured_at, now + (8 * 86_400))

      long_after = now + (99 * 86_400)
      expect(sig.readings.where.not(matured_at: nil)).to be_present  # the row exists
      expect(sig.maturity(now: long_after)).to eq(:pending)          # and does not count
      expect(s.done?(now: long_after)).to eq(false)
    end

    it "refuses to mature an inward reading by name" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.create!(sized_slice: s, instrumented_at: now)
      r = Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "inward", observed_at: now
      )

      out = sig.mature!(r, now: now + 86_400)
      expect(out[:ok]).to eq(false)
      expect(out[:reason]).to eq(Vv::Perch::Refusals::INWARD_IS_NOT_OUTWARD)
    end

    it "refuses to mature before the window closes, and stamps after" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.create!(
        sized_slice: s, delay_iso8601: "P7D", instrumented_at: now
      )
      r = Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "outward", observed_at: now
      )

      early = sig.mature!(r, now: now + 86_400)
      expect(early[:ok]).to eq(false)
      expect(early[:reason]).to eq(Vv::Perch::Refusals::SIGNAL_NOT_MATURED)
      expect(early[:because]).to include("Pending is not a failed aim")

      late = sig.mature!(r, now: now + (8 * 86_400))
      expect(late[:ok]).to eq(true)
      expect(r.reload.matured_at).not_to be_nil
    end

    # matured_at is a note about a computation, so the computation writes it.
    # Hand-stamping it would declare a window closed while it is open.
    it "refuses a hand-stamped matured_at inside the window" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.create!(
        sized_slice: s, delay_iso8601: "P7D", instrumented_at: now
      )
      r = Vv::Perch::SignalReading.new(
        outward_signal: sig, signal_class: "outward",
        observed_at: now, matured_at: now + 86_400
      )

      expect(r.save).to eq(false)
      expect(r.errors[:matured_at]).to include(Vv::Perch::Refusals::SIGNAL_NOT_MATURED)
    end

    it "refuses a delay it cannot read rather than treating it as zero" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.new(
        sized_slice: s, delay_iso8601: "7 days", instrumented_at: now
      )

      expect(sig.save).to eq(false)
      expect(sig.errors[:delay_iso8601]).to include(Vv::Perch::Refusals::SIGNAL_DELAY_UNPARSEABLE)
    end

    it "reads the durations a window is allowed to use" do
      sig = Vv::Perch::OutwardSignal.new(sized_slice: released_slice("S1"))
      { "P7D" => 604_800, "P1W" => 604_800, "PT36H" => 129_600, "PT90M" => 5_400 }
        .each do |iso, secs|
          sig.delay_iso8601 = iso
          expect(sig.delay_seconds).to eq(secs), "#{iso} should be #{secs}s"
        end

      # Months and years are not fixed durations; a window whose length depends
      # on the month is not a window.
      sig.delay_iso8601 = "P1M"
      expect(sig.delay_seconds).to eq(:invalid)
    end

    it "treats an absent window as mature on observation, not as broken" do
      s = released_slice("S1")
      sig = Vv::Perch::OutwardSignal.create!(sized_slice: s, instrumented_at: now)
      r = Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "outward", observed_at: now
      )

      expect(sig.delay_seconds).to be_nil
      expect(sig.matured?(r, now: now)).to eq(true)
      expect(s.done?(now: now)).to eq(true)
    end

    it "does not claim a slice is done before it is released" do
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S9")
      sig = Vv::Perch::OutwardSignal.create!(sized_slice: s, instrumented_at: now)
      Vv::Perch::SignalReading.create!(
        outward_signal: sig, signal_class: "outward", observed_at: now
      )

      expect(sig.maturity(now: now)).to eq(:reporting)
      expect(s.done?(now: now)).to eq(false)
    end
  end

  describe "freeze cascade" do
    it "stores cost_shown_at_climb as a record and computes current cost as a query" do
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")
      f0 = Vv::Perch::Freeze.create!(sized_slice: s, rung: 0, cost_shown_at_climb: "shown: none")
      f2 = Vv::Perch::Freeze.create!(sized_slice: s, rung: 2, cost_shown_at_climb: "shown: F0")
      Vv::Perch::FreezeEdge.create!(rung_freeze: f2, depends_on_freeze: f0)
      expect(f0.cost_shown_at_climb).to eq("shown: none")
      above = Vv::Perch::Freeze.cascade_from(f0)
      expect(above.map(&:id)).to contain_exactly(f2.id)
      expect(Vv::Perch::Freeze.column_names).not_to include("reversal_cost_estimate")
      expect(Vv::Perch::Freeze.column_names).not_to include("cascade_cost")
    end
  end

  describe "methods are not throughput" do
    it "has a rung and a mode and no delivery flag" do
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")
      m = Vv::Perch::SliceMethod.create!(sized_slice: s, name: "pay", mode: "effect", rung: 2)
      expect(m).to be_persisted
      cols = Vv::Perch::SliceMethod.column_names
      %w[released delivered done shipped complete].each do |flag|
        expect(cols).not_to include(flag)
      end
    end
  end

  describe "R1/R3/R4 columns" do
    it "binds an effect without an executor or credential" do
      uc = use_case
      b = Vv::Perch::EffectBinding.create!(use_case: uc, effect_ref: "erp.post", mode: "by_receiver")
      expect(b).to be_persisted
      cols = Vv::Perch::EffectBinding.column_names
      expect(cols).not_to include("executor")
      expect(cols).not_to include("credential")
    end

    it "stores rank_together and has no rank/priority/position" do
      o = Vv::Perch::Orphan.create!(kind: "shared_route", rank_together: true)
      expect(o.rank_together).to eq(true)
      all = ActiveRecord::Base.connection.tables.select { |t| t.start_with?("perch_") }.flat_map do |t|
        ActiveRecord::Base.connection.columns(t).map(&:name)
      end
      expect(all).not_to include("rank")
      expect(all).not_to include("priority")
      expect(all).not_to include("position")
      expect(all).not_to include("jws")
      expect(all).not_to include("signature")
    end
  end

  describe "owner calls O1–O4" do
    it "defaults a use case to canonical (O4)" do
      expect(Vv::Perch::Doctrine::DEFAULT_PLACEMENT).to eq("canonical")
      uc = use_case
      expect(uc.ledger_placement).to eq("canonical")
    end

    it "treats all-by_receiver slices as advisory, no envelope (O1)" do
      expect(Vv::Perch::Doctrine::BY_RECEIVER_IN_GOVERNANCE).to eq(true)
      uc = use_case
      bind = Vv::Perch::EffectBinding.create!(use_case: uc, effect_ref: "desk.close", mode: "by_receiver")
      step = Vv::Perch::Step.create!(use_case: uc, step_key: "4", kind: "effect", effect_binding: bind)
      s = Vv::Perch::Slice.create!(use_case: uc, slice_key: "S1")
      Vv::Perch::SliceStep.create!(sized_slice: s, step: step, performed_by: "receiver")
      expect(s.reload.advisory?).to eq(true)
      expect(s.needs_envelope?).to eq(false)
    end

    it "needs an envelope when an effect is not by_receiver (O1)" do
      uc = use_case
      bind = Vv::Perch::EffectBinding.create!(use_case: uc, effect_ref: "erp.post", mode: "per_instance")
      step = Vv::Perch::Step.create!(use_case: uc, step_key: "5", kind: "effect", effect_binding: bind)
      s = Vv::Perch::Slice.create!(use_case: uc, slice_key: "S1")
      Vv::Perch::SliceStep.create!(sized_slice: s, step: step, performed_by: "agent")
      expect(s.reload.advisory?).to eq(false)
      expect(s.needs_envelope?).to eq(true)
    end

    it "stores a T4 restatement with the slice" do
      clerk = actor(role_key: "owner", name: "Pat")
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")
      out = s.restate!(aim: "the bill is settled", receiver: "the specialist", actor_id: clerk.id)
      expect(out[:ok]).to eq(true)
      expect(s.reload.aim_restated).to eq("the bill is settled")
      expect(s.restated_by_id).to eq(clerk.id)
    end

    it "refuses a draft freeze subject (O2)" do
      expect(Vv::Perch::Doctrine::DRAFT_NAMESPACE).to be_nil
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")
      f = Vv::Perch::Freeze.new(sized_slice: s, rung: 1, subject_ref: "care.v8-draft")
      expect(f.save).to eq(false)
      expect(f.errors[:subject_ref]).to include(Vv::Perch::Refusals::DRAFT_NAMESPACE_UNDECIDED)
      ok = Vv::Perch::Freeze.create!(sized_slice: s, rung: 1, subject_ref: "care.v8")
      expect(ok).to be_persisted
    end

    # O3. The rule is "a binding is a route, not a path", so the test is every
    # shape of path -- not one spelling of one fork. The first version asserted
    # a single literal, which is also all the code refused.
    it "refuses any checkout path as a prod binding (O3)" do
      expect(Vv::Perch::Doctrine::NOOA_FORK_REFUSED).to eq(true)
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")

      [
        "nooa/src/teacher.py",        # a fork, relative
        "nooa/lib/teacher.py",        # same fork, a directory the old rule missed
        "NOOA/src/teacher.py",        # same fork, shouted
        "/Users/me/fork/teacher.py",  # somebody's laptop
        "../../elsewhere/model.rb",   # climbing out
        "teacher.py",                 # a bare file is not a route either
        "C:\\models\\teacher.py"      # a path is a path
      ].each do |ref|
        m = Vv::Perch::SliceMethod.new(
          sized_slice: s, name: "assess", mode: "agent", prod_binding_ref: ref
        )
        expect(m.save).to eq(false), "expected #{ref.inspect} to be refused"
        expect(m.errors[:prod_binding_ref]).to include(Vv::Perch::Refusals::PIN_NEVER_FORK)
      end
    end

    it "accepts the route forms perchv2 5.3 actually binds" do
      s = Vv::Perch::Slice.create!(use_case: use_case, slice_key: "S1")

      ["ornith-teacher", "ornith-1.5-35b-a3b-care", "care-eligibility-slm@2026.11.1"].each_with_index do |ref, i|
        m = Vv::Perch::SliceMethod.new(
          sized_slice: s, name: "assess_#{i}", mode: "agent", prod_binding_ref: ref
        )
        expect(m.save).to eq(true), "expected #{ref.inspect} to be accepted: #{m.errors.full_messages}"
      end
    end
  end
end
