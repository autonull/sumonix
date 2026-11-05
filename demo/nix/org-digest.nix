# Org-level demo: the Pick Your AI pages, taxonomized under SUMO.
# Prints a compact digest: totals, kinds, copies, stale names, and the proof of one finding.
let
  pins = import ../../pins.nix;
  c = import ../../org/check.nix { merge = pins.merge; midLevel = pins.midLevel; };
  pad = n: let s = toString n; in if builtins.stringLength s < 2 then " " + s else s;
  byKind = builtins.sort (a: b: a.v > b.v) (builtins.attrValues (builtins.mapAttrs (k: v: { n = k; v = v; }) c.kinds));
  top = builtins.genList (i: builtins.elemAt byKind i) 6;
  copies = builtins.sort (a: b: a.n < b.n) (builtins.attrValues (builtins.mapAttrs (k: v: { n = k; v = v; }) c.copies));
  shownCopies = builtins.filter (x: x.v.identicalPairs > 0 || x.v.largestIdentical > 1) copies;
  stale = [ (builtins.head c.staleNames) ];
  whyStale = c.why [ "staleName" (builtins.head (builtins.head stale)) (builtins.elemAt (builtins.head stale) 1) ];
in ''
Total pages taxonomized:            ${toString c.pages}
  process pages (class reasoning):  ${toString c.processPages}
  unclassified (no rule matches):   ${toString (builtins.length c.unclassified)}

Biggest page kinds:
${builtins.concatStringsSep "\n" (map (x: "  ${x.n}: ${toString x.v}") top)}

Identical copies found:
${builtins.concatStringsSep "\n" (map (x: "  ${x.n}: ${toString x.v.largestIdentical} of ${toString x.v.pages} identical") shownCopies)}

Former team names still in use: ${toString (builtins.length c.staleNames)}
  e.g. ${builtins.head (builtins.head stale)} → “${builtins.elemAt (builtins.head stale) 1}”

The proof that this page uses a retired name:
${whyStale}
''
