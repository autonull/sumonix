#!/bin/sh
# nix/sumo-facts.sh — write /run/sumo/facts.kif from this NixOS system.
#
# Live sources: systemctl (services), nix-store (closure + references),
# /proc/sys/kernel/osrelease (kernel), ss (listeners).
# Fixtures: the advisory (CVE) and the optional facts file, both appended under
# an explicit `source: fixture` header. Live facts are never mixed with them.

set -eu

FACTS_DIR="/run/sumo"
FACTS_FILE="${FACTS_DIR}/facts.kif"
ADVISORY_FILE="${ADVISORY_FILE:-${FACTS_DIR}/advisory.kif}"
FACTS_FIXTURE="${FACTS_FIXTURE:-${FACTS_DIR}/facts-fixture.kif}"
RULES_SRC="${RULES_SRC:-${FACTS_DIR}/rules.kif}"

# Demo-relevant package subset. The full closure is thousands of paths; the demo
# reasons about these.
ALLOWED="nginx openssl curl bash coreutils nix glibc zlib"

mkdir -p "${FACTS_DIR}" "${FACTS_DIR}/nix-state"
chmod 755 "${FACTS_DIR}/nix-state"

TMP_FILE="$(mktemp "${FACTS_DIR}/facts.kif.XXXXXX")"
trap 'rm -f "${TMP_FILE}"' EXIT

base_name() {
  printf '%s' "$1" | sed 's|.*/||' | sed 's/-[0-9].*//'
}

allowed() {
  case "$1" in
    nginx|openssl|curl|bash|coreutils|nix|glibc|zlib) return 0 ;;
    *) return 1 ;;
  esac
}

{
  echo ";; SUMOnix live facts — generated $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo ";; source: live"
  echo ""

  echo ";; Kernel (host kernel, shared by the container)"
  echo "(runningKernel \"$(cat /proc/sys/kernel/osrelease 2>/dev/null || echo unknown)\")"
  echo ""

  echo ";; NIXPackage instances (filtered from the /run/current-system closure)"
  if [ -e /run/current-system ]; then
    nix-store -q --requisites /run/current-system 2>/dev/null \
      | while read -r path; do
          base="$(base_name "$path")"
          if allowed "$base"; then
            echo "(instance ${base} NIXPackage)"
          fi
        done | sort -u
  fi
  echo ""

  echo ";; dependsOn edges (nix-store --query --references, filtered)"
  if [ -e /run/current-system ]; then
    nix-store -q --requisites /run/current-system 2>/dev/null \
      | while read -r path; do
          base="$(base_name "$path")"
          allowed "$base" || continue
          nix-store -q --references "$path" 2>/dev/null \
            | while read -r ref; do
                refbase="$(base_name "$ref")"
                if allowed "$refbase" && [ "$refbase" != "$base" ]; then
                  echo "(dependsOn ${base} ${refbase})"
                fi
              done
        done | sort -u
  fi
  echo ""

  echo ";; NIXService instances (running systemd services)"
  systemctl list-units --type=service --state=running --no-legend 2>/dev/null \
    | while read -r unit _; do
        name="$(basename "$unit" .service)"
        case "$name" in
          systemd-*|getty*|serial-getty*|sumo-facts|sumonix-guard) continue ;;
        esac
        echo "(instance ${name} NIXPackage)"
        echo "(instance ${name} NIXService)"
        echo "(serviceState ${name} running)"

        pid="$(systemctl show -p MainPID --value "$unit" 2>/dev/null || echo 0)"
        if [ -n "$pid" ] && [ "$pid" != "0" ]; then
          ss -ltnp 2>/dev/null | grep "pid=${pid}," | while read -r _ _ _ addr _; do
            port="${addr##*:}"
            if [ "$port" != "$addr" ]; then
              echo "(listensOn ${name} ${port})"
            fi
          done
        fi

        user="$(systemctl show -p User --value "$unit" 2>/dev/null || true)"
        if [ -n "$user" ] && [ "$user" != "root" ]; then
          echo "(runningAs ${name} ${user})"
        fi
      done
  echo ""

  if [ -f "${ADVISORY_FILE}" ]; then
    echo ";; source: fixture (advisory)"
    cat "${ADVISORY_FILE}"
    echo ""
  fi

  if [ -f "${FACTS_FIXTURE}" ]; then
    echo ";; source: fixture (factsFile)"
    cat "${FACTS_FIXTURE}"
    echo ""
  fi
} > "${TMP_FILE}"

mv "${TMP_FILE}" "${FACTS_FILE}"
trap - EXIT

# Keep the rules file available to the CLI on first run.
if [ ! -f "${RULES_SRC}" ] && [ -f "${SUMO_RULES_DEFAULT:-/dev/null}" ]; then
  cp "${SUMO_RULES_DEFAULT}" "${RULES_SRC}"
fi

echo "sumo-facts: wrote ${FACTS_FILE}"
