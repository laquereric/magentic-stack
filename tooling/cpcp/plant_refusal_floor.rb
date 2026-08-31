#!/usr/bin/env ruby
# frozen_string_literal: true
# Gap 89. Prove the RefusalLog floor survives, or prove it does not.
# Scratch directory / RAM disk / a child we spawned. Does not chmod the repo,
# does not fill the host disk, does not SIGKILL anything we did not start.
# Does not fix the floor.

require "json"
require "fileutils"
require "tmpdir"
require "timeout"
require "rbconfig"
require "securerandom"

ROOT = File.expand_path("../..", __dir__)
require File.join(ROOT, "gems/rails-cpcp/lib/rails_cpcp/refusal_log")

STDOUT.sync = true
rows = []
def note(rows, condition, invariant, passed, detail, extra = {})
  rec = { "condition" => condition, "invariant" => invariant,
          "ok" => passed, "detail" => detail }.merge(extra)
  rows << rec
  flag = passed ? "OK  " : "FAIL"
  skip = passed.nil?
  flag = "SKIP" if skip
  puts "  #{flag}  #{condition} / #{invariant}: #{detail}"
  rec
end

def inspect_jsonl(path)
  out = { "exists" => File.file?(path), "parsed" => [], "unparsed" => [], "bytes" => 0 }
  return out unless out["exists"]
  out["bytes"] = File.size(path)
  File.readlines(path, chomp: true).each_with_index do |line, i|
    next if line.strip.empty?
    begin
      out["parsed"] << JSON.parse(line)
    rescue JSON::ParserError
      out["unparsed"] << { "line" => i + 1, "bytes" => line.bytesize, "prefix" => line[0, 120] }
    end
  end
  out
end

def inspect_hb(path)
  return { "exists" => false } unless File.file?(path)
  raw = File.read(path)
  begin
    obj = JSON.parse(raw)
    { "exists" => true, "parseable" => true, "ran" => obj["ran"] == true,
      "bytes" => raw.bytesize, "obj" => obj }
  rescue JSON::ParserError
    { "exists" => true, "parseable" => false, "bytes" => raw.bytesize,
      "prefix" => raw[0, 120] }
  end
end

def with_scratch
  dir = Dir.mktmpdir("gap89-")
  log = File.join(dir, "cpcp_refusals.jsonl")
  hb  = File.join(dir, "cpcp_refusal_observer.json")
  ENV["CPCP_REFUSAL_LOG"] = log
  ENV["CPCP_REFUSAL_HEARTBEAT"] = hb
  yield dir, log, hb
ensure
  FileUtils.chmod_R(0o700, dir) if dir && File.exist?(dir)
  FileUtils.remove_entry(dir) if dir && File.directory?(dir)
end

def record!(reason, because = "marker")
  RailsCpcp::RefusalLog.record(reason: reason, because: because, source: "plant/gap89")
end

# -- 1. restart --------------------------------------------------------------
with_scratch do |_dir, log, hb|
  record!("before_restart")
  prior = inspect_jsonl(log)
  hb1 = inspect_hb(hb)
  # New interpreter, same files.
  cmd = [
    RbConfig.ruby, "-e", <<~RUBY, ROOT, log, hb
      require File.join(ARGV[0], "gems/rails-cpcp/lib/rails_cpcp/refusal_log")
      ENV["CPCP_REFUSAL_LOG"] = ARGV[1]
      ENV["CPCP_REFUSAL_HEARTBEAT"] = ARGV[2]
      rows = File.readlines(ARGV[1], chomp: true).map { |l| JSON.parse(l) }
      hb = JSON.parse(File.read(ARGV[2]))
      puts JSON.generate("reasons" => rows.map { |r| r["reason"] }, "hb_ran" => hb["ran"])
    RUBY
  ]
  out = IO.popen(cmd, err: [:child, :out], &:read)
  status = $?.success?
  data = JSON.parse(out) rescue { "parse_error" => out[0, 200] }
  note(rows, "restart", "prior_survives",
       status && Array(data["reasons"]).include?("before_restart"),
       data.inspect)
  note(rows, "restart", "heartbeat_distinguishes",
       status && data["hb_ran"] == true && hb1["parseable"] == true,
       "child=#{data.inspect} parent_hb=#{hb1.inspect}")
end

