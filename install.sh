#!/usr/bin/env bash
# Installs or updates the agent protocol in the current project.
#
# Run it from the top folder of a git repository:
#
#   curl -fsSL https://raw.githubusercontent.com/starscream000/agent-protocol/main/install.sh | bash
#
# or, from a local copy of agent-protocol:
#
#   /path/to/agent-protocol/install.sh
#
# Protocol-owned files (.agents/) are overwritten with the newest version.
# Project-owned files (CLAUDE.md, docs/, tasks/, reports/) are created only
# if they are missing. Nothing is committed; review the changes and commit
# them yourself.

set -euo pipefail

REPO="starscream000/agent-protocol"
BRANCH="main"
MARKER="<!-- agent-protocol:start -->"

say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# --- Where are we installing? ------------------------------------------------

TARGET="$(pwd)"
TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" \
  || die "this folder is not inside a git repository. Run 'git init' first."
[ "$TOP" = "$TARGET" ] \
  || die "run this from the top folder of the repository: $TOP"

# --- Where do the protocol files come from? ----------------------------------

SRC=""
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
  SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
  if [ -d "$SELF_DIR/scaffold" ] && [ -f "$SELF_DIR/.agents/PROTOCOL.md" ]; then
    SRC="$SELF_DIR"
  fi
fi

if [ -z "$SRC" ]; then
  command -v curl >/dev/null || die "curl is needed to download the protocol"
  command -v tar  >/dev/null || die "tar is needed to unpack the protocol"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  say "Downloading agent-protocol ($BRANCH)…"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" \
    | tar -xz -C "$TMP" --strip-components=1 \
    || die "download failed. Check your connection and try again."
  SRC="$TMP"
fi

[ "$SRC" != "$TARGET" ] \
  || die "this is the agent-protocol repository itself. Run the script inside the project you want to set up."
[ -f "$SRC/.agents/VERSION" ] || die "the protocol source looks incomplete: $SRC"

NEW_VERSION="$(tr -d '[:space:]' < "$SRC/.agents/VERSION")"
OLD_VERSION="none"
[ -f "$TARGET/.agents/VERSION" ] \
  && OLD_VERSION="$(tr -d '[:space:]' < "$TARGET/.agents/VERSION")"

# --- Protocol-owned files: always replaced ------------------------------------

mkdir -p "$TARGET/.agents"
rm -rf "$TARGET/.agents/templates"
mkdir -p "$TARGET/.agents/templates"
cp "$SRC/.agents/PROTOCOL.md" "$TARGET/.agents/PROTOCOL.md"
cp "$SRC/.agents/VERSION"     "$TARGET/.agents/VERSION"
cp "$SRC/.agents/templates/"* "$TARGET/.agents/templates/"

# --- Project-owned files: created only if missing -----------------------------

CREATED=()
KEPT=()

while IFS= read -r -d '' FILE; do
  REL="${FILE#"$SRC/scaffold/"}"
  DEST="$TARGET/$REL"
  DEST_DIR="$(dirname "$DEST")"

  if [ "$(basename "$REL")" = ".gitkeep" ]; then
    # A placeholder so git keeps an empty folder. Skip if the folder
    # already exists.
    if [ ! -d "$DEST_DIR" ]; then
      mkdir -p "$DEST_DIR"
      cp "$FILE" "$DEST"
      CREATED+=("$(dirname "$REL")/")
    fi
    continue
  fi

  if [ -e "$DEST" ]; then
    KEPT+=("$REL")
  else
    mkdir -p "$DEST_DIR"
    cp "$FILE" "$DEST"
    CREATED+=("$REL")
  fi
done < <(find "$SRC/scaffold" -type f -print0 | sort -z)

# --- Existing CLAUDE.md: add the pointer to the protocol once -----------------

CLAUDE_NOTE=""
if [ -f "$TARGET/CLAUDE.md" ] && ! grep -qF "$MARKER" "$TARGET/CLAUDE.md"; then
  {
    printf '\n'
    sed -n '/<!-- agent-protocol:start -->/,/<!-- agent-protocol:end -->/p' \
      "$SRC/scaffold/CLAUDE.md"
  } >> "$TARGET/CLAUDE.md"
  CLAUDE_NOTE="Added the protocol pointer to the end of your existing CLAUDE.md."
fi

# --- Summary -----------------------------------------------------------------

say ""
if [ "$OLD_VERSION" = "none" ]; then
  say "Agent protocol $NEW_VERSION installed."
elif [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
  say "Agent protocol $NEW_VERSION re-installed (already on this version)."
else
  say "Agent protocol updated: $OLD_VERSION -> $NEW_VERSION."
fi

say ""
say "Replaced (protocol-owned):"
say "  .agents/PROTOCOL.md"
say "  .agents/VERSION"
say "  .agents/templates/"

if [ "${#CREATED[@]}" -gt 0 ]; then
  say ""
  say "Created (yours to edit):"
  for ITEM in "${CREATED[@]}"; do say "  $ITEM"; done
fi

if [ "${#KEPT[@]}" -gt 0 ]; then
  say ""
  say "Left untouched (already existed):"
  for ITEM in "${KEPT[@]}"; do say "  $ITEM"; done
fi

if [ -n "$CLAUDE_NOTE" ]; then
  say ""
  say "$CLAUDE_NOTE"
fi

say ""
say "Nothing was committed. Review with 'git status', then commit with:"
say "  git add -A && git commit -m \"protocol: install v$NEW_VERSION\""
