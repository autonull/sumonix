## Metavisor live loop

`./tools/metavisor-tour.sh` drives three metavisor scenes against a real
NixOS-in-Podman systemd host — no fixtures, no mocks.

```bash
# Prerequisite: unprivileged user namespaces (needed to build in a diverted store)
sudo sysctl -w kernel.unprivileged_userns_clone=1

./container/run.sh build   # build the NixOS VM
./container/run.sh run     # boot it and install the sumo CLI
```

| Scene | What happens | Why it matters |
|-------|--------------|----------------|
| 1. The gate | A wildcard postgres listener and a closed firewall fail `sumo gate` with a proof naming both option paths. | A contradiction is caught before the build. |
| 2. Live drift | The declared unit is stopped; one timer tick later `sumo status` and the journal carry the drift with its proof. An undeclared listener is a violation, not a guess. | The running system is held to its declaration. |
| 3. Verified repair | `sumo repair` ranks single-option patches, each re-lifted and re-gated; the top patch is applied and the system rebuilds through the same gate. | The fix is verified before a human applies it. |

### Scene 1: The gate

A NixOS module with a wildcard postgres listener and a closed firewall fails
`sumo gate` with a proof naming both option paths:

```console
1 · The gate: postgres listens on 0.0.0.0, the firewall allows nothing
    -> the eval fails with a proof naming both option paths

$ ./bin/sumo gate --configuration container/nixos/d1-bad.nix
gate: violation — the configuration contradicts system.kif
(policyViolation "services.postgresql" NoFirewallAllowance)    by policyViolation#6
  (declaredService "services.postgresql" "services.postgresql.enable")    asserted
  (firewallEnabled "networking.firewall.enable")    asserted
  (serviceListener "services.postgresql" "0.0.0.0")    by serviceListener#3
    (listenerDeclared "services.postgresql" "0.0.0.0" "services.postgresql.settings.listen_addresses")    asserted
  (servicePort "services.postgresql" "5432")    by servicePort#2
    (portInferred "services.postgresql" "5432" "services.postgresql.settings.port")    asserted
  (firewallTcpOption "networking.firewall.allowedTCPPorts")    asserted
```

### Scene 2: Live drift

The declared unit is stopped; one timer tick later `sumo status` and the
journal carry the drift with its proof. A listener nobody declared is a
violation, not a guess:

```console
$ systemctl stop postgresql
$ run the metavisor tick
🛰 METAVISOR (source-labeled)
  declared: /etc/sumo/declared.kif (<n> facts)
  observed: /run/sumo/observed.kif (<n> facts, snapshot snap-<id>, exporter <exporter>)
  status: drift
  drift:
    - unit postgresql.service  (sha256:<hash>)
      (drift "postgresql.service")    by drift#7
        (declaredRunning "services.postgresql" "services.postgresql.enable")    asserted
        (aliasOf "services.postgresql" "postgresql.service")    asserted
        (completeFor unitActive "snap-<id>")    asserted
        (freshSnapshot "snap-<id>")    asserted
journal: drift unit=postgresql.service (proof sha256:<hash>)

$ nc -l 0.0.0.0 9999   # a rogue listener
$ run the metavisor tick
🛰 METAVISOR (source-labeled)
  status: violation
  rogue listener:
    - nc on 0.0.0.0:9999  (sha256:<hash>)
      (rogueListener "nc" "0.0.0.0" "9999")    by rogueListener#8
        (completeFor listener "snap-<id>")    asserted
        (freshSnapshot "snap-<id>")    asserted
        (observedListener "nc" "0.0.0.0" "9999" "snap-<id>")    asserted
journal: rogueListener process=nc addr=0.0.0.0 port=9999 (proof sha256:<hash>)
```

### Scene 3: Verified repair

`sumo repair` ranks single-option patches, each re-lifted and re-gated; the top
patch is applied and the whole system rebuilds through the same gate:

```console
$ sumo repair --configuration /etc/nixos/bad.nix
base gate: violation
candidates: 3, verified: 3, rejected: 0

#1 allow port 5432 in the firewall
  networking.firewall.allowedTCPPorts = [5432];
re-lifted gate: pass

#2 bind services.postgresql to localhost
  services.postgresql.settings.listen_addresses = "localhost";
re-lifted gate: pass

#3 disable services.postgresql
  services.postgresql.enable = false;
re-lifted gate: pass

$ apply #1: networking.firewall.allowedTCPPorts = [5432]
$ nixos-rebuild build   # the gate runs inside the rebuild
nixos-rebuild build: gate passed, the patched system built
```

### How it works

| Step | Command | What happens |
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

### Full normalized transcript

