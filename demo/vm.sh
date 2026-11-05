#!/usr/bin/env bash
# demo/vm.sh — Build, boot, record, and manage the sumonix demo VM.
#
# Usage:
#   ./demo/vm.sh build       # Build the VM (one repack, system.build.vm)
#   ./demo/vm.sh boot        # Boot the VM interactively (headless, serial console)
#   ./demo/vm.sh --record    # Boot, run scripted tour, capture asciicast
#   ./demo/vm.sh --check     # Check KVM availability, exit 0 if available, SKIP otherwise
#   ./demo/vm.sh --teardown  # Clean up VM processes

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/env.sh"
VM_DIR="$ROOT/demo/vm"
BUILD_SCRIPT="$VM_DIR/build.sh"
VM_RESULT="$VM_DIR/result-vm"
TOUR_SCRIPT="$VM_DIR/session.sh"
CAST_OUTPUT="$ROOT/docs/demo/tour.cast"

# Hard timeout for VM operations (5 minutes)
VM_TIMEOUT=300

# Exit trap to kill QEMU
cleanup() {
  local pids=$(jobs -p)
  if [ -n "$pids" ]; then
    kill $pids 2>/dev/null || true
    wait $pids 2>/dev/null || true
  fi
}
trap cleanup EXIT

check_kvm() {
  local ok=0
  if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "KVM: available"
  else
    echo "KVM: MISSING (/dev/kvm not read-write) — the VM will not boot"
    ok=1
  fi

  # Nix needs mount namespaces to build in the repo-local root store
  # (logical /nix/store). Without them, substitutes work but builds do not.
  if unshare -r true 2>/dev/null; then
    echo "user namespaces: available"
  else
    echo "user namespaces: UNAVAILABLE"
    echo "  Nix cannot build in a diverted store without mount namespaces."
    echo "  Substitution still works into ${SUMONIX_BUILD_ROOT}/nix/store."
    echo "  To enable: sudo sysctl -w kernel.unprivileged_userns_clone=1"
    ok=1
  fi

  if [ "$ok" -ne 0 ]; then
    echo "SKIP: VM build/boot prerequisites not met"
  fi
  return "$ok"
}

build_vm() {
  echo "Building VM..."
  bash "$BUILD_SCRIPT"
}

boot_vm() {
  if [ ! -d "$VM_RESULT" ]; then
    echo "VM not built. Run './demo/vm.sh build' first."
    exit 1
  fi

  # Find the run script
  RUN_SCRIPT=$(find "$VM_RESULT" -name "run-*-vm" -type f | head -1)
  if [ -z "$RUN_SCRIPT" ]; then
    echo "VM run script not found in $VM_RESULT"
    exit 1
  fi

  echo "Booting VM (serial console)..."
  echo "Press Ctrl+A then X to exit"
  timeout "$VM_TIMEOUT" "$RUN_SCRIPT" || true
}

record_tour() {
  if [ ! -d "$VM_RESULT" ]; then
    echo "VM not built. Run './demo/vm.sh build' first."
    exit 1
  fi

  RUN_SCRIPT=$(find "$VM_RESULT" -name "run-*-vm" -type f | head -1)
  if [ -z "$RUN_SCRIPT" ]; then
    echo "VM run script not found in $VM_RESULT"
    exit 1
  fi

  if [ ! -f "$TOUR_SCRIPT" ]; then
    echo "Tour script not found at $TOUR_SCRIPT"
    exit 1
  fi

  mkdir -p "$(dirname "$CAST_OUTPUT")"

  echo "Recording scripted tour to $CAST_OUTPUT..."
  # Run the VM with asciinema recording the session
  # We use a wrapper that feeds the session script to the VM
  timeout "$VM_TIMEOUT" asciinema rec --overwrite --command "
    expect -c '
      spawn $RUN_SCRIPT
      log_user 1
      set timeout 30
      expect \"demo@.*:~\\$ \"
      # Source the session script commands
      send \"source $TOUR_SCRIPT\r\"
      expect eof
    '
  " "$CAST_OUTPUT" || true

  echo "Tour recorded to $CAST_OUTPUT"
}

run_session() {
  # Run the session script inside the VM (for interactive use)
  if [ ! -d "$VM_RESULT" ]; then
    echo "VM not built. Run './demo/vm.sh build' first."
    exit 1
  fi

  RUN_SCRIPT=$(find "$VM_RESULT" -name "run-*-vm" -type f | head -1)
  if [ -z "$RUN_SCRIPT" ]; then
    echo "VM run script not found in $VM_RESULT"
    exit 1
  fi

  if [ ! -f "$TOUR_SCRIPT" ]; then
    echo "Tour script not found at $TOUR_SCRIPT"
    exit 1
  fi

  echo "Running session script in VM..."
  timeout "$VM_TIMEOUT" "$RUN_SCRIPT" -c "source $TOUR_SCRIPT" || true
}

teardown() {
  echo "Tearing down VM processes..."
  pkill -f "qemu.*sumonix" 2>/dev/null || true
  pkill -f "run-.*-vm" 2>/dev/null || true
  echo "Done."
}

# Main command dispatch
cmd="${1:-}"
shift || true

case "$cmd" in
  build)
    build_vm
    ;;
  boot)
    boot_vm
    ;;
  --record)
    record_tour
    ;;
  --check)
    check_kvm || true
    ;;
  --teardown)
    teardown
    ;;
  *)
    echo "Usage: $0 {build|boot|--record|--check|--teardown}"
    echo ""
    echo "  build      Build the VM (one repack, system.build.vm)"
    echo "  boot       Boot the VM interactively (headless, serial console)"
    echo "  --record   Boot, run scripted tour, capture asciicast"
    echo "  --check    Check KVM availability, exit 0 if available, SKIP otherwise"
    echo "  --teardown Clean up VM processes"
    exit 1
    ;;
esac