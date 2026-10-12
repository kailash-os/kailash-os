# Layer CLASSIC — C-5 Password & Offline-Credential (KA-07.2, ko#100; §4.5).
#
# DESIGN — the ko#100 pick:
#   * C-5 installs the manifest's offline-credential tool set: the
#     hash-cracking flagship pair (hashcat, the John suite incl. the
#     johnny GUI), hash-type identification (hashid, hash-identifier),
#     and the word-mangling/gen helpers. Online brute-forcing against
#     live services stays OUT (§3.7; the manifest c-05 notes) — the
#     census carries no live-service cracker in this category.
#   * wordlists are ABSENT from this module's install set. The manifest's
#     single data row (seclists, status:data) is excluded by the
#     generator (generated/manifest-ids.json categories.c-05.excluded —
#     "category modules never install data rows") and rides the opt-in
#     kailash-data.wordlists-mega pack (plan D7; manifest categories.yaml
#     c-05 notes: "wordlists ride the opt-in kailash-data.wordlists-mega
#     pack (KA-07.2)"). The pack is a data DERIVATION in kailash-packages
#     — it does NOT land in this OS repo; when the pack grows, its
#     opt-in mounting attaches on the data-pack lane, not by adding
#     rows to a category module.
#
# RED stub (this commit): the module CONSUMES NOTHING — the typed spine
# owns enable/packages on kailash.layers.classic.categories.c-05 and
# this file mounts no config, so an enabled c-05 host resolves an EMPTY
# install set and the flake's c-05-options leg (non-empty set + hashcat
# present) is the watched red, same shape as the c-01-exemplar leg.
# GREEN: the manifest-generated install set wires through the binding
# table below-probe and the SAME assertions pass through the SAME eval.
{ config, lib, pkgs, ... }:

{
  # The §4.5 config-only mount is PENDING (the RED stub): nothing here
  # sets kailash.layers.classic.categories.c-05.packages, so an enabled
  # c-05 host installs NOTHING — the flake's c-05-options check watches
  # this red until the GREEN commit fills the mount with the
  # manifest-generated binding table.
}
