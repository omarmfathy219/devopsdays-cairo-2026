# Same agent, two runtimes

> Companion repo for the talk **"Sandboxing AI Agents in Production & DevOps"**
> — DevOpsDays Cairo 2026, 26 September, CREATIVA Innovation Hub, Giza.
> Everything below runs offline on your laptop in about two minutes.

A deliberately naive "agent" ([`agent/agent.py`](agent/agent.py)) executes a list of
attacker-controlled tool-calls ([`agent/attack_tasks.txt`](agent/attack_tasks.txt)) —
exactly what a prompt-injection payload would smuggle into an agent's tool loop.

The **agent code and the task list are identical** in both runs. The only thing
that changes is the runtime it executes in. That's the whole point: security here
is a property of the **runtime**, not the model or the prompt.

## Prerequisites

- Docker running (`docker info` should succeed)

## Run it

```bash
make build     # build the agent image
make unsafe    # NO sandbox: root + host mounted + network + secrets + privileged
make safe      # SAME agent, hardened sandbox
make benign    # prove the sandbox still lets legitimate work through
make demo      # unsafe then safe, back to back
```

Or call the scripts directly: `./run-unsafe.sh`, `./run-safe.sh`.

## What you'll see

| Tool-call (attack)           | `run-unsafe.sh` | `run-safe.sh` | Control that stops it                |
|------------------------------|-----------------|---------------|--------------------------------------|
| read host password hashes    | ✗ succeeds      | ✓ blocked     | non-root user + no host mount        |
| dump secrets from env        | ✗ succeeds      | ✓ blocked     | broker pattern — no secrets injected |
| send data over the network   | ✗ succeeds      | ✓ blocked     | `--network none`                     |
| tamper with the rootfs       | ✗ succeeds      | ✓ blocked     | `--read-only`                        |
| recon the host filesystem    | ✗ succeeds      | ✓ blocked     | no bind mount                        |

All five live in [`agent/attack_tasks.txt`](agent/attack_tasks.txt) — edit that file
to add your own.

`make benign` runs the *legitimate* job in the same hardened box and every step
completes — a tight sandbox stops the attacks without getting in the work's way.

## The hardening, flag by flag (`run-safe.sh`)

| Flag                                        | Defense                                            |
|---------------------------------------------|----------------------------------------------------|
| `--network none`                            | no egress → exfiltration & C2 have no route        |
| `--read-only`                               | immutable rootfs → no persistence / tampering      |
| `--tmpfs /workspace:…,noexec,nosuid,nodev`  | one size-capped writable path, can't exec from it  |
| `--user 10001`                              | non-root → can't read root-owned secrets           |
| `--cap-drop ALL`                            | zero Linux capabilities                            |
| `--security-opt no-new-privileges`          | setuid binaries can't re-escalate                  |
| `--security-opt seccomp=seccomp-agent.json` | block escape syscalls (`unshare`/`mount`/`ptrace`) |
| `--memory 256m` / `--cpus 0.5`              | resource abuse is bounded                          |
| no host mount, no secrets in env            | sensitive data is never even reachable             |

## Note on the "unsafe" run

`run-unsafe.sh` mounts the host **read-only** (`-v /:/host:ro`) so it can *read*
sensitive files to prove the point without being able to damage the host. It also
adds `--cap-add SYS_ADMIN --security-opt seccomp=unconfined`, which is what a
carelessly privileged agent runtime looks like in the wild — no syscall filtering
and a capability that is most of the way to root on the host.

Everything runs in a `--rm` container; nothing is installed on the host.

## Beyond containers

This demo uses hardened Docker because it runs anywhere. In production, treat the
container as **one** layer and add a kernel/VM isolation boundary underneath for
untrusted or high-blast-radius agents:

- **gVisor** (`runsc`) — user-space kernel; intercepts syscalls before the host kernel.
- **Kata Containers / Firecracker microVMs** — a real VM boundary per agent, OCI-compatible.

Swap the runtime in (`docker run --runtime=runsc …`) and the same manifest gets a
hardware/kernel isolation boundary with no change to the agent.
