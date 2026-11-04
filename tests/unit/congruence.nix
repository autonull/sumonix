# T2.4 — Congruence Closure: cong a b ⇒ P(…a…) ≡ P(…b…) for all predicates.
# Usage: nix --extra-experimental-features nix-command eval --impure --expr 'import ./tests/unit/congruence.nix'  -> "ok"
let
  kif = import ../../kif.nix;
  text = builtins.readFile;

  facts = kif.parse ''
    (instance a NIXPackage)
    (instance b NIXPackage)
    (instance c NIXPackage)
    (cong a b)
    (dependsOn a c)
    (providesCapability a "cap1")
    (providesCapability b "cap2")
  '';

  sumoForms = kif.parse (text ../../sumo.full/Merge.kif);
  nixDomainForms = kif.parse (text ../../nix-domain.kif);
  allForms = sumoForms ++ nixDomainForms;

  ontology = import ../../sumo.nix { forms = allForms; };
  userRules = builtins.filter (f: builtins.head f == "=>") (kif.parse (text ../../rules.kif));
  ingest = import ../../reasoner/ingest.nix { };
  synth = import ../../reasoner/synthesize.nix { forms = sumoForms; };
  congruence = import ../../reasoner/congruence.nix { inherit ontology rules facts; forms = allForms; };

  # Compose all rules
  rules = userRules ++ ingest.rules ++ synth.rules ++ congruence.rules;

  e = import ../../datalog.nix { inherit ontology facts rules; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if builtins.all (x: x) [
  # cong is symmetric, so cong b a should hold
  (check "cong is symmetric" (e.holds [ "cong" "b" "a" ]))

  # dependsOn a c  +  cong a b  ⇒  dependsOn b c
  (check "congruence propagates dependsOn through cong" (e.holds [ "dependsOn" "b" "c" ]))

  # providesCapability a cap1 + cong a b ⇒ providesCapability b cap1
  (check "congruence propagates providesCapability through cong" (e.holds [ "providesCapability" "b" "cap1" ]))

  # providesCapability b cap2 + cong a b ⇒ providesCapability a cap2 (reverse direction)
  (check "congruence propagates in reverse direction" (e.holds [ "providesCapability" "a" "cap2" ]))

  # The proof carries congruence attribution
  (check "proof mentions congruence rule" (
    builtins.match ".*congruence.*" (e.explain [ "dependsOn" "b" "c" ]) != null
  ))

  # The engine still terminates
  (check "closure terminates" (builtins.length (e.facts) < 1000))

  # Diagnostics are present
  (check "diagnostics present" (congruence.diagnostics ? generated && congruence.diagnostics.generated > 0))
] then "ok" else "failed"