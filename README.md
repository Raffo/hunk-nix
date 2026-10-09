# hunk-nix

A non-flake Nix package for [Hunk](https://github.com/modem-dev/hunk),
following the release-binary approach of
[github-copilot-cli-nix](https://github.com/Raffo/github-copilot-cli-nix).
No Node.js, Bun, or flakes required.

## Build and install

With Nix installed and `<nixpkgs>` available, run from this directory:

```sh
nix-build
./result/bin/hunk --version
nix-env -if .
```

The package exposes both `hunk` and `hunkdiff`, includes the bundled agent
skills, and marks the installation as Nix-managed. Git must be available on
your PATH for Git-backed reviews.

## NixOS or Home Manager

Add the overlay and select the package:

```nix
{
  nixpkgs.overlays = [ (import /path/to/hunk-nix/overlay.nix) ];
  environment.systemPackages = [ pkgs.hunk ];
}
```

For Home Manager, use `home.packages = [ pkgs.hunk ];` instead of
`environment.systemPackages`.

You can also use the package directly, without an overlay:

```nix
home.packages = [ (import /path/to/hunk-nix { inherit pkgs; }) ];
```

## Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

Intel macOS requires a nixpkgs version that still supports it, such as 25.11.
The x86-64 binaries require SSE4.2.

## Updates and trust

`sources.json` pins the release version and SHA-256 hash for each archive.
This packages upstream binaries, not a source build; it trusts Hunk's release
publisher. Hashes prevent unexpected archive changes, but do not independently
authenticate the publisher.

To update, change `version` and all four hashes using the new release's
`SHA256SUMS`, check that the archive names/layout are unchanged, and rebuild.
You can obtain a Nix hash for an individual archive with:

```sh
nix-prefetch-url https://github.com/modem-dev/hunk/releases/download/v<VERSION>/hunkdiff-linux-x64.tar.gz
```

Nix accepts the base32 hash printed by this command as well as the SRI hashes
currently in `sources.json`. Do not use `--unpack`: these hashes cover the
compressed archives.

Reinstall with `nix-env -if .`, or rebuild your NixOS/Home Manager configuration.
`hunk update` will direct you back to Nix rather than replace this installation.
There is no automated updater or CI in this project.

## Package checks

Native builds run installation checks for both executable names, help output,
skill discovery, and Nix-managed update behavior. Run them with `nix-build`.
