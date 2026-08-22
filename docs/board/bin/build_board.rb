# frozen_string_literal: true
#
# Render the StewardshipTranslation Board through the whole stack:
#   ACIA document -> Profile9::Renderer -> embedded JSON-LD package
#                 -> vv-html-components  (component visuals, light DOM)
#                 -> ux-host-layout.js   (host Layout Projection, R3)
#
# Run from the rails-osi-level-8 gem so its bundle is active.
require "json"
require "fileutils"

STACK = "/Users/ericlaquer/NoIcloud/magentic-stack"
GEM   = "/Users/ericlaquer/NoIcloud/magentic-market-ai/gems/app-oriented-translation"
VV    = "/Users/ericlaquer/NoIcloud/magentic-market-ai/gems/vv-html-components"
$LOAD_PATH.unshift("#{STACK}/interfaces/rails-osi-level-8/lib")
$LOAD_PATH.unshift("#{GEM}/lib")
require "rails-osi-level-8"
require "app-oriented-translation"

P9  = RailsOsiLevel8::Profile9
OUT = "#{GEM}/docs/board/page"
FileUtils.mkdir_p(OUT)

# The page shell is the engine's SHARED layout
# (app/views/layouts/app_oriented_translation/application.html.erb), never a
# heredoc here. PageRenderer.write also vendors the runtime beside the page, so
# a hydrating page can no longer ship without its assets.
RENDER = AppOrientedTranslation::PageRenderer
ASSETS = {
  "vv-html-components.js" => "#{VV}/dist/vv-html-components.js",
  "ux-host-layout.js" => "#{STACK}/interfaces/rails-osi-level-8/data/osi-level-8/ux-host-layout.js"
}.freeze

TOKENS = { "tokens" => { "setRef" => "tokens:ghis@1" } }

# The applied restyle, owned by the engine so a designer edits ONE file rather
# than a heredoc in a build script. Tokens are set as unlayered author CSS, so
# they beat the library's @layer vv-tokens defaults.
CSS = File.read("#{GEM}/app/assets/stylesheets/app_oriented_translation/board.css")

def emit(doc, slug, title, note)
  res = P9::Renderer.render(acia: doc, token_set: TOKENS, correlation: "cid:page:#{slug}")
  abort "render failed for #{slug}: #{res.inspect[0, 300]}" unless res.is_a?(Hash) && res["ok"]

  html = res["html"]
  correlation = html[/data-ux-correlation="([^"]*)"/, 1]
  digest = P9::Acia.validate(doc).digest

  # NORMALIZE root -> rootNode for the embedded package.
  # Acia.validate accepts EITHER spelling; vv-html-components accepts only
  # rootNode, which is also the spelling in the closed ALLOWED_PREDICATES. Every
  # gem fixture uses `root`, so the library had never been run against one. This
  # is a producer-side normalization, not a fix for the underlying divergence --
  # Profile 9 should settle on one spelling.
  packaged = doc.dup
  if packaged.key?("root") && !packaged.key?("rootNode")
    packaged["rootNode"] = packaged.delete("root")
  end

  pkg = { "@context" => { "@vocab" => P9::Vocabulary::VOCAB_IRI, "cid" => "@id", "type" => "@type" },
          "@type" => "ux:AciaDocumentPackage",
          "correlation" => correlation,
          "aciaDigest" => digest,
          "tokenSet" => "cid:tokenset:ghis@1",
          "document" => packaged }
  json = JSON.generate(pkg).gsub("<", "\\u003c")

  RENDER.write(
    path: "#{OUT}/#{slug}.html", assets_from: ASSETS,
    title: title, stylesheet: CSS, acia_json: json,
    header: "#{slug} &middot; #{digest[0, 24]}…", note: note, body: html
  )
  puts "  #{slug}: digest #{digest[0, 20]}… correlation #{correlation}"
end

emit(P9::Acia.translation_board_document, "board",
     "StewardshipTranslation Board",
     "Five columns from one ACIA document. Component visuals from vv-html-components; " \
     "the five-track grid from the host Layout Projection reading responsiveSignature " \
     "p9.r1.grid.board-5 out of the embedded JSON-LD. Below 48rem it becomes a stack.")

emit(P9::Acia.translation_board_inspect_document, "board-inspect",
     "StewardshipTranslation Board — inspect projection",
     "The successor returned by ux.inspect: a NEW attested ACIA with its own digest and " \
     "correlation, not an annotation of the page above. Cards carry a textual Explore trace, " \
     "never a colour.")
puts "assets vendored beside the pages"
