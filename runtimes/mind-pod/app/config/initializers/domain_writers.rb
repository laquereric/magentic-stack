# frozen_string_literal: true

# ADR 0056 split. Loaded even when Zeitwerk has not eager-loaded app/lib
# (config.eager_load = false). The JSON is the rule; DomainWriters is the gate.
require Rails.root.join("app/lib/domain_writers")
require Rails.root.join("app/lib/sqlite_busy")

ActiveSupport.on_load(:active_record) { DomainWriters.install! }
