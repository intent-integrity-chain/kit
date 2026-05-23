#!/usr/bin/env bash
# BASH 3.2 REQUIRED — no associative arrays, no mapfile
#
# Remove intent-integrity-kit scaffolding from a project so `tessl uninstall`
# does not leave broken hooks, orphaned `.specify/`, or stale tile artifacts
# behind. Designed to be run BEFORE `tessl uninstall tessl-labs/intent-integrity-kit`,
# while the tile is still installed and the skill is reachable.
#
# Auto-removes (tile-managed scaffolding):
#   - .git/hooks/pre-commit  (when marked IIKIT-PRE-COMMIT)
#   - .git/hooks/post-commit (when marked IIKIT-POST-COMMIT)
#   - .git/hooks/iikit-pre-commit, iikit-post-commit (alongside installs)
#   - "IIKit assertion integrity check" chain-call lines from any other hook
#   - .specify/ directory entirely
#   - TECH.md (only when it contains an iikit phase reference)
#
# Reports as user-authored (caller chooses what to do with these):
#   - CONSTITUTION.md
#   - PREMISE.md
#   - specs/
#
# Usage:
#   uninit.sh [--json] [--dry-run] [--remove-user-content]
#
# --dry-run            list what would change without modifying anything
# --remove-user-content also delete CONSTITUTION.md, PREMISE.md, specs/
#
# Output: JSON with `removed` (paths actually deleted/modified),
#         `user_content` (paths the caller must decide on), and
#         `next_step` (the literal `tessl uninstall ...` command to run).

set -u

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
DRY_RUN=false
REMOVE_USER_CONTENT=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --dry-run) DRY_RUN=true ;;
        --remove-user-content) REMOVE_USER_CONTENT=true ;;
        --help|-h)
            sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

REPO_ROOT="$(get_repo_root)"

