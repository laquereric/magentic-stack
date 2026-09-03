# frozen_string_literal: true

# The row-39 closed set as the runtime reads it. SAME file the deploy gate
# enforces (`tooling/compose/check_store_bindings.py` reads
# `config/store_bindings.json`), so the two cannot drift: a path the gate
# would refuse is a path this reader does not know.
module Persist
  class ClosedSet
    class Error < StandardError
      attr_reader :reason, :because
      def initialize(reason, because)
        @reason = reason
        @because = because
        super(reason)
      end
    end

    PATH = File.expand_path("../../../config/store_bindings.json", __dir__)

    def self.read!
      data = JSON.parse(File.read(PATH))
      stores = {}
      Array(data["stores"]).each do |s|
        stores[s["id"].to_s] = {
          "path" => s["path"].to_s,
          "volume" => s["volume"].to_s,
          "env" => s["env"].to_s,
          "rw" => Array(s["rw"]).map(&:to_s),
          "ro" => Array(s["ro"]).map(&:to_s)
        }
      end
      if stores.empty?
        raise Error.new("persist_closed_set_empty", { "offender" => PATH })
      end
      stores
    rescue Errno::ENOENT
      raise Error.new("persist_closed_set_missing", { "offender" => PATH })
    rescue JSON::ParserError
      raise Error.new("persist_closed_set_unparseable", { "offender" => PATH })
    end
  end
end
