# frozen_string_literal: true

# WHOLE-STORE REPLAY -- runtimes/graph/README.md prerequisite 1.
#
#   "Projection today is incremental, scheduled per-row on save; there is no
#    backfill. A reconstructable_from that names a procedure nobody can execute
#    is a false rollback point, not a rollback point."
#
# This is that procedure. It re-emits every Storable record, so a graph volume can
# be dropped and rebuilt from BACK's store -- which is what makes GRAPH a
# projection rather than a second authority.
#
# No new projection logic: it calls the SAME emission path project_on_save! uses,
# because a backfill that writes triples a different way is not a replay of
# anything, it is a second writer with a friendly name.
module GraphReplay
  module_function

  # Every model that declares `triples do ... end`. Discovered, not listed: a
  # hardcoded list silently stops replaying a model the day someone adds one, and
  # the store would then be quietly unreconstructable.
  def storable_models
    Rails.application.eager_load! unless Rails.application.config.eager_load

    ActiveRecord::Base.descendants.select do |klass|
      next false if klass.abstract_class?
      next false unless klass.respond_to?(:semantica_triples_declaration)

      !klass.semantica_triples_declaration.nil?
    end
  rescue StandardError
    []
  end

  def run(params = {})
    models = storable_models
    return { ok: false, reason: :no_storable_models,
             because: "no model declares triples; a replay that finds nothing to " \
                      "replay must say so rather than report success" } if models.empty?

    replayed = {}
    failed   = {}

    models.each do |klass|
      next if params["model"].present? && klass.name != params["model"]

      count = 0
      klass.find_each do |record|
        r = record.semantica_emit_triples!
        # Never-raise: vv-graph returns refusal envelopes. A refusal during replay
        # is counted, not swallowed -- a replay that reports success while a third
        # of the rows refused is the failure this whole exercise is about.
        if r.is_a?(Hash) && r[:ok] == false
          failed[klass.name] = (failed[klass.name] || 0) + 1
        else
          count += 1
        end
      rescue StandardError => e
        failed[klass.name] = (failed[klass.name] || 0) + 1
        Rails.logger.warn("[graph.replay] #{klass.name}##{record.id}: #{e.class}: #{e.message}")
      end
      replayed[klass.name] = count
    end

    { ok: failed.empty?, replayed: replayed, failed: failed,
      models: models.map(&:name),
      because: failed.empty? ? nil : "#{failed.values.sum} record(s) refused; the graph is NOT " \
                                     "a faithful projection until they replay clean" }
  rescue StandardError => e
    { ok: false, reason: :replay_failed, because: "#{e.class}: #{e.message}" }
  end
end
