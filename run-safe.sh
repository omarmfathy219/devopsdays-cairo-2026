#!/usr/bin/env bash

set -euo pipefail                          # -e: stop on any error · -u: error on unset var · -o pipefail: catch errors inside pipes
cd "$(dirname "$0")"                       # switch into this script's own folder, so relative paths point at demo/

IMAGE="agent-demo:latest"                  
docker build -q -t "$IMAGE" . >/dev/null 

echo "==> running agent INSIDE the sandbox (non-root • no net • read-only • caps dropped • seccomp)"

# docker args as an array
args=(
  --rm                                     # delete the container the moment it exits — no leftovers
  --user 10001:10001                       # run as a NON-root user (uid/gid 10001) — can't read root-owned files
  --read-only                              # make the whole filesystem read-only — blocks tampering & persistence
  # the ONLY place the agent can write: a small scratch area in RAM, so real work still runs —
  #   size=64m (capped) · mode=1777 (writable by our user) · noexec (can't run programs from it) · nosuid,nodev (no privilege tricks)
  --tmpfs /workspace:rw,size=64m,mode=1777,noexec,nosuid,nodev
  --cap-drop ALL                           # drop EVERY Linux capability — no root superpowers left
  --security-opt no-new-privileges         # setuid binaries can't be used to re-escalate privileges
  --network none                           # NO network at all — exfiltration & call-home have no route out
  --security-opt seccomp="$(pwd)/seccomp-agent.json"  # apply our syscall allow/deny profile (blocks unshare/mount/ptrace…)
  --memory 256m                            # cap RAM — contains memory-exhaustion abuse
  --cpus 0.5                              
)

docker run "${args[@]}" "$IMAGE" /app/attack_tasks.txt   # run the agent against the 6 malicious tool-calls
