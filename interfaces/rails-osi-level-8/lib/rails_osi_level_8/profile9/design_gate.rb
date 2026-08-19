# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # P9.4 — in-repo DESIGN.md-quality stand-in (no Google CLI).
    # Broken {token} refs and WCAG-ish contrast on colors.fg/colors.bg.
    module DesignGate
      REF_PATTERN = /\A\{([a-z0-9.]+)\}\z/i
      MIN_CONTRAST = 4.5

      Result = Data.define(:passed?, :reason, :findings) do
        def to_h
          { "passed" => passed?, "reason" => reason, "findings" => findings }
        end
      end

      module_function

      def lint(token_set)
        token_set = Request.stringify(token_set || {})
        map = flatten_tokens(token_set)
        findings = []

        map.each do |path, value|
          next unless value.is_a?(String)

          if (m = REF_PATTERN.match(value))
            ref = m[1]
            unless map.key?(ref)
              findings << { "kind" => "unresolved_token_ref", "path" => path, "ref" => ref }
            end
          end
        end

        if findings.any?
          return Result.new(false, Vocabulary::REFUSAL_CODES[:token_ref_broken], findings)
        end

        fg = map["colors.fg"]
        bg = map["colors.bg"]
        if fg && bg && hex?(fg) && hex?(bg)
          ratio = contrast_ratio(fg, bg)
          if ratio && ratio < MIN_CONTRAST
            findings << {
              "kind" => "contrast",
              "path" => "colors.fg/colors.bg",
              "ratio" => ratio.round(2),
              "minimum" => MIN_CONTRAST
            }
            return Result.new(false, Vocabulary::REFUSAL_CODES[:design_grounding_failed], findings)
          end
        end

        Result.new(true, nil, [])
      end

      def flatten_tokens(token_set)
        sets = token_set["tokens"] || token_set["tokenMap"] || {}
        acc = {}
        sets.each_value do |pairs|
          next unless pairs.is_a?(Hash)

          pairs.each { |k, v| acc[k.to_s] = v }
        end
        acc
      end
      private_class_method :flatten_tokens

      def hex?(value)
        value.to_s.match?(/\A#?[0-9a-fA-F]{3,8}\z/)
      end
      private_class_method :hex?

      def contrast_ratio(fg, bg)
        l1 = relative_luminance(fg)
        l2 = relative_luminance(bg)
        return nil unless l1 && l2

        lighter, darker = [l1, l2].minmax.reverse
        (lighter + 0.05) / (darker + 0.05)
      end
      private_class_method :contrast_ratio

      def relative_luminance(hex)
        h = hex.to_s.delete("#")
        h = h.chars.map { |c| c * 2 }.join if h.length == 3
        return nil unless h.match?(/\A[0-9a-fA-F]{6}/)

        r, g, b = h.scan(/../).take(3).map { |ch| channel(ch.to_i(16) / 255.0) }
        0.2126 * r + 0.7152 * g + 0.0722 * b
      end
      private_class_method :relative_luminance

      def channel(c)
        c <= 0.03928 ? c / 12.92 : (((c + 0.055) / 1.055)**2.4)
      end
      private_class_method :channel
    end
  end
end
