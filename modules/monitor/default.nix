{lib, ...}: {
  options.moduleDocumentation.monitor = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Monitoring";
      summary = "Grafana Cloud host metrics, Cockpit administration, and Smokeping latency monitoring.";
    };
  };

  imports = [
    ./alloy.nix
    ./cockpit.nix
    ./smokeping.nix
  ];
}
