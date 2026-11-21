## Documentation map

The README is the complete, self-contained reference. The documents below are
additional project records, not alternate descriptions of the system.

| Document | What is inside |
|----------|----------------|
| [`demo/README.md`](demo/README.md) | Recording notes and the cast index for the demo. |
| [`docs/pick-your-ai-os.md`](docs/pick-your-ai-os.md) | The larger thesis: knowledge and organization kept the way NixOS keeps a computer. |
| [`TODO6.plan.md`](TODO6.plan.md) | The full plan (Phases 0–3), decisions, risks, file manifest, DONE checkboxes. |
| [`TODO6.spec.md`](TODO6.spec.md) | Complete specification for all phases. |
| [`AGENTS.md`](AGENTS.md) | How to develop this repository correctly: store mechanics, Nix best practices, common mistakes. |
| `nix_sumo.md` (gist) | Original design notes: sections 3.1, 6, 11, 18. |
| [`spike/demo.sh`](spike/demo.sh) | Capability discovery VM (boots NixOS, runs the reasoner inside). |
| [`sumo.full/NOTICE.md`](sumo.full/NOTICE.md) | SUMO license (IEEE). |

### Contributing

```bash
./run-tests.sh              # 27 tests, eval-only
./tools/check-readme.sh     # README drift check
./demo/run > /tmp/after.txt # demo byte-identical output
```

One logical change per commit. If the demo output changes, say why in the
commit message. Update `AGENTS.md` when you discover a new store or Nix
pattern. The README is generated from `docs/readme/*.md` by
`tools/build-readme.sh`; do not edit it by hand.
