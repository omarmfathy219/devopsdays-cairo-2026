.PHONY: build unsafe safe benign clean demo

build: ## build the agent image
	docker build -t agent-demo:latest .

unsafe: ## run the agent with NO sandbox (attacks succeed)
	./run-unsafe.sh

safe: ## run the SAME agent inside the hardened sandbox (attacks blocked)
	./run-safe.sh

benign: ## prove the sandbox still lets legitimate work through
	docker run --rm --user 10001:10001 --read-only \
	  --tmpfs /workspace:rw,size=64m,mode=1777,noexec,nosuid,nodev \
	  --cap-drop ALL --security-opt no-new-privileges \
	  --security-opt seccomp="$(PWD)/seccomp-agent.json" \
	  --network none --pids-limit 128 --memory 256m --cpus 0.5 \
	  -e AGENT_MODE=work \
	  agent-demo:latest /app/benign_tasks.txt

demo: unsafe safe ## the full before/after for the talk

clean: ## remove the built image
	-docker rmi agent-demo:latest
