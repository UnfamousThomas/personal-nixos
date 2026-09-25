{
  lib,
  buildNpmPackage,
  src,
}:
# Mineflayer-based Minecraft bot exposed over MCP (for driving a Minestom test
# server). `src` is the flake input, so the version follows flake.lock.
# Upstream pins the Minecraft versions it supports (1.21.11 at the time of
# writing); newer servers need a newer mineflayer/minecraft-data, i.e. a fork
# with those bumped -- repoint the flake input at it.
# After updating the input: set npmDepsHash to lib.fakeHash, build, paste the
# reported hash.
buildNpmPackage {
  pname = "minecraft-mcp-server";
  inherit ((lib.importJSON "${src}/package.json")) version;
  inherit src;

  npmDepsHash = "sha256-L7pBJ7GCoVsbuEB5rxGURVmuv47kq39HSUFGKis/l6E=";

  meta = {
    description = "Minecraft bot (Mineflayer) controllable over MCP";
    homepage = "https://github.com/yuniko-software/minecraft-mcp-server";
    license = lib.licenses.asl20;
    mainProgram = "minecraft-mcp-server";
  };
}
