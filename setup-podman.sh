#!/usr/bin/env bash
# setup-podman.sh — enable rootless Podman with systemd support on CachyOS/Arch
# Run once. If it fails, Podman is not viable on this host without manual intervention.
# Does NOT reboot. You must log out and back in after it succeeds.

set -euo pipefail

USER_NAME="${SUDO_USER:-$USER}"
USER_ID=$(id -u "$USER_NAME")

echo "=== setup-podman.sh for $USER_NAME (UID $USER_ID) ==="
echo

# 1. Check kernel support
echo "[1/6] Checking kernel user namespaces..."
if [[ $(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null) -eq 1 ]]; then
  echo "    OK: kernel.unprivileged_userns_clone=1"
else
  echo "    Enabling kernel.unprivileged_userns_clone..."
  echo "kernel.unprivileged_userns_clone = 1" | sudo tee /etc/sysctl.d/99-userns.conf >/dev/null
  sudo sysctl --system >/dev/null
  if [[ $(sysctl -n kernel.unprivileged_userns_clone) -eq 1 ]]; then
    echo "    OK: enabled"
  else
    echo "    FAIL: kernel.unprivileged_userns_clone still 0"
    exit 1
  fi
fi

# 2. Check cgroup v2
echo "[2/6] Checking cgroup v2..."
CGROUP_FS=$(stat -fc %T /sys/fs/cgroup 2>/dev/null || echo "unknown")
if [[ "$CGROUP_FS" == "cgroup2fs" ]]; then
  echo "    OK: cgroup v2 ($CGROUP_FS)"
else
  echo "    FAIL: cgroup v2 required, found $CGROUP_FS"
  exit 1
fi

# 3. subuid/subgid
echo "[3/6] Checking subuid/subgid for $USER_NAME..."
NEED_SUBUID=0
NEED_SUBGID=0
if ! grep -q "^${USER_NAME}:" /etc/subuid 2>/dev/null; then
  NEED_SUBUID=1
fi
if ! grep -q "^${USER_NAME}:" /etc/subgid 2>/dev/null; then
  NEED_SUBGID=1
fi

if [[ $NEED_SUBUID -eq 1 || $NEED_SUBGID -eq 1 ]]; then
  echo "    Adding subuid/subgid range 100000-165535..."
  [[ $NEED_SUBUID -eq 1 ]] && sudo usermod --add-subuids 100000-165535 "$USER_NAME"
  [[ $NEED_SUBGID -eq 1 ]] && sudo usermod --add-subgids 100000-165535 "$USER_NAME"
  echo "    OK: added"
else
  echo "    OK: already present"
fi

# 4. systemd user lingering + delegation
echo "[4/6] Checking systemd user lingering and cgroup delegation..."
if loginctl show-user "$USER_NAME" -p Linger --value | grep -q "yes"; then
  echo "    OK: linger enabled"
else
  echo "    Enabling linger for $USER_NAME..."
  sudo loginctl enable-linger "$USER_NAME"
  echo "    OK: enabled"
fi

DELEGATE=$(systemctl show-user "$USER_NAME" -p Delegate --value 2>/dev/null || echo "no")
if [[ "$DELEGATE" == "yes" ]]; then
  echo "    OK: cgroup delegation active"
else
  echo "    WARN: Delegation=$DELEGATE (may need re-login to take effect)"
fi

# 5. Podman configuration
echo "[5/6] Configuring Podman rootless..."
# Ensure Podman uses rootless by default
mkdir -p "$HOME/.config/containers"
cat > "$HOME/.config/containers/containers.conf" <<'EOF'
[engine]
runtime = "runc"
cgroup_manager = "systemd"
events_logger = "file"

[containers]
default_capabilities = [
  "CAP_CHOWN", "CAP_DAC_OVERRIDE", "CAP_FOWNER", "CAP_FSETID",
  "CAP_KILL", "CAP_NET_BIND_SERVICE", "CAP_SETFCAP", "CAP_SETGID",
  "CAP_SETPCAP", "CAP_SETUID", "CAP_SYS_CHROOT"
]
EOF
echo "    OK: containers.conf written"

# 6. Test
echo "[6/6] Testing rootless Podman with systemd..."
if ! command -v podman >/dev/null; then
  echo "    FAIL: podman not in PATH"
  exit 1
fi

# Must run as the actual user, not via sudo
if [[ $EUID -eq 0 ]]; then
  echo "    FAIL: do not run this script as root. Run as your user."
  exit 1
fi

echo "    Running: podman info --format '{{.Host.Security.Rootless}}' ..."
ROOTLESS=$(podman info --format '{{.Host.Security.Rootless}}' 2>&1 || echo "ERROR")
if [[ "$ROOTLESS" == "true" ]]; then
  echo "    OK: Podman reports rootless=true"
else
  echo "    FAIL: Podman rootless check failed: $ROOTLESS"
  echo
  echo "    This usually means you need to LOG OUT AND BACK IN for subuid/subgid"
  echo "    and cgroup delegation to take effect."
  exit 1
fi

echo "    Running: podman run --rm --systemd=always alpine true ..."
if podman run --rm --systemd=always alpine true 2>&1; then
  echo "    OK: systemd container test passed"
else
  echo "    FAIL: systemd container test failed"
  echo
  echo "    Try: podman system migrate"
  echo "    Then log out and back in."
  exit 1
fi

echo
echo "=== SUCCESS ==="
echo "Rootless Podman with systemd is working."
echo
echo "Next steps:"
echo "  1. LOG OUT AND BACK IN (or reboot) for all changes to take effect"
echo "  2. Then run: podman run --rm --systemd=always alpine true"
echo "  3. Then build the NixOS container and run it"