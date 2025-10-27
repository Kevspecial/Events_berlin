# Copilot Instructions for Events_berlin

## Development Guidelines

Be an experienced fullstack software engineer, always use these guides:
- **Rails**: https://guides.rubyonrails.org/
- **Ruby**: https://www.ruby-lang.org/en/documentation/
- **Nextjs**: https://nextjs.org/docs
- **ActiveAdmin**: https://activeadmin.info/

- https://docs.rubocop.org/rubocop-rails/index.html

## Project Context
Box2.0-up-1 is a Rails 7.1 application powered by Ruby 3.2.2, built to deliver an Eventbrite-style platform for event management.
The project repository is hosted at git@github.com:Kevspecial/Events_berlin.git and combines modern Rails conventions with enterprise-level tooling.

## Architecture & Stack

### Core Framework
- **Backend:** Rails 7.1 (API mode preferred)
- **Frontend:** Next.js (TypeScript recommended)
- **Database:** PostgreSQL (SQLite3 in development)
- **Admin Interface:** ActiveAdmin with custom addons
- **Frontend Utilities:** Bootstrap + Font Awesome
- **Bundling:** cssbundling-rails and importmap
# Copilot / Assistant Reference — Events_berlin

Purpose: a short, actionable guide for automated assistants (Copilot or reviewers) to work safely and productively on this repository.

Prime facts
- Ruby: 3.2.2
- Rails: 7.1.x (lockfile shows 7.1.5.2)
- Frontend: Next.js (TypeScript present under `/frontend`)
- DB (dev/test): SQLite3 locally, PostgreSQL in CI/production

How to use this file
- Read quickly for project constraints, dev commands, and do/don't rules.
- When proposing changes: prefer small, test-covered edits. Add migration or spec changes where appropriate.

Behaviour & assumptions for automated suggestions
- Act like an experienced Rails fullstack engineer.
- Prefer safe, non-breaking changes by default.
- When upgrading gems, run `bundle install` and the test suite; include a short compatibility note in the PR.
- Avoid editing large files without tests; prefer small, incremental refactors.

Repo conventions (short)
- Code style: RuboCop config in repo — run `bin/rubocop --parallel`.
- Tests: Minitest fixtures under `test/`; run with `bin/rails test`.
- Admin: ActiveAdmin lives in `app/admin` and uses DSL-heavy files (they often trigger Metrics/BlockLength).
- JS: Frontend app under `/frontend` (Next.js) — run `npm install` then `npm run dev` or `npm run build`.

Quick commands
- Install Ruby gems: `bundle install`
- Run RuboCop: `bin/rubocop --parallel`
- Run tests (rails): `bin/rails db:create db:schema:load RAILS_ENV=test && bin/rails test`
- Start Rails (dev): `bin/dev` (or `bin/rails server`)
- Start Next.js: `cd frontend && npm install && npm run dev`

Security & dependency handling
- Report vulnerabilities but avoid forcing CI failure for audit-only findings unless a security owner asks.
- When bumping gems for advisories:
	- bump minimal required version in `Gemfile` and run `bundle update <gem>`.
	- run tests and fix regressions incrementally.

Testing guidance
- Prefer fixing or adding small tests for any behavioral change.
- Fixtures should be valid YAML without runtime ERB that depends on app boot ordering.

Pull request expectations
- Provide a 2–3 line summary of intent.
- List commands you ran locally (lint, test, build).
- Mention any remaining TODOs or risks.

Common tasks & examples
- Update a gem safely:
	1) Edit `Gemfile` to allow the minimal safe version.
	2) Run `bundle update <gem>`.
	3) Run `bin/rails test` and `bin/rubocop --parallel`.

- Fix a failing fixture:
	- Ensure `test/fixtures/*.yml` contains valid YAML.
	- Avoid ERB that references runtime-only code (e.g., Devise encryptors at parse time).

Prompt templates for the assistant
- "Summarize the failing tests after `bin/rails test` and suggest the minimal code fix and fixture change." 
- "Create a focused PR that updates `rack` to >= 3.2.x and runs tests; include rollback instructions if tests fail." 
- "Refactor `app/admin/*.rb` files to reduce method complexity in separate commits and keep tests green."

Notes and constraints
- Keep PRs small and focused. Large cross-cutting refactors should be split.
- When touching production-facing code, run integration smoke tests locally if possible.

If unsure
- Ask a short clarifying question and include the precise file and line range you plan to change.

Repository links
- CI workflow: `.github/workflows/ci.yml`
- RuboCop config: `.rubocop.yml`
- Test fixtures: `test/fixtures/`

End of guide
