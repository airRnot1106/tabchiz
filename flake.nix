{
  description = "Tabchiz development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        # mkShellNoCC keeps DEVELOPER_DIR and SDKROOT unset so xcrun and xcodebuild use the system Xcode.
        default = pkgs.mkShellNoCC {
          packages = [
            pkgs.lefthook
            pkgs.swiftlint
            pkgs.xcodegen
          ];
        };
      });
    };
}
