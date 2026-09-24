# Minimal image for the toy agent. Includes curl so the "exfiltrate over
# network" tool-call has a real tool to reach for — the sandbox, not the
# missing binary, is what should stop it.
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# A dedicated non-root user. The hardened run pins to this uid; the unsafe run
# overrides it back to root with --user 0 to show the contrast.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin agent

# The python base image ships a GPG_KEY env var used for its own build; clear
# it so the "dump secrets from environment" tool-call has nothing to latch onto
# in the hardened run (the broker pattern: sensitive values never enter the box).
ENV GPG_KEY=""

WORKDIR /app
COPY agent/ /app/

# Default workspace the agent writes to. In the hardened run this path is a
# size-capped tmpfs mounted over it; here it's just a placeholder dir.
RUN mkdir -p /workspace && chown agent:agent /workspace

USER agent
ENTRYPOINT ["python3", "/app/agent.py"]
CMD ["/app/attack_tasks.txt"]
