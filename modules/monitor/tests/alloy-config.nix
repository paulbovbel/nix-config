{
  pkgs,
  nixosConfigurations,
}: let
  inherit (pkgs) lib;
  hosts = lib.filterAttrs (_: host: host.config.grafanaCloud.enable) nixosConfigurations;
  validate = name: host: let
    configuration = pkgs.writeText "alloy-${name}.alloy" host.config.environment.etc."alloy/config.alloy".text;
  in ''
    alloy validate ${configuration}
  '';
in
  pkgs.runCommand "alloy-config" {
    nativeBuildInputs = [pkgs.grafana-alloy];
    # Validation needs a nonempty placeholder, never the real publishing token.
    GRAFANA_CLOUD_API_KEY = "validation-only";
  } ''
    ${lib.concatStrings (lib.mapAttrsToList validate hosts)}
    touch "$out"
  ''
