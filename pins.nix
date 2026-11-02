# The SUMO corpus this repository reads, pinned. The same ref and hashes as TrikeShed's utils/sumo/sumo-corpus.pins.
# A file of ./sumo.full (Git LFS) is used when it is there and has the pinned SHA-256; otherwise builtins.fetchurl
# downloads it once and refuses a file whose SHA-256 differs. Nothing is taken on trust either way.
let
  ref = "25bb366fdffd8769e741d2e22f215c2785bddce1";
  file = name: sha256:
    let local = ./sumo.full + "/${name}"; in
    if builtins.pathExists local && builtins.hashFile "sha256" local == sha256 then local
    else builtins.fetchurl {
      url = "https://raw.githubusercontent.com/ontologyportal/sumo/${ref}/${name}";
      inherit sha256;
    };
in
{
  inherit ref;
  merge = file "Merge.kif" "bda2f68ce375f64134c5c58656f94a50f920444b3b17b0329ee00fd0437b3cc2";
  midLevel = file "Mid-level-ontology.kif" "9a39696fb9e8feafcd5a3f3d10bc59a7a8257a42fefda3d5684b087036fafb49";
}
