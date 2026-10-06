_: let
  lanInterfaceCommand = "ip -o -4 route show to default | { read -r _ _ _ _ iface _; printf '%s\\n' \"$iface\"; }";
  lanAddressCommand = ''iface=$(${lanInterfaceCommand}); ip -o -4 addr show dev "$iface" scope global | { read -r _ _ _ cidr _; printf '%s\n' "''${cidr%%/*}"; }'';
  lanNetworkCommand = ''iface=$(${lanInterfaceCommand}); ip -o -4 route show dev "$iface" proto kernel scope link | { read -r network _; printf '%s\n' "$network"; }'';
in {
  imports = [
    ./documentation/options.nix
    ./accounts
    ./auto-upgrade
    ./backup
    ./ddns
    ./attic-cache
    ./upnp
    ./caddy
    ./authentik
    ./storage
    ./monitor
    ./podman-server
    ./root-fs
    ./site
    ./nvidia
    ./netboot
    ./llama-cpp
    ./media-server
    ./game-server
    ./game-streaming
    ./github-runner
  ];

  config._module.args = {
    inherit lanAddressCommand lanInterfaceCommand lanNetworkCommand;
  };
}
