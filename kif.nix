# SUO-KIF text to S-expressions: an atom is a string, a list is a Nix list.
#
#   parse :: String -> [Sexp]        every top-level form, comments dropped
#
# A variable is an atom that starts with "?", a string literal keeps its quotes.
let
  inherit (builtins) filter foldl' genList head isList length elemAt match split substring tail;

  # One token: a parenthesis, a quoted string, a comment, or a run of other characters.
  tokenPattern = ''([()]|"([^"\\]|\\.)*"|;[^
]*|[^ 	
()";]+)'';

  tokens = text:
    filter (t: substring 0 1 t != ";")
      (map head (filter isList (split tokenPattern text)));

  reverse = xs: let n = length xs; in genList (i: elemAt xs (n - 1 - i)) n;

  # cur is the list being read, newest first; up holds the lists it sits inside.
  step = st: t:
    if t == "(" then { cur = [ ]; up = [ st.cur ] ++ st.up; }
    else if t == ")" then
      if st.up == [ ] then throw "kif: unbalanced ')'"
      else { cur = [ (reverse st.cur) ] ++ head st.up; up = tail st.up; }
    else { cur = [ t ] ++ st.cur; up = st.up; };
in
{
  inherit tokens;
  parse = text:
    let end = foldl' step { cur = [ ]; up = [ ]; } (tokens text); in
    if end.up != [ ] then throw "kif: unclosed '('" else reverse end.cur;
}
