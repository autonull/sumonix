# org/names.nix: how a repository and a page are named as atoms.  A page is REPO:path, so a proof reads as a path.
let
  inherit (builtins) concatStringsSep filter isString split;
  cls = import ./classify.nix;
in
rec {
  atom = s: concatStringsSep "-" (filter (x: x != "") (filter isString (split "[^a-z0-9]+" (cls.lower s))));
  pageId = p: "${atom p.repo}:${p.path}";
}
