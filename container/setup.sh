#!/usr/bin/env bash
# setup-all.sh — Complete setup for SUMOnix NixOS container demo
# Run this once to prepare the host for building and running the container.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "$ROOT/tools/env.sh"

log() { printf '\033[1;36m│\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }

# 1. Check prerequisites
log "Checking prerequisites..."

# Nix
if ! command -v nix >/dev/null 2>&1; then
  err "nix not found. Install with: sh <(curl -L https://nixos.org/nix/install) --daemon"
  exit 1
fi
ok "nix: $(nix --version)"

# Podman
if ! command -v podman >/dev/null 2>&1; then
  err "podman not found. Install with your package manager."
  exit 1
fi
ok "podman: $(podman --version)"

# Rootless Podman + cgroup v2 (setup-podman.sh enables these; it needs sudo,
# so it is not run from here — see the message below).
ROOTLESS_OK=1
CGROUP_OK=1
podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -q "true" || ROOTLESS_OK=0
stat -fc %T /sys/fs/cgroup 2>/dev/null | grep -q "cgroup2fs" || CGROUP_OK=0

if [ "$ROOTLESS_OK" -eq 0 ] || [ "$CGROUP_OK" -eq 0 ]; then
  err "Podman prerequisites are not met (rootless=$ROOTLESS_OK cgroup2=$CGROUP_OK)"
  echo
  echo "    Run ./setup-podman.sh once (it uses sudo), then log out and back in:"
  echo "      ./setup-podman.sh"
  echo "    Then re-run this script."
  exit 1
fi
ok "podman rootless: true"
ok "cgroup v2: active"

# 2. Ensure Nix experimental features are enabled
log "Configuring Nix..."
mkdir -p ~/.config/nix
if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
  echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
  ok "Added experimental-features to ~/.config/nix/nix.conf"
else
  ok "Nix experimental features already configured"
fi

# 3. Build the container image
mkdir -p "$ROOT/.logs" "$ROOT/.artifacts/container"
log "Building NixOS container image..."
export NIX_CONFIG="substituters = https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
sandbox = false
build-users-group ="

unset NIX_STORE_DIR
unset NIX_STATE_DIR

# The build uses the root store (--store local?root=...) so cache.nixos.org substitutes work
# This will take 5-30 minutes on first run depending on cache hits
nix --extra-experimental-features 'nix-command flakes' \
  --store "$SUMONIX_BUILD_STORE" \
  --max-jobs "${SUMONIX_MAX_JOBS:-4}" \
  build ".#nixosConfigurations.sumonix-container.config.system.build.tarball" \
  -o ".artifacts/container/result" \
  --print-out-paths 2>&1 | tee ".logs/build.log"

# The --store local?root=$SUMONIX_BUILD_ROOT keeps logical paths as /nix/store/...
# while the bytes live under the repo. Resolve the result symlink through it.
resolve_tarball() {
  local link="$1" target
  [ -e "$link" ] || { echo ""; return; }
  target="$(readlink "$link")"
  case "$target" in
    /nix/store/*) target="$SUMONIX_BUILD_ROOT$target" ;;
  esac
  find "$target" -name "*.tar.xz" -type f 2>/dev/null | head -1
}

# 4. Import into Podman
log "Importing into Podman..."
TARBALL="$(resolve_tarball ".artifacts/container/result")"
if [ -z "$TARBALL" ]; then
  err "Tarball not found"
  exit 1
fi

podman import --change 'CMD ["/sbin/init"]' "$TARBALL" "localhost/sumonix-demo:latest" 2>&1 | tee ".logs/import.log"

DIGEST=$(podman image inspect --format '{{.Digest}}' "localhost/sumonix-demo:latest")
SIZE=$(podman image inspect --format '{{.Size}}' "localhost/sumonix-demo:latest")

cat > ".artifacts/container/manifest.json" <<EOF
{
  "image": "localhost/sumonix-demo:latest",
  "digest": "$DIGEST",
  "size": $SIZE,
  "tarball": "$TARBALL",
  "built": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
}
EOF

ok "Image imported: localhost/sumonix-demo:latest"
ok "Digest: $DIGEST"
ok "Size: $(numfmt --to=iec-i --suffix=B $SIZE)"

log "Setup complete! Run the container with:"
echo "  ./demo/container.sh run"
echo "  ./demo/container.sh exec"