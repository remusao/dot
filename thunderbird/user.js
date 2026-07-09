// Thunderbird user.js — managed in ~/.dot, symlinked into the active profile by install.sh.
// Global prefs only; account-specific prefs (mail.server.serverN.*) stay in prefs.js.
// Verified against Thunderbird 140.12.1esr defaults (omni.ja) + comm-central source.

// Folder-DB caching — highest impact with 60+ folders (defaults 300000ms / 30 → churn every 60s)
user_pref("mail.db.idle_limit", 3000000);      // 50 min: stop .msf close/reopen churn
user_pref("mail.db.max_open", 200);            // hold all folder DBs open

// IMAP: CONDSTORE left OFF (TB default). Enabling it triggered a heavy first-time
// re-sync of the large Gmail folders (All Mail/Important) and stuck TB at
// "Checking mail server capabilities…". Revisit only after those folders are trimmed.
user_pref("mail.server.default.use_condstore", false);

// Disk I/O — TB blocks remote mail content, so the disk cache does ~nothing; kill its writes
user_pref("browser.cache.disk.enable", false);

// Network — no speculative connections/prefetch (honored in TB; privacy + fewer background hits)
user_pref("network.predictor.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);

// Privacy
user_pref("network.cookie.cookieBehavior", 2); // reject all cookies
user_pref("places.history.enabled", false);

// Telemetry — one master switch (the rest are no-ops / already-off on ESR)
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("network.connectivity-service.enabled", false); // stop detectportal pings

// Email-only: disable the chat/IM subsystem entirely (no Matrix, no Chat space)
user_pref("mail.chat.enabled", false);

// UI / snappiness
user_pref("ui.prefersReducedMotion", 1);       // INTEGER; disables cosmetic animations
user_pref("mail.uidensity", 0);                // compact
user_pref("mail.biff.play_sound", false);
