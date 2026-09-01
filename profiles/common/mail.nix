{
  config,
  lib,
  pkgs,
  ...
}: {
  age.secrets.gmail-password = {
    file = ../../secrets/common/gmail-password.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  programs.msmtp = {
    enable = true;
    defaults = {
      aliases = "/etc/aliases";
      auth = true;
      tls = true;
      tls_starttls = true;
      port = 587;
      syslog = "LOG_MAIL";
    };
    accounts.default = {
      host = "smtp.gmail.com";
      from = "paul@bovbel.com";
      user = "paul@bovbel.com";
      passwordeval = "${pkgs.coreutils}/bin/cat ${config.age.secrets.gmail-password.path}";
    };
  };

  services.smartd = {
    enable = true;
    defaults.autodetected = "-a -n standby,15,q -o on -S on -s (L/../../6/01|S/../.././02)";
    notifications.mail = {
      enable = true;
      sender = "paul@bovbel.com";
      recipient = "paul@bovbel.com";
    };
  };

  services.zfs.zed = lib.mkIf ((config.rootFs.enable && config.rootFs.backend == "zfs") || config.storage.enable) {
    enableMail = true;
    settings = {
      ZED_EMAIL_ADDR = ["paul@bovbel.com"];
      ZED_EMAIL_PROG = "${pkgs.mailutils}/bin/mail";
      ZED_EMAIL_OPTS = "-s '@SUBJECT@' @ADDRESS@";
      ZED_NOTIFY_INTERVAL_SECS = 3600;
      ZED_NOTIFY_VERBOSE = true;
    };
  };
}
