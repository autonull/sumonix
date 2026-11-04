# org/time.nix: calendar dates as day numbers, in plain Nix.  There is no clock here: "today" is always an argument, so a margin
# is the same on every machine and on every day the same input is given.
#
#   parse "2026-11-03"   ->  20760 (days since 1970-01-01), or null when the text is not a real date in 2000..2099
let
  inherit (builtins) foldl' genList match stringLength substring;

  digit = { "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4; "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9; };
  num = s: foldl' (a: i: a * 10 + digit.${substring i 1 s}) 0 (genList (i: i) (stringLength s));

  leap = y: (y - y / 4 * 4 == 0 && y - y / 100 * 100 != 0) || y - y / 400 * 400 == 0;
  monthDays = y: m:
    if m == 2 then (if leap y then 29 else 28)
    else if m == 4 || m == 6 || m == 9 || m == 11 then 30
    else 31;

  # Howard Hinnant's days_from_civil: days since 1970-01-01 for a date from 1970 on.
  dayNumber = y: m: d:
    let
      y' = if m <= 2 then y - 1 else y;
      era = y' / 400;
      yoe = y' - era * 400;
      mp = if m > 2 then m - 3 else m + 9;
      doy = (153 * mp + 2) / 5 + d - 1;
      doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    in era * 146097 + doe - 719468;

  parse = s:
    let g = match "([0-9]{4})-([0-9]{2})-([0-9]{2})" s; in
    if g == null then null
    else
      let y = num (builtins.elemAt g 0); m = num (builtins.elemAt g 1); d = num (builtins.elemAt g 2); in
      if y < 2000 || y > 2099 || m < 1 || m > 12 || d < 1 || d > monthDays y m then null else dayNumber y m d;
in
{ inherit num parse dayNumber monthDays; }
