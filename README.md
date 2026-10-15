# hunk-nix

A non-flake Nix package for [Hunk](https://github.com/modem-dev/hunk).
Packages upstream release binaries, including `hunk`, `hunkdiff`, and
the bundled agent skills. No Node.js or Bun installation required.

Requires Nix. Command-line installation also needs an available `<nixpkgs>`.
Git must be on your `PATH` for Git-backed reviews.

## Install

From this repository's directory:

```sh
nix-env -if .
hunk --version
```

This builds and installs the package; a separate `nix-build` is not needed.

### NixOS

Alternatively, add this to your NixOS configuration, replacing the path with
the absolute path to this repository:

```nix
{ pkgs, ... }: {
  environment.systemPackages = [
    (import /absolute/path/to/hunk-nix { inherit pkgs; })
  ];
}
```

Apply with `sudo nixos-rebuild switch`.

### Home Manager

Add this to your Home Manager configuration, replacing the path:

```nix
{ pkgs, ... }: {
  home.packages = [
    (import /absolute/path/to/hunk-nix { inherit pkgs; })
  ];
}
```

Apply with `home-manager switch`, or rebuild NixOS if Home Manager is
configured as a NixOS module.

## Platforms

Linux and macOS on x86-64 and ARM64.

Intel macOS requires a nixpkgs version that still supports it, such as 26.05.
The x86-64 binaries require SSE4.2.

## Update

Pull the latest changes to this repository, then repeat your install command
or rebuild your NixOS/Home Manager configuration. The installed version is
pinned by this repository; `hunk update` cannot replace a Nix installation.

## Maintainer notes

GitHub Actions checks for stable Hunk releases every six hours, or on demand
via **Actions > Auto-update to latest release > Run workflow** on the default
branch. Like [github-copilot-cli-nix](https://github.com/Raffo/github-copilot-cli-nix),
it commits updates directly to that branch, after `nix-build` passes on
x86-64 Linux. The workflow needs permission to push to the default branch;
branch protection rules still apply.

To update manually, run `bash update.sh` (requires `curl` and `jq`), then
`nix-build`. The script updates `sources.json` using upstream's `SHA256SUMS`
and checks that all four platform archives are published. Failed updates are
not committed. If the upstream license changes, update its pinned hash in
`default.nix` manually.

Run `nix-build` to build and check both executables, skill discovery, and
Nix-managed update behavior on the native platform. Run `bash tests/update.sh`
to test the updater without network access.

This package trusts upstream's binary releases. Pinned hashes detect archive
changes; they do not independently authenticate the publisher.
