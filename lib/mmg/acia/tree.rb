# frozen_string_literal: true

module Mmg
  module Acia
    # ACIA TREE BUILDERS (epic_65 Stage 3 -- moved verbatim from Mmg::Sal::Render).
    # Domain data -> a host-agnostic node-hash tree: the canonical ACIA structure an
    # operation PRODUCES ("ACIA OUT") and CONSUMES ("ACIA IN"), independent of any host.
    # A node is a plain Hash (graph-groundable):
    #   { kind: "pane"|"list"|"table"|"text"|"entity_token"|"action",
    #     value:, entity_iri:, semantic_role:, hint:, children: [ node, ... ] }
    # The host RENDERERS (unix_tree/dom) live in mmg-sal; the .md MATERIALIZATION in
    # Mmg::Acia::Markdown. Pure, never-raise. Mmg::Sal::Render delegates here.
    module Tree
      module_function

      # Build a SAL node tree from an mmg-nvc message { observation, need, request }.
      # Shape: pane { text(observation) ; text(need) ; list(ask) { action* } }.
      # The Request's options become ACTION nodes (the affordances).
      def from_nvc(message, title: "your call")
        m   = message.is_a?(::Hash) ? message : {}
        req = m[:request] || m["request"] || {}
        actions = ::Kernel.Array(req[:options] || req["options"]).map do |o|
          o = { "label" => o.to_s } unless o.is_a?(::Hash)
          { kind: "action", value: (o[:label] || o["label"]).to_s, hint: (o[:hint] || o["hint"]).to_s }
        end
        {
          kind: "pane", value: (m[:title] || m["title"] || title).to_s,
          children: [
            { kind: "text", value: (m[:observation] || m["observation"]).to_s },
            { kind: "text", value: (m[:need] || m["need"]).to_s },
            { kind: "list", value: (req[:ask] || req["ask"]).to_s, children: actions }
          ]
        }
      end

      # Build a SAL node tree for an ARC awaiting human sign-off, with its EPIC
      # GENEALOGY (operator: the human approves the ARC, not a brief) --
      #   Epic(s) created -> Arcs -> which was SELECTED -> which just COMPLETED.
      # Genealogy nodes are graph-grounded EntityTokens. Affordances are BARE action
      # labels -- the label IS the interaction; NO command hints.
      def from_arc(arc:, epic: nil, epic_iri: nil, selected: nil, completed: nil,
                   options: ["review", "approve", "decline"])
        children = []
        if epic && !epic.to_s.empty?
          children << { kind: "entity_token", value: "epic: #{epic}",
                        entity_iri: (epic_iri || "urn:mm:epic:#{epic}"), semantic_role: "epic" }
        end
        children << { kind: "text", value: "selected: #{selected}" } if selected && !selected.to_s.empty?
        children << { kind: "text", value: "completed: #{completed}" } if completed && !completed.to_s.empty?
        actions = ::Kernel.Array(options).map do |o|
          { kind: "action", value: (o.is_a?(::Hash) ? (o[:label] || o["label"]) : o).to_s }
        end
        children << { kind: "list", value: "your call", children: actions }
        headline = "ARC #{arc} -- just completed" + (epic && !epic.to_s.empty? ? "  (serves #{epic})" : "")
        { kind: "pane", value: headline, children: children }
      end

      # Build the FULL ACIA node tree for an ARC awaiting human sign-off (operator
      # 2026-07-11): the human reviews the whole change WITH its chain lineage AND the
      # concrete diff. Sections (each omitted when its data is empty), then affordances:
      #   friction(s) -> plan -> epic -> arc -> brief -> slot -> mcbmap
      #   -> files changed -> diffs -> [review] [approve] [decline]
      # Lineage cells are graph-grounded EntityTokens. `diffs` is a list of
      # { path:, patch: }; each patch's lines render as capped text children. Pure.
      def from_acia(arc:, epic: nil, epic_iri: nil, plan: nil, plan_iri: nil,
                    frictions: [], brief: nil, brief_iri: nil, slot: nil, slot_detail: nil,
                    mcbmap: [], files: [], diffs: [], completed: nil, loss: nil,
                    options: ["review", "approve", "decline"], diff_line_cap: 40, voice: nil,
                    epic_summary: nil, plan_title: nil, brief_detail: nil, arc_detail: nil,
                    briefs: [], pr_title: nil, pr_body: nil, detail_cap: 8, detail_width: 96,
                    git_repos: [], git_repos_total: nil)
        s = ->(v) { !v.nil? && !v.to_s.strip.empty? }
        c = []
        c << { kind: "text", value: voice.to_s } if s.(voice)
        fr = ::Kernel.Array(frictions).map { |f| f.is_a?(::Hash) ? f : { slug: f.to_s } }
                    .reject { |f| (f[:slug] || f["slug"]).to_s.empty? }
        unless fr.empty?
          c << { kind: "list", value: (fr.size > 1 ? "frictions" : "friction"),
                 children: fr.map { |f|
                   fslug = (f[:slug] || f["slug"]).to_s
                   fdet  = (f[:detail] || f["detail"]).to_s
                   { kind: "entity_token", value: fslug, entity_iri: "urn:mm:friction:#{fslug}", semantic_role: "friction",
                     children: (s.(fdet) ? detail_lines(fdet, detail_cap, detail_width) : []) } } }
        end
        c << { kind: "entity_token", value: "plan: #{plan}",   entity_iri: (s.(plan_iri)  ? plan_iri  : "urn:mm:plan:#{plan}"),   semantic_role: "plan",
               children: (s.(plan_title) ? detail_lines(plan_title, detail_cap, detail_width) : []) }  if s.(plan)
        c << { kind: "entity_token", value: "epic: #{epic}",   entity_iri: (s.(epic_iri)  ? epic_iri  : "urn:mm:epic:#{epic}"),   semantic_role: "epic",
               children: (s.(epic_summary) ? detail_lines(epic_summary, detail_cap, detail_width) : []) }  if s.(epic)
        c << { kind: "entity_token", value: "arc: #{arc}",     entity_iri: "urn:mm:arc:#{arc}",  semantic_role: "arc",
               children: (s.(arc_detail) ? detail_lines(arc_detail, detail_cap, detail_width) : []) }   if s.(arc)
        bl = ::Kernel.Array(briefs).map { |b| b.is_a?(::Hash) ? b : { id: b.to_s } }
                    .reject { |b| (b[:id] || b["id"]).to_s.empty? }
        bl = [{ id: brief.to_s, iri: brief_iri, detail: brief_detail }] if bl.empty? && s.(brief)
        unless bl.empty?
          c << { kind: "list", value: "briefs (#{bl.size})", children: bl.map { |b|
            bid  = (b[:id] || b["id"]).to_s
            biri = (b[:iri] || b["iri"]).to_s
            bdet = (b[:detail] || b["detail"]).to_s
            { kind: "entity_token", value: bid, entity_iri: (biri.empty? ? "urn:mm:brief:#{bid}" : biri), semantic_role: "brief",
              children: (s.(bdet) ? detail_lines(bdet, detail_cap, detail_width) : []) } } }
        end
        c << { kind: "text", value: "slot: #{slot}" + (s.(slot_detail) ? " (#{slot_detail})" : "") } if s.(slot)
        mc = ::Kernel.Array(mcbmap).map(&:to_s).reject(&:empty?)
        c << { kind: "list", value: "mcbmap (scope)", children: mc.map { |m| { kind: "text", value: m } } } unless mc.empty?
        c << { kind: "text", value: "completed: #{completed}" + (s.(loss) ? " (loss #{loss})" : "") } if s.(completed)
        fl = ::Kernel.Array(files).map { |f| f.is_a?(::Hash) ? f : { path: f.to_s } }
                    .reject { |f| (f[:path] || f["path"]).to_s.empty? }
        unless fl.empty?
          c << { kind: "list", value: "files changed (#{fl.size})",
                 children: fl.map { |f|
                   fp  = (f[:path] || f["path"]).to_s
                   tm  = (f[:top_matter] || f["top_matter"]).to_s
                   cls = ::Kernel.Array(f[:classes] || f["classes"]).map { |cl|
                     { kind: "entity_token", value: cl.to_s, entity_iri: "urn:mm:class:#{cl}", semantic_role: "class", hint: fp } }
                   { kind: "entity_token", value: fp, entity_iri: "urn:mm:file:#{fp}", semantic_role: "file",
                     children: ((s.(tm) ? detail_lines(tm, detail_cap, detail_width) : []) + cls) } } }
        end
        dl = ::Kernel.Array(diffs).map { |d| d.is_a?(::Hash) ? d : { path: d.to_s } }
                    .reject { |d| (d[:path] || d["path"]).to_s.empty? }
        c << { kind: "list", value: "diffs", children: dl.map { |d| diff_node(d, diff_line_cap) } } unless dl.empty?
        gr = ::Kernel.Array(git_repos).map { |r| r.is_a?(::Hash) ? r : {} }.reject { |r| (r[:name] || r["name"]).to_s.empty? }
        gtot = git_repos_total.to_i
        if gtot.positive? && gr.empty?
          c << { kind: "text", value: "git: all #{gtot} repo#{gtot == 1 ? "" : "s"} clean -- nothing blocks the merge" }
        elsif !gr.empty?
          c << { kind: "list", value: "git state (#{gr.size}#{gtot.positive? ? " of #{gtot}" : ""} need attention)",
                 children: gr.map { |r|
                   nm  = (r[:name] || r["name"]).to_s
                   stt = (r[:status] || r["status"]).to_s
                   iri = (r[:iri] || r["iri"]).to_s
                   ab  = "ahead #{(r[:ahead] || r["ahead"]).to_i}/behind #{(r[:behind] || r["behind"]).to_i}"
                   { kind: "entity_token", value: "#{nm} -- #{stt} (#{ab})",
                     entity_iri: (iri.empty? ? "urn:mm:repo:#{nm}" : iri), semantic_role: "repo" } } }
        end
        if s.(pr_title) || s.(pr_body)
          c << { kind: "list", value: "proposed PR" + (s.(pr_title) ? ": #{pr_title}" : ""),
                 children: (s.(pr_body) ? detail_lines(pr_body, detail_cap, detail_width) : []) }
        end
        actions = ::Kernel.Array(options).map do |o|
          if o.is_a?(::Hash)
            lbl  = (o[:label]  || o["label"]).to_s
            act  = (o[:action] || o["action"]).to_s
            node = { kind: "action", value: lbl }
            unless act.empty?
              node[:entity_iri]    = "urn:mm:action:#{act}"
              node[:semantic_role] = "mcb_action"
            end
            node
          else
            { kind: "action", value: o.to_s }
          end
        end
        actions << { kind: "action", value: "enter friction" } unless actions.any? { |a| a[:value].to_s == "enter friction" }
        c << { kind: "list", value: "your call", children: actions }
        headline = "ARC #{arc} -- just completed" + (s.(epic) ? "  (serves #{epic})" : "")
        { kind: "pane", value: headline, children: c }
      end

      # One diff file cell for from_acia: value=path (drillable EntityToken), children =
      # the patch lines (capped at `cap`, with a trailing "... (N more)" beyond it).
      def diff_node(d, cap)
        d     = d.is_a?(::Hash) ? d : { path: d.to_s }
        path  = (d[:path]  || d["path"]).to_s
        patch = (d[:patch] || d["patch"] || d[:content] || d["content"]).to_s
        lines = patch.split("\n")
        shown = lines.first(cap).map { |ln| { kind: "text", value: ln } }
        if lines.size > cap
          shown << { kind: "text", value: "... (#{lines.size - cap} more line#{lines.size - cap == 1 ? "" : "s"})" }
        end
        { kind: "entity_token", value: path, entity_iri: "urn:mm:file:#{path}", semantic_role: "diff", children: shown }
      end

      # Turn a block of prose into capped, soft-wrapped `text` child nodes -- the
      # drill-down detail under a lineage EntityToken. Honours newlines, wraps long
      # lines to `width`, caps at `cap` lines with a trailing count.
      def detail_lines(text, cap = 8, width = 96)
        raw = text.to_s.split("\n").flat_map { |para| soft_wrap(para, width) }
        shown = raw.first(cap).map { |ln| { kind: "text", value: ln } }
        shown << { kind: "text", value: "… (#{raw.size - cap} more line#{raw.size - cap == 1 ? "" : "s"})" } if raw.size > cap
        shown
      end

      # Greedy word-wrap a single line to `width` columns; returns >= 1 line.
      def soft_wrap(line, width = 96)
        return [""] if line.to_s.strip.empty?
        out = []
        cur = ""
        line.to_s.split(/\s+/).each do |w|
          if !cur.empty? && (cur.length + 1 + w.length) > width
            out << cur
            cur = w
          else
            cur = cur.empty? ? w : "#{cur} #{w}"
          end
        end
        out << cur unless cur.empty?
        out
      end

      # Bridge the LIVE grounded graph to the ACIA tree: turn Vv::Graph::Sparql select
      # rows (RDF-term-encoded { "var" => "value" } hashes) into a node tree -- each row
      # an entity_token bound to its IRI. iri_key selects the binding; label_keys build
      # the display.
      def from_rows(rows, title: "results", iri_key: nil, label_keys: [], role: nil)
        kids = ::Kernel.Array(rows).map do |r|
          r     = r.is_a?(::Hash) ? r : {}
          iri   = iri_key ? unquote(row_get(r, iri_key)) : ""
          label = ::Kernel.Array(label_keys).map { |k| unquote(row_get(r, k)) }.reject(&:empty?).join("  ")
          val   = label.empty? ? (iri.empty? ? r.inspect : iri) : label
          { kind: "entity_token", value: val, entity_iri: iri, semantic_role: role.to_s }
        end
        { kind: "pane", value: title.to_s, children: kids }
      end

      # Read a binding from a SPARQL row hash whether the keys are strings or symbols.
      def row_get(row, key)
        (row[key] || row[key.to_s] || row[key.to_sym]).to_s
      end

      # Strip RDF-term encoding from a SPARQL binding value:
      #   <iri> -> iri ; "lit"^^<type> -> lit ; "lit"@lang -> lit ; plain -> plain
      def unquote(term)
        s = term.to_s.strip
        return s[1..-2] if s.length >= 2 && s.start_with?("<") && s.end_with?(">")
        m = s.match(/\A"(.*)"(?:\^\^.*|@.*)?\z/m)
        m ? m[1] : s
      end
    end
  end
end
