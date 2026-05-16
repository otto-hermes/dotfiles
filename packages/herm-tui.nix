{ lib, stdenvNoCC, fetchurl, bun, makeWrapper }:

let
  version = "1.5.0";
  opentuiCoreVersion = "0.2.2";
  opentuiCorePackage = "@opentui/core-linux-arm64";

  hermSrc = fetchurl {
    url = "https://registry.npmjs.org/herm-tui/-/herm-tui-${version}.tgz";
    hash = "sha512-fTR1xangnUxaqTOT7TcnJRTVzuLJTdtFFxQ9+b2LDD2/HlMoPlxuG7AY9WK+Afog8aTizCyIQvs+nZh9KBeCwg==";
  };

  opentuiCoreSrc = fetchurl {
    url = "https://registry.npmjs.org/@opentui/core-linux-arm64/-/core-linux-arm64-${opentuiCoreVersion}.tgz";
    hash = "sha512-1pzTYFEZauYuw6AGycw2TYGtAlZVGjuUtSdxH1fP51kBPS3oVWduUY2j7GKREz3SU5NulvO2Wc6HWsm3feMqwQ==";
  };
in
stdenvNoCC.mkDerivation {
  pname = "herm-tui";
  inherit version;

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = ''
    runHook preUnpack

    mkdir -p herm-tui opentui-core
    tar -xzf ${hermSrc} -C herm-tui --strip-components=1
    tar -xzf ${opentuiCoreSrc} -C opentui-core --strip-components=1

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    app_dir=$out/lib/herm-tui
    mkdir -p "$app_dir/node_modules/@opentui/core-linux-arm64" "$out/bin"

    cp -R herm-tui/. "$app_dir/"
    cp -R opentui-core/. "$app_dir/node_modules/@opentui/core-linux-arm64/"

    makeWrapper ${bun}/bin/bun "$out/bin/herm" \
      --add-flags "$app_dir/index.js" \
      --set-default HERMES_HOME /home/hermes/.hermes

    runHook postInstall
  '';

  meta = {
    description = "Herm, an OpenTUI dashboard TUI for Hermes Agent";
    homepage = "https://github.com/liftaris/herm";
    license = lib.licenses.mit;
    mainProgram = "herm";
    platforms = [ "aarch64-linux" ];
  };
}
