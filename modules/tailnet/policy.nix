{
  lib,
  nixosConfigurations,
  policy,
  containerGrants ? [],
}: let
  tags = lib.unique (lib.concatMap (host: host.config.tailnet.tags) (lib.attrValues nixosConfigurations));
  undeclaredTags = builtins.filter (tag: !(builtins.hasAttr tag (policy.tagOwners or {}))) tags;
  renderPort = port: let
    first = port.hostPort;
    last = first + port.count - 1;
    range =
      if port.count == 1
      then toString first
      else "${toString first}-${toString last}";
  in "${port.protocol}:${range}";
  expand = entry: let
    host = nixosConfigurations.${entry.host} or (throw "Unknown tailnet container-grant host: ${entry.host}");
    containers = host.config.podmanServer.containers;
    ports = lib.concatMap (name: let
      container = containers.${name} or (throw "Unknown or disabled tailnet container: ${entry.host}/${name}");
    in
      builtins.filter (port: builtins.elem "tailnet" port.exposure) container.ports)
    entry.containers;
    ip = lib.unique (map renderPort ports);
  in
    if entry.grant ? ip
    then throw "Container grant for ${entry.host} must not define ip; it is generated from container ports"
    else lib.optional (ip != []) (entry.grant // {inherit ip;});
in
  if undeclaredTags != []
  then throw "Host tailnet tags missing from policy.tagOwners: ${lib.concatStringsSep ", " undeclaredTags}"
  else policy // {grants = (policy.grants or []) ++ lib.concatMap expand containerGrants;}
