# frozen_string_literal: true

module RailsCpcp
  # Distinguishes empty, unparseable, and parsed request bodies.
  # A malformed body must not be mistaken for an unknown method (gap 54).
  module RequestBody
    Result = Struct.new(:payload, :error, :because, keyword_init: true)

    module_function

    def read(raw)
      text = raw.to_s
      if text.strip.empty?
        return Result.new(payload: nil, error: "empty_body", because: "request body was empty")
      end
      parsed = JSON.parse(text)
      unless parsed.is_a?(Hash)
        return Result.new(payload: nil, error: "unparseable_json", because: "request body must be a JSON object")
      end
      Result.new(payload: parsed, error: nil, because: nil)
    rescue JSON::ParserError
      Result.new(payload: nil, error: "unparseable_json", because: "request body was not JSON")
    end
  end
end
