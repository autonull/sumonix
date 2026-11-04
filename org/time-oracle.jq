# org/time-oracle.jq: the dates of one file, read again in jq (Oniguruma), to check org/extract.nix.
#   jq -S -n -c --rawfile text FILE --arg path PATH -f org/time-oracle.jq     ->  { time, named } for that page
# Run it over the scratch files of the pinned commits and compare with org/pages.json (the loop is in the README).
# The cue lists are the same as in extract.nix.  Everything else is read again: the dates in words, the byte window, the words of a
# window, the break characters, the walk of a JSON page, the pointer, the label, the time of day, the calendar.
def months: {January: "01", February: "02", March: "03", April: "04", May: "05", June: "06", July: "07", August: "08", September: "09",
             October: "10", November: "11", December: "12", Jan: "01", Feb: "02", Mar: "03", Apr: "04", Jun: "06", Jul: "07", Aug: "08",
             Sep: "09", Sept: "09", Oct: "10", Nov: "11", Dec: "12"};
def monthRe: "(?<m>January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept|Sep|Oct|Nov|Dec)";
def mdyRe: monthRe + "\\.? (?<d>[0-9]{1,2})(?:st|nd|rd|th)?,? (?<y>20[0-9]{2})";
def dmyRe: "(?<d>[0-9]{1,2})(?:st|nd|rd|th)? " + monthRe + "\\.?,? (?<y>20[0-9]{2})";
def dateRe: "[0-9]{4}-[0-9]{2}-[0-9]{2}";
def pad2: if length == 1 then "0" + . else . end;
def rewrite: gsub(mdyRe; "\(.y)-\(months[.m])-\(.d | pad2)") | gsub(dmyRe; "\(.y)-\(months[.m])-\(.d | pad2)");
def hasDate: test(dateRe) or test(mdyRe) or test(dmyRe);

def boundCues: ["observation cutoff", "snapshot cutoff", "data cutoff", "explicit cutoff", "analysis cutoff", "evidence cutoff"] | join("|");
def toCues:    ["deadline", "due", "expires", "expire", "expiry", "expiration", "until", "through", "valid to", "end", "ends", "no later than",
                "review by", "refresh by", "next review", "before", "cutoff"] | join("|");
def fromCues:  ["effective", "start", "starts", "starting", "begin", "begins", "since", "from", "after"] | join("|");
def joiners:   ["is", "was", "are", "on", "by", "at", "the", "a", "an", "of", "for", "in", "as", "or", "set", "utc", "date", "time", "local",
                "day", "next", "final", "current", "to"] | join("|");
def asofStems: "access|verif|checked|created|captured|observ| read |retriev|record|submitted|attempted|generated|evaluated|merged|closed|reviewed|inspected|compared|started|finished|completed|published|estimated|prepared|requested|received|occurred|approved|accepted|searched|snapshot|as of|date|origin";

# the last n bytes of a string, as whole characters (a character cut in two becomes a separator in the words anyway)
def ulen: if . < 128 then 1 elif . < 2048 then 2 elif . < 65536 then 3 else 4 end;
def tailBytes($n):
  explode as $cp
  | (reduce range(($cp | length) - 1; -1; -1) as $i ({b: 0, start: ($cp | length), stop: false};
       if .stop then . else (($cp[$i] | ulen) as $u | if .b + $u <= $n then .b += $u | .start = $i else .stop = true end) end)) as $r
  | $cp[$r.start:] | implode;

def camel: gsub("(?<a>[a-z])(?<b>[A-Z])"; "\(.a) \(.b)");
def words: " " + ([camel | ascii_downcase | match("[a-z0-9]+"; "g").string] | join(" ")) + " ";
def afterBreak: split("[\\]\\[|,;(){}]"; null) | last;

