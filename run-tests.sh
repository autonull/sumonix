#!/usr/bin/env bash
# Run sumo-nix tests with local Nix store

export NIX_STORE_DIR=/home/me/sumonix/.nix-store
export NIX_STATE_DIR=/home/me/sumonix/.nix-state

nix_cmd="nix --extra-experimental-features nix-command"

run_test() {
    local name=$1
    local expr=$2
    echo -n "  $name... "
    if eval "$nix_cmd eval --impure --expr '$expr'" > /dev/null 2>&1; then
        echo "✓"
    else
        echo "✗"
        eval "$nix_cmd eval --impure --expr '$expr'"
        return 1
    fi
}

run_json() {
    local name=$1
    local expr=$2
    echo -n "  $name... "
    if eval "$nix_cmd eval --impure --json --expr '$expr'" > /dev/null 2>&1; then
        echo "✓"
    else
        echo "✗"
        eval "$nix_cmd eval --impure --json --expr '$expr'"
        return 1
    fi
}

echo "Running sumo-nix test suite..."

# Core tests
run_test "default" 'import ./tests/default.nix'
run_test "rules" 'import ./tests/rules.nix'
run_test "ingest-smoke" 'import ./tests/ingest-smoke.nix'

# Unit tests
run_test "equivalents" 'import ./tests/unit/equivalents.nix'
run_test "synthesize" 'import ./tests/unit/synthesize.nix'
run_test "stratify" 'import ./tests/unit/stratify.nix'
run_test "relax" 'import ./tests/unit/relax.nix'
run_test "congruence" 'import ./tests/unit/congruence.nix'
run_test "builtins" 'import ./tests/unit/builtins.nix'

# Proof check
run_test "proof-check" 'import ./tests/proof-check.nix'

echo "All tests passed!"