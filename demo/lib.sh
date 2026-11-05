# Shared helpers for the demo scenes. Sourced by every scene script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/env.sh"

say()  { printf '\033[1;36m│\033[0m %s\n' "$*"; }
cmd()  { printf '\033[1;32m$\033[0m %s\n' "$*"; }
rule() { printf '\033[1;34m%s\033[0m\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
banner() { printf '\033[1;35m%s\033[0m\n' "$*"; }
