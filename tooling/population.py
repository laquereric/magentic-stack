# Shared "what did this checker look at" reporting.
#
# A checker that prints "OK" after examining nothing is indistinguishable
# from a checker that looked and found no problems. emit_population prints
# the denominator and returns False when it is zero so the caller can exit
# non-zero without changing what a non-empty run decides.
from __future__ import annotations
import sys


def emit_population(examined, skipped=0, skipped_reason=""):
    examined = int(examined)
    skipped = int(skipped)
    line = "population: %d examined, %d skipped" % (examined, skipped)
    if skipped and skipped_reason:
        line += " (%s)" % skipped_reason
    print(line)
    rec = {
        "examined": examined,
        "skipped": skipped,
        "skipped_reason": skipped_reason or None,
        "empty": examined == 0,
    }
    if examined == 0:
        print("FAIL: empty population -- 0 examined is not a pass", file=sys.stderr)
        return False, rec
    return True, rec
