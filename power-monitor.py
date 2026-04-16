#!/usr/bin/env python3
# power-monitor — Real-time USB-C PD cycling diagnostic
#
# Polls power supply sysfs and displays a refreshing view to detect
# PD 3.1 voltage negotiation issues (connect/disconnect cycling).
#
# Usage:
#   power-monitor [OPTIONS]
#
# Options:
#   --interval SECS   Poll interval in seconds (default: 1)
#   --log FILE        Append transitions to a file
#   -h, --help        Show help

import argparse
import os
import signal
import sys
import time

NO_COLOR = bool(os.environ.get("NO_COLOR")) or not sys.stdout.isatty()

if NO_COLOR:
    RED = GREEN = YELLOW = CYAN = BOLD = DIM = RESET = ""
else:
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    CYAN = "\033[36m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"

SYSFS = {
    "ac_online":  "/sys/class/power_supply/AC/online",
    "bat_status": "/sys/class/power_supply/BAT0/status",
    "capacity":   "/sys/class/power_supply/BAT0/capacity",
    "power_now":  "/sys/class/power_supply/BAT0/power_now",
    "voltage_now": "/sys/class/power_supply/BAT0/voltage_now",
    "energy_now": "/sys/class/power_supply/BAT0/energy_now",
}


def read_sysfs(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except (OSError, IOError):
        return None


def poll():
    raw = {k: read_sysfs(v) for k, v in SYSFS.items()}
    return {
        "time": time.time(),
        "ac_online": raw["ac_online"] == "1" if raw["ac_online"] is not None else None,
        "bat_status": raw["bat_status"],
        "capacity": int(raw["capacity"]) if raw["capacity"] else None,
        "power_w": int(raw["power_now"]) / 1e6 if raw["power_now"] else None,
        "voltage_v": int(raw["voltage_now"]) / 1e6 if raw["voltage_now"] else None,
        "energy_wh": int(raw["energy_now"]) / 1e6 if raw["energy_now"] else None,
    }


def state_key(sample):
    return (sample["ac_online"], sample["bat_status"])


def format_time(ts):
    return time.strftime("%H:%M:%S", time.localtime(ts))


def count_in_window(transitions, now, seconds):
    cutoff = now - seconds
    return sum(1 for t in transitions if t["time"] >= cutoff)


def render(sample, transitions, start_time):
    lines = []
    now = sample["time"]
    elapsed = now - start_time

    lines.append(f"{BOLD}Power Monitor{RESET} — polling every {args.interval}s (Ctrl+C to stop)")
    lines.append("─" * 52)

    # Current state
    if sample["ac_online"] is None:
        ac_str = f"{DIM}unknown{RESET}"
    elif sample["ac_online"]:
        ac_str = f"{GREEN}online{RESET}"
    else:
        ac_str = f"{RED}offline{RESET}"

    bat = sample["bat_status"] or "unknown"
    if bat == "Discharging":
        bat_str = f"{RED}{bat}{RESET}"
    elif bat in ("Charging", "Full"):
        bat_str = f"{GREEN}{bat}{RESET}"
    else:
        bat_str = f"{YELLOW}{bat}{RESET}"

    cap = f"{sample['capacity']}%" if sample["capacity"] is not None else "?"
    pwr = f"{sample['power_w']:.1f}W" if sample["power_w"] is not None else "?"
    volt = f"{sample['voltage_v']:.1f}V" if sample["voltage_v"] is not None else "?"

    lines.append(f"  AC: {ac_str}    Battery: {bat_str}  {cap}  {pwr}  {volt}")
    lines.append("")

    # Transition counts
    c10 = count_in_window(transitions, now, 10)
    c1m = count_in_window(transitions, now, 60)
    c5m = count_in_window(transitions, now, 300)
    total = len(transitions)

    lines.append(f"  Transitions    10s   1m   5m   total")
    lines.append(f"  ──────────    {c10:>3}  {c1m:>3}  {c5m:>3}   {total:>5}")

    # Alert
    if c1m > 2:
        lines.append("")
        lines.append(f"  {RED}{BOLD}⚠ PD CYCLING DETECTED — {c1m} transitions in the last 60s{RESET}")

    # Recent transitions
    lines.append("")
    if transitions:
        lines.append(f"  Recent events:")
        for t in reversed(transitions[-20:]):
            ac_old = "AC" if t["old"][0] else "BAT"
            ac_new = "AC" if t["new"][0] else "BAT"
            old_st = t["old"][1] or "?"
            new_st = t["new"][1] or "?"

            if t["old"][0] != t["new"][0]:
                change = f"{ac_old} → {ac_new}"
            else:
                change = f"{old_st} → {new_st}"

            ts = format_time(t["time"])
            lines.append(f"    {DIM}{ts}{RESET}  {change}")
    else:
        lines.append(f"  {DIM}No transitions yet — monitoring...{RESET}")

    lines.append("")
    mins = elapsed / 60
    lines.append(f"  {DIM}Running {mins:.0f}m ({total} transitions){RESET}")

    return "\n".join(lines)


def clear_screen():
    if not NO_COLOR:
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()


def main(args):
    transitions = []
    log_file = None
    start_time = time.time()

    if args.log:
        log_file = open(args.log, "a")
        log_file.write(f"# power-monitor started {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    prev = poll()

    try:
        while True:
            sample = poll()
            old_key = state_key(prev)
            new_key = state_key(sample)

            if old_key != new_key:
                t = {"time": sample["time"], "old": old_key, "new": new_key}
                transitions.append(t)

                if log_file:
                    ts = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(sample["time"]))
                    log_file.write(f"{ts}  {old_key} -> {new_key}\n")
                    log_file.flush()

            clear_screen()
            print(render(sample, transitions, start_time))

            prev = sample
            time.sleep(args.interval)

    except KeyboardInterrupt:
        pass

    # Final summary
    elapsed = time.time() - start_time
    mins = elapsed / 60
    total = len(transitions)
    rate = total / mins if mins > 0 else 0

    print()
    print(f"{BOLD}Summary{RESET}")
    print(f"  Runtime:      {mins:.1f} min")
    print(f"  Transitions:  {total}")
    print(f"  Rate:         {rate:.1f}/min")

    if total > 0:
        print(f"\n  All transitions:")
        for t in transitions:
            ts = time.strftime("%H:%M:%S", time.localtime(t["time"]))
            print(f"    {ts}  {t['old']} -> {t['new']}")

    if log_file:
        log_file.write(f"# stopped {time.strftime('%Y-%m-%d %H:%M:%S')} — {total} transitions in {mins:.1f}m\n")
        log_file.close()
        print(f"\n  Log written to: {args.log}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Real-time USB-C PD cycling diagnostic — monitors power supply state changes"
    )
    parser.add_argument("--interval", type=float, default=1, help="poll interval in seconds (default: 1)")
    parser.add_argument("--log", metavar="FILE", help="append transitions to a log file")
    args = parser.parse_args()

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main(args)
