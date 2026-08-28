# frozen_string_literal: true

# GRAPH at the seam. No new route -- /_cpcp stays the only one.
#
# Registration is explicit by design (see mmg-graph/lib/mmg/graph.rb: "requiring
# the gem never reaches for Rails that may not be there"), so it happens here
# rather than in an engine hook.
#
# BACK ONLY. FRONT holds no database and no repository, and graph.publish writes
# through ActiveRecord to create the grounding Entry -- registering it on FRONT
# would offer an operation that cannot work. Mirrors the ROLE guard that
# osi_level_8.rb already applies to CpcpAdapter.
Rails.application.config.to_prepare do
  next unless ENV.fetch("ROLE", "back") == "back"

  result = Mmg::Graph::Cpcp.register!
  Rails.logger.info("[mmg-graph] #{result.inspect}")
end
