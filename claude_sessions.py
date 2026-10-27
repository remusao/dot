#!/usr/bin/env python3
"""List recent Claude Code sessions with resume commands, or save/restore live ones."""

import json
import glob
import os
import argparse
import fcntl
import re
import shlex
import subprocess
import sys
import tempfile
import time
from datetime import datetime

SESSIONS_GLOB = os.path.expanduser("~/.claude/projects/*/*.jsonl")
HOME = os.path.expanduser("~")
STATE_DIR = os.path.expanduser("~/.local/state/claude-sessions")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("n", nargs="?", type=int, default=15, metavar="N",
                    help="number of recent sessions (default: 30)")
parser.add_argument("--resume", action="store_true",
                    help="open each listed session in a urxvt window on i3 workspace 4")
parser.add_argument("--save", action="store_true",
                    help="snapshot live sessions and their i3 layout")
parser.add_argument("--restore", action="store_true",
                    help="reopen the latest snapshot from an earlier X session")
args = parser.parse_args()
N = args.n

# ANSI
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"
CYAN = "\033[36m"
YELLOW = "\033[33m"
GREEN = "\033[32m"
WHITE = "\033[37m"
MAGENTA = "\033[35m"


def short_path(path):
    return path.replace(HOME, "~") if path.startswith(HOME) else path


def format_ts(ts):
    if not ts:
        return "?"
    dt = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
    now = datetime.now().astimezone()
    if dt.date() == now.date():
        return f"today {dt.strftime('%H:%M')}"
    delta = (now.date() - dt.date()).days
    if delta == 1:
        return f"yesterday {dt.strftime('%H:%M')}"
    if delta < 7:
        return dt.strftime("%a %H:%M")
    return dt.strftime("%Y-%m-%d %H:%M")


def extract_session_info(path):
    uuid = os.path.basename(path).replace(".jsonl", "")
    cwd = branch = slug = first_prompt = None
    last_ts = None

    with open(path) as f:
        for line in f:
            try:
                obj = json.loads(line)

                if obj.get("type") == "user" and cwd is None:
                    cwd = obj.get("cwd")
                    branch = obj.get("gitBranch")
                    slug = obj.get("slug")

                if obj.get("type") == "user" and "message" in obj and first_prompt is None:
                    msg = obj["message"]
                    if isinstance(msg, dict):
                        content = msg.get("content", "")
                        if isinstance(content, list):
                            content = next(
                                (p["text"] for p in content if isinstance(p, dict) and p.get("type") == "text"),
                                "",
                            )
                    elif isinstance(msg, str):
                        content = msg
                    else:
                        content = ""
                    first_prompt = content.split("\n")[0]

                ts = obj.get("timestamp")
                if ts:
                    last_ts = ts
            except json.JSONDecodeError:
                print(f"{YELLOW}Warning: Skipping malformed line in {path}{RESET}")
                continue

    return {
        "uuid": uuid,
        "cwd": cwd or "?",
        "branch": branch or "?",
        "slug": slug or "?",
        "last_ts": last_ts,
        "first_prompt": first_prompt or "?",
    }


def i3(cmd):
    out = json.loads(subprocess.run(["i3-msg", cmd], capture_output=True, text=True).stdout)
    if not all(r["success"] for r in out):
        sys.exit(f"i3-msg {cmd!r}: {out}")


def i3_tree():
    return subprocess.check_output(["i3-msg", "-t", "get_tree"], text=True)


def live_sessions():
    out = subprocess.check_output(["claude", "agents", "--json"], timeout=60)
    return [s for s in json.loads(out) if s["kind"] == "interactive" and s.get("sessionId")]


def snapshot_path():
    """One file per X session (boot + i3 instance): the next session's saves can't
    overwrite what is to be restored, after a reboot or an X crash alike."""
    with open("/proc/sys/kernel/random/boot_id") as f:
        boot = f.read().strip()
    i3_sock = subprocess.check_output(["i3", "--get-socketpath"], text=True).strip()
    return os.path.join(STATE_DIR, f"{boot}-{os.path.basename(i3_sock)}.json")


