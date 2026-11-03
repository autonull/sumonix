# org/due.jq: the report of org/due.nix, worked out again from org/pages.json in jq.
#   jq -S -L org --arg today 2026-11-03 --argjson examples false -f org/due.jq org/pages.json
include "rules";

def dayNo: strptime("%Y-%m-%d") | mktime / 86400;
def band: if . < 0 then "past" elif . == 0 then "today" elif . <= 7 then "week" elif . <= 30 then "month" else "later" end;
def isExample: .path | ascii_downcase | test("^(.*/)?(examples?|tests?|fixtures?|testdata|__tests__)/.*");
def pageId: "\(.repo | atom):\(.path)";
def firstSet: map(select(. != null)) | first // null;
def rank: if .priority == null then "~" else .priority end;
($today | dayNo) as $d0

| def items($field):
    [ .[] | select(.time != null) | select($examples or (isExample | not)) | . as $p
      | ($p.time[$field] // [])[]
      | (if has("label") then "\($p.repo | atom)/\(.label)" else ($p | pageId) end) as $who
      | { key: "\($who)|\(.d)", who: $who, date: .d, days: ((.d | dayNo) - $d0), cue: .cue, at: (.at // null),
          label: (.label // null), priority: (.priority // null),
          where: { page: ($p | pageId), loc: .loc, kind: ($p | classify | .kind) } } ];

  def merged:
    . as $is | $is[0] as $h
    | { date: $h.date, days: $h.days, band: ($h.days | band), at: ($is | map(.at) | firstSet), label: ($is | map(.label) | firstSet),
        priority: ($is | map(.priority) | firstSet), cues: ($is | map(.cue) | unique),
        where: ($is | map(.where) | reduce .[] as $w ([]; if index([$w]) then . else . + [$w] end) | sort_by(.page)), who: $h.who };

  def groups($field): items($field) | group_by(.key) | map(merged);
  def soonest: sort_by([.days, rank, .who, .date]);
  def clean: map(del(.who));

  groups("to") as $ends | groups("from") as $starts
| { today: $today, day: $d0,
    ends: { ahead: ($ends | map(select(.days >= 0)) | soonest | clean),
            past: ($ends | map(select(.days < 0)) | sort_by([(0 - .days), rank, .who, .date]) | clean) },
    starts: { ahead: ($starts | map(select(.days >= 0)) | soonest | clean) } }
