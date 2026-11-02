# sumo.full

The 78 files of `PINS`, copied byte for byte from https://github.com/ontologyportal/sumo at commit
`25bb366fdffd8769e741d2e22f215c2785bddce1`. Each file's SHA-256 is in `PINS`; none was edited.

SUMO, the Suggested Upper Merged Ontology (`Merge.kif`), is copyright IEEE, Inc. The IEEE is acknowledged as the
source and copyright owner of it, under the terms in the header of that file, which allow copying, publishing and
distributing it. The mid-level ontology and the domain ontologies carry their own notices in their headers; the upstream
README (`UPSTREAM-README.txt`) states that the code and ontologies of the project are released under the GNU Public License.
Those terms apply to these files and not to the code of this repository.

Please cite: Niles, I., and Pease, A. 2001. Towards a Standard Upper Ontology. In Proceedings of the 2nd International
Conference on Formal Ontology in Information Systems (FOIS-2001). See also http://www.ontologyportal.org.

The files are stored with Git LFS. `git lfs pull` fetches them; without it a checkout holds pointer files. The Nix code of
this repository does not need them: `pins.nix` fetches the file it reads, and checks its SHA-256.
