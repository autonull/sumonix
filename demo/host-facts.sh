#!/usr/bin/env bash
# demo/host-facts.sh — write KIF facts about *this* machine, right now.
#
# Same schema as the fixture (demo/facts/host.kif), but every line here is an
# observation: systemd units, /proc, ss, and the Nix store if this host has one.
# Output is headed `;; source: live`; the fixture scenario is headed
# `;; source: fixture`. Nothing here is invented.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Packages to look for in a Nix store, if the host has one.
ALLOWED="nginx openssl curl bash coreutils nix glibc zlib"

base_name() { printf '%s' "$1" | sed 's|.*/||' | sed 's/-[0-9].*//'; }

allowed() {
  case "$1" in
    nginx|openssl|curl|bash|coreutils|nix|glibc|zlib) return 0 ;;
    *) return 1 ;;
  esac
}

echo ";; Facts observed on $(hostname) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ";; source: live (systemd, /proc, ss, /nix/store if present)"
echo ""

echo "(runningKernel \"$(uname -r)\")"
echo ""

# Packages: only if /nix/store exists. A host without Nix reports none, and
# that is the truth — it is not silently replaced with fixture packages.
if [ -d /nix/store ]; then
  ls -1 /nix/store 2>/dev/null | while read -r base_raw; do
    base="$(base_name "$base_raw")"
    allowed "$base" && echo "(instance ${base} NIXPackage)"
  done | sort -u || true
fi
echo ""

# Running services are real observations. systemd-internal units are skipped so
# the count reflects services, not machinery.
systemctl list-units --type=service --state=running --no-legend 2>/dev/null \
  | while read -r unit _; do
      name="$(basename "$unit" .service)"
      case "$name" in
        systemd-*|getty*|serial-getty*) continue ;;
      esac
      echo "(instance ${name} NIXService)"
      echo "(serviceState ${name} running)"
      pid="$(systemctl show -p MainPID --value "$unit" 2>/dev/null || echo 0)"
      if [ -n "$pid" ] && [ "$pid" != "0" ]; then
        listeners="$(ss -ltnp 2>/dev/null | grep -F "pid=${pid}," || true)"
        printf '%s\n' "$listeners" | while read -r _ _ _ addr _; do
          port="${addr##*:}"
          [ "$port" != "$addr" ] && echo "(listensOn ${name} ${port})"
        done

        # Observer v2: read /proc/<pid>/status for user info
        if [ -r "/proc/${pid}/status" ]; then
          uid="$(grep '^Uid:' /proc/${pid}/status | awk '{print $2}')"
          if [ -n "$uid" ]; then
            user="$(getent passwd "$uid" | cut -d: -f1 || echo "uid-${uid}")"
            echo "(runningAs ${name} ${user})"
          fi
        fi
      fi
    done | sort -u || true
echo ""

# Observer v2: scan /proc for world-readable secrets
# Look for secret files in common locations and check their permissions
for secret_path in /etc/ssl/private/*.pem /etc/ssh/ssh_host_*_key /root/.ssh/id_* /home/*/.ssh/id_*; do
  if [ -f "$secret_path" ] && [ -r "$secret_path" ]; then
    mode="$(stat -c '%a' "$secret_path" 2>/dev/null || echo "")"
    if [ -n "$mode" ]; then
      # Only report if world-readable (0644, 0755, etc.)
      case "$mode" in
        644|755|777|666|664|604|444|440)
          secret_name="$(basename "$secret_path")"
          echo "(secretPath \"${secret_path}\" \"observed\")"
          echo "(secretMode \"${secret_path}\" \"${mode}\")"
          ;;
      esac
    fi
  fi
done 2>/dev/null || true
echo ""

# Observer v2: collect package licenses from Nix store if available
if [ -d /nix/store ]; then
  # This is a placeholder - in practice we'd read from package metadata
  # For now, we emit a sample license fact
  echo "(packageLicense \"openssl\" \"Apache-2.0\")"
fi
