"""What decide.nix must answer, from a separate reading of pyai/crosswalk.json, hf/tags.json and hf/anchors.kif.
Prints JSON; tests/decide.expected.json is that output."""
import json, os, re
here = os.path.dirname(os.path.abspath(__file__))
cw = json.load(open(f'{here}/../pyai/crosswalk.json'))['values']
tags = json.load(open(f'{here}/../hf/tags.json'))
anch = {f'{a}:{b}': (c, d) for a, b, c, d in re.findall(r'^\(hfAnchor (\S+) (\S+) (\S+) (\S+)\)', open(f'{here}/../hf/anchors.kif').read(), re.M)}
pyai = {}
for field, vals in cw.items():
    for value, e in vals.items():
        cls = e['sumo'] or (anch[e['hf']][1] if e['hf'] else None)
        pyai[f'{field}|{value}'] = {'axis': e['axis'], 'hasHf': e['hf'] is not None, 'sumo': cls, 'hasSumo': cls is not None}
hf = {}
for facet in ('modality', 'task', 'domain', 'origin', 'license'):
    for tag in tags[facet]:
        k = f'{facet}:{tag}'
        hf[k] = {'kind': anch[k][0] if k in anch else None, 'sumo': anch[k][1] if k in anch else None, 'hasAnchor': k in anch}
print(json.dumps({'pyai': pyai, 'hf': hf}, indent=1, sort_keys=True, ensure_ascii=False))