def save():
    # urxvt exports WINDOWID (its i3 window id) to its shell; claude inherits it.
    by_window = {}
    for s in live_sessions():
        try:
            with open(f"/proc/{s['pid']}/environ", errors="replace") as f:
                env = dict(kv.split("=", 1) for kv in f.read().split("\0") if "=" in kv)
            by_window[int(env["WINDOWID"])] = s
        except (OSError, KeyError, ValueError):
            pass

    def capture(con):
        """Keep only Claude windows, dropping containers left empty."""
        if con["window"]:
            s = by_window.get(con["window"])
            return s and {"session": s["sessionId"], "cwd": s["cwd"]}
        nodes = [n for n in map(capture, con["nodes"]) if n]
        return nodes and {"layout": con["layout"], "nodes": nodes}

    def walk(con):
        yield con
        for c in con["nodes"]:
            yield from walk(c)

    workspaces = [{"name": c["name"], **ws} for c in walk(json.loads(i3_tree()))
                  if c["type"] == "workspace" and (ws := capture(c))]
    if not workspaces:
        return  # never replace a good snapshot with an empty one
    os.makedirs(STATE_DIR, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=STATE_DIR, delete=False) as f:
        json.dump(workspaces, f, indent=1)
        f.flush()
        os.fsync(f.fileno())
    os.replace(f.name, snapshot_path())


