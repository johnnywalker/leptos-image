{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    fenix,
    git-hooks,
    nixpkgs,
    nixpkgs-unstable,
    treefmt-nix,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

    overlayRustPackage = {
      rustPlatform,
      final,
      prev,
      old,
      override,
    }:
      final.callPackage prev.${old}.override {
        rustPlatform =
          rustPlatform
          // {
            buildRustPackage = args:
              rustPlatform.buildRustPackage (
                args
                // (override args)
              );
          };
      };

    overlays = [
      (_: prev: let
        pkgs = fenix.inputs.nixpkgs.legacyPackages.${prev.system};
      in
        # use pkgs from fenix input
        fenix.overlays.default pkgs pkgs)
      (final: prev: {unstable = import nixpkgs-unstable {inherit (prev) system;};})
      (final: prev: {
        rustToolchain = with prev.fenix;
          combine [
            stable.toolchain
            targets.wasm32-unknown-unknown.stable.rust-std
          ];

        cargo-leptos = overlayRustPackage {
          inherit final prev;
          old = "cargo-leptos";
          # use newer rustc
          rustPlatform = let
            toolchain = prev.fenix.stable.toolchain;
          in
            prev.makeRustPlatform {
              cargo = toolchain;
              rustc = toolchain;
            };
          # use newer version of cargo-leptos to match wasm-bindgen in Cargo.toml
          override = args: rec {
            version = "0.2.44";
            src = prev.fetchFromGitHub {
              owner = "leptos-rs";
              repo = "cargo-leptos";
              rev = "v${version}";
              hash = "sha256-Kef0o2te5rj0+f+kY96BQzcIByWCp2ccCLT3UiYEGUg=";
            };
            cargoHash = "sha256-SfQ6W8FMy2TT9V19HEQGgbJxTxs9Ssm/ZusHvKEJc8o=";
            # copy from unstable
            nativeBuildInputs = with prev; [pkg-config]; # for openssl-sys
            buildInputs = with prev; [openssl]; # for openssl-sys
            env = {
              OPENSSL_NO_VENDOR = 1; # for openssl-sys
            };
          };
        };

        # align version with Cargo.toml
        wasm-bindgen-cli = prev.callPackage ./wasm-bindgen-cli.nix {};
      })
    ];

    # small tool to iterate over each system
    eachSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system: let
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
        f pkgs);

    # Eval the treefmt modules from ./treefmt.nix
    treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
  in {
    checks = eachSystem (pkgs: {
      # check formatting
      formatting = treefmtEval.${pkgs.system}.config.build.check self;
    });

    # for `nix fmt`
    formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

    packages = eachSystem (pkgs: {
      # helper script to run rustfmt and leptosfmt from rustic-mode
      crustfmt = pkgs.writeShellScriptBin "crustfmt" ''
        rustfmt "$@" && leptosfmt "$@"
      '';
    });

    # Used by `nix develop` or `direnv` to open a devShell
    devShells = eachSystem (pkgs: let
      # use in devShell only due to significant challenges running in `nix flake check`
      hooks = import ./git-hooks.nix {
        inherit pkgs;
        treefmt-wrapper = treefmtEval.${pkgs.system}.config.build.wrapper;
        git-hooks = git-hooks.lib.${pkgs.system};
      };
    in {
      default = pkgs.mkShell {
        inputsFrom = builtins.attrValues self.checks.${pkgs.system};

        # Extra inputs can be added here
        nativeBuildInputs =
          hooks.enabledPackages
          ++ (
            with pkgs; [
              cargo-leptos
              cargo-outdated
              cargo-watch
              just
              leptosfmt
              # toolchain from fenix
              rustToolchain
              sass
              tailwindcss_4
              wasm-bindgen-cli
            ]
          )
          ++ (with self.packages.${pkgs.system}; [crustfmt]);

        shellHook = ''
          ${hooks.shellHook}
        '';
      };
    });
  };
}
