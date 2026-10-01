{lib}: name: let
  baseUrl = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/638a84c865f3cdbab3a4b715c016f0543b1e530e";
  catalogue = lib.importJSON (builtins.fetchurl {
    url = "https://api.github.com/repos/homarr-labs/dashboard-icons/git/trees/638a84c865f3cdbab3a4b715c016f0543b1e530e?recursive=1";
    sha256 = "1m9j2hayrknbbyl8bi8mjb12lqhcwxllkgnhb2706ninlsp98njh";
  });
  paths = map (entry: entry.path) catalogue.tree;
  hasIcon = icon: lib.elem "svg/${icon}.svg" paths || lib.elem "png/${icon}.png" paths;
  # Light artwork remains visible on the dashboard's dark background.
  icon = lib.findFirst hasIcon "folder" ["${name}-light" name];
  format =
    if lib.elem "svg/${icon}.svg" paths
    then "svg"
    else "png";
in "${baseUrl}/${format}/${icon}.${format}"
