# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::RetryPolicy do
  let(:policy) { described_class }

  it "retries a 503 that states a window, twice at most" do
    headers = { "retry-after" => "2" }
    expect(policy.decide(face: :pull, http_status: 503, headers: headers).retry?).to be true
    expect(policy.decide(face: :pull, http_status: 503, headers: headers).after).to eq 2
    expect(policy.decide(face: :pull, attempt: 2, http_status: 503, headers: headers).retry?).to be false
  end

  it "retries a PUSH under the same operationId" do
    decision = policy.decide(face: :push, http_status: 503, headers: { "retry-after" => "1" },
                             operation_id: "note-create-abc")
    expect(decision.retry?).to be true
  end

  it "never retries a PUSH that has no operationId" do
    decision = policy.decide(face: :push, http_status: 503, headers: { "retry-after" => "1" })
    expect(decision.retry?).to be false
  end

  it "does not treat a bare 503 as a retry signal" do
    expect(policy.decide(face: :pull, http_status: 503, headers: {}).retry?).to be false
  end

  it "retries once when there was no response at all" do
    expect(policy.decide(face: :pull, transport_error: :timeout).retry?).to be true
    expect(policy.decide(face: :pull, attempt: 1, transport_error: :timeout).retry?).to be false
    expect(policy.decide(face: :push, transport_error: :timeout, operation_id: "x").retry?).to be true
  end

  it "does not retry statuses the contract says are decisions" do
    [200, 400, 401, 403, 404, 422, 500, 502, 504].each do |status|
      expect(policy.decide(face: :pull, http_status: status, headers: { "retry-after" => "5" }).retry?)
        .to be(false), "expected no retry on #{status}"
    end
  end

  it "reads an HTTP-date Retry-After and clamps the wait" do
    headers = { "Retry-After" => (Time.now + 3).httpdate }
    expect(policy.decide(face: :pull, http_status: 503, headers: headers).after).to be_between(0, 4)

    far = { "retry-after" => "9999" }
    expect(policy.decide(face: :pull, http_status: 503, headers: far).after).to eq described_class::MAX_WAIT
  end
end
