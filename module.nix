{ otp-notifications }:

{
  config,
  lib,
  ...
}:
let
  cfg = config.services.otp-notifications;

  inherit (lib)
    getExe
    mkEnableOption
    mkOption
    types
    mkIf
    ;
in
{
  options.services.otp-notifications = {
    enable = mkEnableOption "OTP Notification Bridge";

    package = mkOption {
      type = types.package;
      default = otp-notifications;
      description = "Package providing the otp-notifications executable.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host address for the OTP notification bridge to listen on.";
    };

    port = mkOption {
      type = types.port;
      default = 8429;
      description = "Port for the OTP notification bridge to listen on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured port in the firewall.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    systemd.user.services.otp-notifications = {
      description = "OTP Notification Bridge";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];

      environment = {
        OTP_NOTIFICATIONS_HOST = cfg.host;
        OTP_NOTIFICATIONS_PORT = toString cfg.port;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = getExe cfg.package;
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        RestrictSUIDSGID = true;
      };
    };
  };
}
