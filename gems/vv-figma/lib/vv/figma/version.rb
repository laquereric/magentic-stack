# frozen_string_literal: true

module Vv
  module Figma
    VERSION = "0.1.0"

    # Plugin sandbox API. Figma injects `figma` into the plugin main
    # thread. Do not vendor a Figma runtime; the host serves it.
    PLUGIN_API = "1.0.0"

    DEFAULT_API_URL = "https://api.figma.com"
    AUTHORIZE_URL = "https://www.figma.com/oauth"
    TOKEN_PATH = "/v1/oauth/token"
    REFRESH_PATH = "/v1/oauth/refresh"
    EMBED_BASE = "https://www.figma.com/embed"
    FILE_URL_BASE = "https://www.figma.com/file"
  end
end
