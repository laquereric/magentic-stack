# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "open3"
require "net/http"
require "json"
require "uri"
require "base64"
require "tmpdir"
require "fileutils"
require "securerandom"

require "vv/browser/version"
require "vv/browser/session_handle"
require "vv/browser/bidi/session"
require "vv/browser/engines"
require "vv/browser/engine" if defined?(::Rails::Engine)

# Additive pure-Ruby BiDi core (vv-browser_bidi_core_design) — mock-first transport
require "vv/browser/outcome"
require "vv/browser/protocol/command_envelope"
require "vv/browser/protocol/response_envelope"
require "vv/browser/protocol/event_envelope"
require "vv/browser/transport/web_socket"
require "vv/browser/bidi_session"
require "vv/browser/capability_matrix"
require "vv/browser/engine_adapter/mock"
require "vv/browser/engine_adapter/firefox"
require "vv/browser/engine_adapter/chromium"
require "vv/browser/sal_event_bridge"
require "vv/browser/graph_grounding"
require "vv/browser/agent_driver"
require "vv/browser/mcb_actions"
require "vv/browser/procedures"
require "vv/browser/probe"
require "vv/browser/cpcp"

module Vv
  # Browser -- drive a browser over WebDriver BiDi and surface what it sees.
  # Engine-agnostic: :firefox (geckodriver) and :chrome (chromedriver) are
  # interchangeable adapters behind one BiDi command surface.
  #
  # Chrome is NOT a Firefox launch-flag substitution:
  #   Chrome  = HTTP POST /session (webSocketUrl:true) → attach BiDi (NO session.new)
  #   Firefox = HTTP POST /session (webSocketUrl:true) → attach BiDi (same shared layer)
  #
  # Additive BiDi core: Transport::WebSocket + BiDiSession + domain modules +
  # AgentDriver.drive + MCB actions (mock transport for specs).
  #
  # Never-raise envelopes throughout. Pure Ruby (TCPSocket + websocket-driver); NO selenium.
  module Browser
    module_function

    # WebDriver BiDi driver binaries we know how to launch -> the browser they drive.
    DRIVERS = { "geckodriver" => :firefox, "chromedriver" => :chrome }.freeze

    # PERSISTENT automation profile. A fresh headless profile has NO login/cookies.
    DEFAULT_PROFILE = ::File.join(::Dir.home, ".mm", "browser-profile")

    # Find an installed BiDi driver -> [path, browser] or nil.
    def find_driver
      DRIVERS.each do |bin, browser|
        path = which(bin)
        return [path, browser] if path
      end
      nil
    end

    # Resolve an engine adapter (:auto | :firefox | :chrome).
    def resolve_engine(engine = :auto)
      Engines.resolve(engine)
    end

    # Inspect a URL over BiDi: launch the driver, open a BiDi session, navigate,
    # capture a screenshot, and read the title + console entries.
    # binary: optional browser binary (e.g. Chrome Beta path) passed to engine bootstrap.
    def inspect_url(url, screenshot_path: nil, engine: :auto, headless: true, profile: nil, binary: nil)
      Procedures.probe(
        url,
        screenshot_path: screenshot_path,
        engine: engine,
        headless: headless,
        profile: profile,
        binary: binary,
        wait_s: 0.4
      )
    end

    # Navigate to `url`, run one JS expression, return its value.
    # engine: :auto | :firefox | :chrome
    def evaluate(url, js, headless: true, profile: DEFAULT_PROFILE, wait_s: 0, screenshot_path: nil, engine: :auto, binary: nil)
      # Chrome ephemeral profile when DEFAULT_PROFILE and engine is chrome — avoid
      # contending with a Firefox profile dir. Callers can still pass an explicit path.
      prof = profile
      with_session(engine: engine, headless: headless, profile: prof, binary: binary) do |handle, session|
        ctx = session.browsing_context_create.dig(:result, "context")
        session.browsing_context_navigate(ctx, url)
        (sleep [wait_s.to_i, 60].min) if wait_s.to_i.positive?
        val  = session.script_evaluate(ctx, js).dig(:result, "result", "value")
        path = save_screenshot(session.capture_screenshot(ctx), screenshot_path)
        {
          ok: true, url: url.to_s, value: val, screenshot_path: path,
          browser: handle.engine, engine: handle.engine,
          session_new_sent: session.session_new_sent?,
          bootstrap: handle.bootstrap
        }
      end
    end

    # epic_98 — ARM a rendered SAL WEB surface (HTML already produced by mmg-web).
    def arm_sal_surface(path: nil, title: nil, html: nil, spawn: false, screenshot_path: nil, engine: :auto)
      p = path.to_s
      if p.empty? && html.to_s != ""
        dir = ::File.join(::Dir.home, ".mm", "sal-renders", "_armed")
        ::FileUtils.mkdir_p(dir)
        p = ::File.join(dir, "surface-#{::Process.pid}-#{::Time.now.to_i}.html")
        ::File.write(p, html)
      end
      if p.empty? || !::File.file?(p)
        return { ok: false, armed: false, reason: :no_surface_file,
                 because: "arm_sal_surface needs path= to an HTML file or html= body" }
      end

      url = "file://#{p}"
      out = {
        ok: true, armed: true, path: p, url: url, title: title.to_s,
        spawn: false, surface: "sal_web"
      }

      do_spawn = spawn == true || spawn.to_s == "1" ||
                 ::ENV["MM_BROWSER_ARM"].to_s == "1" ||
                 ::ENV["MM_BROWSER_ARM"].to_s.downcase == "true"
      return out unless do_spawn

      insp = inspect_url(url, screenshot_path: screenshot_path, engine: engine)
      out.merge(spawn: true, inspect: insp, ok: !!(insp.is_a?(::Hash) && insp[:ok] != false))
    rescue => e
      { ok: false, armed: false, reason: :arm_sal_surface_failed, because: "#{e.class}: #{e.message}" }
    end

    # Open a live BiDi session. Caller MUST #close the returned Probe (or use
    # with_session). Cucumber holds this across steps; RSpec uses with_session.
    def start_session(engine: :auto, headless: true, profile: nil, binary: nil)
      resolved = Engines.resolve(engine)
      return resolved unless resolved[:ok]

      eng = resolved[:engine]
      prof = profile
      if eng.name == :chrome && (prof.nil? || prof.to_s == DEFAULT_PROFILE)
        prof = nil
      end

      boot = eng.bootstrap(headless: headless, profile: prof, binary: binary)
      return boot unless boot[:ok]
      handle = boot[:handle]

      session = ::Vv::Browser::Bidi::Session.new
      conn = session.attach_to_webdriver_session(handle.bidi_url)
      unless conn[:ok]
        eng.shutdown(handle, bidi_session: session)
        return conn
      end

      if handle.engine == :chrome && session.session_new_sent?
        eng.shutdown(handle, bidi_session: session)
        return { ok: false, reason: :session_new_forbidden,
                 because: "Chrome attach path must not emit session.new" }
      end

      probe = Probe.new(engine: eng, handle: handle, session: session)
      { ok: true, probe: probe, handle: handle, session: session, engine: handle.engine }
    rescue => e
      { ok: false, reason: :session_failed, because: "#{e.class}: #{e.message}" }
    end

    # Shared session lifecycle: resolve engine → bootstrap → attach BiDi → yield → shutdown.
    # Never sends session.new for HTTP-bootstrapped engines (Firefox HTTP + Chrome).
    def with_session(engine: :auto, headless: true, profile: nil, binary: nil)
      started = start_session(engine: engine, headless: headless, profile: profile, binary: binary)
      return started unless started[:ok]

      begin
        yield started[:handle], started[:session]
      ensure
        started[:probe].close
      end
    end

    def which(bin)
      path = (`command -v #{bin} 2>/dev/null`.strip rescue "")
      path.empty? ? nil : path
    end

    # --- backwards-compatible helpers (delegate to engines) -------------------

    def launch_driver(driver_path, browser = nil)
      eng_name = browser || DRIVERS[::File.basename(driver_path.to_s)] || :firefox
      eng = Engines.for(eng_name)
      return { ok: false, reason: :unknown_engine, because: eng_name.to_s } unless eng
      eng.launch_driver
    end

    def webdriver_bidi_session(port, browser, headless: true, profile: nil)
      eng = Engines.for(browser) || Engines::Firefox.new
      caps = eng.build_capabilities(headless: headless, profile: profile)
      # strip internal keys if chrome adapter stuffed them
      if caps.is_a?(::Hash)
        caps = caps.dup
        caps.delete(:_ephemeral_profile)
        caps.delete(:_profile_dir)
      end
      eng.post_session(port, caps)
    end

    def free_port
      Engines::Firefox.new.free_port
    end

    def save_screenshot(shot, path)
      return nil unless shot.is_a?(::Hash) && shot[:ok]
      data = shot.dig(:result, "data")
      return nil unless data
      path ||= ::File.join(::Dir.tmpdir, "vv-browser-#{::Process.pid}.png")
      ::File.binwrite(path, ::Base64.decode64(data))
      path
    rescue
      nil
    end

    # --- BiDi core affordances (additive; mock transport default) -------------

    def mcb_actions = McbActions.mcb_actions

    def driver_registry
      @driver_registry ||= {}
    end

    def last_driver
      @last_driver
    end

    def last_driver=(drv)
      @last_driver = drv
    end

    # Open a BiDi session via engine adapter + optional navigate.
    # engine: :mock | :firefox | :chrome | :chromium
    # transport: optional Transport::WebSocket (inject mock in specs)
    def open_bidi(url: nil, engine: :mock, intention: nil, transport: nil, descriptor: nil)
      Outcome.capture(reason: :open_failed) do
        eng_name = engine.to_sym
        eng_name = :chromium if eng_name == :chrome
        adapter = case eng_name
                  when :firefox then EngineAdapter::Firefox.new
                  when :chromium then EngineAdapter::Chromium.new
                  else EngineAdapter::Mock.new
                  end
        boot = if descriptor
                 Outcome.ok(endpoint: descriptor)
               else
                 adapter.bootstrap
               end
        return boot unless boot[:ok]

        endpoint = boot[:endpoint] || (boot[:handle] && {
          engine: eng_name,
          ws_url: boot[:handle].bidi_url,
          bootstrap: :attached,
          session_id: boot[:handle].session_id
        })
        session = BiDiSession.new(transport: transport || Transport::WebSocket.new)
        opened = session.open(descriptor: endpoint)
        return opened unless opened[:ok]

        driver = AgentDriver.new(session: session, intention: intention, engine: eng_name)
        key = "sess_#{SecureRandom.hex(4)}"
        driver_registry[key] = driver
        self.last_driver = driver
        if url
          nav = driver.navigate(url)
          return nav unless nav[:ok]
        end
        Outcome.ok(session_key: key, driver: driver, endpoint: endpoint, engine: eng_name)
      end
    end

    # Agent drive DSL — yields AgentDriver; never-raise outer outcome.
    def drive(url: nil, engine: :mock, intention: nil, transport: nil)
      Outcome.capture(reason: :drive_failed) do
        opened = open_bidi(url: url, engine: engine, intention: intention, transport: transport)
        return opened unless opened[:ok]

        driver = opened[:driver]
        result = nil
        begin
          result = yield driver if block_given?
        ensure
          driver.close
          driver_registry.delete(opened[:session_key])
          self.last_driver = nil if last_driver.equal?(driver)
        end
        Outcome.ok(session_key: opened[:session_key], result: result, engine: opened[:engine])
      end
    end

    # MVP proof runner (epic_115). Guarded when chrome/chromedriver absent.
    def prove_chrome_vertical!(url: nil, js: "document.title", screenshot_path: nil, binary: nil)
      eng = Engines.for(:chrome)
      unless eng.available?
        return { ok: false, reason: :no_driver, skipped: true,
                 because: "chromedriver not in PATH — install chromedriver + Chrome for live proof" }
      end

      html = <<~HTML
        <!doctype html><html><head><title>vv-browser-chrome-proof</title></head>
        <body><h1 id="h">ok</h1><script>window.__MMG=42</script></body></html>
      HTML
      dir = ::Dir.mktmpdir("vv-browser-proof-")
      path = ::File.join(dir, "proof.html")
      ::File.write(path, html)
      target = url || "file://#{path}"
      shot = screenshot_path || ::File.join(dir, "shot.png")

      res = evaluate(target, js, engine: :chrome, headless: true, profile: nil,
                     screenshot_path: shot, wait_s: 0, binary: binary)
      res.merge(
        proof: :chrome_vertical,
        session_new_sent: res[:session_new_sent],
        expected_no_session_new: true,
        fixture: target
      )
    ensure
      # leave dir if screenshot wanted; temp cleaned by OS eventually
    end
  end
end
