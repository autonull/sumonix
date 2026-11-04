# org/oracle.jq: [repo, path, kind, rule] for every page, from org/rules.jq.
#   jq -r -L org -f org/oracle.jq org/pages.json
include "rules";
.[] | . + classify | [.repo, .path, (.kind // "null"), (.rule // "null")] | @tsv
