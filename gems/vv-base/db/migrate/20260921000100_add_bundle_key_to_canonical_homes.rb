# frozen_string_literal: true

# ADR 0074 decision 2. A canonical home row is scoped to a bundle.
#
# actors.role_key and information_models.key were globally unique, so two
# applications each seeding an actor called "steward" collided: the second
# either failed or silently adopted the first one's row. ledger_placement
# could not serve as the scope -- canonical/sync_intent/private_local answers
# whether a row may cross the PULL boundary, not whose row it is.
#
# Spelled as in vv_per_site_okf_nodes, which already validates okf_path
# uniqueness scoped to bundle_key. Reused rather than invented.
#
# Decision 3: bundle_key is a VALUE THE SEED CARRIES, NOT A REGISTRY. There is
# no table of known bundle keys, no validation against a list, and nothing here
# knows what any of them mean -- exactly as this repo does not for OKF nodes.
# A registry would be ADR 0063's prohibition arriving as bookkeeping: the
# substrate naming its consumers.
#
# Children are not scoped. flow_steps is unique on (flow_id, step_key) and
# information_fields on (information_model_id, name); both inherit scope
# through their parent. ADR 0074 leaves denormalising that to a later decision
# with evidence.
class AddBundleKeyToCanonicalHomes < ActiveRecord::Migration[7.0]
  # The rows that exist are the substrate's own application's: j1.rb seeds the
  # authorization-review journey and mind-pod's db/seeds.rb seeds its own. Both
  # run as mind-pod, so that is what they are backfilled to. This is a
  # statement about existing data, not a default for new rows -- there is no
  # column default, and the loader must be told the bundle it is seeding.
  BACKFILL_BUNDLE = "mind-pod"

  TABLES = %i[journeys actors information_models].freeze

  def change
    TABLES.each { |t| add_column t, :bundle_key, :string }

    reversible do |dir|
      dir.up do
        TABLES.each do |t|
          execute("UPDATE #{t} SET bundle_key = #{quote(BACKFILL_BUNDLE)} WHERE bundle_key IS NULL OR bundle_key = ''")
        end
      end
    end

    TABLES.each { |t| change_column_null t, :bundle_key, false }

    # The global uniques become scoped. Each drop/add pair is one constraint
    # moving, not a constraint being relaxed: the same collision is still
    # refused, now within a bundle instead of across all of them.
    remove_index :actors, :role_key
    add_index :actors, %i[bundle_key role_key], unique: true, name: "idx_actors_bundle_role_key"

    remove_index :information_models, :key
    add_index :information_models, %i[bundle_key key], unique: true, name: "idx_information_models_bundle_key"

    # Replaces the provisional global index from decision 1's migration.
    remove_index :journeys, :journey_key
    add_index :journeys, %i[bundle_key journey_key], unique: true, name: "idx_journeys_bundle_key"

    TABLES.each { |t| add_index t, :bundle_key }
  end
end
