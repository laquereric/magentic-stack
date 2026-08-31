#!/usr/bin/env ruby
# frozen_string_literal: true
# Plant for gaps 76-78. No Rails boot. Proves:
#   76. the allowlist is the split (BACKJOB cannot write Note by rule)
#   77. live files already wal; declaring WAL on a copy is a no-op
#   78. a real SQLITE_BUSY is recorded as reason=sqlite_busy in RefusalLog
#
# Does not mutate the host domain DB. Does not push. Prints a plant table.

require "json"
require "fileutils"
require "tmpdir"
require "sqlite3"

ROOT = File.expand_path("../..", __dir__)
APP  = File.join(ROOT, "runtimes/mind-pod/app")
HOST_DB = File.join(ROOT, "runtimes/mind-pod/app/db/mind_pod.sqlite3")
# The worktree copy may not have the sqlite; the canonical checkout does.
HOST_DB_FALLBACK = "/Users/ericlaquer/NoIcloud/magentic-stack/runtimes/mind-pod/app/db/mind_pod.sqlite3"

require File.join(ROOT, "gems/rails-cpcp/lib/rails_cpcp/refusal_log")
require File.join(APP, "app/lib/domain_writers")
require File.join(APP, "app/lib/sqlite_busy")

log = File.join(Dir.tmpdir, "cpcp_refusals-plant-#{Process.pid}.jsonl")
hb  = File.join(Dir.tmpdir, "cpcp_refusal_observer-plant-#{Process.pid}.json")
FileUtils.rm_f(log)
FileUtils.rm_f(hb)
ENV["CPCP_REFUSAL_LOG"] = log
ENV["CPCP_REFUSAL_HEARTBEAT"] = hb

rows = []
ok = true
def note(rows, name, passed, detail)
  rows << { "plant" => name, "ok" => passed, "detail" => detail }
  passed
end

# -- 76 allowlist ----------------------------------------------------------
ENV["ROLE"] = "backjob"
a = DomainWriters.allowed_class?("Reconciliation", "backjob")
b = DomainWriters.allowed_class?("Note", "backjob")
c = DomainWriters.allowed_class?("Note", "back")
d = DomainWriters.allowed_class?("Note", "front")
e = DomainWriters.allowed_table?("reconciliations", "backjob")
f = DomainWriters.allowed_table?("notes", "backjob")
split_ok = a && !b && c && !d && e && !f
ok &&= note(rows, "76-allowlist", split_ok,
            "backjob Reconciliation=#{a} Note=#{b} table.reconciliations=#{e} table.notes=#{f}; back Note=#{c}; front Note=#{d}")

begin
  DomainWriters.guard_table!("notes")
  ok &&= note(rows, "76-gate-raises", false, "guard_table!(notes) under ROLE=backjob did not raise")
rescue DomainWriters::Refused => err
  ok &&= note(rows, "76-gate-raises", err.role == "backjob" && err.table_name == "notes",
              err.message)
end

# -- 77 WAL ----------------------------------------------------------------
yml = File.read(File.join(APP, "config/database.yml"))
declared = yml.match?(/pragmas:\s*\n\s*journal_mode:\s*wal\b/)
ok &&= note(rows, "77-declared", declared, "database.yml pragmas.journal_mode: wal")

src = if File.file?(HOST_DB)
        HOST_DB
      elsif File.file?(HOST_DB_FALLBACK)
        HOST_DB_FALLBACK
      end
if src
  before = SQLite3::Database.new(src, readonly: true).get_first_value("PRAGMA journal_mode")
  Dir.mktmpdir("wal-plant") do |dir|
    copy = File.join(dir, "copy.sqlite3")
    FileUtils.cp(src, copy)
    db = SQLite3::Database.new(copy)
    after = db.get_first_value("PRAGMA journal_mode=WAL")
    db.close
    unchanged = before.to_s.downcase == "wal" && after.to_s.downcase == "wal"
    ok &&= note(rows, "77-runtime-unchanged", unchanged,
                "before=#{before.inspect} after-declare-on-copy=#{after.inspect} src=#{src} — delivering the GUARANTEE, not a runtime change")
  end
else
  ok &&= note(rows, "77-runtime-unchanged", false, "no host sqlite to measure")
end

# -- 78 SQLITE_BUSY in the log --------------------------------------------
busy_error = nil
Dir.mktmpdir("busy-plant") do |dir|
  path = File.join(dir, "busy.sqlite3")
  holder = SQLite3::Database.new(path)
  holder.execute("CREATE TABLE t (id INTEGER)")
  holder.execute("BEGIN IMMEDIATE")
  holder.execute("INSERT INTO t VALUES (1)")
  contender = SQLite3::Database.new(path)
  contender.busy_timeout = 1
  begin
    contender.execute("BEGIN IMMEDIATE")
    contender.execute("INSERT INTO t VALUES (2)")
    ok &&= note(rows, "78-produced-busy", false, "second writer did not raise")
  rescue SQLite3::Exception => e
    busy_error = e
    is_busy = SqliteBusy.busy?(e)
    ok &&= note(rows, "78-produced-busy", is_busy,
                "#{e.class}: #{e.message} busy?=#{is_busy}")
    if is_busy
      SqliteBusy.record!(e, source: "plant/sqlite_busy")
    end
  ensure
    contender.close rescue nil
    holder.execute("ROLLBACK") rescue nil
    holder.close rescue nil
  end
end

if File.file?(log)
  lines = File.readlines(log, chomp: true).reject(&:empty?).map { |l| JSON.parse(l) }
  hit = lines.find { |r| r["kind"] == "refusal" && r["reason"] == "sqlite_busy" }
  ok &&= note(rows, "78-in-log", !hit.nil?,
              hit ? hit.to_json : "no sqlite_busy line in #{log} (#{lines.size} rows)")
  if hit
    puts "REFUSAL LOG LINE:"
    puts JSON.pretty_generate(hit)
  end
else
  ok &&= note(rows, "78-in-log", false, "no JSONL at #{log}")
end

puts "PLANT TABLE"
rows.each do |r|
  flag = r["ok"] ? "OK " : "FAIL"
  puts "  #{flag}  #{r['plant']}: #{r['detail']}"
end
puts ok ? "plant two-writers: OK" : "plant two-writers: FAIL"
exit(ok ? 0 : 1)
