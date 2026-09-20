# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../lib/vv-frame"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.expect_with(:rspec) { |e| e.syntax = :expect }
end

# The real bundle this gem was written against. It sits beside the gem, not
# above it: the frame and the decisions are what vv-frame reads.
BUNDLE_ROOT = File.expand_path("../docs", __dir__)

module BundleFixture
  # A minimal, valid bundle: one frame section, one decision, linked both ways.
  def self.write(root, frame_sections: nil, adrs: nil)
    FileUtils.mkdir_p(File.join(root, "adr"))
    frame_sections ||= [[
      "Layers", "Where a change is allowed to land.\n\n**Grounded by**\n\n" \
                "* [ADR 0001 — Ownership](./adr/0001-ownership.md) — the tier rule.\n"
    ]]
    File.write(File.join(root, "frame.md"), <<~MD)
      ---
      type: Frame
      title: "Test Frame"
      okf_version: "0.2"
      ---

      # Test Frame

      #{frame_sections.map { |t, b| "## #{t}\n\n#{b}\n" }.join("\n")}
    MD

    adrs ||= [{
      id: "0001", file: "0001-ownership.md", title: "Ownership",
      frame: { "layer" => "repo", "phase" => "extract", "freezes_at_rung" => 3,
               "evidence" => "gold", "instrument" => "refusal" },
      paths: ["grammar", "gems/vv-base/lib"],
      enforced_by: ["tooling/boundary/check_closed.py"],
      grounds: [["Layers", "layers", "the tier rule."]]
    }]
    adrs.each { |a| File.write(File.join(root, "adr", a[:file]), adr_md(a)) }
    root
  end

  def self.adr_md(a)
    fm = {
      "type" => "Architecture Decision", "title" => a[:title], "adr_id" => a[:id],
      "status" => a.fetch(:status, "accepted"), "okf_version" => "0.2",
      "frame" => a[:frame], "paths" => a[:paths], "enforced_by" => a[:enforced_by]
    }
    fm["unenforced"] = true if a[:unenforced]
    body = +"# ADR #{a[:id]} — #{a[:title]}\n\n## Decision\n\n#{a.fetch(:decision, 'Do the thing.')}\n\n## Frame\n\n"
    a[:grounds].each { |title, slug, why| body << "* [#{title}](../frame.md##{slug}) — #{why}\n" }
    "#{fm.to_yaml}---\n\n#{body}"
  end

  def self.in_tmp(**kwargs)
    Dir.mktmpdir("vv-frame") do |dir|
      write(dir, **kwargs)
      yield dir
    end
  end
end
