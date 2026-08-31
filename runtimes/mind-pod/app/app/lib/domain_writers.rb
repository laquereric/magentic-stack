# frozen_string_literal: true
require "json"

# ADR 0056: BACK and BACKJOB are the sole writers of domain state. This is
# the split. The JSON at config/domain_writers.json is the rule; this file
# is the gate. An unknown ROLE writes nothing.
module DomainWriters
  class Refused < StandardError
    attr_reader :role, :model_name, :table_name

    def initialize(role:, model_name: nil, table_name: nil)
      @role = role
      @model_name = model_name
      @table_name = table_name
      super("domain_write_refused role=#{role} model=#{model_name} table=#{table_name}")
    end
  end

  CONFIG_PATH = File.expand_path("../../config/domain_writers.json", __dir__)
  SCHEMA_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  module_function

  def config
    @config ||= JSON.parse(File.read(CONFIG_PATH))
  end

  def role
    ENV.fetch("ROLE", "back").to_s
  end

  def spec_for(role_name = role)
    roles = config.fetch("roles")
    roles[role_name]
  end

  def allowed_class?(class_name, role_name = role)
    spec = spec_for(role_name)
    return false if spec.nil?
    writes = spec["writes"]
    return true if writes == "all_domain"
    names = Array(writes) + Array(spec["consequential"])
    names.include?(class_name.to_s)
  end

  def allowed_table?(table, role_name = role)
    spec = spec_for(role_name)
    return false if spec.nil?
    return true if spec["writes"] == "all_domain"
    Array(spec["tables"]).include?(table.to_s)
  end

  def guard!(record)
    name = record.class.name
    return if allowed_class?(name)
    refuse!(model_name: name)
  end

  def guard_table!(table)
    t = table.to_s
    return if t.empty? || SCHEMA_TABLES.include?(t)
    return if allowed_table?(t)
    refuse!(table_name: t)
  end

  def refuse!(model_name: nil, table_name: nil)
    r = role
    if defined?(::RailsCpcp::RefusalLog)
      ::RailsCpcp::RefusalLog.record(
        reason: "domain_write_refused",
        because: { "role" => r, "model" => model_name, "table" => table_name },
        source: "domain_writers",
        restoration: {
          "state_reached" => "no row written",
          "inconsistency" => "domain sqlite unchanged for this attempt",
          "restore_when" => "the ROLE allowlist includes the model, or the write is not issued",
          "restore_action" => "do not retry from this ROLE; change the declared split or the caller"
        }
      )
    end
    raise Refused.new(role: r, model_name: model_name, table_name: table_name)
  end

  def install!
    return unless defined?(::ActiveRecord::Base)
    return if ::ActiveRecord::Base.instance_variable_get(:@_domain_writers_gate)

    ::ActiveRecord::Base.instance_variable_set(:@_domain_writers_gate, true)
    ::ActiveRecord::Base.class_eval do
      before_save    { |rec| DomainWriters.guard!(rec) }
      before_destroy { |rec| DomainWriters.guard!(rec) }
    end

    return unless defined?(::ActiveSupport::Notifications)

    write_sql = /\A\s*(INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+"?(\w+)"?/i
    ::ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args, payload|
      sql = payload && payload[:sql]
      next unless sql
      m = write_sql.match(sql)
      next unless m
      DomainWriters.guard_table!(m[2])
    end
  end
end
