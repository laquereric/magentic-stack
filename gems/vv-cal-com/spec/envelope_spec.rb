# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom::Envelope do
  describe ".from_cal" do
    it "unwraps { status: success, data: } and keeps pagination" do
      r = described_class.from_cal(
        {
          "status" => "success",
          "data" => [{ "uid" => "b1" }],
          "pagination" => { "hasMore" => true, "nextCursor" => "c1" }
        },
        http_status: 200
      )
      expect(r[:ok]).to be true
      expect(r[:data]).to eq([{ "uid" => "b1" }])
      expect(r[:pagination]).to eq("hasMore" => true, "nextCursor" => "c1")
      expect(r[:http_status]).to eq(200)
    end

    it "treats a raw OAuth token object as success" do
      r = described_class.from_cal(
        { "access_token" => "at", "token_type" => "bearer", "expires_in" => 1800, "refresh_token" => "rt", "scope" => "BOOKING_READ" }
      )
      expect(r[:ok]).to be true
      expect(r[:data]["access_token"]).to eq("at")
    end

    it "treats status error as a refusal, not success" do
      r = described_class.from_cal(
        {
          "status" => "error",
          "error" => { "message" => "Invalid event type", "code" => "BadRequestException" }
        },
        http_status: 400
      )
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:cal_error)
      expect(r[:because]).to eq("Invalid event type")
      expect(r[:code]).to eq("BadRequestException")
      expect(r[:http_status]).to eq(400)
    end

    it "treats RFC 6749 error as oauth_error" do
      r = described_class.from_cal(
        { "error" => "invalid_grant", "error_description" => "code expired" },
        http_status: 400
      )
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:oauth_error)
      expect(r[:because]).to eq("code expired")
      expect(r[:code]).to eq("invalid_grant")
    end
  end

  describe "never raises" do
    it "ok and refuse always return hashes with :ok" do
      expect(described_class.ok(data: 1)[:ok]).to be true
      expect(described_class.refuse(:x, "y")[:ok]).to be false
    end
  end
end
