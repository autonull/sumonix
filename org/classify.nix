# org/classify.nix: what each page is, by an ordered rule table.
#
# The first rule that matches the lower-cased path wins.  A page no rule matches gets kind null: unknown, never a guess.  Every
# answer carries the id of the rule that gave it, so a reader can see why.  The table is lookup, not a model: the same path always
# gets the same answer.  Patterns are POSIX extended regular expressions, searched (not anchored) with builtins.split.
#
# This is the lookup half.  org/taxonomy.kif says how the kinds sit under SUMO's Document, and org/rules.kif reasons over them.
let
  inherit (builtins) split length replaceStrings foldl';

  upper = [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ];
  # replaceStrings with two lists of equal length lower-cases a whole string in one pass
  lower = replaceStrings upper [ "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" ];

  keywords = "workflows?|process(es)?|procedures?|gates?|reviews?|publication|eligibility|handoffs?|escalation|acceptance|validation|release|onboarding|setup|checklists?|rules|policy|policies|charter|maintenance|dependencies|methods?|methodology";

  rules = [
    { id = "r01"; kind = "receipt"; re = "receipt|establishment_status"; }
    { id = "r02"; kind = "evidence"; re = "^evidence/|/evidence/"; }
    { id = "r02a"; kind = "data"; re = "^templates/examples/"; }
    { id = "r03"; kind = "template"; re = "^\\.github/issue_template/|(^|/)pull_request_template\\.md$|^templates/"; }
    { id = "r04"; kind = "automation"; re = "^\\.github/(workflows|rulesets|actions)/|^\\.github/[^/]+\\.ya?ml$|^tools/|^scripts/|^automation/"; }
    { id = "r05"; kind = "governance"; re = "(^|/)(contributing|agents|security|support|code_of_conduct|governance|implementation_agents|third_party_rights|notice|license)(\\.md)?$|(^|/)codeowners$|^docs/governance/|^governance/|^docs/naming\\.md$"; }
    { id = "r06"; kind = "decision"; re = "^docs/decisions/|(^|/)decisions\\.md$"; }
    { id = "r07"; kind = "readme"; re = "(^|/)readme\\.md$"; }
    { id = "r08"; kind = "prompt"; re = "^prompts/|(^|/)prompts\\.md$"; }
    { id = "r09"; kind = "planning-record"; re = "^planning/(issues|issue-bodies)/"; }
    { id = "r10"; kind = "planning"; re = "^planning/|(^|/)(delivery_plan|implementation_handoff|handoffs|backlog)[^/]*\\.md$|^docs/delivery/"; }
    { id = "r11"; kind = "contract"; re = "^contracts/|^schemas/|\\.schema\\.json$|^(docs/)?[^/]*contract[^/]*$"; }
    { id = "r12"; kind = "catalog"; re = "^catalog/"; }
    { id = "r13"; kind = "taxonomy"; re = "^taxonomy/"; }
    { id = "r14"; kind = "market"; re = "^research/market/|^docs/market-research/"; }
    { id = "r15"; kind = "research"; re = "^research/|^papers/"; }
    { id = "r16"; kind = "proposal"; re = "^proposals/|^docs/proposals/"; }
    { id = "r17"; kind = "data"; re = "^data/|^tests/fixtures/|^examples/|^sources/|^pricing/|^coverage/|^assets/|^docs/images/|^docs/assets/|^docs/directory/"; }
    { id = "r18"; kind = "process"; re = "^docs/(validation|acceptance|operations|security|security-response|source-use|policies|workstreams)/|^(docs/)?([^/]*[^a-z/])?(${keywords})([^a-z]|$)[^/]*$"; }
    { id = "r19"; kind = "doc"; re = "^docs/|^[^/]+\\.md$"; }
    { id = "r20"; kind = "package-data"; re = "^(packages|core|preview|apps|app)/"; }
    { id = "r21"; kind = "config"; re = "(^|/)(package(-lock)?|tsconfig[^/]*|composer|deno)\\.json$|(^|/)\\.[a-z]+rc(\\.json)?$|compose\\.ya?ml$"; }
  ];

  hits = re: s: length (split re s) > 1;

  classify = path:
    let
      p = lower path;
      first = foldl' (acc: r: if acc != null then acc else if hits r.re p then r else null) null rules;
    in
    if first == null then { kind = null; rule = null; } else { inherit (first) kind; rule = first.id; };
in
{ inherit rules classify lower; }
