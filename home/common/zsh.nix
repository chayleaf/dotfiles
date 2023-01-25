{ config, pkgs, lib, ... }:
{
  programs.zsh = {
    enable = true;
    # zsh-autosuggestions
    enableAutosuggestions = true;
    # zsh-syntax-highlighting
    enableSyntaxHighlighting = true;
    defaultKeymap = "viins";
    dotDir = ".config/zsh";
    history.ignoreDups = true;
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    shellAliases.s = "sudo -A";
    shellAliases.se = "sudo -AE";
    localVariables = {
      POWERLEVEL9K_LEFT_PROMPT_ELEMENTS = [
        # "os_icon"               # os identifier
        "dir"                     # current directory
        "vcs"                     # git status
        "prompt_char"             # prompt symbol
      ];
      POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS = [
        "status"                  # exit code of the last command
        "command_execution_time"  # duration of the last command
        "background_jobs"         # presence of background jobs
        # "direnv"                # direnv status (https://direnv.net/)
        # "asdf"                  # asdf version manager (https://github.com/asdf-vm/asdf)
        # "virtualenv"            # python virtual environment (https://docs.python.org/3/library/venv.html)
        # "anaconda"              # conda environment (https://conda.io/)                               
        # "pyenv"                 # python environment (https://github.com/pyenv/pyenv)
        # "goenv"                 # go environment (https://github.com/syndbg/goenv)    
        # "nodenv"                # node.js version from nodenv (https://github.com/nodenv/nodenv)
        # "nvm"                   # node.js version from nvm (https://github.com/nvm-sh/nvm)    
        # "nodeenv"               # node.js environment (https://github.com/ekalinin/nodeenv)
        # "node_version"          # node.js version
        # "go_version"            # go version (https://golang.org)
        # "rust_version"          # rustc version (https://www.rust-lang.org)
        # "dotnet_version"        # .NET version (https://dotnet.microsoft.com)
        # "php_version"           # php version (https://www.php.net/)
        # "laravel_version"       # laravel php framework version (https://laravel.com/)
        # "java_version"          # java version (https://www.java.com/)
        # "package"               # name@version from package.json (https://docs.npmjs.com/files/package.json)
        # "rbenv"                 # ruby version from rbenv (https://github.com/rbenv/rbenv)
        # "rvm"                   # ruby version from rvm (https://rvm.io)
        # "fvm"                   # flutter version management (https://github.com/leoafarias/fvm)
        # "luaenv"                # lua version from luaenv (https://github.com/cehoffman/luaenv)
        # "jenv"                  # java version from jenv (https://github.com/jenv/jenv) 
        # "plenv"                 # perl version from plenv (https://github.com/tokuhirom/plenv)
        # "phpenv"                # php version from phpenv (https://github.com/phpenv/phpenv)
        # "scalaenv"              # scala version from scalaenv (https://github.com/scalaenv/scalaenv)
        # "haskell_stack"         # haskell version from stack (https://haskellstack.org/)
        # "kubecontext"           # current kubernetes context (https://kubernetes.io/)
        # "terraform"             # terraform workspace (https://www.terraform.io)
        # "terraform_version      # terraform version (https://www.terraform.io)
        # "aws"                   # aws profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
        # "aws_eb_env"            # aws elastic beanstalk environment (https://aws.amazon.com/elasticbeanstalk/)
        # "azure"                 # azure account name (https://docs.microsoft.com/en-us/cli/azure)
        # "gcloud"                # google cloud cli account and project (https://cloud.google.com/)
        # "google_app_cred"       # google application credentials (https://cloud.google.com/docs/authentication/production)
        # "toolbox"               # toolbox name (https://github.com/containers/toolbox)
        # "context"               # user@hostname
        # "nordvpn"               # nordvpn connection status, linux only (https://nordvpn.com/)
        # "ranger"                # ranger shell (https://github.com/ranger/ranger)
        "nnn"                     # nnn shell (https://github.com/jarun/nnn)
        # "xplr"                  # xplr shell (https://github.com/sayanarijit/xplr)
        "vim_shell"               # vim shell indicator (:sh)
        # "midnight_commander"    # midnight commander shell (https://midnight-commander.org/)
        "nix_shell"               # nix shell (https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html)
        # "vi_mode"               # vi mode (you don't need this if you've enabled prompt_char)
        # "vpn_ip"                # virtual private network indicator
        # "load"                  # CPU load
        # "disk_usage"            # disk usage
        # "ram"                   # free RAM
        # "swap"                  # used swap
        # "todo"                  # todo items (https://github.com/todotxt/todo.txt-cli)
        # "timewarrior"           # timewarrior tracking status (https://timewarrior.net/)
        # "taskwarrior"           # taskwarrior task count (https://taskwarrior.org/)
        # "time"                  # current time
        # "ip"                    # ip address and bandwidth usage for a specified network interface
        # "public_ip"             # public IP address
        # "proxy"                 # system-wide http/https/ftp proxy
        # "battery"               # internal battery
        # "wifi"                  # wifi speed
        # "example"               # example user-defined segment (see prompt_example function below)
      ];
      POWERLEVEL9K_MODE = "nerdfont-complete";
      POWERLEVEL9K_ICON_PADDING = "none";
      POWERLEVEL9K_PROMPT_ADD_NEWLINE = "true";
      POWERLEVEL9K_TRANSIENT_PROMPT = "same-dir";
      POWERLEVEL9K_INSTANT_PROMPT = "verbose";
      POWERLEVEL9K_DIR_FOREGROUND = "254";
      POWERLEVEL9K_SHORTEN_STRATEGY = "truncate_to_unique";
      POWERLEVEL9K_DIR_ANCHOR_BOLD = "true";
      POWERLEVEL9K_SHORTEN_FOLDER_MARKER = "(.bzr|.citc|.git|.hg|.node-version|.python-version|.go-version|.ruby-version|.lua-version|.java-version|.perl-version|.php-version|.tool-version|.shorten_folder_marker|.svn|.terraform|CVS|Cargo.toml|composer.json|flake.nix|go.mod|package.json|stack.yaml)";
      # POWERLEVEL9K_PROMPT_CHAR_LEFT_LEFT_WHITESPACE = "";
      # POWERLEVEL9K_PROMPT_CHAR_LEFT_RIGHT_WHITESPACE = "";
      POWERLEVEL9K_STATUS_ERROR_FOREGROUND = "15";
      POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND = "15";
      POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND = "15";
      POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND = "0";
      POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND = "3";
      POWERLEVEL9K_NIX_SHELL_FOREGROUND = "15";
      SHELL = "zsh";
    };
    plugins = with pkgs; [
      { name = "zsh-vi-mode";
        src = zsh-vi-mode.src; }
      { name = "fzf-tab";
        src = zsh-fzf-tab.src; }
      { name = "nix-shell";
        src = zsh-nix-shell.src; }
      { name = "powerlevel10k";
        src = zsh-powerlevel10k.src;
        file = "powerlevel10k.zsh-theme"; }
      { name = "you-should-use";
        src = zsh-you-should-use.src; }
    ];
  };
}
