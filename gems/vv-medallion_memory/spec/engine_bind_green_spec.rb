# frozen_string_literal: true

# M3 closes the loop: with audit! answered and M4-M10 landed, bind! goes
# green. The engine is PROBED, so this uses a stub that answers everything
# the real engine now answers -- the same posture as the audit!-absent
# examples in medallion_memory_spec.rb, taken to the green branch.
RSpec.describe "the engine binding, once M3 lands" do
  def full_engine
    flow = Class.new do
      def purpose = "build"
    end
    Module.new do
      define_singleton_method(:audit!) { |*_a| { ok: true } }
      define_singleton_method(:provenance_required_on_land?) { true }
      define_singleton_method(:temporal_landed?) { true }
      define_singleton_method(:cascade) { |*_a| { ok: true } }
      define_singleton_method(:decay_bound?) { true }
      define_singleton_method(:confidence_is_a_stamp?) { true }
      define_singleton_method(:const_defined?) { |n| %i[VERSION Flow Curator].include?(n) }
      define_singleton_method(:const_get) do |n|
        next "0.2.0" if n == :VERSION
        next flow if n == :Flow

        curator = Module.new do
          def self.requires_model_contract_on_arm? = true
        end
        curator
      end
    end
  end

  before do
    allow(Vv::MedallionMemory::EngineBinding).to receive(:engine).and_return(full_engine)
  end

  it "binds" do
    result = Vv::MedallionMemory::EngineBinding.bind!
    expect(result[:ok]).to be(true)
    expect(result[:home]).to eq(:stack)
  end

  it "measures M3-M10 landed and only M1/M2 pending" do
    expect(Vv::MedallionMemory::EngineBinding.landed).to contain_exactly(
      "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10"
    )
    expect(Vv::MedallionMemory::EngineBinding.still_pending.keys).to contain_exactly("M1", "M2")
  end

  it "no longer refuses engine_not_landed" do
    result = Vv::MedallionMemory::EngineBinding.bind!
    expect(result[:reason]).to be_nil
  end
end
