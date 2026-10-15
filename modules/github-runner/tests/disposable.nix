{pkgs}: let
  inherit (pkgs) lib;
  listener = lib.makeOverridable (_:
    pkgs.runCommand "fake-github-runner" {} ''
      mkdir -p "$out/bin"
      cp ${./fake-listener.sh} "$out/bin/Runner.Listener"
      chmod +x "$out/bin/Runner.Listener"
      patchShebangs "$out/bin/Runner.Listener"
    '') {};
in
  pkgs.testers.runNixOSTest {
    name = "github-runner-disposable";
    nodes.machine = {
      imports = [
        ../../documentation/options.nix
        ../default.nix
      ];
      # Substitute only secret delivery; exercise the real container and runner units.
      options.age.secrets = lib.mkOption {type = lib.types.attrsOf lib.types.attrs;};
      config = {
        githubRunner = {
          enable = true;
          url = "https://github.com/example/test";
          extraLabels = ["test"];
        };
        # Test credentials are deliberately inert; no GitHub access is needed.
        age.secrets = {
          github-runner-token.path = "/etc/runner-token";
          github-runner-ssh-key.path = "/etc/runner-ssh-key";
        };
        environment.etc = {
          runner-token.text = "ghp_validation-only";
          runner-ssh-key.text = "unused-test-key";
        };
        containers.github-runner.config.services.github-runners.nix-config.package = lib.mkForce listener;
        virtualisation.memorySize = 2048;
        system.stateVersion = "26.05";
      };
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("container@github-runner.service")
      runner = "nixos-container run github-runner -- "
      work = "/var/lib/github-runner/work"
      # Avoid nsenter/su probes during boot or shutdown: they can get stuck in
      # the dying guest and delay namespace teardown. Resolve the current
      # leader on every attempt, including across ephemeral root replacements.
      guest_root = (
          "leader=$(machinectl show github-runner --property=Leader --value) && "
          'test "$leader" -gt 1 && root="/proc/$leader/root" && '
      )
      listening = 'test -e "$root' + work + '/listening"'
      machine.wait_until_succeeds(guest_root + listening)

      for exit_code in (0, 2):
          with subtest(f"fresh container after listener exit {exit_code}"):
              identity = machine.succeed(runner + "cat /etc/machine-id").strip()
              machine.succeed(runner + "mkdir -p " + work + "/.config/gcx")
              machine.succeed(runner + "touch " + work + "/.config/gcx/config.yaml /var/lib/previous-job /tmp/previous-job")
              machine.succeed(guest_root + f'echo {exit_code} > "$root{work}/finish"')
              machine.wait_until_succeeds(
                  guest_root + listening + " && "
                  + 'current_id=$(cat "$root/etc/machine-id") && '
                  + f'test -n "$current_id" && test "$current_id" != "{identity}"',
                  timeout=180,
              )
              machine.succeed(runner + "test ! -e " + work + "/.config/gcx/config.yaml")
              machine.succeed(runner + "test ! -e /var/lib/previous-job")
              machine.succeed(runner + "test ! -e /tmp/previous-job")
              machine.succeed(runner + "test ! -e " + work + "/finish")

      with subtest("explicit host stop stays stopped"):
          machine.succeed("systemctl stop container@github-runner.service")
          machine.sleep(12)
          machine.fail("systemctl is-active --quiet container@github-runner.service")
    '';
  }
