{
  pkgs,
  nixpkgs,
}: let
  inherit (pkgs) lib;
  streamingPkgs = import nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  evaluate = extra:
    (nixpkgs.lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [../default.nix {nixpkgs.pkgs = streamingPkgs;} extra];
    }).config;
  disabled = evaluate {};
  automatic = evaluate {gameStreaming.enable = true;};
  vaapi = evaluate {
    gameStreaming = {
      enable = true;
      encoder = "vaapi";
    };
  };
  nvenc = evaluate {
    gameStreaming = {
      enable = true;
      encoder = "nvenc";
    };
  };
  tests = {
    disabledDoesNotStartServer =
      !disabled.services.sunshine.enable
      && !(disabled.systemd.user.services ? sunshine)
      && disabled.networking.firewall.allowedTCPPorts == [];
    automaticHasNoVendorPolicy =
      !(automatic.services.sunshine.settings ? encoder)
      && !(automatic.services.sunshine.settings ? nvenc_preset)
      && !(automatic.programs.gamemode.settings ? gpu);
    nonNvidiaPackage =
      vaapi.services.sunshine.package.outPath
      == (streamingPkgs.sunshine.override {cudaSupport = false;}).outPath
      && vaapi.services.sunshine.settings.encoder == "vaapi";
    nvidiaPackage =
      nvenc.services.sunshine.package.outPath
      == (streamingPkgs.sunshine.override {cudaSupport = true;}).outPath
      && nvenc.services.sunshine.settings.encoder == "nvenc";
  };
  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) tests);
in
  assert lib.assertMsg (failed == []) "Game streaming contract failures: ${lib.concatStringsSep ", " failed}";
    pkgs.runCommand "game-streaming-contracts" {} "touch $out"
