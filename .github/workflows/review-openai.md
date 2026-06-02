---
name: PR Policy Review (OpenAI)
description: |
  Reviews every same-repo pull request against the latest published
  `jbaruch/coding-policy` rule set, using an OpenAI-family reviewer model.
  Pairs with `review-anthropic.md`; each workflow self-gates to skip PRs
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
    - OPENAI_API_KEY or CODEX_API_KEY — Codex engine authentication
      (either name is accepted; the workflow coalesces them at runtime)
    - TESSL_TOKEN — tessl install authentication

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
  id: codex
  model: gpt-5.4
  env:
    # gh-aw's compiled validation step accepts EITHER CODEX_API_KEY or
    # OPENAI_API_KEY as the credential, but the Codex CLI / API-proxy
    # path only reads OPENAI_API_KEY at runtime. Without the fallback,
    # a consumer who set CODEX_API_KEY only would pass validation and
    # then fail with an empty-credential error after burning setup time.
    # Coalescing here makes both names work from end to end.
    OPENAI_API_KEY: ${{ secrets.CODEX_API_KEY || secrets.OPENAI_API_KEY }}

timeout-minutes: 15

network:
  # This allowlist applies to the AGENT runtime inside the awf firewall
  # sandbox — NOT to the earlier runner-side `tessl install` step (that
  # runs in the workflow's `steps:` on the runner host, before the
  # sandbox starts, and is unaffected by this list). The hosts here cover
  # agent-initiated GitHub access (gh / MCP / API calls and related
  # Codex/GitHub service traffic) and Codex UI/telemetry that Codex's
  # `defaults` doesn't include. `github` and `threat-detection` are
  # gh-aw ecosystem identifiers (preferred over enumerating individual
  # domains): `github` covers github.com / codeload / raw / objects,
  # `threat-detection` covers api.github.com. `ab.chatgpt.com` and
  # `chatgpt.com` are Codex UI/telemetry. The Anthropic-side template
  # inherits GitHub via its own engine `defaults`; this list is the
  # OpenAI-side equivalent.
  allowed:
    - defaults
    - github
    - threat-detection
    - ab.chatgpt.com
    - chatgpt.com

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

# Coding-Policy PR Reviewer (OpenAI family)

You review pull requests against the `jbaruch/coding-policy` rule set. A workflow setup step has run `tessl install jbaruch/coding-policy --yes` from `/tmp/gh-aw/coding-policy/`, so the policy is available at `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/` at the version currently published to the registry. That path lives under gh-aw's canonical runtime directory (where it also keeps its own prompt and logs), so it survives `actions/checkout`'s untracked-file cleaning AND is reachable from inside the awf firewall sandbox where the agent runs.

Your reviewer family is **openai** (engine is Codex / gpt-5.x). The paired workflow `review-anthropic.lock.yml` handles the anthropic family. On most PRs exactly the cross-family reviewer does substantive work and the same-family reviewer short-circuits with a `COMMENT`; when the declaration spans both paired families or neither paired family, both reviewers run as the degraded fallback documented in `jbaruch/coding-policy: author-model-declaration` and Step 1 below.

## Context

- Repository: ${{ github.repository }}
- PR number: ${{ github.event.pull_request.number }}
- Head SHA: ${{ github.event.pull_request.head.sha }}

## Step 1 — Self-Review Gate

Your reviewer family is **openai**; your paired reviewer's family is **anthropic**. Read the PR body and commit trailers to determine the author-model signal, per `jbaruch/coding-policy: author-model-declaration` (loaded in Step 2 below):

