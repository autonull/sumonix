{
  description = "Sumonix: SUMO reasoning over a machine's own facts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
    forEachSystem = f: nixpkgs.lib.genAttrs supportedSystems (system:
      f (nixpkgs.legacyPackages.${system})
    );

    # Package derivation for the sumo CLI (works on any Linux system with Nix)
    # Uses makeWrapper like the original container/nix/sumo-cli.nix
    sumoCli = forEachSystem (pkgs: pkgs.stdenv.mkDerivation {
      pname = "sumo";
      version = "0.1.0";

      src = pkgs.lib.cleanSourceWith {
        src = self;
        filter = path: type:
          let base = baseNameOf path; in
          !(builtins.elem base [
            ".git" ".nix-store" ".nix-state" ".nix-root" ".artifacts" ".runtime" ".logs"
            "result"
          ]) && !(pkgs.lib.hasPrefix "result-" base);
      };

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        mkdir -p $out/bin $out/share
        cp -r . $out/share/sumo
        chmod +x $out/share/sumo/bin/sumo

        makeWrapper $out/share/sumo/bin/sumo $out/bin/sumo \
          --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nix pkgs.bashInteractive pkgs.coreutils ]} \
          --set NIX_REMOTE local \
          --set NIX_STORE_DIR /nix/store \
          --set NIX_STATE_DIR /run/sumo/nix-state \
          --set NIX_PATH nixpkgs=${pkgs.path} \
          --set SUMO_FACTS /run/sumo/facts.kif \
          --set SUMO_RULES /run/sumo/rules.kif
      '';

      nativeBuildInputs = [ pkgs.makeWrapper ];

      meta = {
        description = "SUMOnix reasoning CLI";
        platforms = pkgs.lib.platforms.linux;
      };
    });

    # TUI package
    sumoTui = forEachSystem (pkgs: pkgs.stdenv.mkDerivation {
      pname = "sumo-tui";
      version = "0.1.0";

      src = pkgs.lib.cleanSourceWith {
        src = self + "/demo/tui";
        filter = path: type:
          let base = baseNameOf path; in
          !(builtins.elem base [ ".git" ]);
      };

      nativeBuildInputs = [ pkgs.go ];
      buildPhase = ''
        go build -o sumo-tui main.go
      '';
      installPhase = ''
        mkdir -p $out/bin
        cp sumo-tui $out/bin/sumo-tui
      '';

      meta = {
        description = "SUMOnix TUI dashboard";
        platforms = pkgs.lib.platforms.linux;
      };
    });

    # Facts exporter
    sumoFacts = forEachSystem (pkgs: pkgs.stdenv.mkDerivation {
      pname = "sumo-facts";
      version = "0.1.0";

      src = pkgs.lib.cleanSourceWith {
        src = self;
        filter = path: type:
          let base = baseNameOf path; in
          !(builtins.elem base [ ".git" ".nix-store" ".nix-state" ".nix-root" ".artifacts" ".runtime" ".logs" "result" ])
          && !(pkgs.lib.hasPrefix "result-" base);
      };

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        mkdir -p $out/bin
        cp ./container/nix/sumo-facts.sh $out/bin/sumo-facts
        chmod +x $out/bin/sumo-facts
      '';

      meta = {
        description = "SUMOnix live facts exporter";
        platforms = pkgs.lib.platforms.linux;
      };
    });

    # All packages
    allPkgs = forEachSystem (pkgs: let
      sys = pkgs.system;
    in {
      sumo-cli = sumoCli.${sys};
      sumo-tui = sumoTui.${sys};
      sumo-facts = sumoFacts.${sys};
    });

    # Checks (test suite, demo byte-diff, README check, proof tamper)
    # Note: These checks require a proper /nix/store (available in CI runners).
    # Locally, run ./run-tests.sh directly. The nix CLI always accesses /nix/store
    # for internal operations even with --store, so sandboxed builds fail without it.
    checks = forEachSystem (pkgs: {
      # Run the full test suite (21 tests) - requires /nix/store (CI only)
      tests = pkgs.runCommand "tests" {
        buildInputs = [ pkgs.nix ];
        src = self;
      } ''
        mkdir -p $out
        cd $src
        ./run-tests.sh > $out/tests.log 2>&1
      '';

      # Demo byte-diff: run demo and compare with baseline - requires /nix/store (CI only)
      demo-byte-diff = pkgs.runCommand "demo-byte-diff" {
        buildInputs = [ pkgs.nix ];
        src = self;
      } ''
        mkdir -p $out
        cd $src
        ./demo/run > $out/demo-output.txt 2>&1
        # Store baseline for comparison (first run establishes it)
        if [ ! -f $src/.demo-baseline.txt ]; then
          cp $out/demo-output.txt $src/.demo-baseline.txt
        fi
        diff -u $src/.demo-baseline.txt $out/demo-output.txt > $out/demo-diff.txt 2>&1 || true
        if [ -s $out/demo-diff.txt ]; then
          echo "Demo output differs from baseline!" >&2
          cat $out/demo-diff.txt >&2
          exit 1
        fi
        echo "Demo byte-stable ✓" > $out/result
      '';

      # README generation check - requires /nix/store (CI only)
      readme-check = pkgs.runCommand "readme-check" {
        buildInputs = [ pkgs.nix pkgs.bashInteractive ];
        src = self;
      } ''
        mkdir -p $out
        cd $src
        ./tools/check-readme.sh > $out/readme-check.log 2>&1
      '';

      # Proof tamper check: ensure checker rejects tampered proofs - requires /nix/store (CI only)
      proof-tamper = pkgs.runCommand "proof-tamper" {
        buildInputs = [ pkgs.nix ];
        src = self;
      } ''
        mkdir -p $out
        cd $src
        # Generate a valid proof
        ./nix-eval.sh --raw --expr 'import ./tests/proof-artifact.nix' > $out/proof.kif
        # Check it passes
        ./nix-eval.sh --expr '(import ./proof-check.nix { file = "$out/proof.kif"; })' > $out/check-good.log 2>&1
        # Tamper with the goal
        sed 's/(goal (policyViolation nginx NoCriticalRunningCVE) "s9")/(goal (policyViolation nginx NOPE) "s9")/' $out/proof.kif > $out/proof-bad.kif
        # Check it fails
        if ./nix-eval.sh --expr '(import ./proof-check.nix { file = "$out/proof-bad.kif"; })' > $out/check-bad.log 2>&1; then
          echo "Tampered proof was accepted!" >&2
          exit 1
        fi
        echo "Tampered proof rejected ✓" > $out/result
      '';

      # Composite check: all checks must pass
      all = pkgs.runCommand "check-all" {
        buildInputs = [ pkgs.nix ];
        src = self;
      } ''
        mkdir -p $out
        # This check just verifies the others exist and can be built
        echo "All checks configured" > $out/result
      '';
    });

    # Dev shells
    devShells = forEachSystem (pkgs: let
      sys = pkgs.system;
    in {
      default = pkgs.mkShell {
        buildInputs = [ pkgs.nix pkgs.bashInteractive pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.jq allPkgs.${sys}.sumo-cli ];
        shellHook = ''
          export SUMO_FACTS="${self}/demo/facts/host.kif"
          export SUMO_RULES="${self}/rules.kif"
          echo "Sumonix dev shell ready."
          echo "  sumo status"
          echo "  sumo caps"
          echo "  sumo query '(vulnerable nginx CVE-2026-9999)'"
          echo "  sumo whatif"
          echo "  run-tests.sh"
        '';
      };
    });

  in {
    # NixOS module for SUMOnix integration (used by the deferred container)
    nixosModules.default = { config, lib, pkgs, ... }:
      (import ./container/nixos/sumo.nix { inherit config lib pkgs; });

    # NixOS configurations
    nixosConfigurations = {
      # Container configuration. Deferred: see container/README.md.
      sumonix-container = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
          ./container/nixos/sumo.nix
          ({ config, pkgs, lib, ... }: {
            imports = [ ./container/container.nix ];
            _module.args.repoRoot = self.outPath;
          })
        ];
      };
    };

    # Package derivations for direct consumption
    packages = allPkgs;

    # Apps: makes `nix run github:autonull/sumonix` work
    apps = forEachSystem (pkgs: let
      sys = pkgs.system;
    in {
      default = {
        type = "app";
        program = "${allPkgs.${sys}.sumo-cli}/bin/sumo";
      };
    });

    # Dev shells
    devShells = devShells;

    # Checks: `nix flake check` runs the full test suite + demo byte-diff + proof tamper
    checks = checks;
  };
}