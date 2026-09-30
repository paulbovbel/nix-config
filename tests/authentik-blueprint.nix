{
  blueprint,
  image,
  pkgs,
}: let
  authentikImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/goauthentik/server";
    imageDigest = "sha256:ab9b4e8cc4ab3f8d1198d2db6aeea66bafea1963b3f2843589e0d163f97d9849";
    sha256 = "sha256-fA+RYsJ8eYS/bz5Rj91qcR+VIkGBealhlhbMxHCkb2A=";
    finalImageName = "ghcr.io/goauthentik/server";
    finalImageTag = "2026.8.3";
  };
  postgresImage = pkgs.dockerTools.pullImage {
    imageName = "docker.io/library/postgres";
    imageDigest = "sha256:721873c34ceb9f8d8fc265984940dc982404c105f19ad51be9fdc5970a6080ea";
    sha256 = "sha256-fjgoa8cITe7zk0N1zx7Ze1FlaEWGxqOyi8P69sE3Z2A=";
    finalImageName = "docker.io/library/postgres";
    finalImageTag = "16-alpine";
  };
in
  pkgs.testers.runNixOSTest {
    name = "authentik-blueprint";

    nodes.machine = {pkgs, ...}: {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
        oci-containers = {
          backend = "podman";
          containers = {
            authentik-db = {
              image = "docker.io/library/postgres:16-alpine";
              environment = {
                POSTGRES_DB = "authentik";
                POSTGRES_USER = "authentik";
                POSTGRES_PASSWORD = "authentik-test";
              };
            };
            authentik-worker = {
              inherit image;
              cmd = ["worker"];
              dependsOn = ["authentik-db"];
              environment = {
                AUTHENTIK_POSTGRESQL__HOST = "authentik-db";
                AUTHENTIK_POSTGRESQL__NAME = "authentik";
                AUTHENTIK_POSTGRESQL__USER = "authentik";
                AUTHENTIK_POSTGRESQL__PASSWORD = "authentik-test";
                AUTHENTIK_SECRET_KEY = "authentik-blueprint-validation-secret";
                AUTHENTIK_BOOTSTRAP_PASSWORD = "authentik-test";
                GOOGLE_OAUTH2_CLIENT_ID = "google-test";
                GOOGLE_OAUTH2_CLIENT_SECRET = "google-test";
                AUTHENTIK_AUDIOBOOKSHELF_CLIENT_SECRET = "audiobookshelf-test";
              };
              volumes = ["${blueprint}:/blueprints/custom/nix-config.yaml:ro"];
            };
          };
        };
      };

      environment.systemPackages = [pkgs.podman];
      systemd.services = {
        podman-authentik-db.preStart = "${pkgs.podman}/bin/podman load --input ${postgresImage}";
        podman-authentik-worker.preStart = "${pkgs.podman}/bin/podman load --input ${authentikImage}";
      };
      system.stateVersion = "26.05";
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("podman-authentik-db.service")
      machine.wait_for_unit("podman-authentik-worker.service")
      machine.wait_until_succeeds(
          "podman exec authentik-worker ak shell -c "
          "'from authentik.blueprints.models import BlueprintInstance; "
          "b = BlueprintInstance.objects.get(name=\"nix-config identity and applications\"); "
          "assert b.status == \"successful\", b.status'",
          timeout=300,
      )
    '';
  }
