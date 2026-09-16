# frozen_string_literal: true

require "uri"

module Vv
  module Miro
    # REST v2 client for `https://api.miro.com`. Boards, items, app
    # cards, webhooks — works whether or not a human has the board open.
    #
    # Never raises. Every method returns `{ ok: true, data: }` or
    # `{ ok: false, reason:, because: }`.
    #
    #   client = Vv::Miro::Client.new(access_token: ENV["MIRO_ACCESS_TOKEN"])
    #   client.get_board("uXjV…")
    class Client
      ITEM_COLLECTIONS = Effects::ITEM_COLLECTIONS

      attr_reader :uri, :access_token, :transport

      def initialize(access_token: nil, uri: nil, transport: nil,
                     open_timeout: nil, read_timeout: nil)
        @uri = (uri || ENV["MIRO_API_URL"] || Miro::DEFAULT_API_URL).to_s
        @access_token = (access_token || ENV["MIRO_ACCESS_TOKEN"] || ENV["MIRO_TOKEN"]).to_s
        @transport = transport || Transport.new(
          uri: @uri,
          access_token: @access_token,
          open_timeout: open_timeout || Transport::DEFAULT_OPEN_TIMEOUT,
          read_timeout: read_timeout || Transport::DEFAULT_READ_TIMEOUT
        )
      end

      # Escape hatch for any REST path this gem has not named yet.
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

      def patch(path, body = nil)
        call(:patch, path, body: body)
      end

      def delete(path, body = nil)
        call(:delete, path, body: body)
      end

      # ── boards ─────────────────────────────────────────────────

      def list_boards(**query)
        get("/v2/boards", query)
      end

      def get_board(board_id)
        need_board!(board_id) or return @__refusal
        get("/v2/boards/#{enc(board_id)}")
      end

      def create_board(**body)
        post("/v2/boards", body)
      end

      def update_board(board_id, **body)
        need_board!(board_id) or return @__refusal
        patch("/v2/boards/#{enc(board_id)}", body)
      end

      def delete_board(board_id)
        need_board!(board_id) or return @__refusal
        delete("/v2/boards/#{enc(board_id)}")
      end

      def copy_board(board_id, **body)
        need_board!(board_id) or return @__refusal
        post("/v2/boards/#{enc(board_id)}/copy", body)
      end

      # ── items ──────────────────────────────────────────────────

      def list_items(board_id, **query)
        need_board!(board_id) or return @__refusal
        get("/v2/boards/#{enc(board_id)}/items", query)
      end

      def get_item(board_id, item_id)
        need_board!(board_id) or return @__refusal
        need_item!(item_id) or return @__refusal
        get("/v2/boards/#{enc(board_id)}/items/#{enc(item_id)}")
      end

      def delete_item(board_id, item_id)
        need_board!(board_id) or return @__refusal
        need_item!(item_id) or return @__refusal
        delete("/v2/boards/#{enc(board_id)}/items/#{enc(item_id)}")
      end

      def update_item_position(board_id, item_id, **body)
        need_board!(board_id) or return @__refusal
        need_item!(item_id) or return @__refusal
        patch("/v2/boards/#{enc(board_id)}/items/#{enc(item_id)}", body)
      end

      def create_item(board_id, type:, **body)
        need_board!(board_id) or return @__refusal
        col = collection!(type) or return @__refusal
        post("/v2/boards/#{enc(board_id)}/#{col}", body)
      end

      def update_typed_item(board_id, type:, item_id:, **body)
        need_board!(board_id) or return @__refusal
        need_item!(item_id) or return @__refusal
        col = collection!(type) or return @__refusal
        patch("/v2/boards/#{enc(board_id)}/#{col}/#{enc(item_id)}", body)
      end

      def get_typed_item(board_id, type:, item_id:)
        need_board!(board_id) or return @__refusal
        need_item!(item_id) or return @__refusal
        col = collection!(type) or return @__refusal
        get("/v2/boards/#{enc(board_id)}/#{col}/#{enc(item_id)}")
      end

      # Named item helpers. Same never-raise envelope.

      def create_app_card(board_id, **body) = create_item(board_id, type: "app_card", **body)
      def get_app_card(board_id, item_id) = get_typed_item(board_id, type: "app_card", item_id: item_id)
      def update_app_card(board_id, item_id, **body)
        update_typed_item(board_id, type: "app_card", item_id: item_id, **body)
      end
      def delete_app_card(board_id, item_id) = delete_item(board_id, item_id)

      def create_sticky_note(board_id, **body) = create_item(board_id, type: "sticky_note", **body)
      def get_sticky_note(board_id, item_id) = get_typed_item(board_id, type: "sticky_note", item_id: item_id)
      def update_sticky_note(board_id, item_id, **body)
        update_typed_item(board_id, type: "sticky_note", item_id: item_id, **body)
      end

      def create_shape(board_id, **body) = create_item(board_id, type: "shape", **body)
      def create_text(board_id, **body) = create_item(board_id, type: "text", **body)
      def create_frame(board_id, **body) = create_item(board_id, type: "frame", **body)
      def create_connector(board_id, **body) = create_item(board_id, type: "connector", **body)
      def create_image(board_id, **body) = create_item(board_id, type: "image", **body)
      def create_card(board_id, **body) = create_item(board_id, type: "card", **body)
      def create_embed(board_id, **body) = create_item(board_id, type: "embed", **body)
      def create_tag(board_id, **body) = create_item(board_id, type: "tag", **body)

      def list_connectors(board_id, **query)
        need_board!(board_id) or return @__refusal
        get("/v2/boards/#{enc(board_id)}/connectors", query)
      end

      def apply_effect(board_id, effect = nil, **kw)
        effect = kw unless kw.empty?
        mapped = Effects.to_rest(effect, board_id: board_id)
        return mapped unless mapped[:ok]

        spec = mapped[:data]
        call(spec[:method], spec[:path], body: spec[:body])
      end

      def share(name:, effects:)
        Share.push(self, name: name, effects: effects)
      end

      # ── webhooks ───────────────────────────────────────────────

      def list_webhooks(**query)
        get("/v2/webhooks/subscriptions", query)
      end

      def get_webhook(subscription_id)
        need!(subscription_id, :webhook_required, "get_webhook needs a subscription id") or return @__refusal
        get("/v2/webhooks/subscriptions/#{enc(subscription_id)}")
      end

      def create_webhook(**body)
        post("/v2/webhooks/subscriptions", body)
      end

      def update_webhook(subscription_id, **body)
        need!(subscription_id, :webhook_required, "update_webhook needs a subscription id") or return @__refusal
        patch("/v2/webhooks/subscriptions/#{enc(subscription_id)}", body)
      end

      def delete_webhook(subscription_id)
        need!(subscription_id, :webhook_required, "delete_webhook needs a subscription id") or return @__refusal
        delete("/v2/webhooks/subscriptions/#{enc(subscription_id)}")
      end

      private

      def collection!(type)
        col = ITEM_COLLECTIONS[type.to_s]
        if col.nil?
          @__refusal = Envelope.refuse(:item_type_unsupported, "unknown item type #{type.inspect}")
          return nil
        end
        col
      end

      def need_board!(board_id)
        need!(board_id, :board_required, "this call needs a board id")
      end

      def need_item!(item_id)
        need!(item_id, :item_id_required, "this call needs an item id")
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
