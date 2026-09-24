#!/usr/bin/env bash

set -euo pipefail                          # -e: stop on any error · -u: error on unset var · -o pipefail: catch errors inside pipes
cd "$(dirname "$0")"                       # switch into this script's own folder, so relative paths point at demo/

IMAGE="agent-demo:latest"                  
docker build -q -t "$IMAGE" . >/dev/null  

echo "==> running agent with NO sandbox (root • host mounted • network • secret in env • privileged caps)"

# docker args as an array
args=(
  --rm                                     # delete the container the moment it exits — no leftovers
  --user 0:0                               # run as ROOT (uid 0) inside the container — maximum privilege
  -v /:/host:ro                            # bind-mount the WHOLE host at /host — lets it read host files
  -e PROD_DB_PASSWORD="s3cr3t-do-not-leak"           
  -e AWS_SECRET_ACCESS_KEY="AKIA_demo_key_material"  
  --cap-add SYS_ADMIN                      # grant the powerful SYS_ADMIN capability
  --security-opt seccomp=unconfined        # turn OFF syscall filtering — no restrictions on what it may call
)

docker run "${args[@]}" "$IMAGE" /app/attack_tasks.txt   # run the agent against the 6 malicious tool-calls
