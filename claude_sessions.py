#!/usr/bin/env python3
"""List recent Claude Code sessions with resume commands."""

import json
import glob
import os
import argparse
import shlex
import subprocess
from datetime import datetime

SESSIONS_GLOB = os.path.expanduser("~/.claude/projects/*/*.jsonl")
HOME = os.path.expanduser("~")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("n", nargs="?", type=int, default=15, metavar="N",
                    help="number of recent sessions (default: 30)")
parser.add_argument("--resume", action="store_true",
                    help="open each listed session in a urxvt window on i3 workspace 4")
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
