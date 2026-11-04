# org/expected.jq: the report org/check.nix must give, worked out again from org/pages.json with no Datalog and no Nix.
#   jq -S -L org -f org/expected.jq org/pages.json > org/expected.json
include "rules";

def pid: (.repo | atom) + ":" + .path;
def count(f): group_by(f) | map({key: (.[0] | f), value: length}) | from_entries;

map(. + classify + {role: role}) as $ps
| ($ps | map(select(.repo | test("@") | not)) | map(.repo) | unique) as $public
| ["ContributingGuide","SecurityPolicy","SupportGuide","ConductCode","PullRequestTemplate","IssueTemplate","CodeOwnersFile","AgentsGuide"] as $expected
| ["ContributingGuide","SecurityPolicy","SupportGuide","ConductCode","PullRequestTemplate","IssueTemplate"] as $inherited
| ["ContributingGuide","SecurityPolicy","SupportGuide","ConductCode","AgentsGuide","PullRequestTemplate"] as $compared
| ($ps | map(select(.role != null)) | map({repo, role}) | unique) as $has
| def own($repo; $role): any($has[]; .repo == $repo and .role == $role);
  def effective($repo; $role): own($repo; $role) or (($inherited | index($role)) != null and own(".github"; $role));
{
  pages: ($ps | length),
  unclassified: ($ps | map(select(.kind == null) | pid) | sort),
  kinds: ($ps | map(select(.kind != null)) | count(.kind)),
  processPages: ($ps | map(select(.kind as $k | processKinds | index($k) != null)) | length),
  byRepo: ($ps | group_by(.repo) | map({key: (.[0].repo | atom), value: {
      pages: length,
      processPages: (map(select(.kind as $k | processKinds | index($k) != null)) | length)}}) | from_entries),
  generatedProcessPages: ($ps | map(select((.kind as $k | processKinds | index($k) != null) and (.marks | length > 0))) | length),
  present: ([ $expected[] as $r | {key: $r, value: ($public | map(select(own(.; $r))) | length)} ] | from_entries),
  lacks: ([ $expected[] as $r | {key: $r, value: ($public | map(select(effective(.; $r) | not) | atom) | sort)} ] | from_entries),
  copies: ([ $compared[] as $r
      | ($ps | map(select(.role == $r))) as $g
      | ($g | group_by(.sha) | map(length)) as $sizes
      | {key: $r, value: {
          pages: ($g | length),
          distinctBlobs: ($sizes | length),
          largestIdentical: ($sizes | max // 0),
          identicalPairs: ($sizes | map(. * (. - 1)) | add // 0),
          divergentPairs: ((($g | length) * (($g | length) - 1)) - ($sizes | map(. * (. - 1)) | add // 0))}} ] | from_entries),
  staleNames: ($ps | map(select(.kind != "receipt" and .kind != "evidence" and ((.path | ascii_downcase) != "docs/naming.md") and (.former | length > 0)))
      | map(. as $p | .former[] | [($p | pid), atom]) | sort)
}
