#!/usr/bin/env bash
# Prepare a release: bump VERSION, roll the CHANGELOG's Unreleased section into
# a dated entry, and print the git commands to run.
#
#   scripts/release.sh 0.2.0
#   scripts/release.sh minor      # patch | minor | major
#
# This script only edits files. It never commits, tags or pushes — it prints
# those commands for you to run yourself.
set -euo pipefail

cd "$(dirname "$0")/.."

REPO_URL="https://github.com/tangent160/libation-docker-ui"
CURRENT="$(tr -d '[:space:]' < VERSION)"

die() { echo "error: $*" >&2; exit 1; }

[[ $# -eq 1 ]] || die "usage: $(basename "$0") <version|patch|minor|major>"

case "$1" in
    major|minor|patch)
        IFS=. read -r maj min pat <<<"$CURRENT"
        [[ "$maj" =~ ^[0-9]+$ && "$min" =~ ^[0-9]+$ && "$pat" =~ ^[0-9]+$ ]] \
            || die "cannot bump non-numeric current version '$CURRENT'"
        case "$1" in
            major) NEW="$((maj + 1)).0.0" ;;
            minor) NEW="$maj.$((min + 1)).0" ;;
            patch) NEW="$maj.$min.$((pat + 1))" ;;
        esac
        ;;
    *)
        NEW="${1#v}"
        [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] \
            || die "'$NEW' is not a semantic version (e.g. 1.2.3)"
        ;;
esac

[[ "$NEW" != "$CURRENT" ]] || die "version is already $NEW"
if git rev-parse "v$NEW" >/dev/null 2>&1; then
    die "tag v$NEW already exists"
fi

grep -q '^## \[Unreleased\]' CHANGELOG.md || die "CHANGELOG.md has no '## [Unreleased]' section"

# Refuse to cut a release with nothing written down.
if ! awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f && NF' CHANGELOG.md | grep -q .; then
    die "the Unreleased section of CHANGELOG.md is empty — describe the changes first"
fi

TODAY="$(date +%F)"

echo "$NEW" > VERSION

python3 - "$NEW" "$CURRENT" "$TODAY" "$REPO_URL" <<'PY'
import re, sys

new, current, today, repo = sys.argv[1:5]
text = open("CHANGELOG.md").read()

# Open a fresh Unreleased section above the newly dated one.
text = text.replace(
    "## [Unreleased]",
    f"## [Unreleased]\n\n## [{new}] - {today}",
    1,
)

# Repoint the Unreleased compare link and add one for the new version.
text = re.sub(
    r"^\[Unreleased\]: .*$",
    f"[Unreleased]: {repo}/compare/v{new}...HEAD\n"
    f"[{new}]: {repo}/compare/v{current}...v{new}",
    text,
    count=1,
    flags=re.M,
)

open("CHANGELOG.md", "w").write(text)
PY

echo "Prepared $CURRENT -> $NEW"
echo
echo "Review the diff, then:"
echo
echo "  git add VERSION CHANGELOG.md"
echo "  git commit -m 'release: v$NEW'"
echo "  git tag -a v$NEW -m 'v$NEW'"
echo "  git push origin main v$NEW"
echo
echo "Pushing the tag is what builds and publishes the image."
