#!/usr/bin/env python3
"""
toy_agent — a deliberately naive "agent" for the sandboxing demo.

It reads a list of tool-calls (shell commands) from a task file and executes
each one, exactly like an agent whose tool-use loop has been hijacked by a
prompt-injection payload. The agent code is IDENTICAL in both runs of the demo.
The ONLY thing that changes is the sandbox it runs inside — so the difference in
outcome is attributable to the runtime, not the code.

Usage:  agent.py <task_file>
"""
import os
import subprocess
import sys

# ── brand-ish ANSI colors (teal good / pink bad / amber warn / muted) ──────────
TEAL = "\033[38;2;63;179;162m"
PINK = "\033[38;2;194;85;134m"
AMBER = "\033[38;2;217;160;91m"
PURPLE = "\033[38;2;126;107;196m"
MUTED = "\033[38;2;133;147;173m"
LIGHT = "\033[38;2;226;232;242m"
BOLD = "\033[1m"
RESET = "\033[0m"


def banner(text: str) -> None:
    print(f"\n{PURPLE}┌{'─' * 66}┐{RESET}")
    print(f"{PURPLE}│{RESET} {BOLD}{LIGHT}{text:<64}{RESET} {PURPLE}│{RESET}")
    print(f"{PURPLE}└{'─' * 66}┘{RESET}")


# "attack" = malicious task list (a non-zero exit is the sandbox winning).
# "work"   = the legitimate job (a zero exit is the job getting done).
MODE = os.environ.get("AGENT_MODE", "attack")


def run_tool_call(idx: int, label: str, command: str) -> None:
    """Execute one 'tool call' and classify the outcome for the audience."""
    print(f"\n{MUTED}[tool_call #{idx}]{RESET} {LIGHT}{label}{RESET}")
    print(f"{MUTED}  $ {command}{RESET}")
    try:
        proc = subprocess.run(
            ["/bin/sh", "-c", command],
            capture_output=True,
            text=True,
            timeout=8,
        )
        out = (proc.stdout + proc.stderr).strip()
        # Trim noisy output to keep the slide/terminal readable.
        if len(out) > 240:
            out = out[:240] + f" {MUTED}… (truncated){RESET}"
        reached = proc.returncode == 0 and bool(out)
        if MODE == "work":
            if reached:
                print(f"{TEAL}  ✓ completed{RESET}")
                for line in out.splitlines()[:4]:
                    print(f"{LIGHT}      {line}{RESET}")
            else:
                print(f"{PINK}  ✗ failed{RESET} {MUTED}(rc={proc.returncode}) — sandbox too tight for the job{RESET}")
                if out:
                    print(f"{MUTED}      {out.splitlines()[0]}{RESET}")
            return
        if reached:
            # The malicious action was NOT stopped by the runtime.
            print(f"{TEAL}  ✓ SUCCEEDED{RESET}")
            for line in out.splitlines()[:4]:
                print(f"{LIGHT}      {line}{RESET}")
        else:
            print(f"{TEAL}  ✓ BLOCKED by sandbox{RESET} {MUTED}(rc={proc.returncode}){RESET}")
            if out:
                print(f"{MUTED}      {out.splitlines()[0]}{RESET}")
    except subprocess.TimeoutExpired:
        print(f"{TEAL}  ✓ BLOCKED{RESET} {MUTED}(timed out — no route to target){RESET}")
    except Exception as exc:  # noqa: BLE001 — demo wants the raw failure surfaced
        print(f"{TEAL}  ✓ BLOCKED{RESET} {MUTED}({type(exc).__name__}: {exc}){RESET}")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: agent.py <task_file>", file=sys.stderr)
        return 2

    task_file = sys.argv[1]
    with open(task_file, encoding="utf-8") as fh:
        lines = [ln.rstrip("\n") for ln in fh if ln.strip() and not ln.startswith("#")]

    banner("agent booted — executing attacker-controlled tool-calls")
    print(f"{MUTED}  runtime identity : {RESET}", end="")
    sys.stdout.flush()
    subprocess.run(["/bin/sh", "-c", "id"])
    print(f"{MUTED}  workspace        : {os.getcwd()}{RESET}")
    print(f"{MUTED}  rootfs writable? : {RESET}", end="")
    print(f"{LIGHT}{'yes' if os.access('/', os.W_OK) else 'no (read-only)'}{RESET}")

    for idx, entry in enumerate(lines, start=1):
        label, _, command = entry.partition("::")
        run_tool_call(idx, label.strip(), command.strip() or label.strip())

    banner("run complete — review which tool-calls reached their target")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
