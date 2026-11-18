# M3A — Operator surface over the drift engine.
#
#   mv = import ./reasoner/metavisor.nix {
#     declared; observed; now; declaredSource; observedSource;
#   };
#   mv.status        # pass | drift | violation | unknown
#   mv.events        # one record per drift/rogue, with a stable proof ID
#   mv.journal       # "<proofId>\t<kind> <subject>" lines for the journal
#   mv.text          # source-labeled human section (sumo status / sumo drift)
#   mv.json          # source-labeled, machine-readable section
#
# This is deliberately thin: drift.nix keeps the claim logic (R1) and this file
# only labels the sources and assigns proof IDs. No new step kinds.
{ declared
, observed ? ""
, now
, declaredSource ? "declared.kif"
, observedSource ? "observed.kif"
}:
let
  inherit (builtins)
    concatMap concatStringsSep head isString map sort stringLength substring;

  drift = import ./drift.nix { inherit declared observed now; };

  unquote = s:
    if isString s && substring 0 1 s == "\"" && substring (stringLength s - 1) 1 s == "\""
    then substring 1 (stringLength s - 2) s
    else s;

  proofId = p: "sha256:" + builtins.hashString "sha256" p;

  driftRows = map
    (r: {
      unit = unquote r.unit;
      proofId = proofId r.proof;
      proof = r.proof;
    })
    drift.drift;

  rogueRows = map
    (r: {
      process = unquote r.process;
      addr = unquote r.addr;
      port = unquote r.port;
      proofId = proofId r.proof;
      proof = r.proof;
    })
    drift.rogue;

  events =
    map
      (r: {
        ts = now;
        kind = "drift";
        unit = r.unit;
        proofId = r.proofId;
        proof = r.proof;
      })
      driftRows
    ++ map
      (r: {
        ts = now;
        kind = "violation";
        process = r.process;
        addr = r.addr;
        port = r.port;
        proofId = r.proofId;
        proof = r.proof;
      })
      rogueRows;

  snapshot = if drift.fresh == [ ] then null else unquote (head drift.fresh);
  exporters = map unquote drift.sources.exporters;

  journal =
    map (r: r.proofId + "\tdrift unit=" + r.unit) driftRows
    ++ map (r: r.proofId + "\trogueListener process=" + r.process + " addr=" + r.addr + " port=" + r.port) rogueRows
    ++ (if drift.status == "unknown" then [ ( "unknown\t" + drift.unknownReason ) ] else [ ]);

  sources = {
    declared = {
      path = declaredSource;
      facts = drift.sources.declared;
      trust = "config eval (pure lift)";
    };
    observed = {
      path = observedSource;
      facts = drift.sources.observed;
      inherit exporters;
      snapshot = snapshot;
      stale = drift.stale;
      trust = "exporter attestation (hashed, TTL'd)";
    };
    declaredPath = declaredSource;
    observedPath = observedSource;
  };

  # Human section. Proofs are printed in full: an unexplained claim is not an
  # answer (the constitution's "if there is no proof it is not a valid answer").
  proofBlock = title: rows: line:
    if rows == [ ] then [ ]
    else [ ("  " + title + ":") ] ++ concatMap
      (r: [
        ("    - " + line r + "  (" + r.proofId + ")")
        ("      " + builtins.replaceStrings [ "\n" ] [ "\n      " ] r.proof)
      ])
      rows;

  statusLine =
    if drift.status == "unknown" then
      [ ("  status: unknown - " + drift.unknownReason) ]
    else if drift.status == "pass" then
      [ "  status: pass - no drift, no rogue listeners" ]
    else
      [ ("  status: " + drift.status) ];

  text = concatStringsSep "\n" (
    [
      "🛰 METAVISOR (source-labeled)"
      ("  declared: " + declaredSource + " (" + toString drift.sources.declared + " facts)")
      ("  observed: " + observedSource + " (" + toString drift.sources.observed + " facts"
      + (if snapshot == null then "" else ", snapshot " + snapshot)
      + (if exporters == [ ] then "" else ", exporter " + concatStringsSep "," exporters)
      + ")")
    ]
    ++ statusLine
    ++ proofBlock "drift" driftRows (r: "unit " + r.unit)
    ++ proofBlock "rogue listener" rogueRows (r: r.process + " on " + r.addr + ":" + r.port)
  );

  signature =
    drift.status + ":"
    + concatStringsSep "," (sort builtins.lessThan (map (e: e.proofId) events));

  json = {
    inherit (drift) status unknownReason stale fresh counts;
    inherit signature snapshot events sources;
    drift = map (r: { inherit (r) unit proofId proof; }) driftRows;
    rogue = map (r: { inherit (r) process addr port proofId proof; }) rogueRows;
  };
in
{
  inherit (drift) status stale fresh counts unknownReason proof;
  drift = driftRows;
  rogue = rogueRows;
  inherit events journal snapshot text json sources signature;
  inherit (drift) engine;
}
