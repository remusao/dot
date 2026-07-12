// Firefox user.js — managed in ~/.dot, symlinked into the active profile by install.sh.
// Verified against Firefox 152.0.5 defaults (searchfox StaticPrefList.yaml/all.js) + arkenfox/Betterfox.
// Edit THIS FILE, not about:config — values re-assert on every restart. Only non-defaults are set.

// ── user.js is the source of truth; propagate to other devices via dotfiles, not Sync.
//    (Sync only carries ~30 allowlisted prefs anyway.) Delete this line only if a device
//    can't run ~/.dot and you want Sync to carry that subset. Bookmarks/tabs/history/add-ons still sync. ──
user_pref("services.sync.engine.prefs", false);

// ── Tracking protection. Complementary to uBlock Origin, NOT redundant: uBO does network/list
//    blocking; ETP Strict adds engine-level Total Cookie Protection (storage partitioning) +
//    Fingerprinting Protection (FPP randomization) + bounce-tracking — none of which a blocklist can do.
//    Load-bearing: this one line also enables FPP, query-stripping, bounce, and the referrer defaults below. ──
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.globalprivacycontrol.enabled", true);              // legally-enforceable opt-out signal
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);           // cross-origin referrer: scheme+host+port only
user_pref("dom.private-attribution.submission.enabled", false);       // no PPA ad measurement (default ON since FF128)
user_pref("browser.uitour.enabled", false);                           // reduce attack surface

// ── HTTPS / TLS / WebRTC (in user.js, NOT policy → per-site exceptions still work for localhost dev) ──
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_send_http_background_request", false);
user_pref("security.tls.enable_0rtt_data", false);                    // off TLS1.3 0-RTT early data (default on): drops replay risk + weak forward-secrecy on resumed conns; cost = ~1 extra RTT on resumption, no breakage
user_pref("media.peerconnection.ice.default_address_only", true);     // WebRTC single interface (video-call-safe)
user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);    // stop sending each downloaded executable's URL/name/SHA256/referrer to Google for reputation. URL malware/phishing + local download lists stay ON. Reputation DB is Win/Mac-centric → little protection lost on Linux. (Leave at default true if you often run untrusted binaries.)
user_pref("browser.download.manager.addToRecentDocs", false);
user_pref("permissions.default.desktop-notification", 2);             // block notification prompts (allow per-site)

// ── DNS: keep the system resolver. ALL Firefox DNS already flows through Tailscale (accept-dns + `~.`),
//    independent of exit-node/traffic routing, so Firefox DoH would bypass the ~110 Brave split-DNS routes
//    and break internal hosts. Mode 5 = same DNS path as default but ALSO locks out Mozilla's DoH rollout
//    (so it can never silently flip DoH on). Want encrypted DNS when the tailnet is down? Do it at
//    systemd-resolved/router level, not here. ──
user_pref("network.trr.mode", 5);
// browser.ipProtection.enabled — left at DEFAULT (currently inactive/unauthenticated), NOT forced off:
//    not all traffic uses a Tailscale exit node, so you may want it to mask your IP on direct traffic.
//    If you enable it, verify *.ts.net / internal Brave hosts still resolve (its Fastly proxy resolves DNS server-side).

// ── Telemetry (policies.json DisableTelemetry locks the 4 upload prefs; these cover the rest) ──
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("toolkit.telemetry.user_characteristics_ping.opt-out", true);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);                             // also stops all Nimbus/rollout enrollment
user_pref("app.normandy.api_url", "");
user_pref("browser.discovery.enabled", false);

// ── Background pings / crash / region (laptop KEEPS captive-portal detection for hotel/café WiFi) ──
user_pref("network.connectivity-service.enabled", false);
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.crashReports.unsubmittedCheck.enabled", false);
user_pref("breakpad.reportURL", "");
user_pref("browser.region.update.enabled", false);

// ── Speculative loading = PERF posture (MAX SNAPPINESS). Your prefs.js currently holds the old privacy
//    values (0/false/true), so we EXPLICITLY restore the defaults here — deleting these lines would leave
//    the stale slow values in prefs.js. Cost: Firefox opens speculative DNS/TCP to links you hover/type. ──
user_pref("network.http.speculative-parallel-limit", 20);            // default: preconnect on hover / urlbar / rel=preconnect
user_pref("network.prefetch-next", true);                            // default: honor <link rel="prefetch">
user_pref("network.dns.disablePrefetch", false);                     // default: DNS prefetch on
// network.predictor.enabled + browser.places/urlbar.speculativeConnect.enabled are already default-ON.
// Even more aggressive (optional): user_pref("network.predictor.enable-prefetch", true); // predictor prefetches, not just preconnects