# Resolve hooks directory via `git rev-parse --git-path hooks` so linked
# worktrees and submodules (where `.git` is a file pointing at the gitdir)
# find the real hooks dir — typically the main repo's `.git/hooks/` or
# `.git/modules/<name>/hooks/` for submodules.
HOOKS_REL="$(git -C "$REPO_ROOT" rev-parse --git-path hooks 2>/dev/null)"
case "$HOOKS_REL" in
    /*) HOOKS_DIR="$HOOKS_REL" ;;
    "") HOOKS_DIR="$REPO_ROOT/.git/hooks" ;;
    *)  HOOKS_DIR="$REPO_ROOT/$HOOKS_REL" ;;
esac

REMOVED=()
USER_CONTENT=()
ERRORS=()

# Track an action that would be taken; perform it unless --dry-run.
record_remove() {
    REMOVED+=("$1")
}

record_error() {
    ERRORS+=("$1")
    printf '[uninit] ERROR: %s\n' "$1" >&2
}

remove_file() {
    local path="$1"
    local rel="${path#"$REPO_ROOT/"}"
    if [[ -e "$path" || -L "$path" ]]; then
        if $DRY_RUN; then
            record_remove "$rel"
            return 0
        fi
        if rm -f "$path" 2>/dev/null && [[ ! -e "$path" && ! -L "$path" ]]; then
            record_remove "$rel"
        else
            record_error "failed to remove $rel — check that you have write permission on the parent directory, then delete '$rel' manually before running \`tessl uninstall\`"
        fi
    fi
}

remove_dir() {
    local path="$1"
    local rel="${path#"$REPO_ROOT/"}"
    if [[ -d "$path" ]]; then
        if $DRY_RUN; then
            record_remove "$rel"
            return 0
        fi
        if rm -rf "$path" 2>/dev/null && [[ ! -d "$path" ]]; then
            record_remove "$rel"
        else
            record_error "failed to remove $rel — close any process holding files inside it, check directory permissions, then delete '$rel' manually before running \`tessl uninstall\`"
        fi
    fi
}

# Strip iikit chain-call lines from a non-iikit hook in place.
# Looks for the literal "# IIKit assertion integrity check" comment and the
# immediately-following call line that invokes iikit-pre-commit / iikit-post-commit.
strip_chain_call() {
    local hook="$1"
    local hook_name="$2"
    local rel="${hook#"$REPO_ROOT/"}"
    [[ -f "$hook" ]] || return 0
    # Require BOTH the marker comment line and the chain-call invocation.
    # Gating on the call line alone would flag a user hook that merely
    # mentions `iikit-pre-commit` in a comment, leading to a misleading
    # `(stripped iikit chain-call)` report on a file the script did not change.
    grep -qF '# IIKit assertion integrity check' "$hook" 2>/dev/null || return 0
    grep -q "iikit-$hook_name" "$hook" 2>/dev/null || return 0

    if $DRY_RUN; then
        record_remove "$rel (stripped iikit chain-call)"
        return 0
    fi

    local tmp
    if ! tmp="$(mktemp 2>/dev/null)"; then
        record_error "could not create temp file while rewriting $rel — check that \$TMPDIR (or /tmp) is writable and has free space, then re-run \`/iikit-core uninit\`"
        return 1
    fi

    if ! awk -v name="iikit-$hook_name" '
        /^# IIKit assertion integrity check$/ { skip = 2; next }
        skip > 0 && $0 ~ name { skip--; next }
        skip > 0 && /^$/      { skip--; next }
        { print }
    ' "$hook" > "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        record_error "awk failed while filtering $rel — strip the '# IIKit assertion integrity check' block and the following iikit-$hook_name call line by hand, then re-run \`/iikit-core uninit\`"
        return 1
    fi

    if ! mv "$tmp" "$hook" 2>/dev/null; then
        rm -f "$tmp"
        record_error "could not overwrite $rel — check write permission on the .git/hooks directory, then re-run \`/iikit-core uninit\`"
        return 1
    fi

    if ! chmod +x "$hook" 2>/dev/null; then
        record_error "could not restore exec bit on $rel — run \`chmod +x $rel\` manually so the hook still fires on commit"
        return 1
    fi

    record_remove "$rel (stripped iikit chain-call)"
}

# Hook handling: marker-owned hooks deleted outright; otherwise strip chain-call.
handle_hook() {
    local hook_name="$1"
    local marker="$2"
    local hook="$HOOKS_DIR/$hook_name"

    if [[ -f "$hook" ]] && grep -q "$marker" "$hook" 2>/dev/null; then
        remove_file "$hook"
    else
        strip_chain_call "$hook" "$hook_name"
    fi
    remove_file "$HOOKS_DIR/iikit-$hook_name"
}

if [[ -d "$HOOKS_DIR" ]]; then
    handle_hook "pre-commit"  "IIKIT-PRE-COMMIT"
    handle_hook "post-commit" "IIKIT-POST-COMMIT"
fi

# pre-commit.d/: remove our IIKIT-PRE-COMMIT-D README; report everything else as
# user content; drop the dir only when truly empty. `find` includes dotfiles so
# stray `.keep` / editor scratch files don't get silently rm -rf'd. Uses the
# same `$HOOKS_DIR` as the hook removal above — both are git-resolved so they
# stay in lockstep across main checkouts, linked worktrees, and submodules.
PRECOMMIT_D="$HOOKS_DIR/pre-commit.d"
if [[ -d "$PRECOMMIT_D" ]]; then
    PRECOMMIT_D_README="$PRECOMMIT_D/README"
    PRECOMMIT_D_README_HANDLED=false
    if [[ -f "$PRECOMMIT_D_README" ]] && grep -q 'IIKIT-PRE-COMMIT-D' "$PRECOMMIT_D_README" 2>/dev/null; then
        remove_file "$PRECOMMIT_D_README"
        # Only treat the README as handled when it's actually gone (or in
        # --dry-run, where it stays on disk but is logically removed). A failed
        # remove_file leaves the file in place and we want subsequent emptiness
        # detection to see it.
        if $DRY_RUN || [[ ! -f "$PRECOMMIT_D_README" ]]; then
            PRECOMMIT_D_README_HANDLED=true
        fi
    fi
    remaining=0
    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        # Skip the iikit-managed README we already recorded for removal.
        # `--dry-run` leaves it on disk so `find` would otherwise double-count
        # it as user content AND keep `remaining` > 0.
        if [[ "$PRECOMMIT_D_README_HANDLED" == true && "$entry" == "$PRECOMMIT_D_README" ]]; then
            continue
        fi
        # Strip REPO_ROOT prefix when applicable; otherwise keep the absolute
        # path (worktrees/submodules: hooks dir lives outside the working tree).
        if [[ "$entry" == "$REPO_ROOT"/* ]]; then
            rel="${entry#"$REPO_ROOT/"}"
        else
            rel="$entry"
        fi
        USER_CONTENT+=("$rel")
        remaining=$((remaining + 1))
    done < <(find "$PRECOMMIT_D" -mindepth 1 -maxdepth 1 -print 2>/dev/null)
    if [[ "$remaining" -eq 0 ]]; then
        remove_dir "$PRECOMMIT_D"
    fi
fi

remove_dir "$REPO_ROOT/.specify"

# TECH.md: only remove when it carries an iikit phase reference.
TECH_MD="$REPO_ROOT/TECH.md"
if [[ -f "$TECH_MD" ]] && grep -qE '/iikit-[0-9]{2}-' "$TECH_MD" 2>/dev/null; then
    remove_file "$TECH_MD"
fi

# User-authored artifacts: report them; caller decides.
check_user_content() {
    local path="$1"
    if [[ -e "$path" ]]; then
        if $REMOVE_USER_CONTENT; then
            if [[ -d "$path" ]]; then
                remove_dir "$path"
            else
                remove_file "$path"
            fi
        else
            USER_CONTENT+=("${path#"$REPO_ROOT/"}")
        fi
    fi
}

check_user_content "$REPO_ROOT/CONSTITUTION.md"
check_user_content "$REPO_ROOT/PREMISE.md"
check_user_content "$REPO_ROOT/specs"

# Output
join_json_array() {
    local first=true
    printf '['
    for item in "$@"; do
        $first || printf ','
        first=false
        printf '"%s"' "$(printf '%s' "$item" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    done
    printf ']'
}

NEXT_STEP="tessl uninstall tessl-labs/intent-integrity-kit"

if $JSON_MODE; then
    printf '{"dry_run":%s,"removed":%s,"user_content":%s,"errors":%s,"next_step":"%s"}\n' \
        "$DRY_RUN" \
        "$(join_json_array "${REMOVED[@]+"${REMOVED[@]}"}")" \
        "$(join_json_array "${USER_CONTENT[@]+"${USER_CONTENT[@]}"}")" \
        "$(join_json_array "${ERRORS[@]+"${ERRORS[@]}"}")" \
        "$NEXT_STEP"
else
    if $DRY_RUN; then
        echo "[uninit] DRY RUN — no files changed"
    fi
    if [[ ${#REMOVED[@]} -gt 0 ]]; then
        echo "[uninit] Removed:"
        for path in "${REMOVED[@]}"; do echo "  - $path"; done
    else
        echo "[uninit] No tile-managed scaffolding found."
    fi
    if [[ ${#USER_CONTENT[@]} -gt 0 ]]; then
        echo ""
        echo "[uninit] User-authored content kept (re-run with --remove-user-content to delete):"
        for path in "${USER_CONTENT[@]}"; do echo "  - $path"; done
    fi
    echo ""
    echo "[uninit] Next: $NEXT_STEP"
fi

# Exit non-zero when any removal failed, so callers see a real failure signal.
[[ ${#ERRORS[@]} -eq 0 ]] || exit 1
