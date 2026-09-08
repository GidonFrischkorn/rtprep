#!/usr/bin/env bash
#
# Apply the repository's branch-protection rulesets and merge settings.
#
# Run this once, after the first CRAN release, and again whenever a file in
# .github/rulesets/ changes. It is idempotent: a ruleset whose name already
# exists on the remote is updated in place rather than duplicated.
#
#   ./.github/apply-repo-protection.sh --dry-run     # show what would change
#   ./.github/apply-repo-protection.sh               # apply main-protection
#   ./.github/apply-repo-protection.sh .github/rulesets/*.json   # all of them
#
# Requires the `gh` CLI, authenticated with an account that has admin rights
# on the repository (`gh auth status` must show the `repo` scope).
#
# NOTE ON THE BYPASS ACTOR. Each ruleset lists actor_id 5 / RepositoryRole,
# which is GitHub's base "admin" role. That is what lets the repository owner
# merge without a second approver while the package has a single developer.
# The script prints the bypass list back after applying so the resolved role
# can be read rather than assumed. A repository admin can always edit or
# delete a ruleset in Settings > Rules regardless of the bypass list, so a
# wrong value here cannot lock anyone out.

set -euo pipefail

DRY_RUN=false
FILES=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) FILES+=("$arg") ;;
  esac
done

if [ ${#FILES[@]} -eq 0 ]; then
  FILES=("$(dirname "$0")/rulesets/main-protection.json")
fi

command -v gh >/dev/null 2>&1 || { echo "error: the gh CLI is not installed" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "error: gh is not authenticated" >&2; exit 1; }

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "repository: $REPO"
echo

# ---------------------------------------------------------------- merge settings
# Squash-only, so main carries one commit per feature and stays linear; merged
# branches are deleted automatically; auto-merge lets a pull request be queued
# to land as soon as the required checks come back green.
echo "== merge settings =="
if [ "$DRY_RUN" = true ]; then
  echo "would set: allow_squash_merge=true allow_merge_commit=false \\"
  echo "           allow_rebase_merge=false delete_branch_on_merge=true \\"
  echo "           allow_auto_merge=true"
else
  gh api --method PATCH "repos/$REPO" \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    -F delete_branch_on_merge=true \
    -F allow_auto_merge=true \
    --jq '"squash=\(.allow_squash_merge) merge_commit=\(.allow_merge_commit) rebase=\(.allow_rebase_merge) delete_branch=\(.delete_branch_on_merge) auto_merge=\(.allow_auto_merge)"'
fi
echo

# -------------------------------------------------------------------- rulesets
for file in "${FILES[@]}"; do
  [ -f "$file" ] || { echo "error: no such file: $file" >&2; exit 1; }
  name=$(jq -r .name "$file")
  echo "== ruleset: $name  ($file) =="

  existing=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$name\") | .id" | head -n 1)

  if [ "$DRY_RUN" = true ]; then
    if [ -n "$existing" ]; then
      echo "would update existing ruleset $existing"
    else
      echo "would create a new ruleset"
    fi
    jq -r '.rules[] | "  rule: \(.type)"' "$file"
    continue
  fi

  if [ -n "$existing" ]; then
    id=$(gh api --method PUT "repos/$REPO/rulesets/$existing" --input "$file" --jq .id)
    echo "updated ruleset $id"
  else
    id=$(gh api --method POST "repos/$REPO/rulesets" --input "$file" --jq .id)
    echo "created ruleset $id"
  fi

  # Read the ruleset back rather than trusting the payload: this is where a
  # wrong bypass actor id or a mistyped status-check context becomes visible.
  gh api "repos/$REPO/rulesets/$id" --jq '
    "  enforcement: \(.enforcement)",
    "  applies to:  \(.conditions.ref_name.include | join(", "))",
    (.bypass_actors[]? | "  bypass:      \(.actor_type) id=\(.actor_id) (\(.bypass_mode))"),
    (.rules[] | "  rule:        \(.type)"),
    (.rules[] | select(.type == "required_status_checks")
       | .parameters.required_status_checks[]
       | "  must pass:   \(.context)")'
  echo
done

if [ "$DRY_RUN" = false ]; then
  cat <<'EOF'
Done. Two things to confirm by hand in Settings > Rules:

  1. Every "must pass" context above matches a check name that actually runs
     on pull requests. A context that never reports leaves pull requests
     waiting for a check that will never arrive.
  2. The bypass row reads "Repository admin". If it does not, fix actor_id in
     the JSON and re-run; the ruleset can always be edited in the web UI.
EOF
fi
