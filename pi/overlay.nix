# Overlay with everything the Pi setup needs (as a plain function, so it can be
# used from any flake or Nix config):
#
#   overlays.pi = import ./pi/overlay.nix { };
#   # with the Minecraft bot too, from a source tree (a flake input):
#   overlays.pi = import ./pi/overlay.nix { minecraftMcpServerSrc = inputs.minecraft-mcp-server; };
#
# Adds: pi-coding-agent (newest release), pi-agent (Pi with tools on PATH),
# piExtensions.*, kotlin-lsp and, if given a source, minecraft-mcp-server.
{
  # Source of https://github.com/yuniko-software/minecraft-mcp-server (or a
  # fork of it); the package is only defined when this is set.
  minecraftMcpServerSrc ? null,
}:
final: prev:
{
  # nixpkgs' recipe, pinned to the newest upstream release instead of
  # whatever nixpkgs has caught up to. To update, bump `version` and set the
  # three hashes to final.lib.fakeHash; the build then reports each correct
  # one in turn. Get them up front with:
  #   nix flake prefetch github:earendil-works/pi/v<version>
  #   nix store prefetch-file https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-<version>.tgz
  # (the npmDeps hash comes from the failed build.) If a new release adds
  # workspaces the recipe doesn't build, copy nixpkgs' package.nix into
  # packages/ and adapt buildPhase.
  pi-coding-agent = prev.pi-coding-agent.overrideAttrs (
    finalAttrs: _: {
      version = "0.87.1";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${finalAttrs.version}";
        hash = "sha256-GUhlq6t+l6iiViOZ0bkV28v3ZDqcLvEwpZpYZ5JAyDk=";
      };

      # buildNpmPackage derives npmDeps from its npmDepsHash *argument*, so
      # overrideAttrs has to rebuild npmDeps itself.
      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = "sha256-JBIYoP2vvRNz1HONNvDJ1U3c+nmCJ7/VgNthRTkrkIA=";
        fetcherVersion = 1;
      };

      # Hydrated provider catalog, shipped by the pi-ai npm package of the
      # same version (see nixpkgs' recipe for why it's not in the source).
      modelData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
        hash = "sha256-NbRDLyfMJmX4a+67mvajmxJRlwiDwwRL2L5PToxzHKA=";
      };
    }
  );

  piExtensions = final.callPackage ./packages/extensions.nix { };
  kotlin-lsp = final.callPackage ./packages/kotlin-lsp.nix { };
  pi-agent = final.callPackage ./packages/pi-agent.nix { };
}
// prev.lib.optionalAttrs (minecraftMcpServerSrc != null) {
  minecraft-mcp-server = final.callPackage ./packages/minecraft-mcp-server.nix {
    src = minecraftMcpServerSrc;
  };
}
