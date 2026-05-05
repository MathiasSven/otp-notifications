{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cherri.url = "github:MathiasSven/cherri";
    cherri.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      cherri,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (nixpkgs) lib;

      inherit (pkgs)
        wrapGAppsHook4
        gobject-introspection
        python3
        libnotify
        ;
    in
    {
      packages.${system} = rec {
        otp-notifications = pkgs.python3Packages.buildPythonApplication (finalAttrs: {
          name = "otp-notifications";
          pyproject = false;

          nativeBuildInputs = [
            wrapGAppsHook4
            gobject-introspection
          ];

          dontWrapGApps = true;

          buildInputs = [ libnotify ];

          dependencies = with python3.pkgs; [
            fastapi
            pygobject3
            uvicorn
          ];

          dontUnpack = true;

          installPhase = ''
            install -Dm755 "${./app.py}" $out/bin/${finalAttrs.name}
          '';

          preFixup = ''
            makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
          '';

          meta.mainProgram = "${finalAttrs.name}";
        });

        default = otp-notifications;
      };

      nixosModules.default = import ./module.nix {
        otp-notifications = self.packages.${system}.otp-notifications;
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        inputsFrom = [ self.packages.${system}.otp-notifications ];

        packages = with pkgs; [
          cherri.packages.${system}.cherri
          yq-go
          gawk
          curl
          qrencode
          just

          black
          isort
          (python3.withPackages (python-pkgs: [ python-pkgs.pygobject-stubs ]))
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
