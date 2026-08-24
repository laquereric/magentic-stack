# frozen_string_literal: true
#
# Build the StewardshipTranslation Workbench storyboards as Profile 9 JSON-LD.
#
# Source of truth is the Manus design doc's indented ACIA trees. This emits the
# full P9 chain as JSON-LD records -- Journey -hasFlow-> Flow -step.page-> Page
# -aciaDocument-> AciaDocument -rootNode-> node tree -- then renders HTML FROM
# the emitted JSON-LD. HTML is a render target, never a source.
#
# Run from the rails-osi-level-8 gem so its bundle is active:
#   cd interfaces/rails-osi-level-8 && bundle exec ruby <this file>

require "json"
require "digest"
require "fileutils"

# Paths are derived from __dir__, never absolute. This script lives in the
# magentic-stack monorepo and must resolve everything WITHIN it: an absolute
# path out to a sibling checkout is a cross-repo reference, and the deploy
# path cannot follow one onto a build box where that checkout does not exist.
ROOT  = File.expand_path("../../../../..", __dir__)   # magentic-stack root
GEM   = File.expand_path("../../..", __dir__)         # apps/app-oriented-translation
STACK = ROOT
VV    = "#{ROOT}/interfaces/vv-html-components"
$LOAD_PATH.unshift("#{STACK}/interfaces/rails-osi-level-8/lib")
require "rails_osi_level_8/profile9/vocabulary"
require "rails_osi_level_8/profile9/acia"
require "rails_osi_level_8/profile9/renderer"

$LOAD_PATH.unshift("#{GEM}/lib")
require "app-oriented-translation"

# One shell for every Profile 9 surface, owned by the engine.
RENDER = AppOrientedTranslation::PageRenderer
ASSETS = {
  "vv-html-components.js" =>
    "#{VV}/dist/vv-html-components.js",
  "ux-host-layout.js" =>
    "#{STACK}/interfaces/rails-osi-level-8/data/osi-level-8/ux-host-layout.js"
}.freeze

P9   = RailsOsiLevel8::Profile9
V    = P9::Vocabulary
ACIA = P9::Acia

SRC  = "#{GEM}/docs/manus/workbench_design.md"
OUT  = "#{GEM}/docs/storyboards"
JLD  = "#{OUT}/jsonld"

REGISTRY = "ghis-19@1"
TOKEN_SET_CID = "cid:tokenset:ghis@1"
ACTOR_CID = "cid:actor:stewardship-decision-maker"

JOURNEYS = {
  "A" => { slug: "orientation", label: "Orientation",
           goal: "Orient a decision maker in an unfamiliar standards-backed workspace",
           scenario: "A decision maker arrives, inspects the decisive term, and meets the action boundary" },
  "B" => { slug: "meaning-clarification", label: "Meaning Clarification",
           goal: "Make a disputed boundary decidable and establish accountable agreement",
           scenario: "Candidate boundary is attested, disputed, verified, and receipted" },
  "C" => { slug: "stewardship-translation", label: "Stewardship Translation",
           goal: "Express a held referent for a new audience without creating a second concept",
           scenario: "Source is held, a scoped target is composed, reviewed within limits, and issued" },
  "D" => { slug: "walls", label: "Walls",
           goal: "Refuse without dead-ending: keep a blocked task productive",
           scenario: "Testability, consistency, federation, and unrepresentability each refuse with a next step" }
}.freeze

# Full SLT tuple per component kind. Every value below is drawn from the closed
# P9 enums (SEMANTIC_ROLES / CONTENT_ROLES / LAYOUT_KINDS / BEHAVIOR_KINDS), so
# the meaning of a component is carried by the tuple, not by its HTML.
#   kind => [semanticRole, contentRole, layoutKind, behaviorKind, variantName]
SLT_MAP = {
  "PageShell"     => %w[landmark context   stack    static        default],
  "PanelFrame"    => %w[article  context   stack    static        default],
  "SemanticText"  => %w[article  context   stack    static        default],
  "StatusBadge"   => %w[status   observation inline static        default],
  "MetricStrip"   => %w[list     observation inline static        default],
  "ContextBanner" => %w[status   context   inline   static        default],
  "DrillDownCard" => %w[article  evidence  stack    inspect       default],
  "DataList"      => %w[list     evidence  stack    static        default],
  "Timeline"      => %w[timeline observation timeline static      default],
  "EvidencePanel" => %w[figure   evidence  stack    inspect       default],
  "DecisionForm"  => %w[form     action    stack    collect_effect default],
  "ActionControl" => %w[button   action    inline   confirm       default],
  "Disclosure"    => %w[article  help      stack    disclose      quiet],
  "FilterBar"     => %w[form     navigation inline  filter        default],
  "TabSet"        => %w[list     navigation inline  navigate      default],
  "EmptyState"    => %w[status   empty     stack    static        quiet],
  "RefusalNotice" => %w[alert    refusal   stack    acknowledge   warning],
  "ScopeTrail"    => %w[list     navigation inline  navigate      default]
}.freeze

