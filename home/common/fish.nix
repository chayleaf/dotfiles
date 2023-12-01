{ pkgs
, config
, ... }:

{
  programs.fish =
    let nom-compat = pkgs.runCommand "any-shell-nom-compat" {} ''
      mkdir -p $out/bin
      for cmd in $(echo nix nix-shell nix-build); do
        echo '#! ${pkgs.bash}/bin/bash' > $out/bin/$cmd
        echo -n 'PATH=`echo $PATH | tr ":" "\n" | grep -v "any-shell-nom-compat" | tr "\n" ":"` ' >> $out/bin/$cmd
        cmd1=$(echo $cmd | sed 's/nix/nom/')
        echo "$cmd1"' "$@"' >> $out/bin/$cmd
        chmod +x $out/bin/$cmd
      done
    '';
  in {
    enable = true;
    # not sure this is needed, but just in case
    shellInit = ''
      source /etc/fish/config.fish
    '';
    interactiveShellInit = ''
      # ${config.programs.atuin.package}/bin/atuin init fish | source
      set -gx ATUIN_SESSION (atuin uuid)
      function _atuin_preexec --on-event fish_preexec
        if not test -n "$fish_private_mode"
          set -gx ATUIN_HISTORY_ID (atuin history start -- "$argv[1]")
        end
      end
      function _atuin_postexec --on-event fish_postexec
        set s $status
        if test -n "$ATUIN_HISTORY_ID"
          RUST_LOG=error atuin history end --exit $s -- $ATUIN_HISTORY_ID &>/dev/null &
          disown
        end
      end
      function _atuin_search
        set h (RUST_LOG=error atuin search $argv -i -- (commandline -b) 3>&1 1>&2 2>&3)
        commandline -f repaint
        if test -n "$h"
          commandline -r $h
        end
      end

      bind \cr _atuin_search
      if bind -M insert > /dev/null 2>&1
        bind -M insert \cr _atuin_search
      end

      # ${pkgs.any-nix-shell}/bin/any-nix-shell fish | source

      function nix-shell
        ${pkgs.any-nix-shell}/bin/.any-nix-shell-wrapper fish $argv
      end
      function nix
        if not set -q argv[1]
          command nix
        else if test $argv[1] = shell
          set argv[1] fish
          ${pkgs.any-nix-shell}/bin/.any-nix-wrapper $argv
        else if test $argv[1] = develop
          command nix $argv --command fish
        else
          command nix $argv
        end
      end

      function nom-shell
        PATH="${nom-compat}/bin:$PATH" ${pkgs.any-nix-shell}/bin/.any-nix-shell-wrapper fish $argv
      end
      function nom
        if not set -q argv[1]
          command nom
        else if test $argv[1] = shell
          set argv[1] fish
          PATH="${nom-compat}/bin:$PATH" ${pkgs.any-nix-shell}/bin/.any-nix-wrapper $argv
        else if test $argv[1] = develop
          command nom $argv --command fish
        else if test $argv[1] = build
          command nom $argv
        else
          command nix --log-format internal-json -v $argv &| command nom --json
        end
      end

      set -gx NOMCOMPAT ${nom-compat}
      # for posix compatibility
      set -gx SHELL ${pkgs.zsh}/bin/zsh

      set -g fish_color_autosuggestion 777 brblack
      set -g fish_color_command green
      set -g fish_color_operator white
      set -g fish_color_param white

      set -g fish_key_bindings fish_vi_key_bindings
      set -g fish_cursor_insert line
      set -g fish_cursor_replace underscore

      # the following 4 values are special in some way
      # (e.g. even if you use -gx to set them, it won't work)
      set -U _tide_left_items pwd git vi_mode
      set -U _tide_prompt_69105 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b34m\x1b\x5b44m\x20\x40PWD\x40\x20\x1b\x5b34m\x1b\x5b40m\ue0b0\x1b\x5b32m\x1b\x5b40m\x20\u276f\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b0 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b2\x1b\x5b32m\x1b\x5b40m\x20\uf00c\x20\x1b\x5b33m\x1b\x5b40m\ue0b2\x1b\x5b30m\x1b\x5b43m\x2021m\x2023s\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b33m
      set -U _tide_prompt_79899 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b34m\x1b\x5b44m\x20\x40PWD\x40\x20\x1b\x5b34m\x1b\x5b40m\ue0b0\x1b\x5b32m\x1b\x5b40m\x20\u276f\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b0 \x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b30m\ue0b2\x1b\x5b32m\x1b\x5b40m\x20\uf00c\x20\x1b\x5b33m\x1b\x5b40m\ue0b2\x1b\x5b30m\x1b\x5b43m\x2015s\x20\x1b\x28B\x1b\x5bm\x1b\x28B\x1b\x5bm\x1b\x5b33m
      set -U _tide_right_items status cmd_duration context jobs rustc nix_shell

      # for the following values, -gx works too (-g doesn't)
      # but it pollutes children's env, so do -U
      # might as well make this an activation script?
      set -U tide_aws_bg_color yellow
      set -U tide_aws_color brblack
      set -U tide_aws_icon \uf270
      set -U tide_character_color brgreen
      set -U tide_character_color_failure brred
      set -U tide_character_icon \u276f
      set -U tide_character_vi_icon_default \u276e
      set -U tide_character_vi_icon_replace \u25b6
      set -U tide_character_vi_icon_visual V
      set -U tide_cmd_duration_bg_color yellow
      set -U tide_cmd_duration_color black
      set -U tide_cmd_duration_decimals 0
      set -U tide_cmd_duration_icon \x1d
      set -U tide_cmd_duration_threshold 3000
      set -U tide_context_always_display false
      set -U tide_context_bg_color brblack
      set -U tide_context_color_default yellow
      set -U tide_context_color_root yellow
      set -U tide_context_color_ssh yellow
      set -U tide_context_hostname_parts 1
      set -U tide_crystal_bg_color brwhite
      set -U tide_crystal_color black
      set -U tide_crystal_icon \u2b22
      set -U tide_docker_bg_color blue
      set -U tide_docker_color black
      set -U tide_docker_default_contexts default colima
      set -U tide_docker_icon \uf308
      set -U tide_git_bg_color green
      set -U tide_git_bg_color_unstable yellow
      set -U tide_git_bg_color_urgent red
      set -U tide_git_color_branch black
      set -U tide_git_color_conflicted black
      set -U tide_git_color_dirty black
      set -U tide_git_color_operation black
      set -U tide_git_color_staged black
      set -U tide_git_color_stash black
      set -U tide_git_color_untracked black
      set -U tide_git_color_upstream black
      set -U tide_git_icon \x1d
      set -U tide_git_truncation_length 24
      set -U tide_go_bg_color brcyan
      set -U tide_go_color black
      set -U tide_go_icon \ue627
      set -U tide_java_bg_color yellow
      set -U tide_java_color black
      set -U tide_java_icon \ue256
      set -U tide_jobs_bg_color brblack
      set -U tide_jobs_color green
      set -U tide_jobs_icon \uf013
      set -U tide_kubectl_bg_color blue
      set -U tide_kubectl_color black
      set -U tide_kubectl_icon \u2388
      set -U tide_left_prompt_frame_enabled false
      set -U tide_left_prompt_items pwd git vi_mode
      set -U tide_left_prompt_prefix 
      set -U tide_left_prompt_separator_diff_color \ue0b0
      set -U tide_left_prompt_separator_same_color \ue0b1
      set -U tide_left_prompt_suffix \ue0b0
      set -U tide_nix_shell_bg_color brblue
      set -U tide_nix_shell_color white
      set -U tide_nix_shell_icon \uf313
      set -U tide_node_bg_color green
      set -U tide_node_color black
      set -U tide_node_icon \u2b22
      set -U tide_os_bg_color white
      set -U tide_os_color black
      set -U tide_os_icon \uf313
      set -U tide_php_bg_color blue
      set -U tide_php_color black
      set -U tide_php_icon \ue608
      set -U tide_private_mode_bg_color brwhite
      set -U tide_private_mode_color black
      set -U tide_private_mode_icon \ufaf8
      set -U tide_prompt_add_newline_before true
      set -U tide_prompt_color_frame_and_connection brblack
      set -U tide_prompt_color_separator_same_color brblack
      set -U tide_prompt_icon_connection \x20
      set -U tide_prompt_min_cols 34
      set -U tide_prompt_pad_items true
      set -U tide_pwd_bg_color blue
      set -U tide_pwd_color_anchors brwhite
      set -U tide_pwd_color_dirs brwhite
      set -U tide_pwd_color_truncated_dirs white
      set -U tide_pwd_icon \x1d
      set -U tide_pwd_icon_home \uf015
      set -U tide_pwd_icon_unwritable \uf023
      set -U tide_pwd_markers \x2ebzr \x2ecitc \x2egit \x2ehg \x2enode\x2dversion \x2epython\x2dversion \x2eruby\x2dversion \x2eshorten_folder_marker \x2esvn \x2eterraform Cargo\x2etoml composer\x2ejson CVS go\x2emod package\x2ejson
      set -U tide_right_prompt_frame_enabled false
      set -U tide_right_prompt_items status cmd_duration context jobs node rustc java php go kubectl toolbox terraform aws nix_shell crystal
      set -U tide_right_prompt_prefix \ue0b2
      set -U tide_right_prompt_separator_diff_color \ue0b2
      set -U tide_right_prompt_separator_same_color \ue0b3
      set -U tide_right_prompt_suffix 
      set -U tide_rustc_bg_color red
      set -U tide_rustc_color black
      set -U tide_rustc_icon \ue7a8
      set -U tide_shlvl_bg_color yellow
      set -U tide_shlvl_color black
      set -U tide_shlvl_icon \uf120
      set -U tide_shlvl_threshold 1
      set -U tide_status_bg_color black
      set -U tide_status_bg_color_failure red
      set -U tide_status_color green
      set -U tide_status_color_failure brwhite
      set -U tide_status_icon \uf00c
      set -U tide_status_icon_failure \u2718
      set -U tide_terraform_bg_color magenta
      set -U tide_terraform_color black
      set -U tide_terraform_icon \x1d
      set -U tide_time_bg_color white
      set -U tide_time_color black
      set -U tide_time_format 
      set -U tide_toolbox_bg_color magenta
      set -U tide_toolbox_color black
      set -U tide_toolbox_icon \u2b22
      set -U tide_vi_mode_bg_color_default black
      set -U tide_vi_mode_bg_color_insert black
      set -U tide_vi_mode_bg_color_replace black
      set -U tide_vi_mode_bg_color_visual black
      set -U tide_vi_mode_color_default green
      set -U tide_vi_mode_color_insert green
      set -U tide_vi_mode_color_replace green
      set -U tide_vi_mode_color_visual green
      set -U tide_vi_mode_icon_default \u276e
      set -U tide_vi_mode_icon_insert \u276f
      set -U tide_vi_mode_icon_replace R
      set -U tide_vi_mode_icon_visual V
    '';
    plugins = with pkgs.fishPlugins; [
      { name = "tide"; src = tide.src; }
    ];
  };
}
