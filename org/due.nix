# org/due.nix: what the pages say ends or starts, and how far that is from a day.
#
#   import ./org/due.nix { pages; today = "2026-11-03"; }  ->  { today, day, ends = { ahead, past }, starts = { ahead } }
#
# `pages` is org/pages.json (made by org/extract.nix).  `today` is the caller's: there is no clock here, so the same pages and the
# same day give the same answer on every machine.  A date is the claim of a page, read from its words (see org/extract.nix).  This
# file does not say the claim is still true: a funding record that says "deadline 2026-11-03" may have been closed, or sent, after the
# commit that was read.
#
# An item is one record and one date (or one page and one date, when the date is not in a record), merged over every page that says it:
#   date, days   the date, and the date minus today.  Negative is past.
#   band         past (days < 0), today (0), week (1 to 7), month (8 to 30), later.
#   at           the time of day when the page gives one beside the date (`11:00:00Z`), else null.  On the day itself, look at it first.
#   label        the id or name of the record in a JSON page, else null.   priority   the record's own `priority`, else null.
#   cues         the words that made it an end or a start.   where   every page, place and kind that says it.
# Sorted soonest first, then by priority (P0 before P1; none last), then by name.  `ends.past` is the other way: most recent first.
# Pages under examples, tests or fixtures are left out unless `examples = true`: their dates are made up.
{ pages, today, examples ? false }:
let
  inherit (builtins) attrNames concatMap filter foldl' groupBy head map match sort;
  t = import ./time.nix;
  cls = import ./classify.nix;
  names = import ./names.nix;

  day0 =
    let d = t.parse today; in
    if d == null then throw "org/due.nix: today must be a date YYYY-MM-DD in 2000..2099, not ${builtins.toJSON today}" else d;

  isExample = path: match "(.*/)?(examples?|tests?|fixtures?|testdata|__tests__)/.*" (cls.lower path) != null;

  band = days:
    if days < 0 then "past" else if days == 0 then "today" else if days <= 7 then "week" else if days <= 30 then "month" else "later";

  # one date of one page, with who it is about
  item = p: e:
    let who = if e ? label then "${names.atom p.repo}/${e.label}" else names.pageId p; in {
      key = "${who}|${e.d}";
      inherit who;
      date = e.d;
      days = t.parse e.d - day0;
      cue = e.cue;
      at = e.at or null;
      label = e.label or null;
      priority = e.priority or null;
      where = { page = names.pageId p; loc = e.loc; kind = (cls.classify p.path).kind; };
    };

  items = field:
    concatMap (p: map (item p) (p.time.${field} or [ ]))
      (filter (p: (p.time or null) != null && (examples || !isExample p.path)) pages);

  firstSet = xs: foldl' (a: x: if a != null then a else x) null xs;
  uniq = xs: foldl' (a: x: if builtins.elem x a then a else a ++ [ x ]) [ ] (sort builtins.lessThan xs);

  merged = is:
    let h = head is; in {
      inherit (h) date days;
      band = band h.days;
      at = firstSet (map (i: i.at) is);
      label = firstSet (map (i: i.label) is);
      priority = firstSet (map (i: i.priority) is);
      cues = uniq (map (i: i.cue) is);
      where = sort (a: b: a.page < b.page) (foldl' (a: i: if builtins.elem i.where a then a else a ++ [ i.where ]) [ ] is);
      inherit (h) who;
    };

  groups = field:
    let g = groupBy (i: i.key) (items field); in map (k: merged g.${k}) (attrNames g);

  rank = i: if i.priority == null then "~" else i.priority;
  soonest = a: b: [ a.days (rank a) a.who a.date ] < [ b.days (rank b) b.who b.date ];
  latest = a: b: [ (0 - a.days) (rank a) a.who a.date ] < [ (0 - b.days) (rank b) b.who b.date ];
  ahead = is: sort soonest (filter (i: i.days >= 0) is);
  clean = map (i: removeAttrs i [ "who" ]);

  ends = groups "to";
  starts = groups "from";
in
{
  inherit today;
  day = day0;
  ends = { ahead = clean (ahead ends); past = clean (sort latest (filter (i: i.days < 0) ends)); };
  starts = { ahead = clean (ahead starts); };
}
