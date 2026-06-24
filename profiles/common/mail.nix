{config, ...}: {
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
      passwordeval = "cat ${config.age.secrets.gmail-password.path}";
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
}
