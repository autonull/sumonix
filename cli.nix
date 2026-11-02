# The commands of bin/sumo-nix. cli.nix ROOT [ "command" "arg" ... ] -> the text to print.
root: args:
let
  b = import ./bags.nix { inherit root; };
  kif = import ./kif.nix;
  cmd = if args == [ ] then "help" else builtins.head args;
  rest = if args == [ ] then [ ] else builtins.tail args;
  tq = import ./tq.nix { ontology = kif.parse (builtins.readFile (root + "/sumo.full/Merge.kif")); };
  runBags = names:
    let
      p = b.compose (if names == [ ] then [ "tests-all" ] else names);
      rs = map (f: tq.run (tq.read (root + "/sumo.tests/${f}"))) p.tests;
      count = v: builtins.length (builtins.filter (r: r.verdict == v) rs);
      line = r: "  ${r.verdict}  ${r.name}" + (if r ? why then "  (" + builtins.concatStringsSep "; " r.why + ")" else "");
    in builtins.concatStringsSep "\n" (map line rs ++ [ "" "pass ${toString (count "pass")}, open ${toString (count "open")}, fail ${toString (count "fail")}, unsupported ${toString (count "unsupported")} of ${toString (builtins.length rs)}" ]) + "\n";
in
if cmd == "help" then
  (if rest == [ ] then b.help.top
   else if builtins.head rest == "bag" then b.help.bag (builtins.elemAt rest 1)
   else if builtins.head rest == "compose" then b.help.compose
   else if builtins.head rest == "tq" then b.help.tq
   else throw "no help screen called ${builtins.head rest}: try help, help bag NAME, help compose, help tq")
else if cmd == "bags" then b.list
else if cmd == "compose" then b.plan rest
else if cmd == "match" then b.matchLine rest
else if cmd == "tq" then runBags rest
else throw "no command called ${cmd}: run help"
