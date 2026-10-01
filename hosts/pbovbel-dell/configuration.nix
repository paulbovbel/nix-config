{
  lib,
  pkgs,
  ...
}: let
  fingerprintPython = pkgs.python3.withPackages (ps: [ps.pyudev ps.systemd-python]);
  fingerprintPolicy = "${fingerprintPython}/bin/python3 ${./scripts/keyboard-policy.py}";
  broadcomFingerprintDriver = pkgs.libfprint-2-tod1-broadcom-cv3plus.overrideAttrs (old: rec {
    version = "6.4.372-6.4.062.0";
    src = pkgs.fetchurl {
      url = "https://packages.broadcom.com/artifactory/dell-controlvault-drivers/brcm_linux_fp_6.4.372_6.4.062.0.tgz";
      hash = "sha256-EQwPhFJHoHlI2t30QtTMXMfXkLkJDBMZvX2+rgPm5p8=";
    };

    buildInputs = map (input:
      if lib.getName input == "libfprint-2-tod1-broadcom-cv3plus-wrapper-lib"
      then
        input.overrideAttrs (_: {
          inherit version;
          __intentionallyOverridingVersion = true;
          nativeBuildInputs = [pkgs.gnutar pkgs.gzip];
          postPatch = ''
            substitute wrapper-lib.c lib.c \
              --subst-var-by to "$out/share/libfprint-2-tod1-broadcom-cv3plus/firmware"
            cc -fPIC -shared lib.c -o wrapper-lib.so
          '';
          postInstall = ''
            mkdir -p "$out/share/libfprint-2-tod1-broadcom-cv3plus/firmware"
            tar -xzf ${src} --strip-components=5 \
              -C "$out/share/libfprint-2-tod1-broadcom-cv3plus/firmware" \
              brcm_linux_fp/var/lib/fprint/.broadcomCv3plusFW/
          '';
        })
      else input)
    old.buildInputs;
  });
in {
  imports = [
    ../site.nix
    ./hardware-configuration.nix
  ];

  boot = {
    initrd.systemd.enable = true;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages;
  };

  networking = {
    hostName = "pbovbel-dell";
    hostId = "8f2543e6";
  };

  services = {
    thermald.enable = true;
    power-profiles-daemon.enable = true;
    fprintd = {
      enable = true;
      tod = {
        enable = true;
        driver = broadcomFingerprintDriver;
      };
    };
  };

  environment.systemPackages = [pkgs.intel-gpu-tools];

  systemd.services = {
    fingerprint-keyboard-policy = {
      description = "Disable fingerprint authentication while an external keyboard is connected";
      wantedBy = ["multi-user.target"];
      before = ["display-manager.service"];
      after = ["systemd-udev-trigger.service"];
      path = [pkgs.systemd];
      serviceConfig = {
        Type = "notify";
        ExecStart = fingerprintPolicy;
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    # An attached keyboard is an expected skip, not a daemon startup failure.
    fprintd.serviceConfig.ExecCondition = ["${fingerprintPolicy} --check"];
  };

  grafanaCloud.role = "laptop";

  rootFs = {
    enable = true;
    backend = "zfs";
    impermanent = true;
    persistDirectories = ["/var/lib/fprint"];
    swapSize = "32G";
  };

  system.stateVersion = "26.05";

  netboot = {
    enable = true;
  };
}
