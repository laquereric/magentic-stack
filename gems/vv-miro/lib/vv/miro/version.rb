# frozen_string_literal: true

module Vv
  module Miro
    VERSION = "0.1.0"

    # Miro Web SDK 2.0 loader. Do not vendor this file; Miro serves it.
    SDK_SRC = "https://miro.com/app/static/sdk/v2/miro.js"

    DEFAULT_API_URL = "https://api.miro.com"
    AUTHORIZE_URL = "https://miro.com/oauth/authorize"
    LIVE_EMBED_BASE = "https://miro.com/app/live-embed"
  end
end
