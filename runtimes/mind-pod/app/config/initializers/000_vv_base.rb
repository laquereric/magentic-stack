# frozen_string_literal: true

# The canonical homes now come from vv-base.
#
# Actor, Persona, Journey, Flow, Mission and Vision each declared themselves the
# canonical home of a concept shared across P9 GHIS and P10 INTENT, while living
# in this one app's app/models. Every other app on the base would have redefined
# them and the copies would have drifted, so they moved to the baseline.
#
# The gem defines them as Vv::Base::Actor and so on, because the next app will
# have an Actor of its own. This app has referred to them by bare name since
# before the gem existed -- in the CPCP projections, in the Profile 9 pulls, in
# the specs -- so it opts in to the bare constants rather than rewriting every
# call site to prove a point.
#
# Loaded as 000_ so the constants exist before rails_cpcp.rb projects them.
#
# SCHEMA STAYS HERE. The engine ships a migration for hosts that have no tables;
# this app has had them since 20260819180001 and its schema.rb is the record of
# that. Table names match exactly, which is why the swap is safe -- see the
# engine comment, which says so for the same reason.
result = Vv::Base.install_bare_constants!

unless result[:ok]
  # A collision means something else already owns that name. Say which, loudly:
  # silently keeping the other definition is how two Actors end up in one process.
  Rails.logger.error({ vv_base_collision: result[:because], installed: result[:installed] }.to_json)
end
