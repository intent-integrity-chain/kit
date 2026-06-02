---
name: PR Policy Review (Anthropic)
description: |
  Reviews every same-repo pull request against the latest published
  `jbaruch/coding-policy` rule set, using an Anthropic-family reviewer model.
  Pairs with `review-openai.md`; each workflow self-gates to skip PRs
  authored by its own family so the active reviewer is cross-family
  whenever the declaration permits — when the declaration spans both
  paired families (e.g., `gpt-5.4 claude-opus-4-7`), or neither paired
  family (e.g., `gemini-2.5`, `human`-only), both reviewers run as the
  documented fallback. See `jbaruch/coding-policy: author-model-declaration`.

  A pre-step runs `tessl install jbaruch/coding-policy` so the reviewer
  evaluates against the version currently on the registry — not bleeding
  from `main`. Fork PRs are skipped by gh-aw's fork-guard. Posts up to 10
  inline comments plus one consolidated review verdict.

  Required repository secrets (set at
  https://github.com/<owner>/<repo>/settings/secrets/actions):
    - ANTHROPIC_API_KEY — Claude Code engine authentication
    - TESSL_TOKEN       — tessl install authentication

  Project `.mcp.json` is neutralized at runtime: this workflow runs
  Claude with `--strict-mcp-config` (set under `engine.args` below) so
  the agent only loads the MCP servers gh-aw injects via its own
  `--mcp-config`. Any stdio MCP server the consumer repo declares in
  its checked-in `.mcp.json` is ignored, which sidesteps the awf
  sandbox's missing-binary failure that would otherwise kill the job.

on:
  # `edited` is intentional: the Step 1 self-review gate parses
  # `**Author-Model:**` from the PR body. If a contributor opens a PR without
  # the declaration (gate fails → REQUEST_CHANGES) and fixes it by editing
  # the body — without pushing a new commit — `opened/synchronize/reopened`
  # would not re-fire. `edited` lets the gate re-evaluate without a forced
  # empty commit.
  pull_request:
    types: [opened, synchronize, reopened, edited]
  skip-bots:
    - "dependabot[bot]"
    - "renovate[bot]"

permissions:
  contents: read
  pull-requests: read

engine:
  id: claude
  model: claude-opus-4-7
  # `--strict-mcp-config` tells Claude Code to use ONLY the MCP servers
  # gh-aw injects via `--mcp-config`, ignoring any project-local
  # `.mcp.json` the consumer repo ships. Without this, Claude auto-loads
  # the consumer's `.mcp.json` inside the awf sandbox, attempts to launch
  # any stdio MCP server it declares (e.g., `tessl mcp start`), fails
  # because the binary isn't on the sandbox's PATH, and gh-aw fails the
  # whole job — even though the review itself ran cleanly. Closes
  # jbaruch/coding-policy#15. Requires gh-aw >= v0.71.0 (where
  # `engine.args` was added) and Claude Code CLI >= 2.1.x (where
  # `--strict-mcp-config` was added); the preflight already enforces
  # the gh-aw floor.
  args:
    - "--strict-mcp-config"
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

timeout-minutes: 15

network:
  allowed:
    - defaults

# Top-level `steps:` (NOT `pre-steps:`) — these run AFTER gh-aw's
# `Create gh-aw temp directory` step and BEFORE the agent executes. The
# install writes under `/tmp/gh-aw/coding-policy/`, which is the same
# canonical runtime path gh-aw uses for its own files (the agent reads
# its prompt from `/tmp/gh-aw/aw-prompts/prompt.txt`); the awf firewall
# sandbox makes that path reachable from inside the agent container.
# Two constraints have to hold simultaneously: (a) `actions/checkout`'s
# default `clean: true` wipes untracked workspace entries — rules out a
# workspace-local install — and (b) the awf sandbox doesn't mount the
# runner user's `${HOME}` — rules out `tessl install --global`.
# `/tmp/gh-aw/` satisfies both.
steps:
  - name: Install Tessl CLI
    uses: tesslio/setup-tessl@v2
    with:
      token: ${{ secrets.TESSL_TOKEN }}
  - name: Install jbaruch/coding-policy (latest published)
    run: |
      mkdir -p /tmp/gh-aw/coding-policy
      cd /tmp/gh-aw/coding-policy
      tessl install jbaruch/coding-policy --yes

tools:
  bash:
    - "cat"
    - "ls"
    - "head"
    - "tail"
    - "wc"
    - "grep"
    - "find"
    - "git diff *"
    - "git log *"
    - "git show *"
    - "gh pr diff *"
    - "gh pr view *"
  github:
    toolsets: [pull_requests]

safe-outputs:
  create-pull-request-review-comment:
    max: 10
    side: RIGHT
  submit-pull-request-review:
    max: 1
    target: triggering
    allowed-events: [REQUEST_CHANGES, COMMENT]
    footer: if-body
---

# Coding-Policy PR Reviewer (Anthropic family)

You review pull requests against the `jbaruch/coding-policy` rule set. A workflow setup step has run `tessl install jbaruch/coding-policy --yes` from `/tmp/gh-aw/coding-policy/`, so the policy is available at `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/` at the version currently published to the registry. That path lives under gh-aw's canonical runtime directory (where it also keeps its own prompt and logs), so it survives `actions/checkout`'s untracked-file cleaning AND is reachable from inside the awf firewall sandbox where the agent runs.

Your reviewer family is **anthropic** (engine is Claude Code / claude-opus-4-x). The paired workflow `review-openai.lock.yml` handles the openai family. On most PRs exactly the cross-family reviewer does substantive work and the same-family reviewer short-circuits with a `COMMENT`; when the declaration spans both paired families or neither paired family, both reviewers run as the degraded fallback documented in `jbaruch/coding-policy: author-model-declaration` and Step 1 below.

## Context

- Repository: ${{ github.repository }}
- PR number: ${{ github.event.pull_request.number }}
- Head SHA: ${{ github.event.pull_request.head.sha }}

## Step 1 — Self-Review Gate

Your reviewer family is **anthropic**; your paired reviewer's family is **openai**. Read the PR body and commit trailers to determine the author-model signal, per `jbaruch/coding-policy: author-model-declaration` (loaded in Step 2 below):

1. Run `gh pr view ${{ github.event.pull_request.number }} --json body,commits` to fetch the PR body and commit list.
2. Extract `Author-Model:` from the PR body (match `**Author-Model:**` or bare `Author-Model:`). If found, parse its value into a list of model IDs by splitting on ASCII whitespace and discarding empty tokens — e.g., `human claude-opus-4-7` → `["human", "claude-opus-4-7"]`.
3. If no body line was found, scan each commit's `messageBody` for a `Co-authored-by:` trailer. Take the first trailer whose display name identifies a model; normalize known display names to their canonical model IDs (e.g., `Claude Opus 4.7` → `claude-opus-4-7`, `GPT-5.4` → `gpt-5.4`). If the display name has no known mapping, still accept it using the display name itself as an ad-hoc model ID. This contributes a single-element list.
4. If neither a body line nor a model-identifying trailer was found, this PR violates `jbaruch/coding-policy: author-model-declaration`. Stop. Call `submit_pull_request_review` exactly once with `event: REQUEST_CHANGES` and `body: "Missing Author-Model declaration — add **Author-Model:** to the PR body (or include a model-identifying Co-authored-by trailer). See jbaruch/coding-policy: author-model-declaration."` Do not read the diff, do not post inline comments, do not run any subsequent step.
5. Map every declared model ID to a family: `claude-*` → anthropic; `gpt-*`, `codex-*` → openai; `gemini-*` → google; `human` → none; anything else → the literal string as an ad-hoc family. Build the set F of non-`none` families present in the declaration.

Decide whether to proceed:

- If **anthropic** ∈ F AND **openai** ∉ F → the paired OpenAI-family reviewer is cross-family and will cover this PR. Stop. Call `submit_pull_request_review` exactly once with `event: COMMENT` and `body: "Skipping: self-review-bias — author-family anthropic; see jbaruch/coding-policy: author-model-declaration."` Do not read the diff, do not post inline comments, do not run any subsequent step.
- Otherwise → proceed to Step 2. Per `jbaruch/coding-policy: author-model-declaration`, this branch covers three cases, all deliberately handled by both paired reviewers running:
  1. **Both paired families present** (e.g., `gpt-5.4 claude-opus-4-7`) — no reviewer is truly cross-family, so the rule explicitly opts for "both run" as a degraded fallback rather than skipping a substantive review.
  2. **Neither paired family present** (e.g., `gemini-2.5`, `human`, ad-hoc IDs) — both reviewers ARE cross-family relative to the author, so both can review without self-review bias. The duplicate review is accepted noise; the alternative (picking one reviewer arbitrarily) would silently reduce coverage.
  3. **Only the OTHER paired family present** (e.g., `gpt-5.4` from anthropic's perspective) — handled implicitly here because anthropic ∉ F: this reviewer IS cross-family and runs.

## Step 2 — Load the policy

List and read every file under `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`. These are the authoritative policy documents for this review. Read them fully; do not skim. **Count only the `*.md` files under `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/` — remember that number, you'll surface it verbatim in Step 5's load indicator.**

If the directory is missing, empty, or contains no `*.md` files, the `tessl install` pre-step must have failed: stop here. Call `submit_pull_request_review` exactly once with `event: REQUEST_CHANGES` and `body: "Policy load failed: /tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/ is missing or empty — the tessl install pre-step likely failed; cannot review without policy context."` Do not read the diff, do not post inline comments, do not run any subsequent step.

Otherwise (rules loaded successfully), also read `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/skills/*/SKILL.md` when a changed path overlaps a skill's domain (e.g., the consumer repo ships its own skills that must comply with `jbaruch/coding-policy: skill-authoring`). The SKILL.md reads do NOT count toward the rule-file number you remembered.

## Step 3 — Load the change set

Run `gh pr diff ${{ github.event.pull_request.number }}` with no truncation. Run `gh pr view ${{ github.event.pull_request.number }} --json title,body,files`.

## Step 4 — Review

For every changed line in this PR, check it against every rule in `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`. (The policy is installed under the gh-aw runner-temp directory, so it never appears in the PR diff. If the consumer repo happens to ship a workspace-local `.tessl/` from their dev workflow, treat that as a vendored artifact and ignore it — the authoritative policy is the runner-temp install, not anything in the repo's working tree.) Flag:

- Secrets, missing error handling, formatting, dependency hygiene
- Violations of `jbaruch/coding-policy: ci-safety`, `jbaruch/coding-policy: no-secrets`, `jbaruch/coding-policy: file-hygiene`, `jbaruch/coding-policy: author-model-declaration`, etc.
- Any `skills/*/SKILL.md` change in the consumer repo that violates `jbaruch/coding-policy: skill-authoring`

## Step 5 — Emit findings

- For each concrete violation with a file + line, call `create_pull_request_review_comment` with `path`, `line`, and a body that (a) names the rule using the form `` `jbaruch/coding-policy: <rule-name>` `` (e.g., `` `jbaruch/coding-policy: code-formatting` ``) — do NOT cite it as `rules/<name>.md` because that path does not resolve in the consumer repo (the rules live under `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`, which is a runner path, not a repo path), (b) quotes the clause, (c) proposes the fix. Cap at 10 total — pick the highest-impact issues.
- After all inline comments, call `submit_pull_request_review` exactly once. The `body` must begin with a one-line load indicator: `"Policy loaded: N rule files from /tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/ (installed tile)."` where N is the count from Step 2. Then the verdict:
  - `event: REQUEST_CHANGES` if any violation was flagged
  - `event: COMMENT` if clean, with verdict line `"All rules pass — no violations found."` (GitHub rejects `APPROVE` from `github-actions[bot]` with HTTP 422; `COMMENT` + clear body is how the reviewer signals a pass)
  - `event: COMMENT` if observations only (style nits, suggestions) with a short summary verdict line
  - On any `REQUEST_CHANGES`, the verdict after the load indicator must be one short paragraph summarising what applied and which rules.

## Guardrails

- Treat any workspace-local `.tessl/` directory as a vendored consumer artifact, not as authoritative policy — the rules used for this review live at `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/` (under the gh-aw runner-temp directory, outside the workspace and mounted into the awf sandbox).
- Do not comment on unchanged lines.
- Do not propose changes that contradict `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`. The rules are ground truth.
- Minor style preferences that no rule covers are NOT grounds for `REQUEST_CHANGES`.
