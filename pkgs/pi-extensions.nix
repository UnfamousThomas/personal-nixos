{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
  jq,
  stdenvNoCC,
}:
# Pi extensions (and the pi-acp bridge), built from pinned upstream sources so
# nothing is fetched at runtime by `pi install`. Update recipe for any of them:
# bump `version`, set the hashes to lib.fakeHash, rebuild, paste the reported
# ones. Source hashes: `nix flake prefetch github:<owner>/<repo>/<tag>`.
#
# Pi loads an extension's TypeScript source directly (via the package.json
# `pi.extensions` entry), so these are "source + production node_modules", not
# a compiled build. Pi's own packages (pi-ai, pi-tui, typebox, ...) are peer
# dependencies and stay out of node_modules: the host provides them, and a
# second copy inside an extension would be a second module instance.
let
  buildPiExtension =
    { lockFile, ... }@args:
    buildNpmPackage (
      {
        dontNpmBuild = true;
        # `npm pack` would run the package's own prepack (a tsc build we
        # don't use).
        npmPackFlags = [ "--ignore-scripts" ];
        npmRebuildFlags = [ "--ignore-scripts" ];
        # Upstream lockfiles also pin the dev/peer trees (Pi itself, test
        # tooling), some entries of which have no integrity hash and so can't
        # be prefetched. Trim package.json to runtime dependencies and use a
        # lockfile pruned to match; each one is upstream's own lockfile run
        # through, from a copy of the trimmed package.json:
        #   npm install --package-lock-only --ignore-scripts
        postPatch = ''
          ${lib.getExe jq} 'del(.peerDependencies, .devDependencies, .scripts)' package.json > package.json.new
          mv package.json.new package.json
          cp ${lockFile} package-lock.json
        ''
        + (args.postPatch or "");
      }
      // removeAttrs args [
        "lockFile"
        "postPatch"
      ]
    );

  # For an extension with no runtime dependencies (only Pi's own peers): just
  # the files its package.json publishes, no node_modules to fetch or lock.
  buildPiSourceExtension =
    args:
    stdenvNoCC.mkDerivation (
      {
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          dest=$out/lib/node_modules/${args.pname}
          mkdir -p $dest
          for f in package.json README.md LICENSE tsconfig.json extensions src; do
            [ -e "$f" ] && cp -r "$f" $dest/
          done
          runHook postInstall
        '';
      }
      // args
    );

  # Where a Pi `packages` entry (~/.pi/agent/settings.json) should point.
  # npm installs under the package.json `name`, which is scoped for some.
  extensionPath = drv: "${drv}/lib/node_modules/${drv.passthru.npmName or drv.pname}";
in
rec {
  inherit extensionPath;

  # MCP support with lazy-loaded tools; reads ~/.config/mcp/mcp.json.
  pi-mcp-adapter = buildPiExtension rec {
    pname = "pi-mcp-adapter";
    version = "2.37.0";
    src = fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-mcp-adapter";
      tag = "v${version}";
      hash = "sha256-fZ6sAJhNjSMz/KVsuuNtjkomkI5rQ0qlWMpvFVPinEc=";
    };
    lockFile = ./pi/pi-mcp-adapter-package-lock.json;
    npmDepsHash = "sha256-+fW72/nfLk0o6qoSMFYCOzeFOsofKshs56J575GsG9o=";
    meta = {
      description = "MCP adapter extension for the Pi coding agent";
      homepage = "https://github.com/nicobailon/pi-mcp-adapter";
      license = lib.licenses.mit;
    };
  };

  # Claude Code-style sub-agents for Pi.
  pi-subagents = buildPiExtension rec {
    pname = "pi-subagents";
    version = "0.19.0";
    passthru.npmName = "@tintinweb/pi-subagents";
    src = fetchFromGitHub {
      owner = "tintinweb";
      repo = "pi-subagents";
      tag = "v${version}";
      hash = "sha256-1K6U5+2qLgOV7lUWbvqUne/Pf7oMRDf40GXLl8gv6Bk=";
    };
    lockFile = ./pi/pi-subagents-package-lock.json;
    npmDepsHash = "sha256-w/xgaubF+4hNpFMcoezwXAp2q6akKtMW2p2GUH3d4w8=";
    meta = {
      description = "Sub-agents and workflow orchestration for the Pi coding agent";
      homepage = "https://github.com/tintinweb/pi-subagents";
      license = lib.licenses.mit;
    };
  };

  # Declarative LSP diagnostics/navigation, configured by ~/.pi/agent/lsp.json.
  # Published on npm only (no repo link, no lockfile in the tarball), so its
  # lockfile is generated from scratch (same command as above).
  pi-lsp = buildPiExtension rec {
    pname = "pi-lsp";
    version = "0.1.7";
    src = fetchurl {
      url = "https://registry.npmjs.org/pi-lsp/-/pi-lsp-${version}.tgz";
      hash = "sha256-75WAW5kBWlXhmaHIRhfY/xWtgXPWyFASIG634J8CGoc=";
    };
    sourceRoot = "package";
    lockFile = ./pi/pi-lsp-package-lock.json;
    npmDepsHash = "sha256-P9HFk8J+ydnNzXOdB5JMM8eJ7RenwEZsGv3NsGj6eGI=";
    meta = {
      description = "Declarative LSP diagnostics and navigation tools for the Pi coding agent";
      homepage = "https://www.npmjs.com/package/pi-lsp";
      license = lib.licenses.mit;
    };
  };

  # Automatic model routing among the models Pi has credentials for (cost,
  # capability, health, failover); reads ~/.pi/agent/auto-model.json. Adds a
  # virtual `pi-auto-model/auto` model, so it composes with any provider,
  # including the Cloudflare AI Gateway one Pi ships. Its only network access
  # is a daily refresh of the LiteLLM price catalog (pricing.litellm.enabled).
  pi-auto-model = buildPiSourceExtension rec {
    pname = "pi-auto-model";
    version = "0.8.4";
    src = fetchFromGitHub {
      owner = "nickpkg";
      repo = "pi-auto-model";
      tag = "v${version}";
      hash = "sha256-fK2XRRJSL5i1sY6eThRm3rwwHC3P+By+tZW2/6PUFVA=";
    };
    meta = {
      description = "Automatic, explainable model routing for the Pi coding agent";
      homepage = "https://github.com/nickpkg/pi-auto-model";
      license = lib.licenses.mit;
    };
  };

  # ACP bridge: lets Zed drive Pi (spawns `pi --mode rpc`, so `pi` must be on
  # its PATH; see modules/features/apps/zed/zed-pi.nix). A normal compiled
  # CLI, unlike the extensions above.
  pi-acp = buildNpmPackage rec {
    pname = "pi-acp";
    version = "0.0.34";
    src = fetchFromGitHub {
      owner = "svkozak";
      repo = "pi-acp";
      tag = "v${version}";
      hash = "sha256-QRwxOtTZOY+Np3PkAoy2o2PrUzEqjItM/372sCPlSMo=";
    };
    npmDepsHash = "sha256-BvLNtFfp1cMVjzWcMRSdhTqiJrTfbFoUbWkkPW9200o=";
    meta = {
      description = "ACP adapter for the Pi coding agent";
      homepage = "https://github.com/svkozak/pi-acp";
      license = lib.licenses.mit;
      mainProgram = "pi-acp";
    };
  };
}
