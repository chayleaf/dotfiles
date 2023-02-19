{ config, pkgs, lib, ... }:
{
  # TODO: theme (it's using fish variables...)
  programs.fish = {
    enable = true;
    # not sure this is needed, but just in case
    shellInit = ''
      source /etc/fish/config.fish
    '';
    interactiveShellInit = ''
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source

      # for posix compatibility
      set -gx SHELL zsh

      set -gx fish_color_autosuggestion 777 brblack
      set -gx fish_color_command green
      set -gx fish_color_operator white
      set -gx fish_color_param white

      set -gx fish_key_bindings fish_vi_key_bindings
      set -gx fish_cursor_insert line
      set -gx fish_cursor_replace underscore

      # set -gx doesn't work in this case for whatever reason
      set -Ux _tide_left_items pwd git vi_mode
      set -Ux _tide_prompt_69105 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b34m\x1b\x5b44m\x20\x40PWD\x40\x20\x1b\x5b34m\x1b\x5b40m\ue0b0\x1b\x5b32m\x1b\x5b40m\x20\u276f\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b0 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b2\x1b\x5b32m\x1b\x5b40m\x20\uf00c\x20\x1b\x5b33m\x1b\x5b40m\ue0b2\x1b\x5b30m\x1b\x5b43m\x2021m\x2023s\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b33m
      set -Ux _tide_prompt_79899 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b34m\x1b\x5b44m\x20\x40PWD\x40\x20\x1b\x5b34m\x1b\x5b40m\ue0b0\x1b\x5b32m\x1b\x5b40m\x20\u276f\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b0 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b2\x1b\x5b32m\x1b\x5b40m\x20\uf00c\x20\x1b\x5b33m\x1b\x5b40m\ue0b2\x1b\x5b30m\x1b\x5b43m\x2015s\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b33m
      set -Ux _tide_right_items status cmd_duration context jobs virtual_env rustc nix_shell

      set -gx tide_aws_bg_color yellow
      set -gx tide_aws_color brblack
      set -gx tide_aws_icon \uf270
      set -gx tide_character_color brgreen
      set -gx tide_character_color_failure brred
      set -gx tide_character_icon \u276f
      set -gx tide_character_vi_icon_default \u276e
      set -gx tide_character_vi_icon_replace \u25b6
      set -gx tide_character_vi_icon_visual V
      set -gx tide_chruby_bg_color red
      set -gx tide_chruby_color black
      set -gx tide_chruby_icon \ue23e
      set -gx tide_cmd_duration_bg_color yellow
      set -gx tide_cmd_duration_color black
      set -gx tide_cmd_duration_decimals 0
      set -gx tide_cmd_duration_icon \x1d
      set -gx tide_cmd_duration_threshold 3000
      set -gx tide_context_always_display false
      set -gx tide_context_bg_color brblack
      set -gx tide_context_color_default yellow
      set -gx tide_context_color_root yellow
      set -gx tide_context_color_ssh yellow
      set -gx tide_context_hostname_parts 1
      set -gx tide_crystal_bg_color brwhite
      set -gx tide_crystal_color black
      set -gx tide_crystal_icon \u2b22
      set -gx tide_docker_bg_color blue
      set -gx tide_docker_color black
      set -gx tide_docker_default_contexts default colima
      set -gx tide_docker_icon \uf308
      set -gx tide_git_bg_color green
      set -gx tide_git_bg_color_unstable yellow
      set -gx tide_git_bg_color_urgent red
      set -gx tide_git_color_branch black
      set -gx tide_git_color_conflicted black
      set -gx tide_git_color_dirty black
      set -gx tide_git_color_operation black
      set -gx tide_git_color_staged black
      set -gx tide_git_color_stash black
      set -gx tide_git_color_untracked black
      set -gx tide_git_color_upstream black
      set -gx tide_git_icon \x1d
      set -gx tide_git_truncation_length 24
      set -gx tide_go_bg_color brcyan
      set -gx tide_go_color black
      set -gx tide_go_icon \ue627
      set -gx tide_java_bg_color yellow
      set -gx tide_java_color black
      set -gx tide_java_icon \ue256
      set -gx tide_jobs_bg_color brblack
      set -gx tide_jobs_color green
      set -gx tide_jobs_icon \uf013
      set -gx tide_kubectl_bg_color blue
      set -gx tide_kubectl_color black
      set -gx tide_kubectl_icon \u2388
      set -gx tide_left_prompt_frame_enabled false
      set -gx tide_left_prompt_items pwd git vi_mode
      set -gx tide_left_prompt_prefix 
      set -gx tide_left_prompt_separator_diff_color \ue0b0
      set -gx tide_left_prompt_separator_same_color \ue0b1
      set -gx tide_left_prompt_suffix \ue0b0
      set -gx tide_nix_shell_bg_color brblue
      set -gx tide_nix_shell_color white
      set -gx tide_nix_shell_icon \uf313
      set -gx tide_node_bg_color green
      set -gx tide_node_color black
      set -gx tide_node_icon \u2b22
      set -gx tide_os_bg_color white
      set -gx tide_os_color black
      set -gx tide_os_icon \uf313
      set -gx tide_php_bg_color blue
      set -gx tide_php_color black
      set -gx tide_php_icon \ue608
      set -gx tide_private_mode_bg_color brwhite
      set -gx tide_private_mode_color black
      set -gx tide_private_mode_icon \ufaf8
      set -gx tide_prompt_add_newline_before true
      set -gx tide_prompt_color_frame_and_connection brblack
      set -gx tide_prompt_color_separator_same_color brblack
      set -gx tide_prompt_icon_connection \x20
      set -gx tide_prompt_min_cols 34
      set -gx tide_prompt_pad_items true
      set -gx tide_pwd_bg_color blue
      set -gx tide_pwd_color_anchors brwhite
      set -gx tide_pwd_color_dirs brwhite
      set -gx tide_pwd_color_truncated_dirs white
      set -gx tide_pwd_icon \x1d
      set -gx tide_pwd_icon_home \uf015
      set -gx tide_pwd_icon_unwritable \uf023
      set -gx tide_pwd_markers \x2ebzr \x2ecitc \x2egit \x2ehg \x2enode\x2dversion \x2epython\x2dversion \x2eruby\x2dversion \x2eshorten_folder_marker \x2esvn \x2eterraform Cargo\x2etoml composer\x2ejson CVS go\x2emod package\x2ejson
      set -gx tide_right_prompt_frame_enabled false
      set -gx tide_right_prompt_items status cmd_duration context jobs node virtual_env rustc java php chruby go kubectl toolbox terraform aws nix_shell crystal
      set -gx tide_right_prompt_prefix \ue0b2
      set -gx tide_right_prompt_separator_diff_color \ue0b2
      set -gx tide_right_prompt_separator_same_color \ue0b3
      set -gx tide_right_prompt_suffix 
      set -gx tide_rustc_bg_color red
      set -gx tide_rustc_color black
      set -gx tide_rustc_icon \ue7a8
      set -gx tide_shlvl_bg_color yellow
      set -gx tide_shlvl_color black
      set -gx tide_shlvl_icon \uf120
      set -gx tide_shlvl_threshold 1
      set -gx tide_status_bg_color black
      set -gx tide_status_bg_color_failure red
      set -gx tide_status_color green
      set -gx tide_status_color_failure brwhite
      set -gx tide_status_icon \uf00c
      set -gx tide_status_icon_failure \u2718
      set -gx tide_terraform_bg_color magenta
      set -gx tide_terraform_color black
      set -gx tide_terraform_icon \x1d
      set -gx tide_time_bg_color white
      set -gx tide_time_color black
      set -gx tide_time_format 
      set -gx tide_toolbox_bg_color magenta
      set -gx tide_toolbox_color black
      set -gx tide_toolbox_icon \u2b22
      set -gx tide_vi_mode_bg_color_default black
      set -gx tide_vi_mode_bg_color_insert black
      set -gx tide_vi_mode_bg_color_replace black
      set -gx tide_vi_mode_bg_color_visual black
      set -gx tide_vi_mode_color_default green
      set -gx tide_vi_mode_color_insert green
      set -gx tide_vi_mode_color_replace green
      set -gx tide_vi_mode_color_visual green
      set -gx tide_vi_mode_icon_default \u276e
      set -gx tide_vi_mode_icon_insert \u276f
      set -gx tide_vi_mode_icon_replace R
      set -gx tide_vi_mode_icon_visual V
      set -gx tide_virtual_env_bg_color brblack
      set -gx tide_virtual_env_color cyan
      set -gx tide_virtual_env_icon \ue73c
    '';
    plugins = with pkgs.fishPlugins; [
      { name = "tide"; src = tide.src; }
    ];
  };
}
