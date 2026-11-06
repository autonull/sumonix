#!/usr/bin/env bash
# demo/container.sh — Build, run, exec, tour, and teardown the SUMOnix NixOS container.
#
# Usage:
#   ./demo/container.sh --check       # Read-only: check prerequisites (no downloads)
#   ./demo/container.sh --estimate    # Dry-run build: report sizes (no downloads)
#   ./demo/container.sh build         # Build container image, import to Podman
#   ./demo/container.sh run           # Start container (detached, systemd as PID 1)
#   ./demo/container.sh exec          # Log in as demo user (interactive)
#   ./demo/container.sh --tour        # Run scripted tour inside container
#   ./demo/container.sh --teardown    # Stop container, clean up Podman storage

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/env.sh"

CONTAINER_DIR="$ROOT/container"
ARTIFACTS_DIR="$ROOT/.artifacts/container"
RUNTIME_DIR="$ROOT/.runtime/podman"
LOGS_DIR="$ROOT/.logs"
MANIFEST_FILE="$ARTIFACTS_DIR/manifest.json"
IMAGE_NAME="localhost/sumonix-demo:latest"
CONTAINER_NAME="sumonix-demo"

# Storage configuration for Podman (keeps everything in .runtime/)
export CONTAINERS_STORAGE_CONF="$RUNTIME_DIR/storage.conf"
export CONTAINER_RUNROOT="$RUNTIME_DIR/runroot"

mkdir -p "$ARTIFACTS_DIR" "$RUNTIME_DIR/storage" "$RUNTIME_DIR/runroot" "$LOGS_DIR"

# Create Podman storage.conf if not exists
if [ ! -f "$CONTAINERS_STORAGE_CONF" ]; then
  cat > "$CONTAINERS_STORAGE_CONF" <<EOF
