# Runs the test files of SUMO's tests/ directory (*.kif.tq) on the Horn solver.
#
#   tq = import ./tq.nix { ontology = [ forms of Merge.kif ... ]; }
#   tq.read ./sumo.tests/SP01.kif.tq   ->  { name, note, category, minLang, time, facts, rules, query, answer, needs }
#   tq.run  (tq.read file)             ->  { verdict, ... }
#
# A .tq file holds KIF facts and rules, a (query F) and an (answer A). The verdicts are:
#   pass         the solver agrees with the answer
#   open         the answer is yes and the solver does not derive it. The file leans on an axiom of Merge.kif that is not
#                Horn (an <=>, an existential) and is not loaded, so this is a gap in the solver, not a verdict on SUMO.
#   fail         the answer is no and the solver derives the query, or the answer is yes and is derived against a no
#   unsupported  the file needs more than Horn rules: <=>, forall, or, a row variable, an existential conclusion,
#                a modal or a query that is not a ground atom or a negation or equality of one. Not run: no verdict is claimed.
{ ontology }:
let
  inherit (builtins) all any concatMap elem elemAt filter head isList isString length;
  kif = import ./kif.nix;

  structural = [ "subclass" "subrelation" "disjoint" "domain" ];
  base = filter (f: isList f && f != [ ] && elem (head f) structural && all isString f) ontology;

  headOf = f: if isList f && f != [ ] && isString (head f) then head f else "";
  # Every operator that appears in a form, at any depth.
  heads = f: if isList f then (if headOf f != "" then [ (headOf f) ] else [ ]) ++ concatMap heads f else [ ];
  atomsOf = f: if isString f then [ f ] else concatMap atomsOf f;

  # What is outside Horn logic.
  outside = f:
    any (h: elem h [ "<=>" "forall" "or" "holdsDuring" "modalAttribute" "knows" "believes" "desires" ]) (heads f)
    || any (a: builtins.substring 0 1 a == "@") (atomsOf f);

  # The consequent of a rule must be a plain atom: not, exists, or and the rest cannot be derived.
  plainConsequent = c: !(elem (headOf c) [ "not" "exists" "forall" "or" "and" "=>" "<=>" "equal" ]);

  field = forms: name: head (map (f: tail' f) (filter (f: headOf f == name) forms) ++ [ null ]);
  tail' = f: builtins.tail f;
in
rec {
  inherit base;

  read = path:
    let
      forms = kif.parse (builtins.readFile path);
      meta = [ "note" "time" "category" "minLang" "maxLang" "query" "answer" ];
      one = name: let v = field forms name; in if v == null then null else v;
      rest = filter (f: !(elem (headOf f) meta)) forms;
    in rec {
      name = builtins.baseNameOf path;
      note = one "note";
      category = one "category";
      minLang = one "minLang";
      time = one "time";
      query = let q = one "query"; in if q == null then null else head q;
      answer = one "answer";
      rules = filter (f: headOf f == "=>") rest;
      facts = filter (f: headOf f != "=>") rest;
      # The operators the file asks of a solver beyond Horn rules.
      needs = (if any outside rest then [ "non-Horn rule or fact" ] else [ ])
        ++ (if any (r: !(plainConsequent (elemAt r 2))) (filter (f: headOf f == "=>" && length f == 3) rest) then [ "compound consequent" ] else [ ])
        ++ (if query != null && outside query then [ "non-Horn query" ] else [ ])
        ++ (if query == null || answer == null then [ "no query or answer" ] else [ ])
        ++ (if minLang != null then [ "minLang ${head minLang}" ] else [ ]);
    };

  # Run one file. A file with a needs entry is not run.
  run = t:
    if t.needs != [ ] then { verdict = "unsupported"; inherit (t) name; why = t.needs; }
    else
      let
        e = import ./datalog.nix {
          ontology = null;
          rules = t.rules;
          facts = base ++ t.facts;
        };
        found = e.ask t.query != [ ];
        want = head t.answer;
        agree = if want == "yes" then found else if want == "no" then !found else null;
      in
      if agree == null then { verdict = "unsupported"; inherit (t) name; why = [ "answer ${want}" ]; }
      else { verdict = if agree then "pass" else if want == "yes" then "open" else "fail"; inherit (t) name; found = found; expected = want; };
}