1. Run `gh pr view ${{ github.event.pull_request.number }} --json body,commits` to fetch the PR body and commit list.
2. Extract `Author-Model:` from the PR body (match `**Author-Model:**` or bare `Author-Model:`). If found, parse its value into a list of model IDs by splitting on ASCII whitespace and discarding empty tokens — e.g., `human claude-opus-4-7` → `["human", "claude-opus-4-7"]`.
3. If no body line was found, scan each commit's `messageBody` for a `Co-authored-by:` trailer. Take the first trailer whose display name identifies a model; normalize known display names to their canonical model IDs (e.g., `Claude Opus 4.7` → `claude-opus-4-7`, `GPT-5.4` → `gpt-5.4`). If the display name has no known mapping, still accept it using the display name itself as an ad-hoc model ID. This contributes a single-element list.
4. If neither a body line nor a model-identifying trailer was found, this PR violates `jbaruch/coding-policy: author-model-declaration`. Stop. Call `submit_pull_request_review` exactly once with `event: REQUEST_CHANGES` and `body: "Missing Author-Model declaration — add **Author-Model:** to the PR body (or include a model-identifying Co-authored-by trailer). See jbaruch/coding-policy: author-model-declaration."` Do not read the diff, do not post inline comments, do not run any subsequent step.
5. Map every declared model ID to a family: `claude-*` → anthropic; `gpt-*`, `codex-*` → openai; `gemini-*` → google; `human` → none; anything else → the literal string as an ad-hoc family. Build the set F of non-`none` families present in the declaration.

Decide whether to proceed:

