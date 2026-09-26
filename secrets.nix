let
  keys = import ./keys.nix;
  inherit (keys) pbovbel;
  white_tower = (import ./hosts/white-tower).ageRecipient;
  rainbow_wave = (import ./hosts/rainbow-wave).ageRecipient;
  pbovbel_dell = (import ./hosts/pbovbel-dell).ageRecipient;
  media = (import ./hosts/media).ageRecipient;
  becmac_pro = (import ./hosts/becmac-pro).ageRecipient;
in {
  "secrets/common/pbovbel-id_rsa.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/laptop/tailscale-oauth-authkey.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell becmac_pro];
  "secrets/server/tailscale-oauth-authkey.age".publicKeys = [pbovbel media];
  "secrets/common/gmail-password.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/common/grafana-cloud-env.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/common/attic-watch-store-token.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/common/pbovbel-password-hash.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/common/rbovbel-password-hash.age".publicKeys = [pbovbel white_tower becmac_pro];
  "secrets/common/abovbel-password-hash.age".publicKeys = [pbovbel rainbow_wave white_tower];
  "secrets/management/grafana-cloud-env.age".publicKeys = [pbovbel];
  "secrets/server/google-oauth-env.age".publicKeys = [pbovbel media];
  "secrets/server/aws-access-env.age".publicKeys = [pbovbel media];
  "secrets/server/web-credentials-env.age".publicKeys = [pbovbel media];
  "secrets/server/pia-env.age".publicKeys = [pbovbel media];
  "secrets/server/mam-id-env.age".publicKeys = [pbovbel media];
  "secrets/server/plex-token-env.age".publicKeys = [pbovbel media];
  "secrets/server/game-server-env.age".publicKeys = [pbovbel media];
  "secrets/server/attic-server-env.age".publicKeys = [pbovbel media];
  "secrets/server/github-runner-token.age".publicKeys = [pbovbel media];
  "secrets/server/youtube-api-key.age".publicKeys = [pbovbel media];
}
