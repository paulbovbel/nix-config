{
  containerImages,
  lib,
  ...
}: {
  options.authentik = {
    enable = lib.mkEnableOption "Authentik identity provider and Caddy forward authentication";
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Public hostname for Authentik and its Google OAuth callback.";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = containerImages.authentik;
      defaultText = lib.literalExpression "containerImages.authentik";
      description = "Pinned Authentik image shared by server and worker.";
    };
    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Provisioned user emails granted Authentik superuser access.";
    };
    roles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["admin" "user"];
      description = "Provisioned Authentik groups available to applications and Caddy authorization.";
    };
    users = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          email = lib.mkOption {
            type = lib.types.str;
            description = "Email address identifying the user.";
          };
          roles = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Roles granted to the user.";
          };
        };
      });
      default = [];
      description = "Users and group memberships provisioned in Authentik; also the application login allowlist.";
    };
    applications = lib.mkOption {
      default = {};
      description = "Native OIDC applications provisioned in Authentik.";
      type = lib.types.attrsOf (lib.types.submodule ({
        name,
        config,
        ...
      }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "Display name for the application and provider.";
          };
          launchUrl = lib.mkOption {
            type = lib.types.str;
            description = "HTTPS application front-page URL opened from the Authentik dashboard.";
          };
          iconUrl = lib.mkOption {
            type = lib.types.str;
            default = (import ../caddy/icons.nix {inherit lib;}) name;
            description = "Application dashboard icon URL.";
          };
          clientId = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "OIDC client identifier.";
          };
          clientType = lib.mkOption {
            type = lib.types.enum ["public" "confidential"];
            default = "confidential";
            description = "OIDC client type.";
          };
          generateClientSecret = lib.mkOption {
            type = lib.types.bool;
            default = config.clientType == "confidential";
            description = "Generate and persist a client secret for confidential clients.";
          };
          grantTypes = lib.mkOption {
            type = lib.types.listOf (lib.types.enum [
              "authorization_code"
              "implicit"
              "hybrid"
              "refresh_token"
              "client_credentials"
              "password"
              "urn:ietf:params:oauth:grant-type:device_code"
              "urn:ietf:params:oauth:grant-type:token-exchange"
            ]);
            default = ["authorization_code" "refresh_token"];
            description = "OAuth grant types accepted by the provider.";
          };
          redirectUris = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Exact OIDC redirect URIs.";
          };
          scopes = lib.mkOption {
            type = lib.types.listOf (lib.types.enum ["openid" "email" "profile" "offline_access" "groups"]);
            default = ["openid" "email" "profile"];
            description = "OIDC scopes exposed to the application.";
          };
          includeClaimsInIdToken = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to include scope claims in the ID token.";
          };
        };
      }));
    };
    blueprint = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Generated Authentik blueprint, with secrets resolved from the worker environment.";
    };
  };
}
