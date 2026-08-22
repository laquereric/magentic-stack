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
require "rails-osi-level-8"

P9  = RailsOsiLevel8::Profile9
OUT = "#{GEM}/docs/board/page"
FileUtils.mkdir_p(OUT)

FileUtils.cp("#{VV}/dist/vv-html-components.js", "#{OUT}/vv-html-components.js")
FileUtils.cp("#{STACK}/interfaces/rails-osi-level-8/data/osi-level-8/ux-host-layout.js",
             "#{OUT}/ux-host-layout.js")

TOKENS = { "tokens" => { "setRef" => "tokens:ghis@1" } }

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

  File.write("#{OUT}/#{slug}.html", <<~DOC)
    <!doctype html><meta charset=utf-8><title>#{title}</title>
    <meta name=viewport content="width=device-width,initial-scale=1">
    <style>
      body{margin:0;padding:1.5rem 2rem;background:#f4f6f8;
           font:15px/1.55 ui-sans-serif,system-ui,-apple-system,sans-serif;color:#17212b}
      .sbhdr{font:600 11px ui-monospace,Menlo,monospace;color:#6a7885;letter-spacing:.05em;
             text-transform:uppercase;border-bottom:1px solid #ccd5dd;padding-bottom:.5rem;margin-bottom:1rem}
      .note{color:#465462;max-width:60rem;margin:0 0 1.25rem;font-size:13px}
    </style>
    <script type="application/ld+json" data-ux-acia-document>#{json}</script>
    <div class=sbhdr>#{slug} &middot; #{digest[0, 24]}…</div>
    <p class=note>#{note}</p>
    #{html}
    <script src="vv-html-components.js" defer></script>
    <script src="ux-host-layout.js" defer></script>
    <!-- The Layout Projection is HOST-OWNED and does not self-run: it exposes
         apply/decide/recipes and the host page invokes it. That is the contract --
         the library styles components, the host decides layout. -->
    <script defer>
      addEventListener("DOMContentLoaded", function () {
        if (window.UxHostLayout) window.UxHostLayout.apply();
      });
    </script>
  DOC
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