// ── Sync scope + autofill: Proton Pass is the single source of truth (built-in mgr off via policy) ──
user_pref("services.sync.engine.creditcards", false);
user_pref("services.sync.engine.addresses", false);
user_pref("services.sync.engine.passwords", false);
user_pref("dom.forms.autocomplete.formautofill", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("extensions.formautofill.addresses.enabled", false);

// ── Search / URL bar: KEEP search-engine + history + open-tab + bookmark suggestions (all default-ON,
//    left untouched). Suggestions stream keystrokes to your DEFAULT engine → set that to Brave Search
//    (Settings → Search; add via search.brave.com). NOTE: default engine lives in the profile, not a pref,
//    and the SearchEngines policy is ESR-only, so that default is a one-time manual step (see README). ──
user_pref("browser.urlbar.suggest.engines", false);                  // no "search with <other engine>" offers
user_pref("browser.urlbar.suggest.trending", false);                 // no trending-topic suggestions
user_pref("browser.urlbar.suggest.recentsearches", false);           // (flip to true to see recent searches)
user_pref("browser.urlbar.suggest.topsites", false);                 // (flip to true for top-site shortcuts on empty focus)
user_pref("browser.urlbar.showSearchTerms.enabled", false);          // keep the real URL visible after a search, not the terms
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);       // rank your history/tabs above engine suggestions
user_pref("browser.newtabpage.activity-stream.showWeather", false);  // (Search/TopSites/Sponsored/Stories → policy)
// Firefox-Suggest sponsored/nonsponsored are default-OFF already — left as default.

// ── AI/ML off (you use brave.ai; normandy-off also prevents re-enrollment) ──
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("sidebar.main.tools", "syncedtabs,history,bookmarks");

// ── Startup / windows / density (i3: tabs-in-titlebar default is fine; add i3 `border pixel 1`) ──
user_pref("browser.startup.page", 3);                                 // restore session
user_pref("browser.startup.homepage", "https://brave.ai");
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.uidensity", 0);                                    // normal density = taller tabs (you preferred this over compact=1)
user_pref("browser.compactmode.show", true);                          // keep the Compact option available in Customize if you want it later

// ── Tabs / find / X11 mouse ──
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
user_pref("findbar.highlightAll", true);
user_pref("middlemouse.paste", false);                                // no accidental primary-selection paste into pages
user_pref("general.autoScroll", true);                                // middle-click autoscroll instead

// ── Downloads / media ──
user_pref("browser.download.always_ask_before_handling_new_types", true);
user_pref("browser.download.open_pdf_attachments_inline", true);
user_pref("media.eme.enabled", true);                                 // DRM for streaming
user_pref("media.webrtc.camera.allow-pipewire", true);

// ── NVMe write reduction (balanced) + throughput (trade a little RAM/CPU; you have 125 GiB / 32T) ──
user_pref("browser.sessionstore.interval", 60000);                    // 15s→60s: ~75% fewer sessionstore writes
user_pref("browser.cache.jsbc_compression_level", 3);                 // compress JS bytecode cache → fewer NVMe writes
user_pref("gfx.content.skia-font-cache-size", 20);                    // 5→20 MB (Chrome parity)
user_pref("gfx.canvas.accelerated.cache-size", 512);                  // 256→512 MB GPU canvas cache
user_pref("image.mem.decode_bytes_at_a_time", 32768);                 // 16→32 KB decode chunks

// ── Containers / sidebar / devtools (reproduce your existing choices) ──
user_pref("privacy.userContext.enabled", true);
user_pref("privacy.userContext.ui.enabled", true);
user_pref("sidebar.revamp", true);
user_pref("sidebar.visibility", "hide-sidebar");
user_pref("devtools.toolbox.host", "right");
user_pref("devtools.netmonitor.persistlog", true);
user_pref("devtools.webconsole.persistlog", true);
user_pref("devtools.cache.disabled", true);