- If **openai** ∈ F AND **anthropic** ∉ F → the paired Anthropic-family reviewer is cross-family and will cover this PR. Stop. Call `submit_pull_request_review` exactly once with `event: COMMENT` and `body: "Skipping: self-review-bias — author-family openai; see jbaruch/coding-policy: author-model-declaration."` Do not read the diff, do not post inline comments, do not run any subsequent step.
- Otherwise → proceed to Step 2. Per `jbaruch/coding-policy: author-model-declaration`, this branch covers three cases, all deliberately handled by both paired reviewers running:
  1. **Both paired families present** (e.g., `gpt-5.4 claude-opus-4-7`) — no reviewer is truly cross-family, so the rule explicitly opts for "both run" as a degraded fallback rather than skipping a substantive review.
  2. **Neither paired family present** (e.g., `gemini-2.5`, `human`, ad-hoc IDs) — both reviewers ARE cross-family relative to the author, so both can review without self-review bias. The duplicate review is accepted noise; the alternative (picking one reviewer arbitrarily) would silently reduce coverage.
  3. **Only the OTHER paired family present** (e.g., `claude-opus-4-7` from openai's perspective) — handled implicitly here because openai ∉ F: this reviewer IS cross-family and runs.

## Step 2 — Load the policy

List and read every file under `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`. These are the authoritative policy documents for this review. Read them fully; do not skim. **Count only the `*.md` files under `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/` — remember that number, you'll surface it verbatim in Step 5's load indicator.**

If the directory is missing, empty, or contains no `*.md` files, the `tessl install` pre-step must have failed: stop here. Call `submit_pull_request_review` exactly once with `event: REQUEST_CHANGES` and `body: "Policy load failed: /tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/ is missing or empty — the tessl install pre-step likely failed; cannot review without policy context."` Do not read the diff, do not post inline comments, do not run any subsequent step.

Otherwise (rules loaded successfully), also read `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/skills/*/SKILL.md` when a changed path overlaps a skill's domain (e.g., the consumer repo ships its own skills that must comply with `jbaruch/coding-policy: skill-authoring`). The SKILL.md reads do NOT count toward the rule-file number you remembered.

## Step 3 — Load the change set

Run `gh pr diff ${{ github.event.pull_request.number }}` with no truncation. Run `gh pr view ${{ github.event.pull_request.number }} --json title,body,files`.

**Build the changed-files allowlist.** From the `files` array returned by `gh pr view --json files`, extract the `path` of every entry into a single explicit list — call it `CHANGED_FILES`. This is the closed allowlist of paths inline comments may reference in Step 5. Files NOT in `CHANGED_FILES` (including the installed tile under `/tmp/gh-aw/coding-policy/...`, the consumer repo's tracked-but-unchanged files, and any path the agent infers from rule prose) are NOT eligible for inline comments — GitHub will reject `create_pull_request_review_comment` calls on those paths with HTTP 422 ("Path could not be resolved"), and the resulting `submit_pull_request_review` call cascade-fails so the substantive verdict never lands on the PR. Keep `CHANGED_FILES` in working memory — Step 5 reads from it.

## Step 4 — Review

For every changed line in this PR, check it against every rule in `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`. (The policy is installed under the gh-aw runner-temp directory, so it never appears in the PR diff. If the consumer repo happens to ship a workspace-local `.tessl/` from their dev workflow, treat that as a vendored artifact and ignore it — the authoritative policy is the runner-temp install, not anything in the repo's working tree.) Flag:

- Secrets, missing error handling, formatting, dependency hygiene
- Violations of `jbaruch/coding-policy: ci-safety`, `jbaruch/coding-policy: no-secrets`, `jbaruch/coding-policy: file-hygiene`, `jbaruch/coding-policy: author-model-declaration`, etc.
- Any `skills/*/SKILL.md` change in the consumer repo that violates `jbaruch/coding-policy: skill-authoring`

## Step 5 — Emit findings

- For each concrete violation with a file + line, call `create_pull_request_review_comment` with `path`, `line`, and a body that (a) names the rule using the form `` `jbaruch/coding-policy: <rule-name>` `` (e.g., `` `jbaruch/coding-policy: code-formatting` ``) — do NOT cite it as `rules/<name>.md` because that path does not resolve in the consumer repo (the rules live under `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`, which is a runner path, not a repo path), (b) quotes the clause, (c) proposes the fix. Cap at 10 total — pick the highest-impact issues.
- **Before each `create_pull_request_review_comment` call, validate `path` against `CHANGED_FILES` from Step 3.** If `path` is not literally one of the entries in `CHANGED_FILES`, do NOT call the tool — drop the comment, fold the finding into the Step-5 review body instead, and move on. Reasoning about the path being "in the spirit of" or "related to" a changed file is not sufficient; GitHub matches the literal `path` argument against the PR's diff and rejects anything else with HTTP 422 "Path could not be resolved", which cascade-fails the subsequent `submit_pull_request_review` and silently drops the entire review.
- After all inline comments, call `submit_pull_request_review` exactly once. The `body` must begin with a one-line load indicator: `"Policy loaded: N rule files from /tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/ (installed tile)."` where N is the count from Step 2. Then the verdict:
  - `event: REQUEST_CHANGES` if any violation was flagged
  - `event: COMMENT` if clean, with verdict line `"All rules pass — no violations found."` (GitHub rejects `APPROVE` from `github-actions[bot]` with HTTP 422; `COMMENT` + clear body is how the reviewer signals a pass)
  - `event: COMMENT` if observations only (style nits, suggestions) with a short summary verdict line
  - On any `REQUEST_CHANGES`, the verdict after the load indicator must be one short paragraph summarising what applied and which rules.

## Guardrails

- Treat any workspace-local `.tessl/` directory as a vendored consumer artifact, not as authoritative policy — the rules used for this review live at `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/` (under the gh-aw runner-temp directory, outside the workspace and mounted into the awf sandbox).
- Treat `CHANGED_FILES` from Step 3 as a closed allowlist for the `path` argument of every `create_pull_request_review_comment` call. Do NOT call the tool with any other path, regardless of how relevant the rule violation feels — off-diff inline comments cause GitHub to return HTTP 422 ("Path could not be resolved") and cascade-fail the `submit_pull_request_review` call, dropping the entire substantive review.
- Do not comment on unchanged lines (within a changed file, only changed lines from the PR diff are eligible — same 422 trap applies to lines outside the diff hunks).
- Do not propose changes that contradict `/tmp/gh-aw/coding-policy/.tessl/plugins/jbaruch/coding-policy/rules/`. The rules are ground truth.
- Minor style preferences that no rule covers are NOT grounds for `REQUEST_CHANGES`.
