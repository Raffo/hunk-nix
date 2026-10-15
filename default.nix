{
  pkgs ? import <nixpkgs> { },
}:

let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  system = pkgs.stdenv.hostPlatform.system;
  source = sources.${system} or (throw "hunk-nix: unsupported system: ${system}");
in
pkgs.stdenv.mkDerivation rec {
  pname = "hunk";
  inherit (sources) version;

  src = pkgs.fetchurl {
    url = "https://github.com/modem-dev/hunk/releases/download/v${version}/${source.name}.tar.gz";
    inherit (source) hash;
  };

  upstreamLicense = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/modem-dev/hunk/v${version}/LICENSE";
    sha256 = "1rpkcgq7m8kmkfdjrg6fcdcv2rq1p76qm1myaw7ilkl7bldy1zl3";
  };

  nativeBuildInputs = [
    pkgs.makeWrapper
  ]
  ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.autoPatchelfHook
  ];
  buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.stdenv.cc.cc.lib
  ];

  dontBuild = true;
  # Bun's compiled application is appended to the executable.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 hunk "$out/bin/hunk"
    cp -r skills "$out/"
    install -Dm644 "$upstreamLicense" "$out/share/licenses/hunk/LICENSE"
    wrapProgram "$out/bin/hunk" --set HUNK_INSTALL_SOURCE nix
    ln -s hunk "$out/bin/hunkdiff"
    runHook postInstall
  '';

  doInstallCheck = pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/hunk-home"
    export HUNK_INSTALL_SOURCE=npm
    mkdir -p "$HOME"
    cd "$TMPDIR"

    for command in hunk hunkdiff; do
      "$out/bin/$command" --version > version.txt
      grep -Fx "${version}" version.txt
      "$out/bin/$command" --help > help.txt
      grep -F "Usage:" help.txt
      "$out/bin/$command" skill path > skill-path.txt
      grep -Fx "$out/skills/hunk-review/SKILL.md" skill-path.txt
      "$out/bin/$command" skill path hunk-extensions > extension-skill-path.txt
      grep -Fx "$out/skills/hunk-extensions/SKILL.md" extension-skill-path.txt
      "$out/bin/$command" update --check > update-check.txt
      grep -F "installed with Nix" update-check.txt
    done
    test -s "$out/skills/hunk-review/SKILL.md"
    test -s "$out/skills/hunk-extensions/SKILL.md"

    status=0
    "$out/bin/hunk" update > update.txt 2>&1 || status=$?
    test "$status" -eq 1
    grep -F "Update it through your Nix configuration" update.txt
    runHook postInstallCheck
  '';

  meta = with pkgs.lib; {
    description = "Terminal diff viewer for agentic changesets";
    homepage = "https://github.com/modem-dev/hunk";
    changelog = "https://github.com/modem-dev/hunk/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "hunk";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