[storage]
driver = "overlay"
graphroot = "$RUNTIME_DIR/storage"
runroot = "$RUNTIME_DIR/runroot"
[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
fi

log() {
  printf '\033[1;36m│\033[0m %s\n' "$*"
}

cmd() {
  printf '\033[1;32m$\033[0m %s\n' "$*"
}

err() {
  printf '\033[1;31m✗\033[0m %s\n' "$*" >&2
}

ok() {
  printf '\033[1;32m✓\033[0m %s\n' "$*"
}

check_prerequisites() {
  log "Checking prerequisites..."

  local ok=0

  # Nix
  if command -v nix >/dev/null 2>&1; then
    ok "nix: $(nix --version)"
  else
    err "nix: not found on PATH"
    ok=1
  fi

  # Podman
  if command -v podman >/dev/null 2>&1; then
    ok "podman: $(podman --version)"
  else
    err "podman: not found on PATH"
    ok=1
  fi

  # Rootless Podman
  if podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -q "true"; then
    ok "podman rootless: true"
  else
    err "podman rootless: false (need user namespaces, subuid/subgid, cgroup v2 delegation)"
    ok=1
  fi

  # cgroup v2
  if stat -fc %T /sys/fs/cgroup 2>/dev/null | grep -q "cgroup2fs"; then
    ok "cgroup v2: active"
  else
    err "cgroup v2: not active (need cgroup v2 delegation)"
    ok=1
  fi

  # Podman systemd smoke test (without pulling image)
  if podman run --rm --systemd=always "$IMAGE_NAME" true 2>/dev/null; then
    ok "podman --systemd=always: works"
  else
    log "podman --systemd=always: not tested (image not built yet)"
  fi

  # Disk space
  local avail=$(df -BG "$ROOT" | tail -1 | awk '{print $4}' | sed 's/G//')
  if [ "$avail" -gt 10 ]; then
    ok "disk space: ${avail}G available"
  else
    err "disk space: only ${avail}G available (need >10G)"
    ok=1
  fi

  # QEMU check (should NOT be used)
  if command -v qemu-system-x86_64 >/dev/null 2>&1; then
    log "qemu-system-x86_64: present (will NOT be used)"
  else
    ok "qemu-system-x86_64: not present (good)"
  fi

  return "$ok"
}

estimate_build() {
  log "Estimating build (dry-run, no download)..."
  cmd "nix build --dry-run --json --store $SUMONIX_BUILD_STORE .#nixosConfigurations.sumonix-container.config.system.build.tarball"
  nix --extra-experimental-features 'nix-command flakes' \
    --store "$SUMONIX_BUILD_STORE" \
    build --dry-run --json \
    "$ROOT#nixosConfigurations.sumonix-container.config.system.build.tarball" \
    > "$LOGS_DIR/estimate.json" 2> "$LOGS_DIR/estimate.log" || {
      err "estimate failed; see $LOGS_DIR/estimate.log"
      exit 1
    }

  if command -v jq >/dev/null 2>&1; then
    local nar
    nar=$(jq '[.[] | (.narSize // 0)] | add' "$LOGS_DIR/estimate.json")
    log "Closure NAR size to build: $(numfmt --to=iec-i --suffix=B "$nar")"
    log "Paths to build: $(jq 'length' "$LOGS_DIR/estimate.json")"
  else
    log "wrote $LOGS_DIR/estimate.json (install jq for a size summary)"
  fi
  log "Disk available: $(df -h "$ROOT" | tail -1 | awk '{print $4}')"
}

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

build_container() {
  log "Building NixOS container image..."

  export NIX_CONFIG="substituters = ${SUMONIX_SUBSTITUTERS}
trusted-public-keys = ${SUMONIX_TRUSTED_KEYS}
sandbox = false
build-users-group ="

  # Unset NIX_STORE_DIR/NIX_STATE_DIR to ensure --store is respected
  unset NIX_STORE_DIR
  unset NIX_STATE_DIR

  cmd "nix build --store $SUMONIX_BUILD_STORE --max-jobs ${SUMONIX_MAX_JOBS:-4} $ROOT#nixosConfigurations.sumonix-container.config.system.build.tarball -o $ARTIFACTS_DIR/result --print-out-paths"

  nix --extra-experimental-features 'nix-command flakes' \
    --store "$SUMONIX_BUILD_STORE" \
    --max-jobs "${SUMONIX_MAX_JOBS:-4}" \
    build "$ROOT#nixosConfigurations.sumonix-container.config.system.build.tarball" \
    -o "$ARTIFACTS_DIR/result" \
    --print-out-paths 2>&1 | tee "$LOGS_DIR/build.log"

  # Find the tarball
  local tarball
  tarball="$(resolve_tarball "$ARTIFACTS_DIR/result")"
  if [ -z "$tarball" ]; then
    err "Tarball not found in $ARTIFACTS_DIR/result"
    exit 1
  fi

  log "Tarball: $tarball"

  # Import into Podman
  log "Importing into Podman..."
  cmd "podman import --change 'CMD [\"/sbin/init\"]' $tarball $IMAGE_NAME"
  podman import --change 'CMD ["/sbin/init"]' "$tarball" "$IMAGE_NAME" 2>&1 | tee "$LOGS_DIR/import.log"

  # Record manifest
  local digest=$(podman image inspect --format '{{.Digest}}' "$IMAGE_NAME")
  local size=$(podman image inspect --format '{{.Size}}' "$IMAGE_NAME")
  cat > "$MANIFEST_FILE" <<EOF
{
  "image": "$IMAGE_NAME",
  "digest": "$digest",
  "size": $size,
  "tarball": "$tarball",
  "built": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "nixpkgs_revision": "$(nix flake metadata --json "$ROOT" 2>/dev/null | jq -r '.locks.nodes.nixpkgs.locked.rev' || echo 'unknown')"
}
EOF

  ok "Image imported: $IMAGE_NAME"
  ok "Digest: $digest"
  ok "Size: $(numfmt --to=iec-i --suffix=B $size)"
  ok "Manifest: $MANIFEST_FILE"
}

run_container() {
  local attach="${1:-false}"

  if ! podman image exists "$IMAGE_NAME"; then
    err "Image not found. Run './demo/container.sh build' first."
    exit 1
  fi

  log "Starting container..."
  local run_args=(
    --name "$CONTAINER_NAME"
    --systemd=always
    --memory=2g --cpus=2
    --rm
  )

  if [ "$attach" = "true" ]; then
    run_args+=(-it)
  else
    run_args+=(-d)
  fi

  run_args+=("$IMAGE_NAME")

  cmd "podman run ${run_args[*]}"
  podman run "${run_args[@]}" 2>&1 | tee "$LOGS_DIR/run.log"

  if [ "$attach" = "false" ]; then
    # Wait for systemd to be running
    log "Waiting for systemd to report 'running'..."
    local timeout=60
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
      if podman exec "$CONTAINER_NAME" systemctl is-system-running 2>/dev/null | grep -q "running"; then
        ok "systemd is running"
        break
      fi
      sleep 2
      elapsed=$((elapsed + 2))
    done

    if [ $elapsed -ge $timeout ]; then
      err "Timeout waiting for systemd"
      podman exec "$CONTAINER_NAME" systemctl --failed
      exit 1
    fi

    log "Container started: $CONTAINER_NAME"
    log "Log in with: ./demo/container.sh exec"
  fi
}

exec_container() {
  if ! podman container exists "$CONTAINER_NAME"; then
    err "Container not running. Run './demo/container.sh run' first."
    exit 1
  fi

  log "Entering container as demo user..."
  podman exec -it -u demo "$CONTAINER_NAME" bash -l
}

tour_container() {
  if ! podman container exists "$CONTAINER_NAME"; then
    err "Container not running. Run './demo/container.sh run' first."
    exit 1
  fi

  log "Running scripted tour inside container..."

  # Run the tour script
  podman exec -it -u demo "$CONTAINER_NAME" bash -lc 'source /run/sumo/tour.sh' 2>&1 | tee "$LOGS_DIR/tour.log"
}

teardown_container() {
  log "Tearing down container..."

  if podman container exists "$CONTAINER_NAME"; then
    cmd "podman stop $CONTAINER_NAME"
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    cmd "podman rm -f $CONTAINER_NAME"
    podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
  fi

  # Clean up Podman storage
  if [ -d "$RUNTIME_DIR" ]; then
    cmd "rm -rf $RUNTIME_DIR"
    rm -rf "$RUNTIME_DIR"
  fi

  ok "Teardown complete"
}

# Main command dispatch
cmd="${1:-}"
shift || true

case "$cmd" in
  --check)
    check_prerequisites
    ;;
  --estimate)
    estimate_build
    ;;
  build)
    build_container
    ;;
  run)
    run_container false
    ;;
  run-attach)
    run_container true
    ;;
  exec)
    exec_container
    ;;
  --tour)
    tour_container
    ;;
  --teardown)
    teardown_container
    ;;
  *)
    echo "Usage: $0 {--check|--estimate|build|run|run-attach|exec|--tour|--teardown}"
    echo ""
    echo "  --check       Read-only: check prerequisites (nix, podman rootless, cgroup v2)"
    echo "  --estimate    Dry-run build: report download/image sizes"
    echo "  build         Build NixOS container image and import to Podman"
    echo "  run           Start container detached (systemd as PID 1)"
    echo "  run-attach    Start container in foreground (attached)"
    echo "  exec          Log in as demo user (interactive)"
    echo "  --tour        Run scripted tour inside container"
    echo "  --teardown    Stop container, clean up Podman storage"
    exit 1
    ;;
esac