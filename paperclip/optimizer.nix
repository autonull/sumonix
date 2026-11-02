# The paperclip optimizer: SUMO says which actions are allowed, a knapsack says which of them to take.
#
#   optimize { merge; world; protect ? null }  ->  { permitted, prohibited, chosen, clips, cost, ... }
#
# merge and midLevel are the paths of Merge.kif and Mid-level-ontology.kif, world is world.kif's. The rules are analysis.kif and decision.kif; the solver is ../datalog.nix.
{ merge, midLevel, world, protect ? null, without ? [ ] }:
let
  kif = import ../kif.nix;
  text = builtins.readFile;
  rules = file: builtins.filter (f: builtins.head f == "=>") (kif.parse (text file));

  # The structural facts of the two ontologies the rules read (Iron, Copper ... are the mid-level's). Nothing else of them is loaded.
  keep = [ "subclass" "subrelation" "disjoint" "domain" ];
  merged = builtins.filter (f: builtins.isList f && f != [ ] && builtins.elem (builtins.head f) keep && builtins.all builtins.isString f)
    (kif.parse (text merge) ++ kif.parse (text midLevel));
  facts = merged ++ builtins.filter (f: builtins.head f != "=>") (kif.parse (text world));
  facts' = if protect == null then facts else facts ++ map (c: [ "protectedClass" c ]) protect;

  solve = rules: facts: import ../datalog.nix { ontology = null; inherit rules facts; };
  # `without` lists positions (1 is the first) of rules of analysis.kif to leave out: how the tests ask what each rule is worth.
  analysis = let rs = rules ./analysis.kif; in builtins.concatLists (builtins.genList (i: if builtins.elem (i + 1) without then [ ] else [ (builtins.elemAt rs i) ]) (builtins.length rs));
  one = solve analysis facts';
  two = solve (rules ./decision.kif) one.facts; # stratum 2 starts from everything stratum 1 entails

  holds = e: f: e.holds f;
  acts = map (f: builtins.elemAt f 1) (builtins.filter (f: builtins.head f == "candidate") facts);
  num = rel: act: builtins.fromJSON (builtins.elemAt (builtins.head (builtins.filter (f: builtins.head f == rel && builtins.elemAt f 1 == act) facts)) 2);
  budget = builtins.fromJSON (builtins.elemAt (builtins.head (builtins.filter (f: builtins.head f == "budget") facts)) 2);

  # 0/1 knapsack: best[w] is the best set of actions that costs at most w.
  knapsack = items:
    let
      empty = builtins.genList (_: { value = 0; set = [ ]; }) (budget + 1);
      add = best: item:
        builtins.genList
          (w:
            let skip = builtins.elemAt best w; in
            if w < item.cost then skip
            else
              let take = builtins.elemAt best (w - item.cost); v = take.value + item.clips; in
              if v > skip.value then { value = v; set = take.set ++ [ item.act ]; } else skip)
          (budget + 1) ;
    in builtins.elemAt (builtins.foldl' add empty items) budget;

  item = act: { inherit act; clips = num "clips" act; cost = num "cost" act; };
  permitted = builtins.filter (a: two.holds [ "permitted" a ]) acts;
  best = knapsack (map item permitted);
  greedy = knapsack (map item acts); # the optimizer with no rules: every candidate is a resource
in
{
  inherit budget permitted;
  prohibited = builtins.filter (a: one.holds [ "prohibited" a ]) acts;
  inconsistent = builtins.filter (a: let r = builtins.elemAt (builtins.head (builtins.filter (f: builtins.head f == "resource" && builtins.elemAt f 1 == a) facts)) 2; in one.holds [ "inconsistent" r ]) acts;
  notFeedstock = builtins.filter (a: !(one.holds [ "feedstock" a ])) acts;
  badAgent = builtins.filter (a: !(one.holds [ "agentTyped" a ])) acts;
  chosen = best.set;
  clips = best.value;
  cost = builtins.foldl' (s: a: s + num "cost" a) 0 best.set;
  unconstrained = { chosen = greedy.set; clips = greedy.value; };
  why = act: one.explain [ "prohibited" act ];
}