def slt_for(kind)
  sem, content, layout, behavior, _ = SLT_MAP.fetch(kind)
  { "semanticRole" => sem, "contentRole" => content,
    "layoutKind" => layout, "layoutArity" => "one", "behaviorKind" => behavior,
    "responsiveSignature" => "default",
    "tokenSignature" => { "setRef" => "tokens:ghis@1" } }
end

def variant_for(kind) = SLT_MAP.fetch(kind).last

# layoutArity is a real claim about the node, so derive it from the children
# actually present rather than stamping every node "one".
def fix_arity!(node)
  n = node["children"].size
  node["slt"]["layoutArity"] = case n
                               when 0, 1 then "one"
                               when 2 then "two"
                               when 3 then "three"
                               else "many"
                               end
  node["children"].each { |c| fix_arity!(c) }
  node
end

def slugify(s, max = 48)
  t = s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
  t = t[0, max].sub(/-+\z/, "")
  t = "n-#{t}" unless t =~ /\A[a-z]/
  t.length < 3 ? "#{t}-node" : t
end

# ---- parse the Manus indented trees -------------------------------------
def parse_panels(path)
  lines = File.read(path).split("\n")
  panels = []
  lines.each_with_index do |ln, i|
    m = ln.match(/^#{'#'}{2,4}\s+([A-D]\d)\.\s+`?([^`\s]+)`?\s+—\s+(.+)$/)
    next unless m
    code, route, purpose = m[1], m[2], m[3].strip
    j = i + 1
    j += 1 while j < lines.size && !lines[j].include?("```")
    body = []
    k = j + 1
    while k < lines.size && !lines[k].include?("```")
      body << lines[k]; k += 1
    end
    panels << { code: code, route: route, purpose: purpose, body: body }
  end
  panels
end

# indented "Kind" / "payload: k=\"v\"; ..." -> node tree
def build_tree(body, code)
  stack = []
  root = nil
  seq = Hash.new(0)
  body.each do |raw|
    next if raw.strip.empty?
    indent = raw[/\A */].size
    text = raw.strip
    if text.start_with?("payload:")
      node = stack.last&.last
      next unless node
      payload = {}
      text.sub(/\Apayload:\s*/, "").split(/;\s*/).each do |pair|
        if (pm = pair.match(/\A([A-Za-z0-9_-]+)\s*=\s*"(.*)"\z/m))
          key, val = pm[1], pm[2]
          # failedCriteria and evidenceRefs are ARRAYS in the Profile 9 contract.
          # The single-line source carries them in a bracketed transport form,
          # "[a, b]", which must become a real array or the validator reports the
          # field missing.
          if %w[failedCriteria evidenceRefs].include?(key) && val.strip.start_with?("[")
            payload[key] = val.strip.delete_prefix("[").delete_suffix("]")
                              .split(",").map(&:strip).reject(&:empty?)
          else
            payload[key] = val
          end
        end
      end
      node["props"]["valueJson"] = payload
      next
    end
    kind = text
    next unless V.component_kind?(kind)
    seq[kind] += 1
    nid = slugify("#{code}-#{kind}-#{seq[kind]}")
    node = {
      "nodeId" => nid,
      "componentKind" => kind,
      "slt" => slt_for(kind),
      "props" => { "propsSchemaCid" => "cid:schema:#{kind.downcase}", "valueJson" => {} },
      "variant" => { "variantName" => variant_for(kind) },
      "slots" => [],
      "children" => []
    }
    if root.nil?
      root = node
      stack = [[indent, node]]
    else
      stack.pop while stack.size > 1 && stack.last[0] >= indent
      stack.last[1]["children"] << node
      stack << [indent, node]
    end
  end
  root
end

# ---- build records -------------------------------------------------------
panels = parse_panels(SRC)
# drop exact-prefix duplicates (Manus emitted D4 twice; second is a truncation)
seen = {}
panels.select! do |p|
  key = p[:code]
  if (prev = seen[key])
    keep = p[:body].size > prev[:body].size
    if keep then seen[key] = p; true else false end
  else
    seen[key] = p; true
  end
end

# Validate EVERY panel before destroying anything. This build previously wiped
# jsonld/ and html/ up front, so a contract change that invalidated a panel
# destroyed a good set before discovering it could not rebuild one. Fail closed
# and leave the committed artifacts untouched.
precheck = []
panels.each do |p|
  t = build_tree(p[:body], p[:code].downcase)
  if t.nil?
    precheck << "#{p[:code]}: no root node parsed"
    next
  end
  fix_arity!(t)
  r = ACIA.validate({ "schemaVersion" => "acia/v1",
                      "componentRegistryVersion" => REGISTRY,
                      "rootNode" => t })
  precheck << "#{p[:code]}: #{r.reason} #{r.because.inspect}" unless r.conforms?
end
if precheck.any?
  warn "REFUSED: #{precheck.size}/#{panels.size} panels do not satisfy the current contract."
  warn "Nothing was written; existing artifacts are untouched."
  precheck.each { |e| warn "  ! #{e}" }
  exit(1)
end

FileUtils.rm_rf(JLD); FileUtils.mkdir_p(["#{JLD}/journeys", "#{JLD}/flows", "#{JLD}/pages", "#{JLD}/acia"])

actor = {
  "@context" => { "@vocab" => V::VOCAB_IRI, "cid" => "@id", "type" => "@type" },
  "cid" => ACTOR_CID, "@type" => "ux:Actor",
  "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical",
  "role" => "stewardship-decision-maker",
  "label" => "Decision maker responsible for a governed digital asset"
}
File.write("#{JLD}/actor.jsonld", JSON.pretty_generate(actor))

ctx = { "@vocab" => V::VOCAB_IRI, "cid" => "@id", "type" => "@type" }
pages, acia_docs, flows, journeys, catalog = [], [], [], [], []
errors = []

by_journey = panels.group_by { |p| p[:code][0] }

by_journey.each do |letter, plist|
  meta = JOURNEYS.fetch(letter)
  journey_cid = "cid:journey:#{meta[:slug]}"
  flow_cid    = "cid:flow:#{meta[:slug]}"
  steps, touchpoints, phases = [], [], []

  plist.each_with_index do |p, idx|
    tree = build_tree(p[:body], p[:code].downcase)
    fix_arity!(tree) if tree
    unless tree
      errors << "#{p[:code]}: no root node parsed"; next
    end
    doc = { "schemaVersion" => "acia/v1",
            "componentRegistryVersion" => REGISTRY,
            "rootNode" => tree }
    r = ACIA.validate(doc)
    unless r.conforms?
      errors << "#{p[:code]}: ACIA invalid #{r.reason} #{r.because.inspect}"; next
    end
    acia_cid = "cid:acia:#{r.digest.delete_prefix('sha256:')}"
    slug = "#{p[:code].downcase}-#{slugify(p[:route])}"
    page_cid = "cid:page:#{slug}"

    acia_rec = actor.dup.clear.merge(
      "@context" => ctx, "cid" => acia_cid, "@type" => "ux:AciaDocument",
      "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical",
      "document" => doc, "digest" => r.digest,
      "predecessorCid" => nil, "tokenSetCid" => TOKEN_SET_CID
    )
    page_rec = {
      "@context" => ctx, "cid" => page_cid, "@type" => "view:Page",
      "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical",
      "flow" => flow_cid, "journey" => journey_cid,
      "routeKey" => p[:route], "pagePurpose" => p[:purpose],
      "contextSelector" => "p11:#{meta[:slug]}",
      "aciaDocument" => acia_cid, "tokenSet" => TOKEN_SET_CID
    }
    File.write("#{JLD}/acia/#{slug}.jsonld",  JSON.pretty_generate(acia_rec))
    File.write("#{JLD}/pages/#{slug}.jsonld", JSON.pretty_generate(page_rec))
    acia_docs << acia_rec; pages << page_rec
    catalog << { "cid" => page_cid, "@type" => "view:Page" }
    catalog << { "cid" => acia_cid, "@type" => "ux:AciaDocument" }

    steps << { "ordinal" => idx + 1, "title" => p[:purpose], "page" => page_cid }
    touchpoints << { "cid" => "cid:touchpoint:#{slug}", "@type" => "c4:Touchpoint",
                     "channel" => "cid:channel:web", "page" => page_cid }
    phases << { "ordinal" => idx + 1, "name" => p[:route].split("/").last, "goal" => p[:purpose] }
  end

  flow = {
    "@context" => ctx, "cid" => flow_cid, "@type" => "ux:Flow",
    "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical",
    "journey" => journey_cid, "taskGoal" => meta[:goal], "status" => "active",
    "step" => steps, "touchpoint" => touchpoints
  }
  journey = {
    "@context" => ctx, "cid" => journey_cid, "@type" => "c4:Journey",
    "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical",
    "primaryActor" => ACTOR_CID, "goal" => meta[:goal], "scenario" => meta[:scenario],
    "channel" => "cid:channel:web", "status" => "active",
    "phase" => phases, "hasFlow" => [flow_cid], "touchpoint" => touchpoints
  }
  File.write("#{JLD}/flows/#{meta[:slug]}.jsonld",    JSON.pretty_generate(flow))
  File.write("#{JLD}/journeys/#{meta[:slug]}.jsonld", JSON.pretty_generate(journey))
  flows << flow; journeys << journey
  catalog << { "cid" => journey_cid, "@type" => "c4:Journey" }
  catalog << { "cid" => flow_cid, "@type" => "ux:Flow" }
end

File.write("#{JLD}/catalog.jsonld", JSON.pretty_generate(
  "@context" => ctx,
  "@graph" => [actor] + journeys + flows + pages + acia_docs
))

puts "journeys: #{journeys.size}  flows: #{flows.size}  pages: #{pages.size}  acia: #{acia_docs.size}"
puts "errors: #{errors.size}"
errors.each { |e| puts "  ! #{e}" }
exit(1) if errors.any?

# ---- render HTML FROM the emitted JSON-LD --------------------------------
# The renderer reads the AciaDocument records we just wrote, so the HTML is a
# projection of the JSON-LD rather than of the markdown. Nothing below invents
# content; a render failure here means the JSON-LD is wrong.
HTML = "#{OUT}/html"
FileUtils.rm_rf(HTML); FileUtils.mkdir_p(HTML)

CSS = <<~STYLE
  body{font:15px/1.55 ui-sans-serif,system-ui,-apple-system,sans-serif;margin:0;padding:1.5rem 2rem;background:#fbfbfc;color:#14171a;max-width:64rem}
  .sbhdr{font:600 12px ui-monospace,Menlo,monospace;color:#6b7280;letter-spacing:.04em;text-transform:uppercase;border-bottom:1px solid #e5e7eb;padding-bottom:.5rem;margin-bottom:1rem}
  [data-ux-node-cid]{margin:.35rem 0}
  [data-ux-label]{font-weight:600}
STYLE

tokens = { "tokens" => { "setRef" => "tokens:ghis@1" } }
index, rendered, failed = [], 0, 0

pages.each_with_index do |page, i|
  acia_rec = acia_docs.find { |a| a["cid"] == page["aciaDocument"] }
  res = P9::Renderer.render(
    acia: acia_rec["document"],
    token_set: tokens,
    correlation: page["cid"]
  )
  unless res.is_a?(Hash) && res["ok"]
    warn "render failed #{page['cid']}: #{res.inspect[0, 200]}"; failed += 1; next
  end
  slug  = page["cid"].sub("cid:page:", "")
  title = "#{page['routeKey']} — #{page['pagePurpose']}"
  fname = format("%02d-%s.html", i + 1, slug)

  # Page-embedded ACIA packaging (vv-html-components DESIGN.md s13 proposals 1+2).
  # ONE inert JSON-LD block carrying the COMPLETE ACIA document, so an enhancement
  # layer can hydrate the payload the deterministic renderer drops -- with no
  # runtime network request. Declares correlation + aciaDigest for equality
  # gating, and nodeId is the canonical identity (it is already on every element
  # as data-ux-node-id).
  #
  # Nothing here changes the renderer or its per-node markup.
  embed = {
    "@context"  => ctx,
    "@type"     => "ux:AciaDocumentPackage",
    # MUST be the correlation the RENDERER actually emitted, not the page cid.
    # The renderer generates its own data-ux-correlation; writing the page cid
    # here made the two disagree, so a consumer's equality gate correctly refused
    # to hydrate even though aciaDigest matched. Found by vv-html-components V5.
    "correlation" => (res["html"][/data-ux-correlation="([^"]*)"/, 1] || page["cid"]),
    "pageCid" => page["cid"],
    "aciaDocument" => page["aciaDocument"],
    "aciaDigest"   => acia_rec["digest"],
    "tokenSet"     => page["tokenSet"],
    "document"     => acia_rec["document"]
  }
  # "<" must be escaped or a payload string containing </script> would break out
  # of the block. JSON parsers decode \u003c transparently.
  embed_json = JSON.generate(embed).gsub("<", "\\u003c")

  # Renders through the engine's SHARED layout. Before this, the storyboards
  # carried their own shell and had drifted off the board's: no viewport meta
  # and NO component runtime at all, so every page here was unhydrated light
  # DOM. Sharing the layout is what fixes that.
  RENDER.write(
    path: "#{HTML}/#{fname}", assets_from: ASSETS,
    title: title, stylesheet: CSS, acia_json: embed_json,
    header: "#{page['cid']} &middot; #{page['aciaDocument']}", body: res["html"]
  )
  index << [fname, title, page["cid"], page["aciaDocument"], page["flow"], page["journey"]]
  rendered += 1
end

File.write("#{OUT}/html/index.json", JSON.pretty_generate(index))
puts "rendered from JSON-LD: #{rendered}  failed: #{failed}"
exit(1) if failed.positive?
