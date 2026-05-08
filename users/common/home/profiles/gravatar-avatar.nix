{ config, lib, pkgs, ... }:

let
  cfg = config.bovbel.gravatarAvatar;
in
{
  options.bovbel.gravatarAvatar = {
    enable = lib.mkEnableOption "deploy-time gravatar profile image";
    hash = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Lowercase MD5 hash of the email for gravatar.";
    };
    fileName = lib.mkOption {
      type = lib.types.str;
      default = "gravatar.jpg";
      description = "Avatar file name under ~/.local/share/.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.gravatarAvatar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/.local/share"
      ${pkgs.curl}/bin/curl -fsSL "https://www.gravatar.com/avatar/${cfg.hash}?s=2048&d=mp" -o "${config.home.homeDirectory}/.local/share/${cfg.fileName}"
      ln -sf "${config.home.homeDirectory}/.local/share/${cfg.fileName}" "${config.home.homeDirectory}/.face"
      ln -sf "${config.home.homeDirectory}/.local/share/${cfg.fileName}" "${config.home.homeDirectory}/.face.icon"

      # Update AccountsService so GNOME Settings/login screen pick it up.
      uid="$(${pkgs.coreutils}/bin/id -u)"
      ${pkgs.glib}/bin/gdbus call \
        --system \
        --dest org.freedesktop.Accounts \
        --object-path "/org/freedesktop/Accounts/User$uid" \
        --method org.freedesktop.Accounts.User.SetIconFile \
        "${config.home.homeDirectory}/.local/share/${cfg.fileName}" \
        >/dev/null 2>&1 || true
    '';
  };
}
