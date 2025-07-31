# Quartz Nix Flake

A Nix flake that packages [Quartz v4](https://github.com/jackyzha0/quartz) CLI as a reusable tool for building static sites from Obsidian vaults or Markdown content.

## Features

- ✅ Packages Quartz CLI as a standalone tool
- ✅ Pre-built dependencies for fast builds
- ✅ `mkQuartzSite` function for building sites in other flakes
- ✅ Development shell with Quartz CLI ready to use
- ✅ No configuration files bundled - users provide their own

## Usage

### As a Development Tool

```bash
# Enter development shell with Quartz CLI
nix develop github:yourusername/quartz-nix

# Now you can use Quartz commands in your project
quartz create
quartz build
quartz sync
```

### As a Flake Input for Building Sites

Add this flake as an input to your project:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    quartz-nix.url = "github:yourusername/quartz-nix";
  };

  outputs = { nixpkgs, quartz-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      mkQuartzSite = quartz-nix.lib.${system}.mkQuartzSite;
    in {
      packages.${system}.my-site = mkQuartzSite {
        name = "my-specification-site";
        src = ./spec;  # Your content directory
        configPath = ./quartz.config.ts;  # Optional: custom config
      };
    };
}
```

### In the Blocksense Monorepo

```nix
# In your main flake.nix
{
  inputs = {
    # ...existing inputs...
    quartz-nix.url = "github:yourusername/quartz-nix";
  };

  outputs = { self, nixpkgs, quartz-nix, ... }:
    let
      mkQuartzSite = quartz-nix.lib.${system}.mkQuartzSite;
    in {
      packages.${system} = {
        # Build the specification website
        spec-site = mkQuartzSite {
          name = "blocksense-specification";
          src = ./spec;
          configPath = ./spec/website/quartz.config.ts;
        };
      };

      devShells.${system}.docs = pkgs.mkShell {
        inputsFrom = [ quartz-nix.devShells.${system}.default ];
        shellHook = ''
          echo "Documentation environment ready!"
          echo "Edit files in ./spec/ and run 'quartz build' to generate site"
        '';
      };
    };
}
```

## Available Packages

- `default` / `quartz-cli` - The Quartz CLI tool with all dependencies

## Available Libraries

- `mkQuartzSite { name, src, configPath? }` - Function to build a Quartz site
  - `name`: Derivation name
  - `src`: Source directory containing your Markdown files
  - `configPath`: Optional path to custom `quartz.config.ts`

## Development Workflow

1. **Setup**: Use `nix develop` to get the Quartz CLI
2. **Initialize**: Run `quartz create` in your content directory
3. **Configure**: Edit `quartz.config.ts` and `quartz.layout.ts` in your project
4. **Build**: Run `quartz build` to generate the static site
5. **Deploy**: Use the `mkQuartzSite` function in your flake for CI/CD

## Updating

When Quartz updates its dependencies, update the `npmDepsHash`:

1. Change the hash to a placeholder (all zeros)
2. Run `nix build` to get the real hash from the error message
3. Update the hash in `flake.nix`
4. Commit the changes

## License

This flake is provided under the same license as Quartz itself.