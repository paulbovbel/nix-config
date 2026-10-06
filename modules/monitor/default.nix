{
  config.moduleDocumentation.monitor = {
    title = "Monitoring";
    category = "Infrastructure";
    summary = "Grafana Cloud host metrics, Cockpit administration, and Smokeping latency monitoring.";
  };

  imports = [
    ./alloy.nix
    ./cockpit.nix
    ./smokeping.nix
  ];
}
