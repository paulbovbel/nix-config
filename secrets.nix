let
  keys = import ./keys.nix;
  inherit (keys) pbovbel;
  white_tower = "age1wk8sq7rwy46a4rms25gwyvxjd0utt53l8nvwnuaujqmqj6ek5ujqjsgt8t";
  rainbow_wave = "age17vygkuef5n8yc5ruha3punredg4gudyhpd9fwpl7zkw8q9yjveks8r6ddn";
  pbovbel_dell = "age1775795dq047mk4hd5ypka5hssd5xr0gwv9ylvq3n6azje2p7n46qmr7yxr";
  media = "age19grruxtufcshcg7j0sveurtqq0tqg9zpjrsk7ghaq4800r8j4shsfv0hae";
  becmac_pro = "age1kkxf00p34aqj8ua53utfwzcrhahhtzmrhymlfynsjmrtkp3k3q5qjuavxx";
in {
  "secrets/common/pbovbel-id_rsa.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/laptop/tailscale-oauth-authkey.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell becmac_pro];
  "secrets/server/tailscale-oauth-authkey.age".publicKeys = [pbovbel media];
  "secrets/common/gmail-password.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/common/attic-watch-store-token.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/common/pbovbel-password-hash.age".publicKeys = [pbovbel rainbow_wave white_tower pbovbel_dell media becmac_pro];
  "secrets/common/rbovbel-password-hash.age".publicKeys = [pbovbel white_tower becmac_pro];
  "secrets/common/abovbel-password-hash.age".publicKeys = [pbovbel rainbow_wave white_tower];
  "secrets/server/google-oauth-env.age".publicKeys = [pbovbel media];
  "secrets/server/aws-access-env.age".publicKeys = [pbovbel media];
  "secrets/server/web-credentials-env.age".publicKeys = [pbovbel media];
  "secrets/server/pia-env.age".publicKeys = [pbovbel media];
  "secrets/server/mam-id-env.age".publicKeys = [pbovbel media];
  "secrets/server/plex-token-env.age".publicKeys = [pbovbel media];
  "secrets/server/abiotic-env.age".publicKeys = [pbovbel media];
  "secrets/server/attic-server-env.age".publicKeys = [pbovbel media];
  "secrets/server/youtube-api-key.age".publicKeys = [pbovbel media];
}
