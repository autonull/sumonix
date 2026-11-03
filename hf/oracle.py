"""An independent check of anchors.kif against tags.json and the SUMO files: its own KIF reader and its own ancestor search.
Prints JSON; expected.json is that output, and tests/hf.nix must agree."""
import json, os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
TOKEN = re.compile(r'[()]|"(?:[^"\\]|\\.)*"|;[^\n]*|[^ \t\r\n()";]+')
def read(path):
    stack = [[]]
    for t in TOKEN.findall(open(path, encoding='latin-1').read()):
        if t.startswith(';'): continue
        if t == '(': stack.append([])
        elif t == ')': d = stack.pop(); stack[-1].append(d)
        else: stack[-1].append(t)
    return stack[0]
sumo = read(f'{here}/../sumo.full/Merge.kif') + read(f'{here}/../sumo.full/Mid-level-ontology.kif')
mine = read(f'{here}/anchors.kif')
snap = json.load(open(f'{here}/tags.json'))
sub = lambda fs: [(f[1], f[2]) for f in fs if len(f) == 3 and f[0] == 'subclass' and all(isinstance(a, str) for a in f)]
above = {}
for c, p in sub(sumo): above.setdefault(c, set()).add(p)
sumo_classes = set(above) | {p for v in above.values() for p in v}
for c, p in sub(mine): above.setdefault(c, set()).add(p)
def up(c):
    seen, todo = set(), [c]
    while todo:
        for p in above.get(todo.pop(), ()):
            if p not in seen: seen.add(p); todo.append(p)
    return seen
groups = {f[1]: f[2] for f in mine if f[0] == 'hfGroup'}
anchors = [f[1:] for f in mine if f[0] == 'hfAnchor']
unanch = [f[1:3] for f in mine if f[0] == 'hfUnanchored']
declared = {c for c, _ in sub(mine)}
bad = []
for facet, tag, how, cls in anchors:
    if tag not in snap[facet]: bad.append(['no such tag', facet, tag])
    if how in ('exact', 'broader') and cls not in sumo_classes: bad.append(['class not in SUMO', facet, tag, cls])
    if how == 'new' and (cls not in declared or cls in sumo_classes): bad.append(['new class missing or already in SUMO', facet, tag, cls])
    if how == 'instance' and cls not in sumo_classes: bad.append(['class not in SUMO', facet, tag, cls])
    g = groups[facet]
    if how != 'instance' and cls != g and g not in up(cls): bad.append(['outside its group', facet, tag, cls, g])
for c, p in sub(mine):
    if p not in sumo_classes and p not in declared: bad.append(['parent not in SUMO', c, p])
covered = {(f, t) for f, t, *_ in anchors} | {tuple(u) for u in unanch}
for facet in groups:
    for tag in snap[facet]:
        if (facet, tag) not in covered: bad.append(['tag has no anchor', facet, tag])
count = {}
for facet, tag, how, cls in anchors: count.setdefault(facet, {}).setdefault(how, 0); count[facet][how] += 1
print(json.dumps({'anchors': count, 'unanchored': sorted(map(list, unanch)), 'new': sorted(declared), 'violations': bad,
                  'twice': sorted({(f, t) for f, t, *_ in anchors if [(a[0], a[1]) for a in anchors].count((f, t)) > 1})}, indent=1, sort_keys=True))
