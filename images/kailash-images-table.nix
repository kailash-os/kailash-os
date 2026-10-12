# The §8.1 image-matrix budget table (KA-28, kailash-os#28).
#
# Shape (per the ratified deliverable-shape decision, [kailash-os#132](https://github.com/kailash-os/kailash-os/issues/132)
# — QEMU image PRIMARY, ISO secondary, desktop-carrying variants deferred):
# each PROFILE that exists (minimal, redteam-ai, full, headless-agent) ships
# one QEMU qcow2 target + one ISO target, EMITTED FROM THE SAME PROFILE EVAL
# (one source, two formats — the decision's proposal-item-2 language).
#
# The budgets here are the plan §8.1 numbers, translated verbatim onto the
# two shipped formats for the profiles that exist today:
#
#   * qemu-minimal    — the §8.1 `iso-standard` scope (the CORE substrate +
#     NixOS floor; no desktop) on the PRIMARY format. §8.1 budget: ≤4 GB.
#   * qemu-redteam-ai — the §8.1 `ova-redteam-ai` lab-VM scope on the
#     PRIMARY format (the plan's OVA row becomes the QEMU qcow2; the
#     `redteam-ai` profile is the §8.1 redteam profile). §8.1 budget: ≤8 GB.
#   * qemu-full       — the §8.1 `iso-full` "kali-everything" live scope on
#     the PRIMARY format. §8.1 budget: ≤10 GB.
#   * qemu-headless-agent — the §8.1 `headless-agent` row (≤1.5 GB).
#   * iso-minimal / iso-headless-agent — the §8.1 `iso-standard` /
#     `headless-agent` ISO scopes with the SAME budgets (the §8.1
#     headless-agent row is ISO/VM dual-format; the iso-standard budget
#     applies to the no-desktop substrate ISO).
#   * iso-redteam-ai / iso-full — same scopes as their QEMU twins, same
#     §8.1 budgets (8 GB / 10 GB): the decision ships one source in two
#     formats at the same scope.
#
# Excluded-by-construction posture (the §8.1 sentence + plan D7): the
# C-7 SDR pack (kailash-data.sdr-tools, opt-in data pack; the five data
# rows the generator excludes from c-07's installable) and the wordlists
# pack (kailash-data.wordlists-mega; seclists rides the same opt-in lane)
# NEVER enter a default image — asserted per-profile, per-format by the
# images-budget check leg (the mass rows + the pack rows in flake.nix).
#
# The `mass` numbers are RECORDED EVIDENCE (not guesses): the committed
# census snapshot (tests/images-census.json) sums each derivation's real
# NarSize from the nixpkgs binary cache (cache.nixos.org narinfo lookups,
# no builds). The eval-time census walk inside the check leg counts
# derivation-level input names from the SAME closure — name-set drift (a
# manifest merge or a pin bump adds/removes a row) turns the leg red until
# the snapshot is regenerated (scripts/gen-image-census.sh, the same cycle).
# The budgets force the heavies (texlive, gnuradio, wordlists, SDR pack)
# into opt-in kailash-data.* derivations by CONSTRUCTION (never a default
# profile/ISO row).
{
  formats = {
    qemu = {
      description = "QEMU/VM disk image — the PRIMARY deliverable shape (kailash-os#132)";
      extension = ".qcow2";
    };
    iso = {
      description = "Bootable ISO — the SECONDARY shape (bare-metal evaluation)";
      extension = ".iso";
    };
  };

  targets = {
    qemu-minimal = {
      profile = "minimal";
      format = "qemu";
      budgetMB = 4096;
      ref = "kailash-images-qemu-minimal";
    };
    qemu-redteam-ai = {
      profile = "redteam-ai";
      format = "qemu";
      budgetMB = 8192;
      ref = "kailash-images-qemu-redteam-ai";
    };
    qemu-full = {
      profile = "full";
      format = "qemu";
      budgetMB = 10240;
      ref = "kailash-images-qemu-full";
    };
    qemu-headless-agent = {
      profile = "headless-agent";
      format = "qemu";
      budgetMB = 1536;
      ref = "kailash-images-qemu-headless-agent";
    };
    iso-minimal = {
      profile = "minimal";
      format = "iso";
      budgetMB = 4096;
      ref = "kailash-images-iso-minimal";
    };
    iso-redteam-ai = {
      profile = "redteam-ai";
      format = "iso";
      budgetMB = 8192;
      ref = "kailash-images-iso-redteam-ai";
    };
    iso-full = {
      profile = "full";
      format = "iso";
      budgetMB = 10240;
      ref = "kailash-images-iso-full";
    };
    iso-headless-agent = {
      profile = "headless-agent";
      format = "iso";
      budgetMB = 1536;
      ref = "kailash-images-iso-headless-agent";
    };
  };
}