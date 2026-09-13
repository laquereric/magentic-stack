# frozen_string_literal: true

module Vv
  module Canvas
    # Named account of a canvas blob. Board class is injectable (overlay AR).
    module Boards
      module_function

      def board_class
        Canvas.board_class
      end

      def list(_params = {})
        klass = board_class
        unless klass
          return { "ok" => true, "@graph" => Canvas.board_memory.values }
        end

        rows = klass.order(updated_at: :desc).limit(50).map { |b| api(b) }
        { "ok" => true, "@graph" => rows }
      rescue StandardError => e
        { "ok" => false, "reason" => "board_store_unavailable", "because" => e.message.to_s[0, 200] }
      end

      def get(params)
        p = BlobGate.stringify(params)
        row = find_board(p["id"])
        unless row
          return { "ok" => false, "reason" => "board_not_found", "because" => { "id" => p["id"] } }
        end

        api(row).merge("ok" => true)
      end

      def put(params)
        refused = BlobGate.graph_iri_refusal(params)
        return refused if refused

        p = BlobGate.stringify(params)
        digest = (p["blobDigest"] || p["blob_digest"]).to_s
        bad = BlobGate.digest_refusal(digest)
        return bad if bad

        title = p["title"].to_s
        title = "Untitled" if title.empty?
        klass = board_class
        unless klass
          id = p["id"].to_s.empty? ? "mem-#{digest[7, 8]}" : p["id"].to_s
          rec = { "id" => id, "title" => title, "blobDigest" => digest,
                  "actorCid" => (p["actorCid"] || p["actor_cid"]).to_s }
          Canvas.board_memory[id] = rec
          return rec.merge("ok" => true)
        end

        board = p["id"].to_s.empty? ? klass.new : (klass.find_by(id: p["id"]) || klass.new)
        board.title = title
        board.blob_digest = digest
        cid = (p["actorCid"] || p["actor_cid"]).to_s
        board.actor_cid = cid unless cid.empty?
        board.save!
        api(board).merge("ok" => true)
      rescue StandardError => e
        { "ok" => false, "reason" => "board_store_unavailable", "because" => e.message.to_s[0, 200] }
      end

      def find_board(id)
        klass = board_class
        return Canvas.board_memory[id.to_s] unless klass

        klass.find_by(id: id)
      end

      def api(board)
        if board.is_a?(Hash)
          return board
        end

        {
          "id" => board.id,
          "title" => board.title,
          "blobDigest" => board.blob_digest,
          "actorCid" => board.actor_cid,
          "updatedAt" => board.updated_at&.iso8601
        }
      end
      private_class_method :api, :find_board
    end
  end
end
