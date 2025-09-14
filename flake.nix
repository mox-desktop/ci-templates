{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      rust-overlay,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      overlays = [
        (import rust-overlay)
        (self: super: {
          rustToolchain = super.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-src"
              "rustfmt"
            ];
          };
        })
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          let
            pkgs = import nixpkgs { inherit system overlays; };
          in
          f pkgs
        );
      formatter = forAllSystems (
        pkgs:
        pkgs.writeShellApplication {
          name = "nix3-fmt-wrapper";
          runtimeInputs = builtins.attrValues {
            inherit (pkgs)
              rustToolchain
              nixfmt-rfc-style
              taplo
              fd
              ;
          };
          text = ''
            fd "$@" -t f -e nix -x nixfmt -q '{}'
            fd "$@" -t f -e toml -x taplo format '{}'
            cargo fmt
          '';
        }
      );
    in
    {
      lib = {
        inherit systems overlays forAllSystems;
        mkMoxFlake =
          extraOutputs:
          let
            baseOutputs = {
              lib = { inherit systems overlays forAllSystems; };
              inherit formatter;
            };
          in
          nixpkgs.lib.recursiveUpdate baseOutputs extraOutputs;
      };
    };
}
