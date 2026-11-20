# M2-lite — Drift and rogue listeners on the existing kernel.
#
#   drift = import ./reasoner/drift.nix { declared; observed; now; };
#   drift.status      # "pass" | "drift" | "violation" | "unknown"
#   drift.drift       # [ { unit; proof; } ] — only from fresh, complete attestations
#   drift.rogue       # [ { process; addr; port; proof; } ]
#   drift.stale       # snapshot ids whose TTL expired (dropped before the engine)
#
# Freshness is data, not a new step kind: the loader compares each
# `(attests <id> <hash> <expiry> <exporter>)` with `now`, drops stale snapshot
# facts before the engine sees them, and emits `(freshSnapshot <id>)`. If no
# fresh attestation exists, or the unitActive/listener completeness attestations
# are missing, the status is `unknown` and no drift/violation claim is made
# (rule R1). The engine stays pure and unchanged.
{ declared, observed, now }:
let
  kif = import ../lib/kif.nix { };
  inherit (kif) parse show showFact headOf unique makeEnvelope defaultMeta;

  inherit (builtins)
    any concatStringsSep elem elemAt filter fromJSON isString length map
    stringLength substring currentTime;

  observedForms = if isString observed then parse observed else observed;

  # Wrap observed facts with meta (deterministic timestamp for reproducible proofs)
  wrapObserved = fact:
    let
      meta = {
        sourceClass = "observed";
        sourceId = "tools/observe.sh";
        observedAt = 0;  # deterministic for proof stability
        expiresAt = 0;
        snapshotId = "";  # will be set per fact
        contentHash = "sha256:" + builtins.hashString "sha256" (showFact fact);
        confidence = 1.0;
        provenance = [ ];
      };
    in makeEnvelope fact meta;

  # Wrap freshSnapshot facts (deterministic timestamp for reproducible proofs)
  wrapFresh = id:
    let fact = [ "freshSnapshot" id ]; in
    makeEnvelope fact {
      sourceClass = "derived";
      sourceId = "reasoner/drift.nix";
      observedAt = 0;  # deterministic for proof stability
      expiresAt = 0;
      snapshotId = id;
      contentHash = "sha256:" + builtins.hashString "sha256" (showFact fact);
      confidence = 1.0;
      provenance = [ ];
    };

  top = name: filter (f: headOf f == name) observedForms;

  unquote = s:
    if isString s && substring 0 1 s == "\"" && substring (stringLength s - 1) 1 s == "\""
    then substring 1 (stringLength s - 2) s
    else s;

  intOf = s: fromJSON (unquote s);

  snapshots = filter (f: length f == 3) (top "snapshot");
  attests = filter (f: length f == 5) (top "attests");

  expiryOf = f: intOf (elemAt f 3);
  freshIds = unique (map (f: elemAt f 1) (filter (f: expiryOf f > now) attests));
  staleIds = unique (map (f: elemAt f 1) (filter (f: expiryOf f <= now) attests));

  snapOf = f:
    if headOf f == "snapshot" || headOf f == "attests" then elemAt f 1
    else if headOf f == "completeFor" || headOf f == "observedActive" then elemAt f 2
    else if headOf f == "observedListener" then elemAt f 4
    else null;

  keptRaw = filter (f: let s = snapOf f; in s != null && elem s freshIds) observedForms;
  kept = map wrapObserved keptRaw;
  freshFacts = map wrapFresh freshIds;

  facts = declared.facts ++ kept ++ freshFacts;

  engine = import ../datalog.nix {
    ontology = declared.ontology;
    rules = declared.rules;
    inherit facts;
  };

  completeFor = kind: id:
    any (f: headOf f == "completeFor" && elemAt f 1 == kind && elemAt f 2 == id)
      observedForms;

  unitFresh = filter (id: completeFor "unitActive" id) freshIds;
  listenerFresh = filter (id: completeFor "listener" id) freshIds;
  bothComplete = unitFresh != [ ] && listenerFresh != [ ];

  driftRows = map
    (b:
      let goal = [ "drift" b."?unit" ]; in {
        unit = b."?unit";
        proof = engine.explain goal;
      })
    (engine.ask [ "drift" "?unit" ]);

  rogueRows = map
    (b:
      let goal = [ "rogueListener" b."?process" b."?addr" b."?port" ]; in {
        process = b."?process";
        addr = b."?addr";
        port = b."?port";
        proof = engine.explain goal;
      })
    (engine.ask [ "rogueListener" "?process" "?addr" "?port" ]);

  drift = if bothComplete then driftRows else [ ];
  rogue = if bothComplete then rogueRows else [ ];

  status =
    if freshIds == [ ] then "unknown"
    else if !bothComplete then "unknown"
    else if rogue != [ ] then "violation"
    else if drift != [ ] then "drift"
    else "pass";

  unknownReason =
    if freshIds == [ ] then
      "observation stale: no fresh completeness attestation (observer silent or TTL expired)"
    else if !bothComplete then
      "observation partial: need fresh completeFor unitActive and listener attestations"
    else "";

  exporters = unique (map (f: elemAt f 4) attests);
  proof =
    if status == "unknown" then unknownReason
    else concatStringsSep "\n\n" (map (d: d.proof) (drift ++ rogue));
in
{
  inherit facts engine drift rogue status proof staleIds;
  stale = staleIds;
  fresh = freshIds;
  unknownReason = if status == "unknown" then unknownReason else "";
  counts = {
    snapshots = length snapshots;
    fresh = length freshIds;
    stale = length staleIds;
    drift = length drift;
    rogue = length rogue;
  };
  sources = {
    declared = length declared.facts;
    observed = length kept;
    exporters = exporters;
  };
}