```console

1 · The gate: postgres listens on 0.0.0.0, the firewall allows nothing
    -> the eval fails with a proof naming both option paths

$ ./bin/sumo gate --configuration container/nixos/d1-bad.nix
gate: violation — the configuration contradicts system.kif
(policyViolation "services.postgresql" NoFirewallAllowance)    by policyViolation#6
  (declaredService "services.postgresql" "services.postgresql.enable")    asserted
  (firewallEnabled "networking.firewall.enable")    asserted
  (serviceListener "services.postgresql" "0.0.0.0")    by serviceListener#3
    (listenerDeclared "services.postgresql" "0.0.0.0" "services.postgresql.settings.listen_addresses")    asserted
  (servicePort "services.postgresql" "5432")    by servicePort#2
    (portInferred "services.postgresql" "5432" "services.postgresql.settings.port")    asserted
  (firewallTcpOption "networking.firewall.allowedTCPPorts")    asserted

2 · Stop the declared unit; one timer tick later the drift is proven

$ systemctl stop postgresql
$ run the metavisor tick
🛰 METAVISOR (source-labeled)
  declared: /etc/sumo/declared.kif (<n> facts)
  observed: /run/sumo/observed.kif (<n> facts, snapshot snap-<id>, exporter <exporter>)
  status: drift
  drift:
    - unit postgresql.service  (sha256:<hash>)
      (drift "postgresql.service")    by drift#7
        (declaredRunning "services.postgresql" "services.postgresql.enable")    asserted
        (aliasOf "services.postgresql" "postgresql.service")    asserted
        (completeFor unitActive "snap-<id>")    asserted
        (freshSnapshot "snap-<id>")    asserted
journal: drift unit=postgresql.service (proof sha256:<hash>)

    and a listener nobody declared is a violation, not a guess

$ nc -l 0.0.0.0 9999   # a rogue listener
🛰 METAVISOR (source-labeled)
  declared: /etc/sumo/declared.kif (<n> facts)
  observed: /run/sumo/observed.kif (<n> facts, snapshot snap-<id>, exporter <exporter>)
  status: violation
  drift:
    - unit postgresql.service  (sha256:<hash>)
      (drift "postgresql.service")    by drift#7
        (declaredRunning "services.postgresql" "services.postgresql.enable")    asserted
        (aliasOf "services.postgresql" "postgresql.service")    asserted
        (completeFor unitActive "snap-<id>")    asserted
        (freshSnapshot "snap-<id>")    asserted
  rogue listener:
    - nc on 0.0.0.0:9999  (sha256:<hash>)
      (rogueListener "nc" "0.0.0.0" "9999")    by rogueListener#8
        (completeFor listener "snap-<id>")    asserted
        (freshSnapshot "snap-<id>")    asserted
        (observedListener "nc" "0.0.0.0" "9999" "snap-<id>")    asserted
journal: rogueListener process=nc addr=0.0.0.0 port=9999 (proof sha256:<hash>)

3 · Repair: ranked single-option patches, each re-lifted and re-gated

$ podman exec sumonix-demo /run/current-system/sw/bin/bash -lc /run/current-system/sw/bin/sumo repair --configuration /etc/nixos/bad.nix
base gate: violation
(policyViolation "services.postgresql" NoFirewallAllowance)    by policyViolation#6
  (declaredService "services.postgresql" "services.postgresql.enable")    asserted
  (firewallEnabled "networking.firewall.enable")    asserted
  (serviceListener "services.postgresql" "0.0.0.0")    by serviceListener#3
    (listenerDeclared "services.postgresql" "0.0.0.0" "services.postgresql.settings.listen_addresses")    asserted
  (servicePort "services.postgresql" "5432")    by servicePort#2
    (portInferred "services.postgresql" "5432" "services.postgresql.settings.port")    asserted
  (firewallTcpOption "networking.firewall.allowedTCPPorts")    asserted
candidates: 3, verified: 3, rejected: 0

#1 allow port 5432 in the firewall
--- a/configuration.nix
+++ b/configuration.nix
@@ networking.firewall.allowedTCPPorts @@
-  networking.firewall.allowedTCPPorts = [];
+  networking.firewall.allowedTCPPorts = [5432];
re-lifted gate: pass
no derivable policyViolation; all lifted facts well typed

#2 bind services.postgresql to localhost
--- a/configuration.nix
+++ b/configuration.nix
@@ services.postgresql.settings.listen_addresses @@
-  services.postgresql.settings.listen_addresses = "0.0.0.0";
+  services.postgresql.settings.listen_addresses = "localhost";
re-lifted gate: pass
no derivable policyViolation; all lifted facts well typed

#3 disable services.postgresql
--- a/configuration.nix
+++ b/configuration.nix
@@ services.postgresql.enable @@
-  services.postgresql.enable = true;
+  services.postgresql.enable = false;
re-lifted gate: pass
no derivable policyViolation; all lifted facts well typed
$ apply #1: networking.firewall.allowedTCPPorts = [5432]

$ nixos-rebuild build   # the gate runs inside the rebuild
nixos-rebuild build: gate passed, the patched system built

$ podman exec sumonix-demo /run/current-system/sw/bin/bash -lc /run/current-system/sw/bin/sumo repair --configuration /tmp/patched.nix
base gate: pass
no violation to repair
candidates: 0, verified: 0, rejected: 0

no verified repair

4 · Rootless limit, stated not hidden: postgres runs as its own uid, so
    `ss` cannot attribute its socket -> status unknown, never a false pass (R1)

🛰 METAVISOR (source-labeled)
  declared: /etc/sumo/declared.kif (<n> facts)
  observed: /run/sumo/observed.kif (<n> facts, snapshot snap-<id>, exporter <exporter>)
  status: unknown - observation partial: need fresh completeFor unitActive and listener attestations
journal: unknown: observation partial: need fresh completeFor unitActive and listener attestations
```

The transcript is normalized (timestamps, snapshot ids, hashes) and
byte-compared in CI, so a changed claim fails the build.

A rootless host where `ss` cannot attribute a socket reports **`status:
unknown`**, never a false pass. Observation TTLs make staleness explicit, so
one missed tick leaves a fresh snapshot and two make the answer unknown.

Record the cast: `./tools/metavisor-tour.sh --record` →
`docs/demo/metavisor-tour.cast`. The container harness is
`./container/run.sh build|run`, and its NixOS configuration is
`container/container.nix`.