# -- 2. permission denied (scratch, not repo) --------------------------------
with_scratch do |dir, log, hb|
  record!("before_chmod")
  FileUtils.chmod(0o000, dir)
  during = nil
  begin
    during = record!("during_chmod")
  rescue StandardError => e
    during = "raised #{e.class}"
  end
  FileUtils.chmod(0o700, dir)
  j = inspect_jsonl(log)
  h = inspect_hb(hb)
  reasons = j["parsed"].map { |r| r["reason"] }
  note(rows, "permission_denied", "prior_survives",
       reasons.include?("before_chmod") && j["unparsed"].empty?,
       "reasons=#{reasons.inspect} unparsed=#{j['unparsed'].inspect} record_returned=#{during.inspect}")
  # After chmod restore we can read. During the fault, new writes should fail
  # closed (record returns false, never raises). Heartbeat file from BEFORE
  # should still parse.
  note(rows, "permission_denied", "heartbeat_distinguishes",
       h["exists"] && h["parseable"] && h["ran"] == true,
       h.inspect)
  note(rows, "permission_denied", "during_write_no_raise",
       during == false || during == true,
       "record! => #{during.inspect} (false=refused as designed; true=write succeeded through chmod 000)")
  note(rows, "permission_denied", "no_truncated_line",
       j["unparsed"].empty?,
       j["unparsed"].inspect)
end

# -- 3. path missing: never created, then directory gone ---------------------
with_scratch do |dir, log, hb|
  FileUtils.remove_entry(dir)
  raised = nil
  begin
    ok_write = record!("first_on_missing")
  rescue StandardError => e
    raised = "#{e.class}: #{e.message}"
    ok_write = :raised
  end
  j = inspect_jsonl(log)
  h = inspect_hb(hb)
  note(rows, "path_missing_never_created", "write_lands",
       raised.nil? && ok_write == true && j["parsed"].any? { |r| r["reason"] == "first_on_missing" },
       "raised=#{raised.inspect} ok=#{ok_write.inspect} parsed=#{j['parsed'].map { |r| r['reason'] }.inspect}")
  note(rows, "path_missing_never_created", "heartbeat_distinguishes",
       h["exists"] && h["parseable"] && h["ran"] == true,
       h.inspect)
end

with_scratch do |dir, log, hb|
  record!("before_rm")
  FileUtils.remove_entry(dir)
  after_rm_log = inspect_jsonl(log)
  after_rm_hb = inspect_hb(hb)
  # Recreate by writing again.
  record!("after_recreate")
  j = inspect_jsonl(log)
  h = inspect_hb(hb)
  prior_gone = !after_rm_log["exists"]
  note(rows, "path_missing_directory_gone", "prior_survives",
       !prior_gone && j["parsed"].any? { |r| r["reason"] == "before_rm" },
       "after_rm exists_log=#{after_rm_log['exists']} exists_hb=#{after_rm_hb['exists']}; after recreate reasons=#{j['parsed'].map { |r| r['reason'] }.inspect}")
  # After rm, heartbeat is missing: "never ran" is indistinguishable from
  # "had refusals, then the directory vanished". After recreate, heartbeat
  # says ran:true with only the new refusal — hides the lost prior.
  note(rows, "path_missing_directory_gone", "heartbeat_distinguishes",
       after_rm_hb["exists"] && after_rm_hb["parseable"],
       "after_rm hb=#{after_rm_hb.inspect}; after recreate hb=#{h.inspect} reasons=#{j['parsed'].map { |r| r['reason'] }.inspect}")
end

