# org/rules.jq: the rule table of org/classify.nix, written again in jq (Oniguruma regular expressions).  A second reading, not a copy:
# org/oracle.jq and org/expected.jq include it, and tests/org.nix compares the Nix answers with theirs.
def rules: [
 ["r01","receipt",         "receipt|establishment_status"],
 ["r02","evidence",        "^evidence/|/evidence/"],
 ["r02a","data",           "^templates/examples/"],
 ["r03","template",        "^\\.github/issue_template/|(^|/)pull_request_template\\.md$|^templates/"],
 ["r04","automation",      "^\\.github/(workflows|rulesets|actions)/|^\\.github/[^/]+\\.ya?ml$|^tools/|^scripts/|^automation/"],
 ["r05","governance",      "(^|/)(contributing|agents|security|support|code_of_conduct|governance|implementation_agents|third_party_rights|notice|license)(\\.md)?$|(^|/)codeowners$|^docs/governance/|^governance/|^docs/naming\\.md$"],
 ["r06","decision",        "^docs/decisions/|(^|/)decisions\\.md$"],
 ["r07","readme",          "(^|/)readme\\.md$"],
 ["r08","prompt",          "^prompts/|(^|/)prompts\\.md$"],
 ["r09","planning-record", "^planning/(issues|issue-bodies)/"],
 ["r10","planning",        "^planning/|(^|/)(delivery_plan|implementation_handoff|handoffs|backlog)[^/]*\\.md$|^docs/delivery/"],
 ["r11","contract",        "^contracts/|^schemas/|\\.schema\\.json$|^(docs/)?[^/]*contract[^/]*$"],
 ["r12","catalog",         "^catalog/"],
 ["r13","taxonomy",        "^taxonomy/"],
 ["r14","market",          "^research/market/|^docs/market-research/"],
 ["r15","research",        "^research/|^papers/"],
 ["r16","proposal",        "^proposals/|^docs/proposals/"],
 ["r17","data",            "^data/|^tests/fixtures/|^examples/|^sources/|^pricing/|^coverage/|^assets/|^docs/images/|^docs/assets/|^docs/directory/"],
 ["r18","process",         "^docs/(validation|acceptance|operations|security|security-response|source-use|policies|workstreams)/|^(docs/)?([^/]*[^a-z/])?(workflows?|process(es)?|procedures?|gates?|reviews?|publication|eligibility|handoffs?|escalation|acceptance|validation|release|onboarding|setup|checklists?|rules|policy|policies|charter|maintenance|dependencies|methods?|methodology)([^a-z]|$)[^/]*$"],
 ["r19","doc",             "^docs/|^[^/]+\\.md$"],
 ["r20","package-data",    "^(packages|core|preview|apps|app)/"],
 ["r21","config",          "(^|/)(package(-lock)?|tsconfig[^/]*|composer|deno)\\.json$|(^|/)\\.[a-z]+rc(\\.json)?$|compose\\.ya?ml$"]
];

def classify: (.path | ascii_downcase) as $p
  | (first(rules[] | . as $r | select($p | test($r[2])) | {rule: $r[0], kind: $r[1]}) // {rule: null, kind: null});

# The kinds under ProcessPage in org/taxonomy.kif.
def processKinds: ["governance","decision","template","process","planning","planning-record","proposal","receipt"];

# The role of a page (org/facts.nix), or null.
def role: (.path | ascii_downcase) as $p
  | if   ($p | test("^(docs/|\\.github/)?contributing\\.md$"))          then "ContributingGuide"
    elif ($p | test("^(docs/|\\.github/)?security\\.md$"))              then "SecurityPolicy"
    elif ($p | test("^(docs/|\\.github/)?support\\.md$"))               then "SupportGuide"
    elif ($p | test("^(docs/|\\.github/)?code_of_conduct\\.md$"))       then "ConductCode"
    elif ($p | test("^agents\\.md$"))                                   then "AgentsGuide"
    elif ($p | test("^(docs/|\\.github/)?pull_request_template\\.md$")) then "PullRequestTemplate"
    elif ($p | test("^(docs/|\\.github/)?codeowners$"))                 then "CodeOwnersFile"
    elif ($p | test("^(docs/|\\.github/)?issue_template/"))             then "IssueTemplate"
    else null end;

def atom: ascii_downcase | [splits("[^a-z0-9]+")] | map(select(. != "")) | join("-");
