# The Magentic Stack — top-level tasks. See docs/plans/ for the full plan.
.DEFAULT_GOAL := help
.PHONY: help bootstrap build test gates pod-up pod-down clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Clone-and-build: submodules + all workspaces + pod smoke test
	./bootstrap

build: ## Build all language workspaces
	-bundle install
	-pnpm install
	-cargo build --workspace

test: ## Run integration-tests/
	@echo "TODO: run integration-tests/ (see docs/plans/pilot-release-gates.md)"

gates: ## Run the six pilot release gates locally (mirrors .github/workflows)
	@echo "TODO: run gates: boundary, shacl, attestation, reversible-pins, offline, governance-evidence"

pod-up: ## Bring up the 5-container MIND pod
	@echo "TODO: docker compose -f deploy/docker-compose.yml up -d"

pod-down: ## Tear down the MIND pod
	@echo "TODO: docker compose -f deploy/docker-compose.yml down"

clean: ## Remove build artifacts
	-rm -rf node_modules target .bundle

demo: ## Run the mind-pod demo (MIND -> BACK over /_cpcp) on :13000
	@cd runtimes/mind-pod && docker compose -f docker-compose.yml -f test/docker-compose.demo.yml up -d --build back
	@for i in $$(seq 1 60); do curl -sf http://localhost:13000/up >/dev/null 2>&1 && break; sleep 2; done
	@cd runtimes/mind-pod && BACK_URL=http://localhost:13000 python3 test/mind_boundary_test.py; \
	 cd $(CURDIR)/runtimes/mind-pod && docker compose -f docker-compose.yml -f test/docker-compose.demo.yml down -v
