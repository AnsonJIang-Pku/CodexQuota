#!/bin/sh

# BetterTouchTool should receive exactly one quiet line. Build once with:
# swift build -c release --product codex-quota-cli

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
CLI="$PROJECT_DIR/.build/release/codex-quota-cli"

if [ ! -x "$CLI" ]; then
    printf '%s\n' 'Cdx --'
    exit 1
fi

"$CLI" 2>/dev/null
