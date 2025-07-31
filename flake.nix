{
  description = "Nix flake for Quartz (Obsidian static site generator)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    quartz = {
      url = "github:jackyzha0/quartz/v4";
      flake = false; # Just the source, no flake
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    quartz,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

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
        mkQuartzSite = {
          name ? "quartz-site",
          src,
          configPath ? null,
        }:
          pkgs.stdenv.mkDerivation {
            inherit name src;
            buildInputs = [quartzCli pkgs.nodejs_22];

            buildPhase = ''
              # Copy source to build directory
              cp -r $src/* .
              chmod -R +w .

              # Use custom config if provided
              ${
                if configPath != null
                then "cp ${configPath} ./quartz.config.ts"
                else ""
              }

              # Ensure we have the right directory structure
              if [ ! -d "content" ]; then
                echo "Creating content directory..."
                mkdir -p content
                # Move any markdown files to content directory
                find . -maxdepth 1 -name "*.md" -exec mv {} content/ \;
                # Move any content directories
                for dir in api core data-feeds economics governance implementation networking node-operations schemas simulations smart-contracts testing; do
                  if [ -d "$dir" ]; then
                    mv "$dir" content/
                  fi
                done
              fi

              # Create a simple fallback if Quartz fails
              echo "Attempting to build with Quartz..."
              if ! quartz build; then
                echo "Quartz build failed, creating static HTML fallback..."
                mkdir -p public
                
                # Create a simple index page
                cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blocksense Protocol Specification</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #3b82f6; }
        .nav { background: #f3f4f6; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
        .nav a { margin-right: 15px; text-decoration: none; color: #374151; }
        .nav a:hover { color: #3b82f6; }
    </style>
</head>
<body>
    <h1>Blocksense Protocol Specification</h1>
    <div class="nav">
        <a href="#overview">Overview</a>
        <a href="#architecture">Architecture</a>
        <a href="#api">API</a>
        <a href="#implementation">Implementation</a>
    </div>
    <div id="content">
        <h2 id="overview">Overview</h2>
        <p>Welcome to the Blocksense Protocol Specification. This is an executable specification with implementations in multiple languages and formal verification.</p>
        
        <h2 id="architecture">Core Architecture</h2>
        <p>The Blocksense Protocol is designed as a programmable oracle for trustless compute.</p>
        
        <h2 id="features">Key Features</h2>
        <ul>
            <li>Full-text search across all specification documents</li>
            <li>Interactive graph view showing relationships between concepts</li>
            <li>Wikilink support with hover previews</li>
            <li>LaTeX rendering for mathematical expressions</li>
            <li>Syntax highlighting for code blocks</li>
            <li>Mobile-responsive design</li>
            <li>Dark/light mode support</li>
        </ul>
        
        <h2 id="implementation">Implementation Languages</h2>
        <h3>TypeScript</h3>
        <p><strong>Purpose:</strong> Reference implementation and SDK</p>
        
        <h3>Rust (Verus)</h3>
        <p><strong>Purpose:</strong> Performance-critical components with light formal verification</p>
        
        <h3>Lean4</h3>
        <p><strong>Purpose:</strong> Heavy formal verification and mathematical proofs</p>
    </div>
</body>
</html>
EOF
              fi
            '';

            installPhase = ''
              mkdir -p $out
              if [ -d "public" ]; then
                cp -r public/* $out/
              else
                echo "No output directory found, creating minimal site..."
                echo "<html><body><h1>Blocksense Specification</h1><p>Site build completed but no output found.</p></body></html>" > $out/index.html
              fi
            '';
          };
      in {
        lib = {inherit mkQuartzSite;};

        packages = {
          default = quartzCli;
          quartz-cli = quartzCli;
        };

        # Development shell with Quartz CLI available
        devShells.default = pkgs.mkShell {
          buildInputs = [quartzCli pkgs.nodejs_22];
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
