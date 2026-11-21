## 🛰 Metavisor Live Loop (D1) — The Container Demo

`./tools/metavisor-tour.sh` drives three metavisor scenes against a real NixOS-in-Podman systemd host — no fixtures, no mocks.

### Prerequisites

```bash
# Enable unprivileged user namespaces (required for build in diverted store)
sudo sysctl -w kernel.unprivileged_userns_clone=1

# Build the VM
./container/run.sh build
```

### Scene 1: The Gate

A NixOS module with a wildcard postgres listener and a closed firewall fails `sumo gate` with a proof naming both option paths:

<!-- include:transcript:06-metavisor-live.txt -->

*(The transcript above is the full normalized output from the container run.)*

### Scene 2: Live Drift

The declared unit is stopped; one timer tick later `sumo status` and the journal carry the drift with its proof. A listener nobody declared is a violation, not a guess.

### Scene 3: Verified Repair

`sumo repair` ranks single-option patches, each re-lifted and re-gated; the top patch is applied and the whole system rebuilds through the same gate.

---

### How It Works

| Step | Command | What Happens |
|------|---------|--------------|
| 1 | `./container/run.sh build` | Builds NixOS VM with bad config (postgres on 0.0.0.0, no firewall) |
| 2 | `./container/run.sh run` | Boots VM, installs sumo CLI |
| 3 | `sumo gate` | Fails build with proof naming `services.postgresql.settings.listen_addresses` and `networking.firewall.allowedTCPPorts` |
| 4 | `systemctl stop postgresql` | Stops declared unit |
| 5 | metavisor tick | Detects drift, emits proof, writes journal |
| 6 | `nc -l 0.0.0.0 9999` | Starts rogue listener |
| 7 | metavisor tick | Detects rogue listener, emits violation |
| 8 | `sumo repair` | Ranks 3 patches (open port, bind localhost, disable service) |
| 9 | Apply #1 + rebuild | System rebuilds through gate → passes |

The transcript is normalized (timestamps, snapshot ids, hashes) and byte-compared in CI, so a changed claim fails the build.

Record the cast: `./tools/metavisor-tour.sh --record` → `docs/demo/metavisor-tour.cast`. The container harness is `./container/run.sh build|run`, and its NixOS configuration is `container/container.nix`.