## 🌍 Application Bootstraps — The Complete Vision

The core engine is the **kernel**. Each bootstrap below is an independent pure-Nix module (converter + policy pack + demo) that plugs into it. No CI, no external deps — just `sumo-nix` as the universal proof layer.

| # | Bootstrap | What It Lifts | Demo Query | Effort |
|---|-----------|---------------|------------|--------|
| 🟢 **B1** | **Nixpkgs Ontology** | 100k+ packages, deps, licenses, meta | "Find all BSD-licensed web servers with no network deps" | 2–4 h |
| 🟢 **B2** | **Epistemic Flakes** | Compliance rules as flake inputs | "Build fails: PII package depends on network-transmitter" | 1–2 h |
| 🟢 **B3** | **json2kif / yaml2kif** | Any JSON/YAML → KIF facts | "Which services use secrets AND expose public ports?" | 1–2 h |
| ☁️ **B4** | **Terraform Plan** | `terraform show -json` | "Prove this plan has no public sensitive data" | 2–3 h |
| ☁️ **B5** | **K8s / Docker Compose** | Manifests → KIF | "Which containers are privileged AND exposed?" | 2–3 h |
| 🔗 **B6** | **Lockfile + OSV/NVD** | package-lock.json + OSV API | "Is my-app exposed to CVE-2024-1234 via transitive deps?" | 2–4 h |
| ⚖️ **B7** | **License Oracle** | SPDX + dep graph | "Can this proprietary artifact ship?" | 2–3 h |
| 📡 **B8** | **OpenAPI / JSON Schema** | OpenAPI v1/v2 → KIF | "Is v2 backward compatible with v1 clients?" | 2–4 h |
| 🗄️ **B9** | **SQL / dbt Lineage** | DDL / dbt manifest → KIF | "Which BI models contain email addresses?" | 3–4 h |
| 📝 **B10** | **Git + CODEOWNERS** | Git log + CODEOWNERS → KIF | "Who must review changes to payment code?" | 1–2 h |
| 🔥 **B11** | **Firewall / SG Analyzer** | iptables, AWS SG, K8s NetworkPolicy | "Is SSH exposed? Which rules are shadowed?" | 2–3 h |
| 🔐 **B12** | **RBAC / ABAC Explainer** | IAM, groups, roles, resources | "Can alice read prod-db? Why/why not?" | 1–2 h |
| ⚙️ **B13** | **CI Pipeline Optimizer** | GitHub Actions / GitLab CI → KIF | "Does deploy run before tests? Any fork secrets?" | 1–2 h |
| 🔧 **B14** | **Env Validator** | .env + app meta → KIF | "Is production fully configured?" | <1 h |
| 🧹 **B15** | **Git Hygiene** | Git ls-files + patterns → KIF | "Are secret-like files tracked?" | <1 h |
| 🔍 **B16** | **Semantic Grep** | Repo files → KIF concepts | `sumo grep . "PII fields"` | 1–2 h |
| 📋 **B17** | **Ontology Task Runner** | Task declarations → KIF | "What tasks to build running-service?" | 1–2 h |
| 💥 **B18** | **Change Impact** | Dependency graph + facts → KIF | "What breaks if I remove redis?" | 2–3 h |
| 📄 **B19** | **Compliance Receipt** | Check results → signed receipt | "Audit artifact for GDPR" | 1–2 h |
| 🏷️ **B20** | **Proof Badges** | Check results → SVG badges | `![No CVE](badge.svg)` links to proof | <1 h |
| 🎯 **B21** | **Semantic Package Select** | Nixpkgs ontology + constraints | `selectPackage { provides="WebServer"; NoGPL }` | 2–3 h |
| 🔐 **B22** | **Crypto Epistemology** | HW state, network, user → KIF | "Secret only exists on corp Wi-Fi + disk unlocked" | 2–3 h |
| 📡 **B23** | **API Evolution** | OpenAPI + client contracts → KIF | "Is v2 backward compatible?" | 2–3 h |
| ⚙️ **B24** | **Config Contradiction** | NixOS modules → KIF | "Postgres needs 5432 but StrictFirewall denies all" | 2–3 h |
| 📦 **B25** | **Policy-as-Flakes** | Flake inputs → KIF rules | `inputs.gdpr.url = "github:org/gdpr-kif"` | 1–2 h |
| ✅ **B26** | **sumo flake check** | Checks → Nix flake checks | `nix flake check` fails with proof | <1 h |
| 🛡️ **B27** | **sumo assert** | `sumo.assert { query; }` in Nix | Build fails with proof in Nix eval | <1 h |
| 🤔 **B28** | **Why-does-this-exist** | Resource facts → generated docs | "Why does redis-cache exist?" | 1–2 h |

### How They Compose

| Milestone | What It Means |
|-----------|---------------|
| **V2** | Core engine + **1 bootstrap** (e.g., B3 json2kif + B14 env validator) |
| **V3** ✅ | V2 + policy product (build gate + relaxation menu) + **3 bootstraps** composing |
| **V4** | V3 + **3 bootstraps** composing + T2.4/T2.6 engine extensions |
| **V5** | All **26 bootstraps** + T2.1/T2.6/T3.1 + T2.7 (Soufflé CI) |

Each bootstrap = converter + policy pack (KIF rules) + demo query. Pure Nix, no CI, no external deps.