def restore():
    if "CLAUDECODE" in os.environ:  # its env (session id, GIT_EDITOR=true, ...) would leak
        sys.exit("Run --restore from a terminal, not from Claude Code.")
    previous = [p for p in glob.glob(os.path.join(STATE_DIR, "*.json")) if p != snapshot_path()]
    if not previous:
        sys.exit(f"No snapshot from an earlier X session in {STATE_DIR}")
    path = max(previous, key=os.path.getmtime)
    with open(path) as f:
        workspaces = json.load(f)
    lock = open(os.path.join(STATE_DIR, "restore.lock"), "w")
    fcntl.flock(lock, fcntl.LOCK_EX)  # held until exit, else two restores pick the same sessions
    print(f"{BOLD} Restoring {short_path(path)}{RESET}\n")

    # Running sessions, plus restored windows and placeholders (cc-<id>) whose
    # claude may not be registered yet: resuming a session twice corrupts it.
    skip = {s["sessionId"] for s in live_sessions()}
    skip |= set(re.findall(r"cc-([0-9a-f-]{36})", i3_tree()))
    windows = []

    def layout(node):
        """Snapshot node -> i3 layout node, with a placeholder per window to reopen."""
        if "session" not in node:
            nodes = [n for n in map(layout, node["nodes"]) if n]
            return nodes and {"layout": node["layout"], "nodes": nodes}
        sid, cwd = node["session"], node["cwd"]
        if sid in skip:
            return None
        if not glob.glob(os.path.expanduser(f"~/.claude/projects/*/{sid}.jsonl")):
            print(f" {YELLOW}skipped (transcript gone): {short_path(cwd)}  {sid}{RESET}")
            return None
        if not os.path.isdir(cwd):
            print(f" {YELLOW}skipped (no dir): {short_path(cwd)}  {sid}{RESET}")
            return None
        windows.append(node)
        skip.add(sid)  # once, even if it was open in two windows
        return {"name": f"i3-placeholder cc-{sid}", "swallows": [{"instance": f"^cc-{sid}$"}]}

    env = {**os.environ, "XMODIFIERS": ""}  # as for --resume
    try:
        for ws in workspaces:
            first = len(windows)
            node = layout(ws)
            if not node:
                continue
            # A lone child goes in as is, so restores don't nest deeper each reboot.
            nodes = node["nodes"] if len(node["nodes"]) == 1 else node
            name = json.dumps(ws["name"], ensure_ascii=False)  # i3 unescapes only \" and \\
            with tempfile.NamedTemporaryFile("w", suffix=".json") as f:
                json.dump(nodes, f)
                f.flush()
                # Must precede the spawns: a window mapped first lands outside its placeholder.
                i3(f"workspace --no-auto-back-and-forth {name}; append_layout {f.name}")
            for w in windows[first:]:
                cmd = f"claude --resume {shlex.quote(w['session'])}; exec zsh"
                # Own session: closing this terminal must not SIGHUP the restored windows.
                subprocess.Popen(["urxvt", "-name", f"cc-{w['session']}", "-e", "zsh", "-ic", cmd],
                                 cwd=w["cwd"], env=env, start_new_session=True,
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
                print(f" {GREEN}ws {ws['name']}{RESET}  {short_path(w['cwd'])}  {DIM}{w['session']}{RESET}")
        if not windows:
            sys.exit("Nothing to restore.")
        # Only unfilled placeholders carry swallow criteria ("^cc-<id>$").
        deadline = time.monotonic() + 60
        while '"^cc-' in i3_tree() and time.monotonic() < deadline:
            time.sleep(0.5)
    finally:
        # Also on errors and Ctrl-C: a leftover placeholder would block its session's
        # next restore. By title, not con_id: a filled placeholder keeps its con_id.
        if '"^cc-' in i3_tree():
            subprocess.run(["i3-msg", "-q", '[title="^i3-placeholder cc-"] kill'])
            print(f"\n {YELLOW}Some windows never appeared; their placeholders were removed{RESET}")
    print()


if args.save:
    save()
    sys.exit()
if args.restore:
    restore()
    sys.exit()

files = sorted(glob.glob(SESSIONS_GLOB), key=os.path.getmtime, reverse=True)[:N]
sessions = [extract_session_info(f) for f in files]

try:
    cols = os.get_terminal_size().columns
except OSError:
    cols = 120

print(f"\n{BOLD} Claude Code Sessions {RESET}{DIM}(last {len(sessions)}){RESET}\n")

for i, s in enumerate(sessions, 1):
    ts = format_ts(s["last_ts"])
    prompt_width = cols - 6  # indent + padding
    prompt = s["first_prompt"][:prompt_width]

    print(f" {BOLD}{WHITE}{i:>2}{RESET}  {CYAN}{s['slug']}{RESET}")
    print(f"     {DIM}{ts}  {RESET}{MAGENTA}{s['branch']}{RESET}  {DIM}{short_path(s['cwd'])}{RESET}")
    print(f"     {DIM}{prompt}{RESET}")
    print()

if args.resume:
    # Switch to workspace 4 once; windows spawned next inherit the focused workspace.
    subprocess.run(["i3-msg", "-q", "workspace --no-auto-back-and-forth 4"])
    print(f"{BOLD} Opening on workspace 4{RESET}\n")
    for i, s in enumerate(sessions, 1):
        if not os.path.isdir(s["cwd"]):
            print(f" {DIM}[{i}]{RESET} {YELLOW}skipped (no dir): {short_path(s['cwd'])}{RESET}")
            continue
        # The exact command, kept open after Claude exits via `; exec zsh`.
        cmd = f"cd {shlex.quote(s['cwd'])} && claude --resume {s['uuid']}; exec zsh"
        # Standalone urxvt with XIM disabled (XMODIFIERS=""): independent process per
        # window, immune to the ibus/XIM-server freeze. Matches the i3 $mod+Return binding.
        subprocess.Popen(["urxvt", "-e", "zsh", "-ic", cmd],
                         env={**os.environ, "XMODIFIERS": ""})
        print(f" {DIM}[{i}]{RESET} {GREEN}{short_path(s['cwd'])}{RESET}  {MAGENTA}{s['branch']}{RESET}")
    print()
else:
    print(f"{BOLD} Resume commands{RESET}\n")
    for i, s in enumerate(sessions, 1):
        print(f" {DIM}[{i}]{RESET} {GREEN}cd {short_path(s['cwd'])} && claude --resume {s['uuid']}{RESET}")
    print()
