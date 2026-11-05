# Phase 3 — Ingestion smoke. Merge Horn ingestion (verdict: ingestible, TODO2.b.md) is ON here.
# The closure over the CVE scenario + ingested Merge rules must terminate, keep the oracle results,
# and expose enumerable diagnostics; part a c is derivable from the (instance part TransitiveRelation)
# declaration alone via synthesize.nix — no hand-written rule.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/ingest-smoke.nix'  -> "ok"
let
  kif = import ../kif.nix;
  pins = import ../pins.nix;
  text = builtins.readFile;
  facts = kif.parse ''
    (instance hello NIXPackage)
    (instance curl NIXPackage)
    (instance nginx NIXPackage)
    (instance nginx NIXService)
    (instance glibc NIXPackage)
    (instance openssl NIXPackage)
    (instance app NIXPackage)
    (dependsOn curl openssl)
    (dependsOn nginx openssl)
    (dependsOn hello glibc)
    (dependsOn app curl)
    (vulnerable openssl CVE-2026-9999)
    (severity CVE-2026-9999 critical)
    (serviceState nginx running)
    (part a b)
    (part b c)
  '';
  ontology = import ../sumo.nix {
    forms = kif.parse (text pins.merge) ++ kif.parse (text ../nix-domain.kif);
  };
  userRules = builtins.filter (f: builtins.head f == "=>") (kif.parse (text ../rules.kif));
  ingest = import ../reasoner/ingest.nix { };
  synth = import ../reasoner/synthesize.nix { forms = kif.parse (text pins.merge); };
  # user rules first: first-wins attributions stay stable
  rules = userRules ++ ingest.rules ++ synth.rules;
  e = import ../datalog.nix { inherit ontology facts rules; };
  affected = builtins.sort builtins.lessThan (map (b: b."?p") (e.ask [ "vulnerable" "?p" "CVE-2026-9999" ]));
  check = what: ok: if ok then true else throw "failed: ${what}";
  allRejectionsHaveReasons = builtins.all (r: r ? reason && r.reason != "") ingest.rejected;
in
if builtins.all (x: x) [
  # --- the CVE oracle results, with ingestion on ---------------------------
  (check "closure terminates and the advisory still reaches exactly the old set" (affected == [ "app" "curl" "nginx" "openssl" ]))
  (check "hello is untouched" (!(e.holds [ "vulnerable" "hello" "CVE-2026-9999" ])))
  (check "nginx breaks the policy" (e.holds [ "policyViolation" "nginx" "NoCriticalRunningCVE" ]))
  (check "the proof still names the user rule, not a merged rule" ((e.why [ "vulnerable" "nginx" "CVE-2026-9999" ]).rule == "vulnerable#3"))
  # --- SUMO-native capability -----------------------------------------------
  (check "part a c derives from the declaration alone (TransitiveRelation)"
    (e.holds [ "part" "a" "c" ]))
  (check "the declaration-derived fact carries a proof" ((e.why [ "part" "a" "c" ]) != null))
  # --- diagnostics: everything enumerated, nothing dropped silently ----------
  (check "every ingested rule names a known source"
    (builtins.all (s: builtins.elem s [ "merge-horn" "or-split" "and-split" "iff-split" "disjunctive-head" ]) (builtins.attrNames ingest.diagnostics.sources)))
  (check "every rejection carries a reason" allRejectionsHaveReasons)
  (check "the ingested set is non-trivial" (ingest.diagnostics.ingested > 50))
  (check "at least one rejection reason is enumerated" (builtins.length (builtins.attrNames ingest.diagnostics.byReason) > 0))
  (check "the unstratifiable predicates are listed, not hidden" (builtins.length ingest.diagnostics.unstratifiablePredicates > 0))
] then "ok" else "failed"
