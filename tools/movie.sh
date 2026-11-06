#!/usr/bin/env bash
# tools/movie.sh [cast] [out.gif] — turn the asciicast into an animated GIF.
#
# GitHub renders GIFs in READMEs but strips <script> embeds, so the cast is
# rasterised: each distinct text state becomes one PNG (Chromium is the text
# rasteriser, so emoji render in colour), then ffmpeg assembles them with the
# timing from the cast.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAST="${1:-$ROOT/docs/demo/tour.cast}"
OUT="${2:-$ROOT/docs/demo/tour.gif}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$(dirname "$OUT")"
mkdir -p "$TMP/frames"

python3 - "$CAST" "$TMP" <<'PY'
import html, json, os, re, sys

cast, tmp = sys.argv[1], sys.argv[2]
lines = open(cast, encoding="utf-8").read().splitlines()
header = json.loads(lines[0])
rows = header["term"]["rows"]
events = [json.loads(l) for l in lines[1:] if l.strip()]

ansi = __import__("re").compile(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07")

buffer = ""
states = []          # (text, seconds)
prev_t = 0.0
for ev in events:
    t, kind, data = ev[0], ev[1], ev[2]
    if kind != "o":
        continue
    data = ansi.sub("", data).replace("\r\n", "\n").replace("\r", "")
    if not data:
        continue
    buffer += data
    visible = buffer.split("\n")[-rows:]
    states.append(["\n".join(visible), max(0.05, min(1.2, t - prev_t))])
    prev_t = t

# Hold the final frame long enough to read.
if states:
    states[-1][1] = 2.5

with open(os.path.join(tmp, "states.json"), "w") as f:
    json.dump(states, f)
print(f"{len(states)} states, {rows} rows")
PY

python3 - "$TMP" <<'PY'
import html, json, os, sys
tmp = sys.argv[1]
states = json.load(open(os.path.join(tmp, "states.json")))

page = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;padding:0;background:#0b0f14;}}
pre{{margin:0;padding:18px;color:#d8dee9;background:#0b0f14;
    font:13px/1.35 "DejaVu Sans Mono","Noto Color Emoji",monospace;
    white-space:pre;}}</style></head><body><pre>{body}</pre></body></html>"""

for i, (text, _dur) in enumerate(states):
    with open(os.path.join(tmp, f"frame{i:04d}.html"), "w", encoding="utf-8") as f:
        f.write(page.format(body=html.escape(text)))
print("html frames:", len(states))
PY

n=$(python3 -c "import json,sys;print(len(json.load(open('$TMP/states.json'))))")
for i in $(seq 0 $((n - 1))); do
  chromium --headless --no-sandbox --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 \
    --window-size=1180,760 \
    --screenshot="$TMP/frames/$(printf '%04d' "$i").png" \
    "file://$TMP/frame$(printf '%04d' "$i").html" >/dev/null 2>&1
done

# Repeat each state for its duration at 10 fps, so timing survives in the GIF.
python3 - "$TMP" <<'PY'
import json, os, shutil, sys
tmp = sys.argv[1]
states = json.load(open(os.path.join(tmp, "states.json")))
seq = os.path.join(tmp, "seq")
os.makedirs(seq, exist_ok=True)
k = 0
for i, (_text, dur) in enumerate(states):
    for _ in range(max(1, int(round(dur * 10)))):
        shutil.copy(os.path.join(tmp, "frames", f"{i:04d}.png"),
                    os.path.join(seq, f"{k:05d}.png"))
        k += 1
print("gif frames:", k)
PY

ffmpeg -loglevel error -y -framerate 10 -i "$TMP/seq/%05d.png" \
  -vf "scale=1180:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 "$OUT"

[ -s "$OUT" ] || { echo "gif generation failed" >&2; exit 1; }
printf 'wrote %s (%s)\n' "$OUT" "$(du -h "$OUT" | cut -f1)"
