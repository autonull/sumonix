# M0.2 — located KIF diagnostics: syntax positions and typo suggestions.
# Usage: nix eval --expr 'import ./tests/unit/diag.nix'  -> "ok"
let
  diag = import ../../lib/kif-diag.nix { };
  inherit (builtins) all filter head length match;

  run = file: text: domains: diag.diagnose { inherit file text domains; };
  hasPos = prefix: lines:
    filter (l: match "${prefix}:[0-9]+:[0-9]+: .*" l != null) lines;

  clean = run "a.kif" "(instance nginx NIXPackage)\n(dependsOn nginx openssl)\n" { dependsOn = { }; };
  unbalancedClose = run "b.kif" "(instance nginx NIXPackage)\n)\n" { };
  unclosed = run "c.kif" "(and\n  (a 1)\n" { a = { }; };
  unterminated = run "e.kif" "(a \"foo\n" { a = { }; };
  typo = run "d.kif" "(instance nginx NIXPackage)\n(dependOn nginx openssl)\n" {
    dependsOn = { };
    instance = { };
  };
  structural = run "f.kif" "(=> (and (a 1)) (b 2))\n" { a = { }; b = { }; };

  check = what: ok: if ok then true else throw "failed: ${what}";
in
if all (x: x) [
  (check "a clean file has no diagnostics"
    (clean.ok && clean.forms == 2 && clean.text == ""))
  (check "an unbalanced ')' carries file:line:col"
    (!unbalancedClose.ok
      && length (hasPos "b.kif" unbalancedClose.errors) == 1
      && match "b.kif:2:1: error: unbalanced.*" (head unbalancedClose.errors) != null))
  (check "an unclosed '(' points at the opening paren"
    (!unclosed.ok
      && length (hasPos "c.kif" unclosed.errors) == 1
      && match "c.kif:1:1: error: unclosed.*" (head unclosed.errors) != null))
  (check "an unterminated string carries its column"
    (!unterminated.ok
      && match "e.kif:1:4: error: unterminated string literal" (head unterminated.errors) != null))
  (check "a typo is a warning with a suggestion"
    (!typo.ok
      && length typo.errors == 0
      && length typo.warnings == 1
      && match "d.kif:2:1: warning: unknown predicate 'dependOn'.*dependsOn.*" (head typo.warnings) != null))
  (check "structural heads are known without domains" structural.ok)
] then "ok" else "failed"
