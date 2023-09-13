{ config
, lib
, pkgs
, ... }:

let
  cfg = config.server;
in {
  services.keycloak = {
    enable = true;
    database.passwordFile = "/secrets/keycloak_db_pass";
    settings = {
      hostname = "keycloak.${cfg.domainName}";
      http-enabled = true;
      http-host = "127.0.0.1";
      http-port = 5739;
      https-port = 5740;
      proxy = "edge";
    };
  };
  services.nginx.virtualHosts."keycloak.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://${lib.quoteListenAddr config.services.keycloak.settings.http-host}:${toString config.services.keycloak.settings.http-port}/";
  };

  services.gitea.settings.openid = {
    ENABLE_OPENID_SIGNIN = true;
    ENABLE_OPENID_SIGNUP = true;
  };

  services.nextcloud.extraOptions.allow_local_remote_servers = true;

  # a crude way to make some python packages available for synapse
  services.matrix-synapse.plugins = with pkgs.python3.pkgs; [ authlib ];
  services.matrix-synapse.settings.password_config.enabled = false;

  # See also https://meta.akkoma.dev/t/390
  # https://<pleroma>/oauth/keycloak?scope=openid+profile
  # ...but this doesnt even work, the callback fails with %OAuth2.Error{reason: :invalid_request}
  # oh well
  /*
  services.akkoma.config = {
    ":ueberauth" = let
      url = "https://keycloak.${cfg.domainName}";
      realm = cfg.keycloakRealm;
      format = pkgs.formats.elixirConf { };
    in {
      "Ueberauth.Strategy.Keycloak.OAuth" = {
        client_id = "akkoma";
        client_secret = format.lib.mkRaw ''System.get_env("KEYCLOAK_CLIENT_SECRET")'';
        site = url;
        authorize_url = "${url}/realms/${realm}/protocol/openid-connect/auth";
        token_url = "${url}/realms/${realm}/protocol/openid-connect/token";
        userinfo_url = "${url}/realms/${realm}/protocol/openid-connect/userinfo";
        token_method = format.lib.mkRaw ":post";
      };
      Ueberauth.providers = {
        keycloak = format.lib.mkTuple [ (format.lib.mkRaw "Ueberauth.Strategy.Keycloak") {
          default_scope = "openid profile";
          uid_field = format.lib.mkRaw ":preferred_username";
        } ];
      };
    };
  };
  services.akkoma.package = pkgs.akkoma.overrideAttrs (old: {
    buildInputs = let
      inherit (pkgs.beamPackages) fetchHex buildMix;
      oldDeps = old.buildInputs or [];
      tesla = builtins.head (builtins.filter (x: x.packageName == "tesla") oldDeps);
      ueberauth = builtins.head (builtins.filter (x: x.packageName == "ueberauth") oldDeps);
    in oldDeps ++ builtins.attrValues rec {
      # TODO: nothing, this is just a reminder to relock these every once in a while
      oauth2 = buildMix rec {
        name = "oauth2";
        version = "2.1.0";
       
        src = fetchHex {
          pkg = name;
          inherit version;
          sha256 = "0h9bps7gq7bac5gc3q0cgpsj46qnchpqbv5hzsnd2z9hnf2pzh4a";
        };
       
        beamDeps = [ tesla ];
      };
      ueberauth_keycloak_strategy = buildMix rec {
        name = "ueberauth_keycloak_strategy";
        version = "0.4.0";
       
        src = fetchHex {
          pkg = name;
          inherit version;
          sha256 = "06r10w0azlpypjgggar1lf7h2yazn2dpyicy97zxkjyxgf9jfc60";
        };
       
        beamDeps = [ oauth2 ueberauth ];
      };
    };
    OAUTH_CONSUMER_STRATEGIES = "keycloak:ueberauth_keycloak_strategy";
  });
  systemd.services.akkoma = {
    environment.OAUTH_CONSUMER_STRATEGIES = "keycloak:ueberauth_keycloak_strategy";
    serviceConfig.EnvironmentFile = "/secrets/akkoma/envrc";
  };*/
}
