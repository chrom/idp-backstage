# IDP Backstage — Docker Compose helpers (PostgreSQL + Backstage).
# Run from the backstage directory: make start | stop | clean
#
# Ports (after `make start`):
#   - Backstage UI:     http://localhost:7007  (container maps host 7007 → app)
#   - PostgreSQL:       localhost:5433 → container 5432 (override with POSTGRES_PUBLISH_PORT)
# Local dev (yarn start): UI http://localhost:3000; backend listens on :7007.
# packages/app/package.json must define "proxy" (/api -> :7007) so the dev server forwards API calls.
# app-config keeps backend.baseUrl http://localhost:3000 (same origin as the UI) so cookies work; without proxy, catalog returns 401.
# If you use another UI port (e.g. PORT=3007), add that origin under backend.cors.origin in app-config.yaml or you get 401 on catalog.
#
# --- Access, users, and “admin” (read also: make auth-info) ---
#
# Backstage has NO default username/password for the web UI. Sign-in is pluggable (guest, GitHub, OIDC, …).
#
# 1) Guest (current default in app-config.yaml)
#    - Click “Enter” on the Guest card — everyone shares one identity, usually user:default/guest.
#    - No password. Use only for local/dev. Some features may warn about unverified identity.
#
# 2) PostgreSQL env vars (POSTGRES_USER / POSTGRES_PASSWORD in .env) are DATABASE credentials for the
#    catalog DB — NOT the Backstage login. Do not confuse them with an “admin user” for the portal.
#
# 3) Named users (recommended next step): GitHub OAuth
#    - Create a GitHub OAuth App: Settings → Developer settings → OAuth Apps.
#    - Authorization callback URL must match your UI origin, e.g.:
#        http://localhost:3000/api/auth/github/handler/frame   (default yarn dev)
#        http://localhost:7007/api/auth/github/handler/frame   (all-in-one Docker image)
#      If you use another port (e.g. 3007), use that port in the URL and in app.baseUrl.
#    - Set in backstage/.env:
#        AUTH_GITHUB_CLIENT_ID=<from GitHub>
#        AUTH_GITHUB_CLIENT_SECRET=<from GitHub>
#    - Enable the GitHub auth provider in app-config (see https://backstage.io/docs/auth/github/provider )
#      and register @backstage/plugin-auth-backend-module-github-provider in packages/backend/src/index.ts.
#    - Add User entities to the catalog (or use signIn.resolvers with dangerouslyAllowSignInWithoutUserInCatalog
#      only for dev — see docs).
#
# 4) “Admin”
#    - There is no built-in Backstage super-user. This repo uses allow-all permission policy for PoC.
#    - Production: configure the permission framework / RBAC plugin and map identities (e.g. GitHub teams)
#      to roles. See https://backstage.io/docs/permissions/

COMPOSE := docker compose

.DEFAULT_GOAL := help

.PHONY: help start stop clean auth-info build-backstage-bundle docker-build

help:
	@echo "Targets:"
	@echo "  make start     Start services (docker compose up -d)"
	@echo "  make stop      Stop and remove containers and networks; DB data volume is kept"
	@echo "  make clean     Full cleanup: containers, networks, volumes (Postgres data removed), local compose-built images"
	@echo "  make auth-info Longer notes on Guest vs DB vs GitHub OAuth and admin/RBAC"
	@echo ""
	@echo "Docker image for Backstage (requires host bundle first — see packages/backend/Dockerfile):"
	@echo "  make build-backstage-bundle   Run yarn install, tsc, and build:backend in backstage/ (creates skeleton.tar.gz + bundle.tar.gz)"
	@echo "  make docker-build             Runs build-backstage-bundle, then docker compose build backstage"
	@echo ""
	@echo "Ports (docker compose):"
	@echo "  Backstage:  http://localhost:7007"
	@echo "  PostgreSQL: localhost:5433 (host) -> 5432 (container); set POSTGRES_PUBLISH_PORT to change"
	@echo "Ports (local yarn start): UI http://localhost:3000, backend http://localhost:7007"
	@echo ""
	@echo "Env files (examples):"
	@echo "  .env.example  — copy to .env (POSTGRES_*, optional GITHUB_TOKEN, optional AUTH_GITHUB_*)"

auth-info:
	@echo "=== Backstage access (summary) ==="
	@echo ""
	@echo "UI login: Guest is enabled by default — no password. PostgreSQL POSTGRES_* vars are for the database only."
	@echo ""
	@echo "For real identities: GitHub OAuth App callback examples:"
	@echo "  http://localhost:3000/api/auth/github/handler/frame"
	@echo "  http://localhost:7007/api/auth/github/handler/frame"
	@echo "Match the port to app.baseUrl in app-config / how you run the app (e.g. :3007 if the dev server uses 3007)."
	@echo ""
	@echo "Set in .env when GitHub auth is configured:"
	@echo "  AUTH_GITHUB_CLIENT_ID"
	@echo "  AUTH_GITHUB_CLIENT_SECRET"
	@echo ""
	@echo "Admin: no default admin account; use permissions/RBAC for production. See Makefile header comments."

start:
	$(COMPOSE) up -d

stop:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v --remove-orphans --rmi local

# Backstage Docker image expects packages/backend/dist/skeleton.tar.gz and bundle.tar.gz from
# `backstage-cli package build` (via yarn build:backend), not only TypeScript emit in dist/.
build-backstage-bundle:
	corepack enable && corepack yarn install && corepack yarn tsc && corepack yarn build:backend

docker-build: build-backstage-bundle
	$(COMPOSE) build backstage
