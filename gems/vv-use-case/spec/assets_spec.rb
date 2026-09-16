# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Vv::UseCase::Assets do
  it "copies use-case.js into the destination public/" do
    Dir.mktmpdir do |dir|
      r = described_class.install!(dir)
      expect(r["ok"]).to be true
      expect(File.file?(File.join(dir, "use-case.js"))).to be true
      js = File.read(File.join(dir, "use-case.js"))
      expect(js).to include("VvUseCase")
      expect(js).not_to include("window.miro.")
      expect(js).not_to include("miro.board")
    end
  end
end
