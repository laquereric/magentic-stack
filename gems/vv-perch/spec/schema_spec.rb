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
