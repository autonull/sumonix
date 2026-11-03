"""Writes tags.json: the small facets of Hugging Face's public tag lists (models-tags-by-type, datasets-tags-by-type).
Languages (8,333 tags), per-dataset ids and the 74 fine task ids are left out. Run it again to refresh, then diff."""
import json, urllib.request, datetime, hashlib
def get(kind):
    return json.load(urllib.request.urlopen(f'https://huggingface.co/api/{kind}-tags-by-type'))
ds, md = get('datasets'), get('models')
ids = lambda d, k: [x['id'].split(':', 1)[-1] for x in d[k]]
other = ids(ds, 'other')
snap = {
    'source': ['https://huggingface.co/api/datasets-tags-by-type', 'https://huggingface.co/api/models-tags-by-type'],
    'fetched': datetime.date.today().isoformat(),
    'modality': ids(ds, 'modality'),
    'task': sorted(set(ids(ds, 'task_categories')) | set(ids(md, 'pipeline_tag'))),
    'license': ids(ds, 'license'),
    'domain': [t for t in other if t not in ('synthetic',)],
    'origin': [t for t in other if t == 'synthetic'],
    'size': ids(ds, 'size_categories'),
    'format': ids(ds, 'format'),
    'library': ids(ds, 'library'),
}
open('tags.json', 'w').write(json.dumps(snap, indent=1) + '\n')
print({k: len(v) for k, v in snap.items() if isinstance(v, list) and k != 'source'})
