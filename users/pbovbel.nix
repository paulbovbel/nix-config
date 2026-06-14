{config, ...}: {
  disko.zfs.settings.datasets."zroot/root/home/pbovbel" = {
    properties.mountpoint = "/home/pbovbel";
  };

  age.secrets.pbovbel-ssh-private-key = {
    file = ../secrets/common/pbovbel-id_rsa.age;
    path = "/home/pbovbel/.ssh/id_rsa";
    owner = "pbovbel";
    group = "users";
    mode = "0400";
    symlink = false;
  };

  systemd.tmpfiles.rules = [
    "d /home/pbovbel/.ssh 0700 pbovbel users - -"
  ];

  age.secrets.pbovbel-password-hash = {
    file = ../secrets/common/pbovbel-password-hash.age;
  };

  users.users.pbovbel = {
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.pbovbel-password-hash.path;
    description = "paul@bovbel.com";
    extraGroups = ["networkmanager" "wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC1WGjxe/6kJ2uHiI1R85VifWC2GeaEj98sAZIMLtFqgqY8zASg7in+We4oE/H1xBPf9AXHwM03rNTNQyVQ/w+YRacPAiRI8w6/tnx+ry/atxwZjFuGgYvzJockc1ar3zGSa3TWWUqe85TfwB6YjbQtSqqvGQ+BWI44+nsbKgGtFzyVyBBhdYmuBcVkNi9rCATRtto4rmBEs9RfHvWb+dLXMdUZbo4DsYZanMiucbWkrq4soHVZKJWGMqBmVRwVsO+pm9FyE3p1EaRh5afILCKi0X3X3jdJUrWIqqn7SiqaQCrx4uotpQef0S45eJhl2AqwpB66OnngMfhB4xaO+wgBEpjOheLLcfnFCH9WXEmD6r49om91K22+8j20Y93zNeDoYC6OYxe0flAzdsTbyfyx2lo2/TdNzYc5ruqgNbnhDnbeZJ2JLx3CbpixxGZJU9BhG2Pye+dpgnLTT48jEX5L/kWQMNkD50mpIEbFK8zLASH5g1q5bvw0NuTrpN8u2FqCmPEvpybFOTw1lV13I0l2fCdHSw3RNPA3QSP/GeGbOkx7yGWH2wJxJTGr1up2FBp7S6uCqU7MlVlrRbSzyKEmH5cTTFho+CnAhr1lQtlajCRTwm5UuoQYLFYkT/J+1lcXqU40H7jKYqRdwgVZ5CL6smJ/9IuZiJY2CA3rmcrPFQ== paul@bovbel.com"
    ];
  };
}
