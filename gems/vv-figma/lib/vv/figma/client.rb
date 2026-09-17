# frozen_string_literal: true

require "uri"

module Vv
  module Figma
    # REST client for `https://api.figma.com`. Files, comments, images,
    # webhooks — works whether or not a human has the file open.
    #
    # Never raises. Every method returns `{ ok: true, data: }` or
    # `{ ok: false, reason:, because: }`.
    #
    #   client = Vv::Figma::Client.new(access_token: ENV["FIGMA_ACCESS_TOKEN"])
    #   client.get_file("AbCdEf")
    class Client
      attr_reader :uri, :access_token, :transport

      def initialize(access_token: nil, uri: nil, transport: nil,
                     open_timeout: nil, read_timeout: nil)
        @uri = (uri || ENV["FIGMA_API_URL"] || Figma::DEFAULT_API_URL).to_s
        @access_token = (access_token || ENV["FIGMA_ACCESS_TOKEN"] || ENV["FIGMA_TOKEN"]).to_s
        @transport = transport || Transport.new(
          uri: @uri,
          access_token: @access_token,
          open_timeout: open_timeout || Transport::DEFAULT_OPEN_TIMEOUT,
          read_timeout: read_timeout || Transport::DEFAULT_READ_TIMEOUT
        )
      end

      def call(method, path, body: nil, query: nil)
        wire = body.nil? ? nil : Keys.to_wire(Keys.compact(body))
        @transport.request(method, path, body: wire, query: query)
      end

      def get(path, query = nil)
        call(:get, path, query: query)
      end

      def post(path, body = nil)
        call(:post, path, body: body)
      end

      def delete(path, body = nil)
        call(:delete, path, body: body)
      end

      def me
        get("/v1/me")
      end

      def get_file(file_key, **query)
        need_file!(file_key) or return @__refusal
        get("/v1/files/#{enc(file_key)}", query)
      end

      def get_nodes(file_key, ids:, **query)
        need_file!(file_key) or return @__refusal
        list = Array(ids).map(&:to_s).reject(&:empty?)
        if list.empty?
          return Envelope.refuse(:item_id_required, "get_nodes needs ids")
        end

        get("/v1/files/#{enc(file_key)}/nodes", query.merge(ids: list.join(",")))
      end

      def get_images(file_key, ids:, **query)
        need_file!(file_key) or return @__refusal
        list = Array(ids).map(&:to_s).reject(&:empty?)
        if list.empty?
          return Envelope.refuse(:item_id_required, "get_images needs ids")
        end

        get("/v1/images/#{enc(file_key)}", query.merge(ids: list.join(",")))
      end

      def list_comments(file_key, **query)
        need_file!(file_key) or return @__refusal
        get("/v1/files/#{enc(file_key)}/comments", query)
      end

      def create_comment(file_key, **body)
        need_file!(file_key) or return @__refusal
        post("/v1/files/#{enc(file_key)}/comments", body)
      end

      def delete_comment(file_key, comment_id)
        need_file!(file_key) or return @__refusal
        need!(comment_id, :item_id_required, "delete_comment needs a comment id") or return @__refusal
        delete("/v1/files/#{enc(file_key)}/comments/#{enc(comment_id)}")
      end

      def list_team_projects(team_id, **query)
        need!(team_id, :team_required, "list_team_projects needs a team id") or return @__refusal
        get("/v1/teams/#{enc(team_id)}/projects", query)
      end

      def list_project_files(project_id, **query)
        need!(project_id, :project_required, "list_project_files needs a project id") or return @__refusal
        get("/v1/projects/#{enc(project_id)}/files", query)
      end

      def apply_effect(file_key, effect = nil, **kw)
        effect = kw unless kw.empty?
        mapped = Effects.to_rest(effect, file_key: file_key)
        return mapped unless mapped[:ok]

        spec = mapped[:data]
        call(spec[:method], spec[:path], body: spec[:body])
      end

      def share(file_key:, effects:, name: nil)
        Share.push(self, file_key: file_key, effects: effects, name: name)
      end

      def list_webhooks(**query)
        get("/v2/webhooks", query)
      end

      def create_webhook(**body)
        post("/v2/webhooks", body)
      end

      def delete_webhook(webhook_id)
        need!(webhook_id, :webhook_required, "delete_webhook needs a webhook id") or return @__refusal
        delete("/v2/webhooks/#{enc(webhook_id)}")
      end

      private

      def need_file!(file_key)
        need!(file_key, :file_required, "this call needs a file_key")
      end

      def need!(value, reason, because)
        if value.nil? || value.to_s.strip.empty?
          @__refusal = Envelope.refuse(reason, because)
          return false
        end
        true
      end

      def enc(value)
        URI.encode_www_form_component(value.to_s)
      end
    end
  end
end
