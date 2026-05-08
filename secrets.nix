let
  pbovbel = "age1hverm742f05uucrlyt2ghq5fadpspcwg2cypsm2z9lqu4x6l4vlslxkpgz";
  whiteTowerHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0NPbKSI7gT3SfT7UqWIbdm7nlipqL40oCtHy8TYi2t root@nixos";
  laptopHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILMSepqhZu6KQ1Jk9Xk6T+2NsHaHkCI1i5WKGacHMjIo root@pbovbel-dell";
in
{
  "secrets/laptop/tailscale-oauth-authkey.age".publicKeys = [ pbovbel laptopHost whiteTowerHost ];
  "secrets/server/tailscale-oauth-authkey.age".publicKeys = [ pbovbel whiteTowerHost ];
  "secrets/shared/pbovbel-id_rsa.age".publicKeys = [ pbovbel ];
}