# -- 4. SIGKILL mid-write (child we started) ---------------------------------
# One 2 MiB payload, not a loop. Poll File.size (not File.read of the
# whole log). Kill as soon as the file grows past the marker. A 12 GB
# loop would fill the host disk — that is out of bounds.
with_scratch do |_dir, log, hb|
  child = <<~'RUBY'
    ROOT, LOG, HB = ARGV
    require File.join(ROOT, "gems/rails-cpcp/lib/rails_cpcp/refusal_log")
    ENV["CPCP_REFUSAL_LOG"] = LOG
    ENV["CPCP_REFUSAL_HEARTBEAT"] = HB
    RailsCpcp::RefusalLog.record(reason: "before_kill", because: "marker", source: "plant/gap89")
    RailsCpcp::RefusalLog.record(reason: "huge", because: ("H" * (2 * 1024 * 1024)), source: "plant/gap89")
  RUBY
  pid = spawn(RbConfig.ruby, "-e", child, ROOT, log, hb, out: File::NULL, err: File::NULL)
  marker_bytes = nil
  killed_mid = false
  begin
    Timeout.timeout(5) do
      loop do
        if File.file?(log) && File.size(log) > 0
          head = File.open(log, "r") { |f| f.read(256).to_s }
          if head.include?("before_kill")
            marker_bytes = File.size(log)
            break
          end
        end
        sleep 0.005
      end
      loop do
        sz = File.file?(log) ? File.size(log) : 0
        if marker_bytes && sz > marker_bytes
          Process.kill("KILL", pid)
          killed_mid = true
          break
        end
        sleep 0.001
      end
    end
  rescue Timeout::Error
    Process.kill("KILL", pid) rescue nil
  rescue Errno::ESRCH
    # child already exited — write finished before we could kill
  end
  Process.wait(pid) rescue nil
  j = inspect_jsonl(log)
  h = inspect_hb(hb)
  reasons = j["parsed"].map { |r| r["reason"] }
  note(rows, "sigkill_mid_write", "prior_survives",
       reasons.include?("before_kill"),
       "killed_mid=#{killed_mid} reasons=#{reasons.uniq.inspect} parsed=#{j['parsed'].size} unparsed=#{j['unparsed'].size} bytes=#{j['bytes']} marker_bytes=#{marker_bytes.inspect}")
  hb_ok = h["exists"] && h["parseable"] && h["ran"] == true
  note(rows, "sigkill_mid_write", "heartbeat_distinguishes",
       hb_ok,
       h.inspect)
  loud = !j["unparsed"].empty? || (h["exists"] && h["parseable"] == false)
  note(rows, "sigkill_mid_write", "truncated_or_corrupt",
       !loud,
       if loud
         "LOUD: unparsed=#{j['unparsed'].inspect} hb_parseable=#{h['parseable'].inspect}"
       else
         "no truncated JSONL line, heartbeat parseable=#{h['parseable']} killed_mid=#{killed_mid} (if killed_mid=false the write finished first; typical refusal lines are <<2MiB)"
       end)
end

# -- 5. disk full (RAM disk, not the host volume) ----------------------------
def with_ramdisk
  raw = `hdiutil attach -nomount ram://16384 2>/dev/null`.to_s
  dev = raw.lines.map(&:strip).reject(&:empty?).first
  return yield(nil, "hdiutil attach failed: #{raw.strip}") if dev.nil? || dev.empty?
  vol = "Gap89F#{Process.pid}"
  unless system("diskutil", "erasevolume", "APFS", vol, dev,
                out: File::NULL, err: File::NULL)
    system("hdiutil", "detach", dev, "-force", out: File::NULL, err: File::NULL)
    return yield(nil, "diskutil erasevolume failed on #{dev}")
  end
  mount = "/Volumes/#{vol}"
  yield mount, nil
ensure
  system("hdiutil", "detach", dev, "-force", out: File::NULL, err: File::NULL) if dev
end

ram_skip = nil
with_ramdisk do |mount, err|
  if mount.nil?
    ram_skip = err
    next
  end
  log = File.join(mount, "cpcp_refusals.jsonl")
  hb  = File.join(mount, "cpcp_refusal_observer.json")
  ENV["CPCP_REFUSAL_LOG"] = log
  ENV["CPCP_REFUSAL_HEARTBEAT"] = hb
  record!("before_full")
  prior = inspect_jsonl(log)
  hb_before = inspect_hb(hb)

  fill = File.join(mount, "fill")
  enospc = false
  File.open(fill, "wb") do |f|
    f.sync = true
    buf = SecureRandom.random_bytes(65_536)
    10_000.times do
      f.write(buf)
    rescue Errno::ENOSPC, Errno::EDQUOT
      enospc = true
      break
    end
  end
  # Squeeze leftover blocks so a JSONL append actually meets ENOSPC.
  begin
    File.open(fill, "ab") do |f|
      f.sync = true
      20_000.times { f.write("Z" * 1024) }
    end
  rescue Errno::ENOSPC, Errno::EDQUOT
    enospc = true
  end
  df = `df -k #{mount}`.to_s.strip

  during = nil
  begin
    during = record!("during_full")
  rescue StandardError => e
    during = "raised #{e.class}: #{e.message}"
  end

  File.delete(fill) if File.file?(fill)
  j = inspect_jsonl(log)
  h = inspect_hb(hb)
  reasons = j["parsed"].map { |r| r["reason"] }
  note(rows, "disk_full", "prior_survives",
       reasons.include?("before_full") && j["unparsed"].empty?,
       "enospc=#{enospc} df=#{df.inspect} reasons=#{reasons.inspect} unparsed=#{j['unparsed'].inspect} during=#{during.inspect} bytes=#{j['bytes']} prior_bytes=#{prior['bytes']}")
  note(rows, "disk_full", "heartbeat_distinguishes",
       h["exists"] && h["parseable"] && h["ran"] == true,
       "before=#{hb_before.inspect} after=#{h.inspect}")
  note(rows, "disk_full", "truncated_or_corrupt",
       j["unparsed"].empty? && !(h["exists"] && h["parseable"] == false),
       "unparsed=#{j['unparsed'].inspect} hb_parseable=#{h['parseable'].inspect} hb_bytes=#{h['bytes'].inspect} during=#{during.inspect}")
  note(rows, "disk_full", "during_write_no_raise",
       during == false || during == true,
       "record! => #{during.inspect}")
  avail_kb = df[/Available|Avail/] ? df.lines[1].to_s.split[3].to_i : -1
  note(rows, "disk_full", "volume_at_zero",
       avail_kb == 0,
       "available_kb=#{avail_kb} (APFS left ~1MiB after ENOSPC on the fill file; a 112-byte JSONL still fits. This is NOT a zero-byte disk. during=#{during.inspect})")
