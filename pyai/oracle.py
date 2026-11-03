"""A second reading of pyai/check.nix: plain Python over the same JSON files and hf/anchors.kif, with its own KIF reader.
Prints JSON; expected.json is that output and tests/pyai.nix must agree."""
import json, os, re
here = os.path.dirname(os.path.abspath(__file__))
fields = json.load(open(f'{here}/fields.json'))['fields']
cw = json.load(open(f'{here}/crosswalk.json'))['values']
tags = json.load(open(f'{here}/../hf/tags.json'))
anchors = {}
for facet, tag, how, cls in re.findall(r'^\(hfAnchor (\S+) (\S+) (\S+) (\S+)\)', open(f'{here}/../hf/anchors.kif').read(), re.M):
    anchors[f'{facet}:{tag}'] = cls
primary = {'Dataset Modality': 'modality', 'Dataset Category': 'role', 'Access Classification': 'access', 'License/Rights Status': 'substance'}
problems, tally, off, sumo, used = [], {}, {}, {}, set()
for f, values in fields.items():
    tally[f], off[f], sumo[f] = {}, [], {}
    for v in values:
        if v not in cw[f]: problems.append(['value has no crosswalk entry', f, v]); continue
        e = cw[f][v]
        tally[f][e['axis']] = tally[f].get(e['axis'], 0) + 1
        if e['axis'] not in (primary[f], 'planning'): off[f].append(v)
        if e['hf']:
            used.add(e['hf'])
            facet, tag = e['hf'].split(':')
            if tag not in tags[facet]: problems.append(['hf tag not in the snapshot', e['hf']])
            if e['hf'] not in anchors: problems.append(['hf tag has no SUMO anchor', e['hf']])
        c = e['sumo'] or (anchors.get(e['hf']) if e['hf'] else None)
        if c: sumo[f][v] = c
    problems += [['crosswalk entry for a value the field lacks', f, v] for v in cw[f] if v not in values]
print(json.dumps({'hfUnused': sorted(t for t in tags['modality'] if f'modality:{t}' not in used), 'offAxis': off, 'problems': problems,
                  'sumo': sumo, 'tally': tally}, indent=1, sort_keys=True, ensure_ascii=False))
