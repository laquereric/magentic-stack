# frozen_string_literal: true

require "digest"
require "json"
require "cgi"
require "securerandom"

module RailsOsiLevel8
  module Profile9
    # P9.2 — minimal deterministic renderer (in-repo stand-in for mmg-render).
    # Accepts only a RenderBundle. Unresolved tokens => RefusalNotice, never HTML fallback.
    module Renderer
      SEMANTIC_TAG = {
        "landmark" => "main",
        "heading" => "h2",
        "list" => "ul",
        "listitem" => "li",
        "article" => "article",
        "figure" => "figure",
        "form" => "form",
        "input" => "div",
        "button" => "button",
        "status" => "div",
        "alert" => "div",
        "dialog" => "dialog",
        "table" => "table",
        "timeline" => "ol"
      }.freeze

      module_function

      # bundle keys: aciaDocument, tokenSet, shownContext (optional), correlationId, receiptSeed
      def render(bundle)
        bundle = stringify(bundle || {})
        acia = bundle["aciaDocument"] || bundle["acia"] || bundle["document"]
        tokens = bundle["tokenSet"] || bundle["tokens"] || default_token_set
        correlation = bundle["correlationId"].to_s
        correlation = SecureRandom.uuid if correlation.empty?
        receipt_seed = bundle["receiptSeed"].to_s
        receipt_seed = SecureRandom.hex(8) if receipt_seed.empty?

        raise KnownRefusal.new("UX_ENVELOPE_INVALID", { "missing" => "aciaDocument" }) unless acia.is_a?(Hash)

        validation = Acia.validate(acia)
        unless validation.conforms?
          raise KnownRefusal.new(validation.reason, validation.because.merge("gate" => "acia"))
        end

        acia_digest = validation.digest
        token_digest = token_set_digest(tokens)
        unresolved = []

        html = +%(<div class="ux-render-root" data-ux-correlation="#{h(correlation)}" data-ux-acia-digest="#{h(acia_digest)}" data-ux-token-digest="#{h(token_digest)}">)
        html << render_node(
          acia["root"] || acia["rootNode"],
          tokens: tokens,
          acia_digest: acia_digest,
          token_digest: token_digest,
          unresolved: unresolved,
          path: "root"
        )
        html << "</div>"

        if unresolved.any?
          # Never HTML-fallback the broken node tree as success — replace with RefusalNotice.
          html = refusal_notice(
            reason: "UX_TOKEN_REF_BROKEN",
            unresolved: unresolved,
            acia_digest: acia_digest,
            token_digest: token_digest,
            correlation: correlation
          )
          receipt = build_receipt(
            ok: false,
            correlation: correlation,
            receipt_seed: receipt_seed,
            acia_digest: acia_digest,
            token_digest: token_digest,
            html_digest: digest_html(html),
            unresolved: unresolved
          )
          return { "ok" => false, "html" => html, "receipt" => receipt, "unresolvedTokens" => unresolved }
        end

        receipt = build_receipt(
          ok: true,
          correlation: correlation,
          receipt_seed: receipt_seed,
          acia_digest: acia_digest,
          token_digest: token_digest,
          html_digest: digest_html(html),
          unresolved: []
        )
        { "ok" => true, "html" => html, "receipt" => receipt }
      end

      def default_token_set
        {
          "cid" => "cid:tokens:ghis@1",
          "tokens" => {
            "tokens:ghis@1" => { "colors.fg" => "#111", "colors.bg" => "#fff", "spacing.md" => "1rem" }
          }
        }
      end

      def render_node(node, tokens:, acia_digest:, token_digest:, unresolved:, path:)
        return "" unless node.is_a?(Hash)

        kind = node["componentKind"].to_s
        node_id = node["nodeId"].to_s
        node_cid = "cid:node:#{Digest::SHA256.hexdigest("#{acia_digest}:#{node_id}")[0, 16]}"
        slt = node["slt"] || {}
        tag = SEMANTIC_TAG[slt["semanticRole"].to_s] || "div"

        # NAVIGATION IS A LINK.
        #
        # A node carrying `navigatesTo` goes somewhere, so it renders as an
        # <a href> and not a <button>. That is not a style preference: only a
        # real link gives back and forward history, open-in-new-tab,
        # middle-click, copy-link, and a screen reader announcing "link" rather
        # than "button". A button that navigates has to reimplement all of that,
        # and never does.
        #
        # semanticRole has no `link` member and this does not add one -- the
        # vocabulary stays closed. The role still says what the node IS; having
        # a destination says what pressing it DOES, and only that decides the
        # tag.
        #
        # Opening in a new tab is deliberately NOT implemented. That is consumer
        # configuration, not a property of a projection, and the default -- same
        # page, back history intact -- is the one that leaves the reader in
        # control of their own history stack.
        navigates_to = node.dig("props", "valueJson", "navigatesTo").to_s
        tag = "a" unless navigates_to.empty?
        role = slt["semanticRole"].to_s
        content_role = slt["contentRole"].to_s
        behavior = slt["behaviorKind"].to_s

        # Token resolution — SLT tokenSignature.setRef must exist in token set
        set_ref = slt.dig("tokenSignature", "setRef").to_s
        set_ref = "tokens:ghis@1" if set_ref.empty?
        unless resolve_token_set(tokens, set_ref)
          unresolved << { "path" => path, "nodeId" => node_id, "setRef" => set_ref }
        end

        # THE KIND NAME IS NOT A LABEL.
        #
        # This used to fall back to the componentKind when a node had no title,
        # which put the words "EvidencePanel", "ScopeTrail" and "RefusalNotice"
        # on the page as if they were content -- seven of them on the
        # translation board alone -- and announced the same to a screen reader.
        # A reader has no use for the name of the class that drew the box.
        #
        # A node with no title now renders no label element at all. The aria
        # fallback is kept: an interactive element with no accessible name is
        # worse than one named clumsily, and a node that wants to be announced
        # properly should carry a title.
        declared_title = node.dig("props", "valueJson", "title").to_s
        title = declared_title.empty? ? kind : declared_title
        safe_title = h(title.to_s)
        state = node.dig("props", "valueJson", "presentationState").to_s
        trace_label = Vocabulary.presentation_state_label(state)

        attrs = [
          %(data-ux-node-cid="#{h(node_cid)}"),
          %(data-ux-node-id="#{h(node_id)}"),
          %(data-ux-component-kind="#{h(kind)}"),
          %(data-ux-acia-digest="#{h(acia_digest)}"),
          %(data-ux-token-digest="#{h(token_digest)}"),
          %(data-ux-content-role="#{h(content_role)}"),
          %(aria-label="#{safe_title}")
        ]
        attrs << %(href="#{h(navigates_to)}") unless navigates_to.empty?

        # A FORM ROLE HAS TO POST SOMEWHERE.
        #
        # semanticRole "form" already mapped to <form>, but nothing carried the
        # target, so it rendered a form that submitted to the current page and
        # collected nothing. submitsTo is to a form what navigatesTo is to a link:
        # the destination, declared in the document rather than wired by script.
        submits_to = node.dig("props", "valueJson", "submitsTo").to_s
        unless submits_to.empty?
          attrs << %(action="#{h(submits_to)}")
          attrs << %(method="post")
        end

        # A control declaring itself the submit of its form gets the type that
        # makes a native form work without a line of JavaScript.
        attrs << %(type="submit") if node.dig("props", "valueJson", "submits")
        attrs << %(data-ux-presentation-state="#{h(state)}") if trace_label

        # A declared tone reaches the DOM. Boards have been setting `tone` on
        # StatusBadge since the beginning and the renderer was dropping it, so a
        # styling hook that documents already carried did not exist. Generic on
        # purpose: presentationState stays DrillDownCard-and-inspect-only, and
        # tone is the thing any component can say about its own state.
        tone = node.dig("props", "valueJson", "tone").to_s
        attrs << %(data-ux-tone="#{h(tone)}") unless tone.empty?
        attrs << %(role="status") if role == "status" || kind == "ContextBanner"
        attrs << %(role="alert") if kind == "RefusalNotice" || role == "alert"

        children_html = Array(node["children"]).each_with_index.map { |child, i|
          render_node(
            child,
            tokens: tokens,
            acia_digest: acia_digest,
            token_digest: token_digest,
            unresolved: unresolved,
            path: "#{path}.children[#{i}]"
          )
        }.join

        trace = trace_label ? %(<span data-ux-explore-trace>#{h(trace_label)}</span>) : ""
        label = declared_title.empty? ? "" : %(<span data-ux-label>#{safe_title}</span>)

        # A `text` PROP THAT RENDERS NOTHING IS A TRAP.
        #
        # Visible copy came only from `title`; `text` was never emitted, so a node
        # carrying text and no title rendered empty and looked like a styling
        # fault. Emitted here ONLY when there is no title -- every existing node
        # sets both, usually to the same string, and rendering both would print
        # the sentence twice.
        declared_text = node.dig("props", "valueJson", "text").to_s
        body = (declared_title.empty? && !declared_text.empty?) ? %(<span data-ux-text>#{h(declared_text)}</span>) : ""

        # A DISCLOSE BEHAVIOUR HAS TO DISCLOSE.
        #
        # `disclose` rendered as a plain div, so a node declaring itself a
        # disclosure showed its contents permanently and its label did nothing.
        # <details>/<summary> is the native answer and needs no JavaScript --
        # which matters here, because these pages carry no event handlers, and an
        # affordance that only looks pressable is worse than no affordance.
        if behavior == "disclose"
          summary = declared_title.empty? ? kind : declared_title
          return %(<details #{attrs.join(" ")}>) +
                 %(<summary data-ux-summary>#{h(summary)}</summary>) +
                 %(#{trace}#{children_html}</details>)
        end

        # AN INPUT ROLE HAS TO BE TYPEABLE.
        #
        # "input" mapped to a plain div, so a node declaring itself an input
        # rendered as read-only text. A surface whose whole job is collecting an
        # edit cannot be a div: it looks editable and refuses the keystroke,
        # which is the same defect as a button with no handler.
        if role == "input"
          v = node.dig("props", "valueJson") || {}
          field = [
            %(data-ux-node-id="#{h(node_id)}-field"),
            %(name="#{h(v['name'] || node_id)}"),
            %(rows="#{h(v['rows'] || 6)}")
          ]
          field << %(placeholder="#{h(v['placeholder'])}") if v["placeholder"]
          return %(<#{tag} #{attrs.join(" ")}>#{label}#{body}#{trace}) +
                 %(<textarea #{field.join(" ")}>#{h(v['text'])}</textarea>) +
                 %(#{children_html}</#{tag}>)
        end

        %(<#{tag} #{attrs.join(" ")}>#{label}#{body}#{trace}#{children_html}</#{tag}>)
      end
      private_class_method :render_node

      def refusal_notice(reason:, unresolved:, acia_digest:, token_digest:, correlation:)
        detail = h(unresolved.map { |u| "#{u['path']}:#{u['setRef']}" }.join("; "))
        operation = "ux.render"
        failed = "tokenSignature.setRef"
        policy = "none"
        remediation = "Supply an accepted token set that contains the referenced tokenSignature.setRef."
        <<~HTML.gsub(/\n\s*/, "")
          <div role="alert" class="ux-refusal-notice"
               data-ux-component-kind="RefusalNotice"
               data-ux-acia-digest="#{h(acia_digest)}"
               data-ux-token-digest="#{h(token_digest)}"
               data-ux-correlation="#{h(correlation)}"
               data-ux-operation="#{h(operation)}"
               data-ux-reason="#{h(reason)}"
               data-ux-failed-criteria="#{h(failed)}"
               data-ux-override-policy="#{h(policy)}"
               data-ux-remediation="#{h(remediation)}">
            <strong>RefusalNotice</strong>
            <span data-ux-operation>#{h(operation)}</span>
            <span>#{h(reason)}</span>
            <span data-ux-failed-criteria>#{h(failed)}</span>
            <span data-ux-remediation>#{h(remediation)}</span>
            <span data-ux-override-policy>#{h(policy)}</span>
            <span data-ux-unresolved>#{detail}</span>
          </div>
        HTML
      end
      private_class_method :refusal_notice

      def resolve_token_set(token_set, set_ref)
        return false unless token_set.is_a?(Hash)

        map = token_set["tokens"] || token_set["tokenMap"] || {}
        return true if map.key?(set_ref)
        return true if token_set["cid"].to_s == set_ref
        false
      end
      private_class_method :resolve_token_set

      def token_set_digest(token_set)
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(deep_sort(stringify(token_set || {}))))}"
      end
      private_class_method :token_set_digest

      def build_receipt(ok:, correlation:, receipt_seed:, acia_digest:, token_digest:, html_digest:, unresolved:)
        payload = {
          "ok" => ok,
          "correlationId" => correlation,
          "receiptSeed" => receipt_seed,
          "aciaDigest" => acia_digest,
          "tokenDigest" => token_digest,
          "htmlDigest" => html_digest,
          "unresolvedTokens" => unresolved,
          "profileId" => Vocabulary::PROFILE_ID
        }
        digest = Digest::SHA256.hexdigest(JSON.generate(deep_sort(payload)))
        payload.merge(
          "cid" => "cid:sha256:#{digest}",
          "digest" => "sha256:#{digest}",
          "receiptKind" => "ux:RenderReceipt"
        )
      end
      private_class_method :build_receipt

      def digest_html(html)
        "sha256:#{Digest::SHA256.hexdigest(html.to_s)}"
      end
      private_class_method :digest_html

      def h(str)
        CGI.escapeHTML(str.to_s)
      end
      private_class_method :h

      def stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), hsh| hsh[k.to_s] = stringify(v) }
        when Array then obj.map { |v| stringify(v) }
        else obj
        end
      end
      private_class_method :stringify

      def deep_sort(obj)
        case obj
        when Hash
          obj.keys.map(&:to_s).sort.each_with_object({}) { |k, hsh| hsh[k] = deep_sort(obj[k]) }
        when Array then obj.map { |v| deep_sort(v) }
        else obj
        end
      end
      private_class_method :deep_sort
    end
  end
end
