# org/facts.nix: the facts of org/pages.json, for org/rules.kif and org/rules-closed.kif.
#
#   (instance PAGE CLASS)             PAGE is a page of that class (by org/classify.nix and the table in org/taxonomy.kif)
#   (unclassified PAGE)               no rule matched: unknown, said out loud
#   (inRepo PAGE REPO)  (blob PAGE SHA)   where the page is, and its git blob SHA at the pinned commit
#   (declaredGenerated PAGE MARK)     the page says, in its own text, that it was generated
#   (usesFormerName PAGE NAME)        the page still uses a team name that docs/NAMING.md of the .github repository retired
#   (renameRegister PAGE)             the page that documents the renames
#   (roleOf PAGE ROLE)  (hasRole REPO ROLE)   the standard files of a repository: CONTRIBUTING, SECURITY, AGENTS, ...
#   (repo REPO) (publicRepo REPO) (orgDefaultRepo REPO) (pinnedAt REPO COMMIT)
#
# A page is named REPO:path, with the repository name made into an atom, so a proof reads as a path.
{ pages, pins }:
let
  inherit (builtins) concatMap concatStringsSep elemAt filter head isList isString length listToAttrs map match readFile split;
  kif = import ../kif.nix;
  cls = import ./classify.nix;

  lines = s: filter isString (split "\n" s);
  tabs = s: filter isString (split "\t" s);

  inherit (import ./names.nix) atom;

  taxonomy = kif.parse (readFile ./taxonomy.kif);
  kindClass = listToAttrs (map (f: { name = elemAt f 1; value = elemAt f 2; })
    (filter (f: isList f && f != [ ] && head f == "pageKindClass") taxonomy));
  groundTaxonomy = filter (f: isList f && f != [ ] && builtins.elem (head f) [ "communityDefault" "ownRole" ]) taxonomy;

  # The roles. The first pattern that matches the whole lower-cased path wins.
  roles = [
    { role = "ContributingGuide"; re = "(docs/|\\.github/)?contributing\\.md"; compared = true; }
    { role = "SecurityPolicy"; re = "(docs/|\\.github/)?security\\.md"; compared = true; }
    { role = "SupportGuide"; re = "(docs/|\\.github/)?support\\.md"; compared = true; }
    { role = "ConductCode"; re = "(docs/|\\.github/)?code_of_conduct\\.md"; compared = true; }
    { role = "AgentsGuide"; re = "agents\\.md"; compared = true; }
    { role = "PullRequestTemplate"; re = "(docs/|\\.github/)?pull_request_template\\.md"; compared = true; }
    { role = "CodeOwnersFile"; re = "(docs/|\\.github/)?codeowners"; compared = false; }
    { role = "IssueTemplate"; re = "(docs/|\\.github/)?issue_template/.*"; compared = false; }
  ];
  roleOf = path:
    let
      p = cls.lower path;
      hit = filter (r: match r.re p != null) roles;
    in if hit == [ ] then null else head hit;

  id = (import ./names.nix).pageId;

  pageFacts = p:
    let
      k = cls.classify p.path;
      i = id p;
      r = roleOf p.path;
    in
    [ [ "inRepo" i (atom p.repo) ] [ "blob" i p.sha ] ]
    ++ (if k.kind == null then [ [ "unclassified" i ] ] else [ [ "instance" i kindClass.${k.kind} ] ])
    ++ map (m: [ "declaredGenerated" i (atom m) ]) p.marks
    ++ map (n: [ "usesFormerName" i (atom n) ]) p.former
    ++ (if cls.lower p.path == "docs/naming.md" then [ [ "renameRegister" i ] ] else [ ])
    ++ (if r == null then [ ] else [ [ "hasRole" (atom p.repo) r.role ] ] ++ (if r.compared then [ [ "roleOf" i r.role ] ] else [ ]));

  pinFacts = map
    (l:
      let f = tabs l; name = elemAt f 0; in
      [ [ "repo" (atom name) ] [ "pinnedAt" (atom name) (elemAt f 3) ] ]
      ++ (if match ".*@.*" name == null then [ [ "publicRepo" (atom name) ] ] else [ ]))
    (filter (l: l != "") (lines pins));
in
concatMap pageFacts pages ++ builtins.concatLists pinFacts ++ [ [ "orgDefaultRepo" "github" ] ] ++ groundTaxonomy
