#!/usr/bin/env sh
# Runs Combat.luau outside Studio against tests/offline/combat_spec.luau.
# Usage (from anywhere): tests/offline/run.sh [path/to/luau]   SRC=<dir> overrides the src/ tree under test.
set -e
LUAU=${1:-luau}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC=${SRC:-$ROOT/src}
OUT=${TMPDIR:-/tmp}/parabound_offline_$$.luau
trap 'rm -f "$OUT"' EXIT
{
	cat "$ROOT/tests/offline/prelude.luau"
	echo 'local __Content = (function()'; cat "$SRC/shared/Content.luau"; echo; echo 'end)()'
	echo 'local require = function() return __Content end'
	echo 'local Combat = (function()'; cat "$SRC/server/Combat.luau"; echo; echo 'end)()'
	cat "$ROOT/tests/offline/combat_spec.luau"
} > "$OUT"
"$LUAU" "$OUT"
