# Claude Code mouse & scrolling on urxvt

Investigated 2026-09-07. Claude Code 2.1.263, rxvt-unicode 9.31-3build2 (Ubuntu noble),
`TERM=rxvt-unicode-256color`, `settings.json: "tui": "fullscreen"`, Logitech G502.

Three separate defects, often mistaken for one. Fixes live in different places and
**none apply to an already-running session** — every fix needs a new `claude` process.

| symptom | cause | fix | lives in |
|---|---|---|---|
| bare mouse movement scrolls | urxvt wheel-button latch × Claude's `& 67` | `CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1` | **env var only — no settings key exists** |
| free-spin wheel scrolls wildly/jerkily | wheel accel ramp (6–15 lines/tick) | `"wheelScrollAccelerationEnabled": false` | `~/.claude/settings.json` |
| mouse select never reaches the clipboard | Claude copies via OSC 52; urxvt has none | Shift+drag, or `Ctrl+O` then `[` | technique, not config |

Applying both: close the urxvt window and relaunch it as usual. The launcher is
`urxvt -e zsh -ic '… claude --resume …'`; `-i` sources `zshrc`, which exports the
env var (verified: `rxvt-unicode-256color` → `1`, `xterm-kitty` → unset). Reusing a
shell older than the `zshrc` edit needs `source ~/.zshrc` first, or the var inline.

---

## 1. Bare mouse movement scrolls

Claude Code's default mouse mode is `full` = `1000+1002+1003+1006`. **1003 = report all
motion.** Verified by capturing startup bytes in a PTY:

| invocation | emitted |
|---|---|
| default | `?1049h ?1000h ?1002h ?1003h ?1006h` |
| `CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1` | `?1049h ?1000h ?1006h` |
| `CLAUDE_CODE_DISABLE_MOUSE_CLICKS=0` | full set (override works) |
| `CLAUDE_CODE_DISABLE_MOUSE=1` | no mouse modes at all |

### urxvt latches the wheel button forever

`src/command.C`, `rxvt_term::button_release`:

```c
if (reportmode) {
    /* don't report release of wheel "buttons" */
    if (ev.button >= 4 && ev.button <= 7)
      return;                    // ← wheel exits here, always
    MEvent.button = ev.button;
    mouse_report (ev);
    MEvent.button = AnyButton;   // added post-9.31; 9.31 has no reset at all
```

The reset never runs for wheel buttons in **any** version — the early return precedes
it. `mouse_report()` derives the reported button from `MEvent.button` (last button
*pressed*) and adds 32 for a `MotionNotify`, so after one wheel tick every motion event
is encoded as `64|32 = 96` (or `97` after a wheel-down). It reports only when the pointer
changes cell → one event per cell crossed.

Motion is reported at all only when 1002 (button held) or 1003 (always) is set
(`command.C`, `case MotionNotify:`). **That is the hook the fix uses.**

`MEvent.button` is `rxvt_term` state, so the latch is **per terminal window and outlives
the application**: 9.31 reports `31` on motion until the first button press, but any
window you have ever scrolled in is already latched.

### Claude Code cannot tell 96 from 64

Decode is two-stage — `Tf` (mouse path) first, falling back to `Cr` → `gy`:

```js
function Tf(t){ … if ((c & 64) !== 0) return null; … }   // "bit 64 → wheel, let gy have it"
function gy(t,s,c,d){ let p = s & 67;                    // 67 = 64|2|1 — bit 32 masked off
  if (p !== 64 && p !== 65) return null;
  return { name: p === 64 ? "wheelup" : "wheeldown", … } }
```

Neither tests bit 32; there is no `&32` guard anywhere in the decode chunk.

```
real wheel   64 = 1000000 & 1000011 = 1000000 = 64 → "wheelup"
bare motion  96 = 1100000 & 1000011 = 1000000 = 64 → "wheelup"
```

**Why urxvt only:** xterm reports bare motion as button 3 → `35`. `35 & 64 == 0`, so `Tf`
claims it as a genuine mouse-move and `gy` never sees it. Any terminal following xterm
here is structurally immune (others untested).

### Evidence

Live capture (move → one wheel tick → move):

```
…96;163;21M   64;163;21M   96;164;21M…
   motion      wheel press    motion     ← no `64;163;21m` (release) in between
```

The absent lowercase-`m` *is* the early return. Across the motion events only the
coordinates change; the button code stays `96`.

### Fix

`zshrc` — TERM-gated, respects an explicit value:

