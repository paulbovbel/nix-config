dockerfile: let
  lines =
    builtins.filter
    (line: builtins.isString line && builtins.match "[[:space:]]*(#.*)?" line == null)
    (builtins.split "\n" (builtins.readFile dockerfile));
  entries = map (line: let
    fields = builtins.match "FROM[[:space:]]+([^[:space:]]+:[^[:space:]@]+@sha256:[0-9a-f]{64})[[:space:]]+AS[[:space:]]+([a-z0-9][a-z0-9-]*)[[:space:]]*" line;
  in
    if fields == null
    then throw "Invalid image catalog entry; expected FROM registry/image:tag@sha256:<digest> AS alias: ${line}"
    else {
      name = builtins.elemAt fields 1;
      value = builtins.head fields;
    })
  lines;
  images = builtins.listToAttrs entries;
in
  if entries == [] || builtins.length entries != builtins.length (builtins.attrNames images)
  then throw "The image catalog must be non-empty and have unique aliases."
  else images
