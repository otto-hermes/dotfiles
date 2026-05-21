{ lib, stdenvNoCC, fetchurl, bun, makeWrapper, hermesAgentPackage ? null }:

let
  version = "1.6.1";
  opentuiCoreVersion = "0.2.2";
  opentuiCorePackage = "@opentui/core-linux-arm64";

  hermSrc = fetchurl {
    url = "https://registry.npmjs.org/herm-tui/-/herm-tui-${version}.tgz";
    hash = "sha512-y57RH1ml6/JK02t32AQpNRab52//pkGmdeEofsoihi7JahbyJ3SiC1Y92GRy8BKDaW+bB4DfUO3sn44g+QMAXg==";
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

    wrapper_args=(
      --add-flags "$app_dir/index.js"
      --set-default HERMES_HOME /home/hermes/.hermes
    )

    ${lib.optionalString (hermesAgentPackage != null) ''
      # herm-tui spawns `python -m tui_gateway.entry`. On NixOS, that module
      # lives in Hermes Agent's wrapped Python env, not in system python3.
      hermes_python="$(sed -n "s/^export HERMES_PYTHON='\([^']*\)'$/\1/p" ${lib.getExe hermesAgentPackage})"
      if [ -z "$hermes_python" ]; then
        echo "could not extract HERMES_PYTHON from ${lib.getExe hermesAgentPackage}" >&2
        exit 1
      fi
      wrapper_args+=(
        --set HERMES_PYTHON "$hermes_python"
        --set-default HERMES_AGENT_ROOT ${hermesAgentPackage}
      )
    ''}

    makeWrapper ${bun}/bin/bun "$out/bin/herm" "''${wrapper_args[@]}"

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
