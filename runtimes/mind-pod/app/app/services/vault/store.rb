# frozen_string_literal: true

require "json"
require "fileutils"
require "digest"
require "active_support/message_encryptor"

# Encrypted file store for provider secrets. The bind-mounted file is durable
# across `docker compose down -v`; a named volume is not (ADR 0046). Secret
# values never appear in list output, exception messages, or to_s.
module Vault
  class Store
    class Error < StandardError
      attr_reader :reason, :because
      def initialize(reason, because)
        @reason = reason
        @because = because
        super(reason)
      end
    end

    NAME_RE = /\A[A-Za-z0-9._-]+\z/

    def initialize(path:, master_key:)
      raise Error.new("vault_store_path_missing", { "offender" => "VAULT_STORE_PATH" }) if path.to_s.strip.empty?
      raise Error.new("vault_master_key_missing", { "offender" => "VAULT_MASTER_KEY" }) if master_key.to_s.strip.empty?
      @path = path
      @encryptor = ActiveSupport::MessageEncryptor.new(Digest::SHA256.digest(master_key))
    end

    def put(name, value)
      n = check_name!(name)
      if value.to_s.empty?
        raise Error.new("vault_secret_empty", { "name" => n })
      end
      data = load
      data[n] = { "value" => value.to_s, "updated_at" => Time.now.utc.iso8601 }
      persist(data)
      { "name" => n, "present" => true, "updated_at" => data[n]["updated_at"] }
    end

    def list
      load.map { |n, rec| { "name" => n, "present" => true, "updated_at" => rec["updated_at"] } }
        .sort_by { |r| r["name"] }
    end

    def get(name)
      n = check_name!(name)
      rec = load[n]
      raise Error.new("vault_secret_absent", { "name" => n }) unless rec
      { "name" => n, "value" => rec["value"] }
    end

    private

    def check_name!(name)
      n = name.to_s
      raise Error.new("vault_secret_name_invalid", { "name" => n }) unless n.match?(NAME_RE)
      n
    end

    def load
      return {} unless File.file?(@path)
      raw = File.binread(@path)
      return {} if raw.empty?
      JSON.parse(@encryptor.decrypt_and_verify(raw))
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise Error.new("vault_store_unreadable", { "offender" => @path })
    end

    def persist(data)
      FileUtils.mkdir_p(File.dirname(@path))
      tmp = "#{@path}.tmp"
      File.binwrite(tmp, @encryptor.encrypt_and_sign(JSON.generate(data)))
      File.chmod(0o600, tmp)
      File.rename(tmp, @path)
    end
  end
end