end
if ram_skip
  note(rows, "disk_full", "prior_survives", nil, "SKIP: #{ram_skip}")
  note(rows, "disk_full", "heartbeat_distinguishes", nil, "SKIP: #{ram_skip}")
end

# tmpfs is actually fillable to zero. 256 KiB. Image must already exist —
# we do not pull. If docker/image is missing, skip.
img = "ruby:3.4-alpine"
docker_ok = system("docker", "image", "inspect", img, out: File::NULL, err: File::NULL)
if docker_ok
  script = <<~'RUBY'
    require "/code/refusal_log.rb"
    ENV["CPCP_REFUSAL_LOG"] = "/fault/cpcp_refusals.jsonl"
    ENV["CPCP_REFUSAL_HEARTBEAT"] = "/fault/cpcp_refusal_observer.json"
    RailsCpcp::RefusalLog.record(reason: "before_full", because: "marker", source: "plant/gap89")
    begin
      File.open("/fault/fill", "wb") { |f| f.sync = true; loop { f.write("Z" * 4096) } }
    rescue Errno::ENOSPC, Errno::EDQUOT
    end
    during = nil
    begin
      during = RailsCpcp::RefusalLog.record(reason: "during_full", because: "x", source: "plant/gap89")
    rescue StandardError => e
      during = "raised #{e.class}"
    end
    log = File.file?("/fault/cpcp_refusals.jsonl") ? File.read("/fault/cpcp_refusals.jsonl") : ""
    hb = File.file?("/fault/cpcp_refusal_observer.json") ? File.read("/fault/cpcp_refusal_observer.json") : ""
    parsed = log.lines.filter_map { |l| JSON.parse(l) rescue :bad }
    hb_ok = (JSON.parse(hb)["ran"] rescue false)
    puts JSON.generate("during" => during, "reasons" => parsed.map { |r| r == :bad ? :bad : r["reason"] },
                       "unparsed" => parsed.count(:bad), "hb_ok" => hb_ok, "hb_empty" => hb.empty?,
                       "df" => `df -k /fault`.to_s)
  RUBY
  out = IO.popen(
    ["docker", "run", "--rm", "--tmpfs", "/fault:rw,size=262144",
     "-v", "#{ROOT}/gems/rails-cpcp/lib/rails_cpcp/refusal_log.rb:/code/refusal_log.rb:ro",
     img, "ruby", "-e", script],
    err: [:child, :out], &:read
  )
  data = JSON.parse(out) rescue { "parse_error" => out.to_s[0, 400] }
  reasons = Array(data["reasons"])
  note(rows, "disk_full_tmpfs", "prior_survives",
       reasons.include?("before_full") && data["unparsed"].to_i.zero?,
       data.inspect)
  note(rows, "disk_full_tmpfs", "heartbeat_distinguishes",
       data["hb_ok"] == true,
       data.inspect)
  note(rows, "disk_full_tmpfs", "during_stopped",
       data["during"] == false || data["during"].to_s.start_with?("raised") || !reasons.include?("during_full"),
       "during=#{data['during'].inspect} reasons=#{reasons.inspect}")
else
  note(rows, "disk_full_tmpfs", "prior_survives", nil, "SKIP: docker image #{img} not present (no pull)")
end

puts
puts "SUMMARY"
fails = rows.select { |r| r["ok"] == false }
skips = rows.select { |r| r["ok"].nil? }
puts "  #{rows.size} results, #{fails.size} FAIL, #{skips.size} SKIP"
puts "plant refusal-floor: #{fails.empty? ? 'RAN (see FAILs — they are the finding)' : 'RAN with FAILs (the finding)'}"
puts JSON.pretty_generate(rows)
exit 0
