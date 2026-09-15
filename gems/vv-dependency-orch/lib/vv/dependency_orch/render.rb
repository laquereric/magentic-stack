# frozen_string_literal: true

require "json"

module Vv
  module DependencyOrch
    # Turning an envelope into something to read.
    #
    # This lives in the library rather than in the rake tasks on purpose. The
    # tasks are a presentation of the model and the CLI will be a second one; if
    # rendering lived in a task body, the CLI would have to reimplement it and
    # the two surfaces would start answering differently. Keeping it here is
    # what makes "no rake task holds domain logic" a rule anybody can follow.
    #
    # JSON IS THE OUTPUT. Text is a rendering of it, offered because an operator
    # reading a drift report at 2am should not have to parse JSON in their head.
    # Anything a gate or a CI job asserts on reads the JSON.
    module Render
      module_function

      def call(view, envelope, format: :json)
        # The graph export is already serialised in the format it was asked
        # for. Re-encoding it inside an envelope would hand CI a JSON string
        # containing JSON, which is the kind of output people write a `jq`
        # incantation around instead of fixing.
        return envelope[:body] if view == :graph && envelope[:ok]

        return JSON.pretty_generate(Export.stringify(envelope)) if format.to_sym == :json

        return refusal(envelope) unless envelope[:ok]

        case view
        when :doctor then doctor(envelope)
        when :resources then resources(envelope)
        when :show then show(envelope)
        when :deps then deps(envelope)
        when :reverse then reverse(envelope)
        when :drift then drift(envelope)
        when :deploy then deploy(envelope)
        when :graph then envelope[:body]
        else JSON.pretty_generate(Export.stringify(envelope))
        end
      end

      # A refusal prints its reason first and its because second, always in that
      # order, because the reason is the closed vocabulary a reader learns once
      # and the because is the sentence they read when it is not enough.
      def refusal(envelope)
        "REFUSED #{envelope[:reason]}\n  #{envelope[:because]}"
      end

      def doctor(envelope)
        out = ["adapters"]
        envelope[:adapters].each do |name, state|
          mark = state[:available] ? "ok " : "-- "
          out << "  #{mark}#{name}#{state[:because] ? "  (#{state[:because]})" : ''}"
        end
        unless envelope[:roots].empty?
          out << "roots"
          envelope[:roots].each do |root|
            flags = []
            flags << "missing" unless root[:exists]
            flags << "SHALLOW: ancestry not answerable here" if root[:shallow]
            out << "  #{root[:root]}#{flags.empty? ? '' : "  [#{flags.join(', ')}]"}"
          end
        end
        out.join("\n")
      end

      def resources(envelope)
        rows = envelope[:resources]
        return "no resources#{notes_suffix(envelope)}" if rows.empty?

        out = rows.map do |r|
          "#{r[:kind].to_s.ljust(6)} #{Identity.short(r[:digest]).ljust(20)} " \
            "#{index_digest_cell(r[:index_digest]).ljust(14)} " \
            "#{platform_cell(r).ljust(16)} " \
            "#{placement_cell(r).ljust(24)} #{Array(r[:names]).first}"
        end
        (out + [notes_block(envelope)]).compact.join("\n")
      end

      def show(envelope)
        r = envelope[:resource]
        out = [
          "digest        #{r[:digest]}",
          "kind          #{r[:kind]}",
          "names         #{Array(r[:names]).join(', ')}",
          "index_digest  #{index_digest_cell(r[:index_digest])}",
          "platforms     #{r[:platform_count]} #{Array(r[:platforms]).join(', ')}",
          "attestations  #{r[:attestations]} (excluded from the platform count)",
          "placements"
        ]
        Array(r[:placements]).each do |p|
          out << "  #{p[:state].to_s.ljust(12)} #{p[:kind]}/#{p[:at]}#{p[:because] ? "  #{p[:because]}" : ''}"
        end
        out << "declares      #{envelope[:declares].length}"
        Array(envelope[:declares]).each { |e| out << "  #{where(e)}" }
        out << "references    #{envelope[:references].length}"
        Array(envelope[:references]).each { |e| out << "  #{where(e)}" }
        out.join("\n")
      end

      def deps(envelope)
        return "no forward edges from #{Identity.short(envelope[:digest])}" if envelope[:edges].empty?

        envelope[:edges].map do |hop|
          e = hop[:edge]
          "#{'  ' * hop[:depth]}#{e[:kind]} -> #{Identity.short(e[:to])}#{e[:where] ? "  #{where(e)}" : ''}"
        end.join("\n")
      end

      # The reverse view prints the two sets under two headings and never
      # totals them. A single "7 lines care" number is the merged set wearing a
      # disguise -- it tells a maintainer how much work there is and not which
      # kind, and the kinds need different work.
      def reverse(envelope)
        out = ["if #{Identity.short(envelope[:digest])} moves:"]
        out << "  DECLARED AT (#{envelope[:declares].length}) -- change the digest here"
        envelope[:declares].each { |e| out << "    #{where(e)}" }
        out << "  REFERENCED BY (#{envelope[:references].length}) -- re-check these because it changed"
        envelope[:references].each { |e| out << "    #{where(e)}" }
        out.join("\n")
      end

      def drift(envelope)
        out = []
        if envelope[:findings].empty?
          out << "no findings from #{envelope[:examined]} referenced resource(s)"
        else
          envelope[:findings].each do |f|
            out << "#{f[:finding]}  #{f[:short]}#{f[:names].empty? ? '' : "  #{f[:names].first}"}"
            out << "  #{f[:means]}"
            out << "  because: #{f[:because]}"
            out << "  platform: #{f[:platform]}" if f[:platform]
            f[:declared_at].each { |c| out << "  declared at  #{consumer(c)}" }
            f[:referenced_by].each { |c| out << "  referenced   #{consumer(c)}" }
            out << ""
          end
        end

        unless envelope[:unknown].empty?
          out << "UNKNOWN (#{envelope[:unknown].length}) -- not findings; nothing gave a completed answer"
          envelope[:unknown].each do |u|
            out << "  #{Identity.short(u[:digest])}  #{u[:because]}"
          end
        end

        out << notes_block(envelope)
        out.compact.join("\n")
      end

      def deploy(envelope)
        out = []
        if envelope[:path]
          out << envelope[:path]
        end
        if envelope[:manifest]
          %w[local_deploy remote_deploy].each do |placement|
            slot = envelope[:manifest][placement]
            next unless slot.is_a?(Hash)

            out << placement
            images = slot["images"] || {}
            images.each do |key, image|
              next unless image.is_a?(Hash)

              idx = image.key?("index_digest") ? image["index_digest"].inspect : "nil"
              out << "  #{key}  #{Identity.short(image['digest'])}  index_digest=#{idx}"
            end
          end
        end
        if envelope[:present]
          out << "present #{envelope[:present].length}"
          envelope[:present].each { |p| out << "  #{p[:key]}  #{Identity.short(p[:digest])}" }
        end
        if envelope[:missing]
          out << "missing #{envelope[:missing].length}"
          envelope[:missing].each { |m| out << "  #{m[:key]}  #{m[:because]}" }
        end
        out << notes_block(envelope)
        out.compact.join("\n")
      end

      def where(edge)
        w = edge[:where] || {}
        return w[:at].to_s if w[:path].nil?

        loc = if w[:pointer]
                "#{w[:repo]}/#{w[:path]}#{w[:pointer]}"
              else
                "#{w[:repo]}/#{w[:path]}:#{w[:line]}"
              end
        loc += "  [#{w[:when]}]" if w[:when]
        loc += "  (#{edge[:because]})" if edge[:because]
        loc
      end

      def consumer(c)
        "#{c[:repo]}/#{c[:path]}:#{c[:line]}#{c[:source] ? "  (#{c[:source]})" : ''}"
      end

      # false and nil must not render the same. "none" is a fact about the
      # world; "unknown" is a fact about us.
      def index_digest_cell(value)
        case value
        when false then "none"
        when nil then "unknown"
        else Identity.short(value)
        end
      end

      def platform_cell(resource)
        return Array(resource[:platforms]).join(",") unless Array(resource[:platforms]).empty?

        resource.dig(:meta, :platform).to_s
      end

      def placement_cell(resource)
        Array(resource[:placements]).map { |p| "#{p[:at]}=#{p[:state]}" }.join(" ")
      end

      def notes_block(envelope)
        notes = Array(envelope[:notes])
        return nil if notes.empty?

        (["", "notes -- what was NOT looked at:"] +
          notes.map { |n| "  #{n[:reason]}: #{n[:because]}" }).join("\n")
      end

      def notes_suffix(envelope)
        Array(envelope[:notes]).empty? ? "" : " (#{envelope[:notes].length} note(s); run with FORMAT=json to see them)"
      end
    end
  end
end