```zsh
if [[ "$TERM" == rxvt-unicode* ]]; then
  export CLAUDE_CODE_DISABLE_MOUSE_CLICKS="${CLAUDE_CODE_DISABLE_MOUSE_CLICKS:-1}"
fi
```

Selects mode `scroll`: 1002/1003 never enabled, so urxvt never reports motion.
Wheel and clicks still work (1000 reports press/release; the mode string feeds nothing
but the escape-sequence table, `entry("mouse", o) → {on: wWe(o)}` — no separate click
gate despite the flag's name). Costs Claude's own drag-to-select, which on urxvt could
never copy anyway (§3).

Edge case: the var is exported, so a terminal launched *from* a urxvt shell inherits `1`.
i3 keybindings give a clean env; worst case another terminal loses drag-select.

### Rejected

- **Upgrading urxvt.** `5ec6fb5e` (2024-02-03, after 9.31's 2023-01-02 release) adds the
  `AnyButton` reset and maps `AnyButton` to button 3, but the wheel early return still
  precedes it at HEAD. Ubuntu's `9.31-3build2` carries no related patch. Debian #1059148
  is the adjacent never-clicked `31`/`-1` case, not this.
- **`CLAUDE_CODE_DISABLE_MOUSE=1`.** Emits no mouse modes, so in fullscreen the wheel
  dies outright — `Xresources` sets `secondaryScroll: 0`, so there is no alt-screen
  scrollback for urxvt to scroll (upstream #62294, #70724).
- **Rebuilding urxvt** with `MEvent.button = AnyButton` before the wheel early return.
  The real fix, but no upstream patch to track.

### Upstream

No matching report found. One line in `gy()`:

```js
if (s & 32) return null;   // a genuine wheel tick never sets the motion bit
```

Reordering `Tf` to claim motion before its `& 64` test would also restore drag-select.

---

## 2. Free-spin wheel scrolls wildly

Separate defect, **not** caused by the §1 fix — it reproduces with mode `scroll`, where
no motion events exist at all. It is the documented setting
`wheelScrollAccelerationEnabled`: *"Ramp mouse-wheel scroll speed during fast scrolls
(fullscreen mode only)"*, default **on** (`Eo(key, !0)`; `Eo(n, s)`'s 2nd arg is the
default, read from `userSettings`).

urxvt resolves to the non-decay path with `base = 1`: `wheelFlood` is false (`ctn()`
flags only Cursor, VS Code 1.92–1.105, xterm.js), as are `xtermJs`, `wtSession`,
`jediTerm` → `useDecayCurve = false`, `z0t(…) = 1`.

```js
if (!x.useDecayCurve) {                                    // ← urxvt: "window (native)"
    …
    if (Re > tZe || !x.accelEnabled) x.mult = x.base;      // gap >40ms, or accel off → reset
    else { let Pe = Math.max(_5t*Math.min(x.base,1), x.base*2);   // = max(6,2) = 6
           x.mult = Math.min(Pe, x.mult + C5t) }           // +0.3 per tick
    return Math.max(1, Math.floor(x.mult));
}
```

Constants: `tZe=40`ms, `C5t=0.3`, `_5t=6`, `A5t=15`, `E5t=3`, `P5t=200`, `nZe=5`, `oZe=150`.

- Ticks <40 ms apart ramp to **6 lines/tick** (~17 ticks). Gaps >40 ms reset to 1.
- A direction reversal returns `0` (drops that tick) and arms `pendingFlip`; if the next
  tick is the new direction within 200 ms it enters `wheelMode` → cap **15**, step **+3**.
- Inside `wheelMode` only, ticks <5 ms apart return 1; five consecutive exit `wheelMode`.

A ratcheted wheel emits a few ticks and barely engages the ramp. A coasting G502 sustains
sub-40 ms ticks for seconds, pinning at 6 (or 15), and bounces in and out of `wheelMode`
— hence jerky, not merely fast.

**Fix:** `"wheelScrollAccelerationEnabled": false` in `~/.claude/settings.json`. Every
tick then yields exactly `base` (1 line); verified all early returns also yield 1. The
direction-reversal tick drop is pre-existing and unaffected.

Tune with `CLAUDE_CODE_SCROLL_SPEED=N` (sets `base`, clamped to 20).

**Needs a new process.** `Xe.current ??= iZe(it)` caches `accelEnabled` at the first
scroll; only `base` refreshes per scroll, and `Hk()` returns a stable reference so the
invalidation never fires. Running sessions keep accel on until restarted.

---

## 3. Mouse selection never reaches the clipboard

Fullscreen's headline mouse feature is in-app selection with auto-copy on release. It
copies via **OSC 52**, and urxvt's OSC table has no 52 (`0-4, 10-19, 30, 31, 46, 50, 51`),
with `Xresources` disabling perl entirely (`perl-ext:`/`perl-ext-common:` empty) so there
is no extension either. **That auto-copy is silently discarded.** Claude's selection can
highlight but never copy here.

The only paths that actually copy:

- **Shift+drag** → native urxvt selection → middle-click (PRIMARY) or `Ctrl+Meta+C`
  (CLIPBOARD, built-in at `command.C` ~793-803, requires `selection.len > 0`).
  Shift sets `bypass_keystate`, which zeroes `reportmode` and skips `mouse_report`, so
  this works identically in mouse mode `full`, `scroll` and `off`.
- **`Ctrl+O` then `[`** ("print to scrollback", present in 2.1.263) dumps the whole
  conversation into urxvt's native scrollback with tool output expanded — native
  selection, `Ctrl+Meta+C` and urxvt's own search then all work on it. Transcript mode
  also has `/` search, `n/N`, `{/}`, `g/G`, `v` (open in `$EDITOR`).

`/config` → "Copy on select" (`copyOnSelect`, default true) is inert on urxvt.

---

## Renderer: fullscreen vs classic

Schema: *"`fullscreen` uses the flicker-free alt-screen renderer with virtualized
scrollback (equivalent to `CLAUDE_CODE_NO_FLICKER=1`). `default` uses the classic
main-screen renderer."* Fullscreen exists to fix flicker, flat memory in long
conversations, and scroll-position jumping to top; it costs native search/selection
because the conversation is not in the terminal's scrollback.

The classic renderer enables **no mouse tracking at all** (`UAe()` is false for
`tui: "default"`), so urxvt handles the mouse natively there.

| | fullscreen | classic |
|---|---|---|
| plain drag select | nothing | native ✓ |
| Shift+drag select | native ✓ | native ✓ |
| bulk select/copy | `Ctrl+O` then `[` | native, always |
| wheel | Claude's viewport ✓ | native urxvt scrollback ✓ |
| flicker / flat memory | ✓ | ✗ |
| scroll jumps to top | ✓ fixed | ✗ known problem |
| issues §1 and §2 | apply | do not apply |

---

## Gotchas

- **`/tui <mode>` is not a per-session toggle.** It rewrites global
  `~/.claude/settings.json`, which Claude Code watches (29 `watchFile` sites), so it
  hot-applies to *every* running session. Doing this with ~20 live sessions disrupted
  all of them. To test a renderer safely, use a per-shell env var — `UAe()` checks
  `CLAUDE_CODE_NO_FLICKER` before it ever consults `settings.tui`:

  ```sh
  CLAUDE_CODE_NO_FLICKER=0 claude    # classic, this session only
  ```

  The rewrite itself was lossless (all keys, env vars and `permissions.deny` rules
  survived), but it reorders keys.
- **Mouse mode has no settings key.** The whole schema contains exactly two
  mouse/scroll keys: `autoScrollEnabled` and `wheelScrollAccelerationEnabled`. `bI()`
  reads only `CLAUDE_CODE_DISABLE_MOUSE` / `CLAUDE_CODE_DISABLE_MOUSE_CLICKS`, else
  returns `full`. So §1 cannot be fixed from `settings.json`.
- **Neither fix reaches a running session.** §1 is captured at process start, §2 at
  first scroll.
- Concurrent Claude Code sessions editing `~/.dot` can collide — check `git status`
  before assuming a diff is yours.
- **The §2 fix is not reproducible yet.** §1 lives in `zshrc` (tracked), but
  `~/.claude/settings.json` is not managed by `install.sh`/`update.sh` and cannot be
  committed wholesale (it holds API keys). `wheelScrollAccelerationEnabled` is
  settings-only — `Eo()` never consults the environment — so it needs an idempotent
  `jq` merge step in `install.sh` to survive a fresh machine.

## Repro

In urxvt: move → one wheel tick → move.

```sh
sh -c 'old=$(stty -g); stty raw -echo; printf "\033[?1000h\033[?1003h\033[?1006h"; timeout 8 cat -v; printf "\033[?1006l\033[?1003l\033[?1000l"; stty "$old"; echo'
```

`96;…M` on bare motion is §1. In an already-latched window the first movement shows it
too, before any wheel tick. Drop `?1003h` to reproduce the fixed configuration.

## Not to be confused with

The "scroll jumps to top" (#34794, #34400) and "wheel sends arrow keys" (#64214, #66601,
#70724) issue families. Different mechanisms.
