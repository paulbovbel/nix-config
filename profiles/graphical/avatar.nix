{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.bovbel.avatar;
in {
  options.bovbel.avatar = {
    enable = lib.mkEnableOption "GNOME profile image from a local asset";
    source = lib.mkOption {
      type = lib.types.path;
      description = "Avatar image to deploy.";
    };
    fileName = lib.mkOption {
      type = lib.types.str;
      default = "avatar.png";
      description = "Avatar file name under ~/.local/share.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = {
      ".local/share/${cfg.fileName}".source = cfg.source;
      ".face".source = cfg.source;
      ".face.icon".source = cfg.source;
    };

    home.activation.gnomeAvatar = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${pkgs.glib}/bin/gdbus call \
        --system \
        --dest org.freedesktop.Accounts \
        --object-path "/org/freedesktop/Accounts/User$(${pkgs.coreutils}/bin/id -u)" \
        --method org.freedesktop.Accounts.User.SetIconFile \
        "${config.home.homeDirectory}/.local/share/${cfg.fileName}" \
        >/dev/null 2>&1 || true
    '';
  };
}
