# profiles/minimal.nix — CORE substrate only, zero categories (KA-01.3).
# Every image/profile inherits this floor; categories are opt-in above it.
{ lib, modulesPath, ... }: {
  imports = [ ../modules ];  # module tree: nothing enabled by default
  kailash = lib.mapAttrs (_: lib.mkDefault false) {
    # explicit zero-categories posture; layer option trees land per module
  };
  system.stateVersion = "25.11";
}
