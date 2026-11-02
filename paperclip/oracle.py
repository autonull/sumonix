"""An independent reading of the paperclip problem: its own KIF reader, its own closures by search, and a dynamic program over
(item, energy left) with memoization instead of the Nix knapsack's table. Prints the numbers test.nix expects, as JSON."""
import json, re, sys
from functools import lru_cache

TOKEN = re.compile(r'[()]|"(?:[^"\\]|\\.)*"|;[^\n]*|[^ \t\r\n()";]+')

def read(path):
    stack = [[]]
    for t in TOKEN.findall(open(path, encoding='latin-1').read()):
        if t.startswith(';'):
            continue
        if t == '(':
            stack.append([])
        elif t == ')':
            done = stack.pop()
            stack[-1].append(done)
        else:
            stack[-1].append(t)
    return stack[0]

here = sys.argv[1] if len(sys.argv) > 1 else '..'
forms = read(f'{here}/sumo.full/Merge.kif') + read(f'{here}/sumo.full/Mid-level-ontology.kif')
world = read(f'{here}/paperclip/world.kif')
atoms = lambda f: all(isinstance(a, str) for a in f)
get = lambda fs, head: [f for f in fs if isinstance(f, list) and f and f[0] == head and atoms(f)]

above = {}                                    # class -> the classes directly above it
for _, c, d in [f for f in get(forms + world, 'subclass') if len(f) == 3]:
    above.setdefault(c, set()).add(d)

def ancestors(c):                             # every class above c, by search
    seen, todo = set(), [c]
    while todo:
        for d in above.get(todo.pop(), ()):
            if d not in seen:
                seen.add(d); todo.append(d)
    return seen

classes = {}                                  # thing -> the classes it is asserted in
for _, x, c in [f for f in get(world, 'instance') if len(f) == 3]:
    classes.setdefault(x, set()).add(c)
isa = lambda x, c: any(c == k or c in ancestors(k) for k in classes.get(x, ()))

disjoint = [(f[1], f[2]) for f in get(forms, 'disjoint') if len(f) == 3]
value = lambda head, key: {f[1]: f[2] for f in get(world, head) if len(f) == 3}
resource, agent, clips, cost = (value(h, 0) for h in ('resource', 'agent', 'clips', 'cost'))
part = {}
for _, x, y in [f for f in get(world, 'part') if len(f) == 3]:
    part.setdefault(x, set()).add(y)
acts = [f[1] for f in get(world, 'candidate')]
budget = int([f for f in get(world, 'budget')][0][2])
domain_agent = [f[3] for f in get(forms, 'domain') if f[1] == 'agent' and f[2] == '2'][0]

def solve(protect_classes, parts=True, subrelation=True, disjoints=True):
    def protected(x, seen=()):
        if any(isa(x, p) for p in protect_classes):
            return True
        return parts and any(protected(y, seen + (x,)) for y in part.get(x, ()) if y not in seen)
    feed = {f[1] for f in get(world, 'feedstockClass')}
    # resource is a subrelation of patient: without that step an action is never done to anything
    prohibited = [a for a in acts if subrelation and protected(resource[a])]
    inconsistent = [a for a in acts if disjoints and any(isa(resource[a], p) and isa(resource[a], q) for p, q in disjoint)]
    feedstock = [a for a in acts if any(isa(resource[a], c) for c in feed)]
    typed = [a for a in acts if isa(agent[a], domain_agent)]
    permitted = [a for a in acts if a in feedstock and a in typed and a not in prohibited and a not in inconsistent]
    return prohibited, inconsistent, feedstock, typed, permitted

def best(items):                              # the most clips for at most `budget` energy
    items = sorted(items)
    @lru_cache(None)
    def go(i, left):
        if i == len(items):
            return 0
        a = items[i]
        skip = go(i + 1, left)
        c = int(cost[a])
        return max(skip, int(clips[a]) + go(i + 1, left - c)) if c <= left else skip
    return go(0, budget)

protect = [f[1] for f in get(world, 'protectedClass')]
prohibited, inconsistent, feedstock, typed, permitted = solve(protect)
variant = lambda **k: sorted(solve(protect, **k)[4])
print(json.dumps({
    'permitted': sorted(permitted), 'prohibited': sorted(prohibited), 'inconsistent': sorted(inconsistent),
    'notFeedstock': len(acts) - len(feedstock), 'badAgent': sorted(a for a in acts if a not in typed),
    'optimum': best(permitted), 'unconstrained': best(acts), 'budget': budget,
    'without': {'parthood': variant(parts=False), 'subrelation': variant(subrelation=False), 'disjointness': variant(disjoints=False)},
}, indent=1))
