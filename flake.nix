{
  description = "Nix flake for Quartz (Obsidian static site generator)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    quartz = {
      url = "github:jackyzha0/quartz/v4";
      flake = false;  # Just the source, no flake
    };
  };

  outputs = { self, nixpkgs, flake-utils, quartz }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Package Quartz CLI as a standalone tool
        quartzCli = pkgs.buildNpmPackage {
          pname = "quartz-cli";
          version = "4.0.0";
          src = quartz;
          npmDepsHash = "sha256-OAARuTdgo9w4xTmqGTB5SnEmdKrbBl96QAA1mA+u5lU=";
          
          # Don't run any build commands, just install the CLI
          dontNpmBuild = true;
          
          installPhase = ''
            mkdir -p $out/bin $out/lib
            
            # Copy the entire Quartz installation
            cp -r . $out/lib/quartz/
            
            # Create a wrapper script for the quartz command
            cat > $out/bin/quartz << EOF
#!${pkgs.bash}/bin/bash
exec ${pkgs.nodejs_22}/bin/node $out/lib/quartz/quartz/bootstrap-cli.mjs "\$@"
EOF
            chmod +x $out/bin/quartz
          '';
        };

        # Function for users to build their Quartz sites
        mkQuartzSite = { name ? "quartz-site", src, configPath ? null }: pkgs.stdenv.mkDerivation {
          inherit name src;
          buildInputs = [ quartzCli pkgs.nodejs_22 ];
          
          buildPhase = ''
            # Copy source to build directory
            cp -r $src/* .
            chmod -R +w .
            
            # Use custom config if provided
            ${if configPath != null then "cp ${configPath} ./quartz.config.ts" else ""}
            
            # Build the site using the packaged quartz CLI
            quartz build
          '';
          
          installPhase = ''
            mkdir -p $out
            if [ -d "public" ]; then
              cp -r public/* $out/
            fi
          '';
        };
      in {
        lib = { inherit mkQuartzSite; };

        packages = {
          default = quartzCli;
          quartz-cli = quartzCli;
        };

        # Development shell with Quartz CLI available
        devShells.default = pkgs.mkShell {
          buildInputs = [ quartzCli pkgs.nodejs_22 ];
          shellHook = ''
            echo "Quartz CLI ready!"
            echo "Available commands:"
            echo "  quartz create    - Create a new site"
            echo "  quartz build     - Build your site"
            echo "  quartz sync      - Sync with content"
            echo ""
            echo "Quartz CLI version:"
            quartz --version || echo "Quartz CLI installed at: $(which quartz)"
          '';
        };
      }
    );
}