def tailCue($cues): (capture("^.* (?<c>" + $cues + ")(?: (?:" + joiners + "))* $") // null) | if . == null then null else .c end;

def role($win):
  ($win | split("\n") | last // "") as $l
  | ($l | tailBytes(80) | afterBreak | words) as $strict
  | ($l | tailBytes(64) | words) as $loose
  | ($strict | tailCue(boundCues)) as $bound
  | ($strict | tailCue(toCues)) as $to
  | ($strict | tailCue(fromCues)) as $from
  | ($loose | test(".*(" + asofStems + ").*")) as $asof
  | if $bound != null then {role: "asof", cue: $bound}
    elif $to != null then {role: "to", cue: $to}
    elif $from != null then {role: "from", cue: $from}
    elif $asof then {role: "asof", cue: "asof"}
    else {role: "other", cue: null} end;

# days since 1970-01-01 for a real date in 2000..2099, else null
def day($d):
  try (($d | strptime("%Y-%m-%d") | mktime) as $s
       | if ($s | todate | .[0:10]) == $d and ($d[0:4] | tonumber) >= 2000 and ($d[0:4] | tonumber) <= 2099 then $s / 86400 else null end)
  catch null;

def isdig: . != "" and test("^[0-9]$");

# the dates of a text, in order: { d, day, nl, role, cue, at }.  One pass over the characters: no slicing of the string by offset.
def scanText:
  . as $t
  | ($t | explode) as $cp
  | ($cp | length) as $len
  | [$t | match(dateRe; "g")] as $ms
  | reduce range(0; $ms | length) as $i ({prevEnd: 0, nl: 0, out: []};
      . as $st
      | $ms[$i] as $m
      | ($m.offset + $m.length) as $end
      | (if $i + 1 < ($ms | length) then $ms[$i + 1].offset else $len end) as $nextEnd
      | $cp[$st.prevEnd:$m.offset] as $prevCp
      | ($st.nl + ([$prevCp[] | select(. == 10)] | length)) as $nl
      | (if ($prevCp | length) == 0 then "" else [$prevCp[-1]] | implode end) as $pc
      | (if $nextEnd == $end then "" else [$cp[$end]] | implode end) as $nc
      | day($m.string) as $day
      | $st | .prevEnd = $end | .nl = $nl
      | if ($pc | isdig) or ($nc | isdig) or $day == null then .
        else
          ($cp[([$st.prevEnd, $m.offset - 80] | max):$m.offset] | implode) as $win
          | role($win) as $r
          | (if $r.role == "to" or $r.role == "from"
             then ($cp[$end:([$nextEnd, $end + 64] | min)] | implode | (split("\n")[0] // "") | capture("^T(?<t>[0-9]{2}:[0-9]{2}(:[0-9]{2})?(\\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?)") // null | if . == null then null else .t end)
             else null end) as $at
          | .out += [{d: $m.string, day: $day, nl: $nl, at: $at} + $r]
        end)
  | .out;

def esc: gsub("~"; "~0") | gsub("/"; "~1");
def idKeys: ["opportunity_id", "id", "program_name", "name", "title"];
def ctxOf($ctx):
  . as $v
  | (idKeys | map(select(($v[.] | type) == "string"))) as $ks
  | if ($ks | length) == 0 then $ctx
    else {label: $v[$ks[0]], priority: (if ($v.priority | type) == "string" then $v.priority else null end)} end;

# every string with a date: { ptr, key, ctx, text }
def strings($ptr; $key; $ctx):
  if type == "string" then rewrite as $w | if ($w | test(dateRe)) then [{ptr: $ptr, key: $key, ctx: $ctx, text: $w}] else [] end
  elif type == "object" then ctxOf($ctx) as $c | . as $o | [($o | keys[]) as $k | $o[$k] | strings($ptr + "/" + ($k | esc); $k; $c)] | add // []
  elif type == "array" then [to_entries[] | .key as $i | .value | strings($ptr + "/" + ($i | tostring); $key; $ctx)] | add // []
  else [] end;
def strings: strings(""; ""; {label: null, priority: null});

def itemsOf($text; $path):
  if ($path | test("\\.json$")) and ($text | test("[0-9]{19,}") | not)
  then [($text | fromjson | strings)[] | . as $s | ("\($s.key): \($s.text)" | scanText)[] | . + {loc: $s.ptr, ctx: $s.ctx}]
  else [($text | rewrite | scanText)[] | . + {loc: "L\(.nl + 1)", ctx: {label: null, priority: null}}] end;

def slim: {d, loc, cue} + (if .at != null then {at} else {} end) + (if .ctx.label != null then {label: .ctx.label} else {} end)
          + (if .ctx.priority != null then {priority: .ctx.priority} else {} end);
def timeOf:
  if length == 0 then null
  else (map(select(.role == "asof"))) as $asof
    | ($asof | map(.day) | max) as $mx
    | {asof: (if ($asof | length) == 0 then null
              else {min: ($asof | min_by(.day) | .d), max: ($asof | map(select(.day == $mx)) | first | .d), n: ($asof | length),
                    maxLoc: ($asof | map(select(.day == $mx)) | first | .loc)} end),
       from: map(select(.role == "from") | slim),
       to: map(select(.role == "to") | slim),
       other: (map(select(.role == "other")) | length)}
  end;

{time: (if ($text | hasDate) then itemsOf($text; $path) | timeOf else null end),
 named: ([($path | scanText)[].d] | reduce .[] as $d ([]; if index($d) then . else . + [$d] end))}
