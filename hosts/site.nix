{
  networking.domain = "bovbel.com";
  tailnet = {
    domain = "axolotl-vibe.ts.net";
    containerGrants = [
      {
        host = "media";
        containers = ["minecraft" "valheim"];
        grant = {
          src = ["group:admins" "tag:adult-device" "tag:kids-device" "autogroup:shared"];
          dst = ["tag:media"];
        };
      }
    ];
    policy = {
      groups."group:admins" = ["paul@bovbel.com" "rebecca@bovbel.com"];
      # Self-ownership permits the shared OAuth credential to enroll tag subsets.
      tagOwners = {
        "tag:adult-device" = ["group:admins" "tag:adult-device"];
        "tag:kids-device" = ["group:admins" "tag:kids-device"];
        "tag:media" = ["group:admins" "tag:media"];
        "tag:exit-node" = ["group:admins" "tag:exit-node"];
        "tag:backup" = ["group:admins" "tag:backup"];
        "tag:unifi" = ["group:admins" "tag:unifi"];
        "tag:jetkvm" = ["group:admins" "tag:jetkvm"];
      };
      autoApprovers.exitNode = ["tag:exit-node"];
      nodeAttrs = [
        {
          target = ["tag:kids-device"];
          attr = ["nextdns:6ad771"];
        }
      ];
      grants = [
        # Tailnet DNS.
        {
          src = ["autogroup:member" "autogroup:tagged"];
          dst = ["tag:media"];
          ip = ["tcp:53" "udp:53"];
        }
        # Shared media web endpoints.
        {
          src = ["autogroup:member" "autogroup:tagged" "autogroup:shared"];
          dst = ["tag:media"];
          ip = ["tcp:80" "tcp:443" "tcp:8443"];
        }
        # Adult administration, including the offsite subnet.
        {
          src = ["group:admins" "tag:adult-device"];
          dst = ["autogroup:tagged" "autogroup:member" "192.168.1.0/24"];
          ip = ["*"];
        }
        # Exit-node internet access.
        {
          src = ["group:admins" "tag:adult-device" "tag:kids-device"];
          dst = ["autogroup:internet"];
          ip = ["*"];
        }
        # Offsite backups.
        {
          src = ["tag:media"];
          dst = ["tag:backup"];
          ip = ["tcp:22"];
        }
      ];
      tests = [
        {
          src = "tag:kids-device";
          proto = "tcp";
          accept = ["tag:media:25565"];
        }
        {
          src = "tag:kids-device";
          proto = "udp";
          accept = ["tag:media:2456" "tag:media:2457"];
        }
        {
          src = "paul@bovbel.com";
          accept = ["tag:media:22" "tag:adult-device:22" "tag:unifi:22"];
        }
        {
          src = "rebecca@bovbel.com";
          accept = ["tag:media:22" "tag:media:443" "tag:adult-device:22" "tag:jetkvm:443" "192.168.1.1:443"];
        }
        {
          src = "tag:adult-device";
          accept = ["tag:media:22" "tag:backup:22" "tag:unifi:22" "tag:jetkvm:443" "tag:kids-device:22" "192.168.1.1:443"];
        }
        {
          src = "tag:media";
          accept = ["tag:backup:22"];
          deny = ["tag:backup:443" "tag:unifi:22" "tag:jetkvm:443" "tag:adult-device:22" "tag:kids-device:22"];
        }
        {
          src = "tag:kids-device";
          accept = ["tag:media:80" "tag:media:443" "tag:media:8443"];
          deny = ["tag:media:22" "tag:backup:22" "tag:adult-device:22" "tag:unifi:22" "tag:jetkvm:443" "192.168.1.1:443"];
        }
        {
          src = "tag:backup";
          proto = "tcp";
          accept = ["tag:media:53"];
          deny = ["tag:media:22"];
        }
        {
          src = "tag:backup";
          proto = "udp";
          accept = ["tag:media:53"];
        }
      ];
    };
  };
}
