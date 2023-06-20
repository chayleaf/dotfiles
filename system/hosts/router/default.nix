{ config
, ... }:

let
  rootUuid = "44444444-4444-4444-8888-888888888888";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";
  cfg = config.router-settings;
  hapdConfig = {
    inherit (cfg) country_code wpa_passphrase;
    he_su_beamformer = true;
    he_su_beamformee = true;
    he_mu_beamformer = true;
    he_bss_color = 128;
    he_spr_sr_control = 3;
    he_default_pe_duration = 4;
    he_rts_threshold = 1023;
    he_mu_edca_qos_info_param_count = 0;
    he_mu_edca_qos_info_q_ack = 0;
    he_mu_edca_qos_info_queue_request = 0;
    he_mu_edca_qos_info_txop_request = 0;
    he_mu_edca_ac_be_aifsn = 8;
    he_mu_edca_ac_be_aci = 0;
    he_mu_edca_ac_be_ecwmin = 9;
    he_mu_edca_ac_be_ecwmax = 10;
    he_mu_edca_ac_be_timer = 255;
    he_mu_edca_ac_bk_aifsn = 15;
    he_mu_edca_ac_bk_aci = 1;
    he_mu_edca_ac_bk_ecwmin = 9;
    he_mu_edca_ac_bk_ecwmax = 10;
    he_mu_edca_ac_bk_timer = 255;
    he_mu_edca_ac_vi_ecwmin = 5;
    he_mu_edca_ac_vi_ecwmax = 7;
    he_mu_edca_ac_vi_aifsn = 5;
    he_mu_edca_ac_vi_aci = 2;
    he_mu_edca_ac_vi_timer = 255;
    he_mu_edca_ac_vo_aifsn = 5;
    he_mu_edca_ac_vo_aci = 3;
    he_mu_edca_ac_vo_ecwmin = 5;
    he_mu_edca_ac_vo_ecwmax = 7;
    he_mu_edca_ac_vo_timer = 255;
    preamble = true;
    vht_oper_chwidth = 1; # 80mhz ch width
    vht_oper_centr_freq_seg0_idx = 42;
    vht_capab = "[RXLDPC][SHORT-GI-80][SHORT-GI-160][TX-STBC-2BY1][SU-BEAMFORMER][SU-BEAMFORMEE][MU-BEAMFORMER][MU-BEAMFORMEE][RX-ANTENNA-PATTERN][TX-ANTENNA-PATTERN][RX-STBC-1][SOUNDING-DIMENSION-4][BF-ANTENNA-4][VHT160][MAX-MPDU-11454][MAX-A-MPDU-LEN-EXP7]";
    country3 = "0x49"; # indoor
  };
in {
  imports = [ ./options.nix ];
  system.stateVersion = "22.11";
  fileSystems = {
    # mount root on tmpfs
    "/" =     { device = "none"; fsType = "tmpfs"; neededForBoot = true;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { device = rootPart; fsType = "btrfs"; neededForBoot = true;
                options = [ "compress=zstd:15" "subvol=@" ]; };
    "/boot" =
              { device = rootPart; fsType = "btrfs"; neededForBoot = true;
                options = [ "subvol=@boot" ]; };
    "/nix" =
              { device = rootPart; fsType = "btrfs"; neededForBoot = true;
                options = [ "compress=zstd:15" "subvol=@nix" ]; };
  };
  services.openssh.enable = true;
  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      { directory = /home/${config.common.mainUsername}; user = config.common.mainUsername; group = "users"; mode = "0700"; }
      { directory = /root; mode = "0700"; }
      { directory = /var/db/dhcpcd; user = "root"; group = "root"; mode = "0755"; }
      { directory = /var/lib/kea; user = "root"; group = "root"; mode = "0755"; }
    ];
  };
  router.enable = true;
  router.interfaces.wlan0 = {
    bridge = "br0";
    hostapd.enable = true;
    hostapd.settings = {
      inherit (cfg) ssid;
      hw_mode = "g";
      supported_rates = [ 60 90 120 180 240 360 480 540 ];
      basic_rates = [ 60 120 240 ];
      ht_capab = "[LDPC][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
    } // hapdConfig;
  };
  router.interfaces.wlan1 = {
    bridge = "br0";
    hostapd.enable = true;
    hostapd.settings = {
      ssid = "${cfg.ssid} 5G";
      ieee80211h = true;
      hw_mode = "a";
      tx_queue_data2_burst = 2;
      ht_capab = "[HT40+][LDPC][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
    } // hapdConfig;
  };
  router.interfaces.lan0 = {
    matchUdevAttrs.address = "11:11:11:11:11:11";
    macAddress = "11:22:33:44:55:66";
  };
  router.interfaces.wan0 = {
    matchUdevAttrs.address = "22:11:11:11:11:11";
    macAddress = "22:22:33:44:55:66";
    dhcpcd.enable = true;
  };
  router.interfaces.br0 = {
    ipv4.addresses = [ {
      address = cfg.network;
      prefixLength = 24;
      dns = [ cfg.network ];
    } ];
    ipv6.addresses = [ {
      address = "0:0:0:5678::";
      prefixLength = 64;
      dns = [ "fd00::1" ];
      radvdSettings = {
        Base6to4Interface = "br0";
      };
    } ];
    ipv4.kea.enable = true;
    ipv6.kea.enable = false;
    ipv6.radvd.enable = true;
    ipv6.corerad.enable = false;
  };
}
