# linkding (self-hosted bookmark manager) as a per-user launchd service on
# macOS. Mirrors the NixOS `services.linkding` module where it makes sense:
# same environment, same uwsgi setup, a background-task worker and a
# `linkding-manage` command. SQLite only.
#
# On NixOS use `services.linkding` instead.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.linkding;
  pkg = cfg.package;
  python = pkg.passthru.python;
  inherit (pkg.passthru) uwsgiWithPython;

  pythonPath = "${python.pkgs.makePythonPath pkg.passthru.dependencies}:${lib.getBin pkg}/${python.sitePackages}";

  # The environment passed to every linkding process
  environment = {
    DJANGO_SETTINGS_MODULE = "bookmarks.settings.prod";
    _NIXOS_LINKDING_DATA_DIR = cfg.dataDir;
    LD_SERVER_PORT = toString cfg.port;
  }
  // cfg.settings;

  envFile = pkgs.writeText "linkding-environment" (lib.generators.toKeyValue { } environment);

  # Start of every script below: stop on the first error, load the
  # environment (and the optional secrets file), then move into the data
  # directory.
  #
  # The secrets file may not exist yet when the agents start: at login
  # right after a boot they can be ahead of whatever puts it there (agenix
  # decrypts a minute or so into the boot). Without the wait the first
  # start fails and launchd restarts it, which works but leaves the agent
  # showing a failed exit for as long as it runs.
  setup = ''
    set -eu
    set -a
    . ${envFile}
    ${lib.optionalString (cfg.environmentFile != null) ''
      for _ in $(seq 120); do
        [ -r ${lib.escapeShellArg cfg.environmentFile} ] && break
        sleep 1
      done
      . ${lib.escapeShellArg cfg.environmentFile}
    ''}
    set +a
    export PYTHONPATH=${lib.escapeShellArg pythonPath}
    mkdir -p ${lib.escapeShellArg cfg.dataDir}/{favicons,previews,assets}
    cd ${lib.escapeShellArg cfg.dataDir}
  '';

  # Adapted from the upstream uwsgi.ini, like the NixOS module. The static-map
  # entries serve the pre-generated static files from the Nix store plus the
  # mutable favicons and previews from the data directory.
  uwsgiIni = pkgs.writeText "linkding-uwsgi.ini" ''
    [uwsgi]
    plugins-dir = ${uwsgiWithPython}/lib/uwsgi
    plugin = python3
    module = bookmarks.wsgi:application
    env = DJANGO_SETTINGS_MODULE=bookmarks.settings.prod
    processes = ${toString cfg.processes}
    threads = ${toString cfg.threads}
    buffer-size = 8192
    die-on-term = true
    mime-file = ${pkgs.mailcap}/etc/mime.types
    http = ${cfg.address}:${toString cfg.port}
    static-map = /static=${pkg}/${python.sitePackages}/bookmarks/static
    static-map = /static=${cfg.dataDir}/favicons
    static-map = /static=${cfg.dataDir}/previews
    static-map = /robots.txt=${pkg}/${python.sitePackages}/bookmarks/static/robots.txt

    if-env = LD_REQUEST_TIMEOUT
    http-timeout = %(_)
    socket-timeout = %(_)
    harakiri = %(_)
    endif =

    if-env = LD_REQUEST_MAX_CONTENT_LENGTH
    limit-post = %(_)
    endif =

    if-env = LD_LOG_X_FORWARDED_FOR
    log-x-forwarded-for = %(_)
    endif =

    if-env = LD_DISABLE_REQUEST_LOGS=true
    disable-logging = true
    log-4xx = true
    log-5xx = true
    endif =
  '';

  # Web server: run migrations / first-time initialisation, then serve
  server = pkgs.writeShellScript "linkding-server" ''
    ${setup}
    ${lib.getExe' pkg "linkding-bootstrap"}
    exec ${uwsgiWithPython}/bin/uwsgi --ini ${uwsgiIni}
  '';

  # Background task processor (Huey): favicons, previews, snapshots
  backgroundTasks = pkgs.writeShellScript "linkding-background-tasks" ''
    ${setup}
    exec ${lib.getExe' pkg "linkding"} run_huey -f
  '';

  # Django management commands against this instance, e.g.
  # `linkding-manage createsuperuser`
  manage = pkgs.writeShellScriptBin "linkding-manage" ''
    ${setup}
    exec ${lib.getExe' pkg "linkding"} "$@"
  '';

  logDir = "${config.home.homeDirectory}/Library/Logs";
  backgroundTasksEnabled = (cfg.settings.LD_DISABLE_BACKGROUND_TASKS or "False") != "True";
in
{
  options.custom.linkding = {
    enable = lib.mkEnableOption "linkding, a self-hosted bookmark manager, as a launchd user agent";

    package = lib.mkPackageOption pkgs "linkding" { };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/linkding";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/linkding"'';
      description = "Directory for the SQLite database, favicons, previews and assets.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to listen on. The default is reachable from this machine only.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Port to listen on.";
    };

    processes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Number of uwsgi worker processes.";
    };

    threads = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Number of threads per uwsgi worker process.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        LD_DISABLE_BACKGROUND_TASKS = "True";
        LD_DISABLE_URL_VALIDATION = "True";
      };
      description = ''
        Extra `LD_*` environment variables, see
        <https://linkding.link/options/>. These end up in the world-readable
        Nix store; put secrets in {option}`environmentFile`.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/linkding.env";
      description = ''
        File with extra `NAME=value` lines, loaded at startup. Use it for
        secrets such as `LD_SUPERUSER_PASSWORD`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isDarwin;
        message = "custom.linkding runs linkding through launchd and is for macOS only; on NixOS use services.linkding.";
      }
    ];

    home.packages = [ manage ];

    launchd.agents.linkding = {
      enable = true;
      config = {
        ProgramArguments = [ "${server}" ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${logDir}/linkding.log";
        StandardErrorPath = "${logDir}/linkding.error.log";
      };
    };

    # Can be disabled with settings.LD_DISABLE_BACKGROUND_TASKS = "True"
    launchd.agents.linkding-background-tasks = lib.mkIf backgroundTasksEnabled {
      enable = true;
      config = {
        ProgramArguments = [ "${backgroundTasks}" ];
        RunAtLoad = true;
        KeepAlive = true;
        # On first start the server may still be creating the database;
        # launchd restarts this until it comes up, at most every 10 seconds
        ThrottleInterval = 10;
        StandardOutPath = "${logDir}/linkding-background-tasks.log";
        StandardErrorPath = "${logDir}/linkding-background-tasks.error.log";
      };
    };
  };
}
