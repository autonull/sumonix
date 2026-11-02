"""An independent reading of sumo.tests for tests/bags.nix: its own KIF reader, its own categories, and its own list of
the files that a Horn solver cannot take. Prints JSON; tests/bags.expected.json is that output."""
import glob, json, os, re
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
TOKEN = re.compile(r'[()]|"(?:[^"\\]|\\.)*"|;[^\n]*|[^ \t\r\n()";]+')

def read(text):
    stack = [[]]
    for t in TOKEN.findall(text):
        if t.startswith(';'): continue
        if t == '(': stack.append([])
        elif t == ')':
            d = stack.pop(); stack[-1].append(d)
        else: stack[-1].append(t)
    return stack[0]

def walk(f):
    if isinstance(f, list):
        for x in f: yield from walk(x)
    else: yield f

def ops(f):
    if isinstance(f, list):
        if f and isinstance(f[0], str): yield f[0]
        for x in f: yield from ops(x)

META = {'note', 'time', 'category', 'minLang', 'maxLang', 'query', 'answer'}
PLAIN = {'not', 'exists', 'forall', 'or', 'and', '=>', '<=>', 'equal'}
BEYOND = {'<=>', 'forall', 'or', 'holdsDuring', 'modalAttribute', 'knows', 'believes', 'desires'}
out = {'categories': {}, 'unsupported': [], 'tq': 0, 'kb': 0}
for path in sorted(glob.glob(root + '/sumo.tests/*.kif.tq')):
    name = os.path.basename(path)
    forms = read(open(path, encoding='latin-1').read())
    head = lambda f: f[0] if isinstance(f, list) and f and isinstance(f[0], str) else ''
    cat = next((f[1] for f in forms if head(f) == 'category'), None)
    out['categories'][cat or '-'] = out['categories'].get(cat or '-', 0) + 1
    body = [f for f in forms if head(f) not in META]
    query = next((f[1] for f in forms if head(f) == 'query'), None)
    answer = next((f[1] for f in forms if head(f) == 'answer'), None)
    minlang = any(head(f) == 'minLang' for f in forms)
    beyond = any(o in BEYOND for f in body for o in ops(f)) or any(a.startswith('@') for f in body for a in walk(f))
    compound = any(head(f) == '=>' and len(f) == 3 and head(f[2]) in PLAIN for f in body)
    qbeyond = query is not None and (any(o in BEYOND for o in ops(query)) or any(a.startswith('@') for a in walk(query)))
    if beyond or compound or qbeyond or minlang or query is None or answer is None or answer not in ('yes', 'no'):
        out['unsupported'].append(name)
    out['tq'] += 1
out['kb'] = sum(1 for l in open(root + '/sumo.full/PINS') if l.strip() and not l.startswith('#'))
print(json.dumps(out, indent=1, sort_keys=True))
