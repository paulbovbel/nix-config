{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.authentik;
  integration = import ./lib.nix {inherit lib;};
  # JSON-style YAML with explicit Authentik tags; no credentials enter the store.
  tag = name: value: {
    __tag = name;
    inherit value;
  };
  key = tag "KeyOf";
  find = model: field: value: tag "Find" [model [field value]];
  flow = slug: find "authentik_flows.flow" "slug" slug;
  render = value:
    if lib.isAttrs value && value ? __tag
    then "!${value.__tag} ${render value.value}"
    else if lib.isAttrs value
    then "{${lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${builtins.toJSON k}: ${render v}") value)}}"
    else if lib.isList value
    then "[${lib.concatStringsSep ", " (map render value)}]"
    else builtins.toJSON value;
  entry = model: id: identifiers: attrs: {inherit model id identifiers attrs;};
  domains = integration.protectedDomains config.caddy.sites;
  providerId = domain: "proxy-${builtins.substring 0 12 (builtins.hashString "sha256" domain)}";
  allowed = builtins.toJSON (map (user: user.email) cfg.users);
  authorization = flow "default-provider-authorization-implicit-consent";
  invalidation = flow "default-provider-invalidation-flow";
  inherit (integration) clientSecretEnvironment;
  usesGroupsScope = lib.any (application: lib.elem "groups" application.scopes) (lib.attrValues cfg.applications);
  managedScope = scope: find "authentik_providers_oauth2.scopemapping" "managed" "goauthentik.io/providers/oauth2/scope-${scope}";
  applicationEntries = lib.concatMap (slug: let
    application = cfg.applications.${slug};
    providerId = "${slug}-provider";
    propertyMappings = map (scope:
      if scope == "groups"
      then key "groups-scope"
      else if scope == "email"
      then key "email-scope"
      else managedScope scope)
    application.scopes;
  in [
    (entry "authentik_providers_oauth2.oauth2provider" providerId {inherit (application) name;} ({
        client_id = application.clientId;
        client_type = application.clientType;
        grant_types = application.grantTypes;
        authorization_flow = authorization;
        invalidation_flow = invalidation;
        signing_key = find "authentik_crypto.certificatekeypair" "name" "authentik Self-signed Certificate";
        include_claims_in_id_token = application.includeClaimsInIdToken;
        property_mappings = propertyMappings;
        redirect_uris =
          map (url: {
            matching_mode = "strict";
            inherit url;
          })
          application.redirectUris;
      }
      // lib.optionalAttrs (application.clientType == "confidential" && application.generateClientSecret) {
        client_secret = tag "Env" (clientSecretEnvironment application);
      }))
    (entry "authentik_core.application" slug {inherit slug;} {
      inherit (application) name;
      meta_launch_url = application.launchUrl;
      meta_icon = application.iconUrl;
      meta_hide = false;
      provider = key providerId;
    })
    (entry "authentik_policies.policybinding" "${slug}-binding" {
        target = key slug;
        order = 0;
      } {
        policy = key "allowed-users";
      })
  ]) (lib.attrNames cfg.applications);
  dashboardEntries = lib.concatMap (siteName: let
    site = config.caddy.sites.${siteName};
    domain = lib.findFirst (domain: domain.tls == "public") (lib.head site.domains) site.domains;
    baseUrl = "https://${integration.domainAddress domain}";
  in
    lib.concatMap (endpointName: let
      endpoint = site.endpoints.${endpointName};
      launchUrl = "${baseUrl}${lib.removeSuffix "/" endpoint.path}/";
      id = "caddy-${siteName}-${endpointName}";
      hasNativeApplication = lib.any (application: application.launchUrl == launchUrl) (lib.attrValues cfg.applications);
    in
      lib.optionals (endpoint.dashboard.enable && !hasNativeApplication) (
        [
          (entry "authentik_core.application" id {slug = id;} {
            name = endpoint.dashboard.name;
            meta_launch_url = launchUrl;
            meta_icon = endpoint.dashboard.iconUrl;
            meta_hide = false;
            provider = null;
            policy_engine_mode = "all";
          })
          (entry "authentik_policies.policybinding" "${id}-allowlist" {
              target = key id;
              order = 0;
            } {
              policy = key "allowed-users";
            })
        ]
        ++ lib.optional (endpoint.auth == "oauth") (entry "authentik_policies.policybinding" "${id}-role" {
            target = key id;
            order = 1;
          } {
            group = key "group-${endpoint.role}";
          })
      )) (lib.attrNames site.endpoints))
  (lib.filter (siteName: config.caddy.sites.${siteName}.domains != []) (lib.attrNames config.caddy.sites));
  entries =
    map (name: {
      model = "authentik_blueprints.metaapplyblueprint";
      attrs = {
        identifiers = {inherit name;};
        required = true;
      };
    }) [
      "System - OAuth2 Provider - Scopes"
      "System - Proxy Provider - Scopes"
      "Default - Authentication flow"
      "Default - Source authentication flow"
      "Default - Provider authorization flow (implicit consent)"
      "Default - Provider invalidation flow"
    ]
    ++ map (role: entry "authentik_core.group" "group-${role}" {name = role;} {})
    cfg.roles
    ++ [
      (entry "authentik_core.group" "authentik-admins" {name = "nix-config Authentik Admins";} {
        is_superuser = true;
      })
    ]
    ++ map (user:
      entry "authentik_core.user" "user-${user.email}" {username = user.email;} {
        inherit (user) email;
        name = user.email;
        groups =
          map (role: key "group-${role}") user.roles
          ++ lib.optional (lib.elem "admin" user.roles) (key "authentik-admins");
        is_active = true;
      })
    cfg.users
    ++ [
      (entry "authentik_sources_oauth.oauthsource" "google" {slug = "google";} {
        name = "Google";
        provider_type = "google";
        consumer_key = tag "Env" "GOOGLE_OAUTH2_CLIENT_ID";
        consumer_secret = tag "Env" "GOOGLE_OAUTH2_CLIENT_SECRET";
        authentication_flow = flow "default-source-authentication";
        enrollment_flow = null;
        user_matching_mode = "email_link";
      })
      (entry "authentik_stages_identification.identificationstage" "login" {name = "default-authentication-identification";} {
        user_fields = [];
        sources = [(key "google")];
      })
      (entry "authentik_policies_expression.expressionpolicy" "allowed-users" {name = "nix-config-allowed-users";} {
        expression = "return request.user.is_active and request.user.email in ${allowed}";
      })
      (entry "authentik_policies_expression.expressionpolicy" "allowed-source-users" {name = "nix-config-allowed-source-users";} {
        expression = ''
          email = request.context.get("oauth_userinfo", {}).get("email", "").lower()
          return email in ${allowed}
        '';
      })
      (entry "authentik_policies.policybinding" "google-allowlist" {
          target = key "google";
          order = 0;
        } {
          policy = key "allowed-source-users";
        })
    ]
    ++ lib.concatMap (domain: let
      id = providerId domain;
    in [
      (entry "authentik_providers_proxy.proxyprovider" id {name = "Caddy ${domain}";} {
        mode = "forward_single";
        external_host = "https://${domain}";
        authorization_flow = authorization;
        invalidation_flow = invalidation;
        intercept_header_auth = false;
      })
      (entry "authentik_core.application" "app-${id}" {slug = id;} {
        name = "Caddy ${domain}";
        meta_launch_url = "https://${domain}/";
        meta_hide = true;
        provider = key id;
      })
      (entry "authentik_policies.policybinding" "binding-${id}" {
          target = key "app-${id}";
          order = 0;
        } {
          policy = key "allowed-users";
        })
    ])
    domains
    ++ [
      (entry "authentik_outposts.outpost" "outpost" {name = "authentik Embedded Outpost";} {
        type = "proxy";
        providers = map (domain: key (providerId domain)) domains;
        config = {authentik_host = "https://${cfg.domain}${cfg.path}";};
      })
    ]
    ++ lib.optional usesGroupsScope (entry "authentik_providers_oauth2.scopemapping" "groups-scope" {name = "nix-config groups";} {
      scope_name = "groups";
      expression = ''return {"groups": list(request.user.groups.values_list("name", flat=True))}'';
    })
    ++ [
      (entry "authentik_providers_oauth2.scopemapping" "email-scope" {name = "nix-config email";} {
        scope_name = "email";
        expression = ''return {"email": request.user.email, "email_verified": True}'';
      })
    ]
    ++ applicationEntries
    ++ dashboardEntries;
in {
  config = lib.mkIf cfg.enable {
    authentik.blueprint = pkgs.writeText "authentik-blueprint.yaml" (render {
      version = 1;
      metadata.name = "nix-config identity and applications";
      inherit entries;
    });
  };
}
