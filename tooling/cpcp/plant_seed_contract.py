#!/usr/bin/env python3
"""Plant violations against check_seed_contract.py; each must fail.

clean must exit 0. Every plant must exit non-zero AND say the specific thing,
because exit status alone would pass even if the checker crashed on import.

The plants restore ADR 0074's Context deliberately, one rule at a time:

  rule-a-model        a caller upserting a canonical home by itself, which is
                      how journeys came to have two idempotence keys
  rule-a-association  the same defect spelled through an association, which is
                      how j1.rb wrote three of its five
  rule-b-unscoped     a unique index on a bundle-scoped table that omits
                      bundle_key, which is the cross-application collision
  rule-b-replay       a global unique that a LATER migration drops. This one
                      must stay GREEN: it is how decision 2 lands, and a gate
                      that flagged it would refuse its own ADR's migrations.
  rule-c-stored-cid   a cid column on flow_steps, which is decision 6 being
                      given up -- a stored identity that can drift from the
                      keys that determine it

rule-b-replay is a NEGATIVE plant on purpose, and it is the one to keep. A
checker is not only wrong when it misses a defect; it is wrong when it refuses
something correct, and that failure mode is the one nobody notices until it
blocks a merge.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECK = ROOT / "tooling/cpcp/check_seed_contract.py"
PY = sys.executable

# The checker reads ruby under the scanned prefixes plus every db/migrate tree.
# Copying vv-base whole keeps the sandbox honest rather than curating it down
# to the files that happen to match today.
SUBJECT = pathlib.Path("gems/vv-base")
MIGRATE = SUBJECT / "db/migrate"
LIB = SUBJECT / "lib/vv/base"


def run(root):
    env = dict(os.environ, CHECK_ROOT=str(root))
    p = subprocess.run([PY, str(CHECK)], capture_output=True, text=True, env=env)
    return p.returncode, (p.stdout + p.stderr)


def sandbox():
    d = pathlib.Path(tempfile.mkdtemp(prefix="plant-seed-"))
    dst = d / SUBJECT
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / SUBJECT, dst)
    return d


def plant_rule_a_model(d):
    p = d / LIB / "planted_seeder.rb"
    p.write_text(
        "module Planted\n"
        "  def self.seed!\n"
        "    ::Vv::Base::Journey.find_or_initialize_by(title: \"Planted\")\n"
        "  end\n"
        "end\n",
        encoding="utf-8")
    return "upserts a canonical home"


def plant_rule_a_association(d):
    p = d / LIB / "planted_assoc.rb"
    p.write_text(
        "module PlantedAssoc\n"
        "  def self.seed!(journey)\n"
        "    journey.flows.find_or_create_by!(title: \"Planted\")\n"
        "  end\n"
        "end\n",
        encoding="utf-8")
    return "upserts a canonical home"


def plant_rule_b_unscoped(d):
    p = d / MIGRATE / "29990101000000_planted_unscoped_unique.rb"
    p.write_text(
        "class PlantedUnscopedUnique < ActiveRecord::Migration[7.0]\n"
        "  def change\n"
        "    add_index :actors, :role_key, unique: true\n"
        "  end\n"
        "end\n",
        encoding="utf-8")
    return "not bundle_key"


def plant_rule_b_replay(d):
    """Must stay GREEN: added then dropped is how decision 2 lands."""
    p = d / MIGRATE / "29990101000001_planted_added_then_dropped.rb"
    p.write_text(
        "class PlantedAddedThenDropped < ActiveRecord::Migration[7.0]\n"
        "  def change\n"
        "    add_index :journeys, :journey_key, unique: true\n"
        "  end\n"
        "end\n",
        encoding="utf-8")
    q = d / MIGRATE / "29990101000002_planted_drops_it.rb"
    q.write_text(
        "class PlantedDropsIt < ActiveRecord::Migration[7.0]\n"
        "  def change\n"
        "    remove_index :journeys, :journey_key\n"
        "    add_index :journeys, %i[bundle_key journey_key], unique: true\n"
        "  end\n"
        "end\n",
        encoding="utf-8")
    return None  # None means: expect PASS


def plant_rule_c_stored_cid(d):
    p = d / MIGRATE / "29990101000003_planted_stored_step_cid.rb"
    p.write_text(
        "class PlantedStoredStepCid < ActiveRecord::Migration[7.0]\n"
        "  def change\n"
        "    add_column :flow_steps, :cid, :string\n"
        "  end\n"
        "end\n",
        encoding="utf-8")
    return "adds a cid column to flow_steps"


PLANTS = [
    ("rule-a-model", plant_rule_a_model),
    ("rule-a-association", plant_rule_a_association),
    ("rule-b-unscoped", plant_rule_b_unscoped),
    ("rule-b-replay", plant_rule_b_replay),
    ("rule-c-stored-cid", plant_rule_c_stored_cid),
]


def main():
    rows = []
    ok_all = True

    d = sandbox()
    rc, out = run(d)
    rows.append(("clean", rc == 0, "exit %d" % rc))
    ok_all &= rc == 0
    shutil.rmtree(d, ignore_errors=True)

    for name, plant in PLANTS:
        d = sandbox()
        expected = plant(d)
        rc, out = run(d)
        if expected is None:
            good = rc == 0
            detail = "exit %d (must stay green)" % rc
        else:
            good = rc != 0 and expected in out
            detail = "exit %d, said %r: %s" % (rc, expected, expected in out)
        rows.append((name, good, detail))
        ok_all &= good
        shutil.rmtree(d, ignore_errors=True)

    print("plant | ok | detail")
    print("------|----|--------")
    for name, good, detail in rows:
        print("%s | %s | %s" % (name, str(good).lower(), detail))
    print("plant seed-contract: %s" % ("OK" if ok_all else "FAIL"))
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
