# The CORE substrate profile (KA-01.3): imports the category module tree and
# enables nothing — every category option defaults to false, so the base
# substrate is all that installs. Higher profiles (full, redteam-ai,
# blue-team-ai, platform) import this file and switch categories on above
# this floor.
{ ... }:

{
  imports = [ ../modules ];

  system.stateVersion = "25.11";
}
