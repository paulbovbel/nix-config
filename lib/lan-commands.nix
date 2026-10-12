let
  lanInterfaceCommand = "ip -o -4 route show to default | { read -r _ _ _ _ iface _; printf '%s\\n' \"$iface\"; }";
  lanAddressCommand = ''iface=$(${lanInterfaceCommand}); ip -o -4 addr show dev "$iface" scope global | { read -r _ _ _ cidr _; printf '%s\n' "''${cidr%%/*}"; }'';
  lanNetworkCommand = ''iface=$(${lanInterfaceCommand}); ip -o -4 route show dev "$iface" proto kernel scope link | { read -r network _; printf '%s\n' "$network"; }'';
in {
  interface = lanInterfaceCommand;
  address = lanAddressCommand;
  network = lanNetworkCommand;
}
