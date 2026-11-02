# A paperclip optimizer in SUMO

An agent, `Clippy`, may turn lots of material into paperclips. It has 150 units of energy. The ontology decides which
lots it may use. A knapsack decides which of those to take. 60 lots, in `world.kif` (written by `gen_world.py`).

    candidate act00, agent Clippy, resource lot00, result clips00, clips 280, cost 35

The rules are KIF, run by `../datalog.nix`, in two strata (`not` is only safe on a fixpoint):

| rule | SUMO operator | what it does |
| --- | --- | --- |
| `isa` | `instance`, `subclass` | a thing belongs to every class above its own (Cow, Cattle, DomesticAnimal, Animal, Organism) |
| `subrelation` | `subrelation` | `resource` and `result` are below `patient`, so what is used up is something done to |
| `protected` | `protectedClass`, `part` | the members of Organism and Building are protected, and so are the parts of a protected thing |
| `prohibited` | | an action done to a protected thing |
| `feedstock` | | the resource belongs to ElementalSubstance, MetallicAlloy or Wire |
| `agentTyped` | `domain` | the agent role takes an AutonomousAgent (`domain agent 2`) |
| `inconsistent` | `disjoint` | a lot in two disjoint classes, such as Substance and CorpuscularObject |
| `permitted` | | feedstock, typed, not prohibited, not inconsistent |

Result: 40 of 60 lots permitted. The best plan takes 6,520 clips for 150 energy. With no rules the same optimizer takes
7,230 and tears down the house (act09) and the three steel lots that are parts of it. Each proof is a tree: `why "act14"` shows that a steel lot is protected because it
is a part of `house1`, which is a House, a ResidentialBuilding, a Building.

## How it is checked

`oracle.py` is a second reading of the problem: its own KIF reader, class closures by search, and a memoized dynamic
program instead of the Nix table. `expected.json` is its output. `test.nix` runs the problem through the solver and compares
the permitted lots, the prohibited lots, the optimum, and what each of three rules is worth when it is left out (parthood +3
lots, subrelation +3, disjointness +1). `mlnix eval paperclip/test.nix` prints `"ok"`, and so does Nix 2.35.4.

SUMO itself is not consistent: `Wood` is both a Substance and a CorpuscularObject, which are disjoint. The audit finds it (act43).
