{ ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      theme = ""; # leave prompt to starship
      plugins = [
        "git"
        "z"
      ];
    };

    shellAliases = {
      ll = "ls -lhrt";
      gs = "git status";
      hms = "home-manager switch";
    };

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      share = true; # share history across sessions
    };
  };

  # If login shell is bash (non-nix systems), auto-launch zsh
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      if [[ -z "$ZSH_VERSION" && $- == *i* ]]; then
        exec zsh
      fi
    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = ''
        [╭╴](fg:arrow)$username$os$git_branch(at $directory)$cmd_duration(via $python$conda$nodejs$c$rust$java)
        [╰─](fg:arrow)$character'';

      add_newline = true;

      palette = "normal";

      palettes.normal = {
        arrow = "#333533";
        os = "#16f4d0";
        os_admin = "#e4ff1a";
        directory = "#9ffff5";
        time = "#bdfffd";
        node = "#a5e6ba";
        git = "#f17f29";
        git_status = "#DFEBED";
        python = "#edf67d";
        conda = "#70e000";
        java = "#F86279";
        rust = "#ffdac6";
        clang = "#caf0f8";
        duration = "#ce4257";
        text_color = "#EDF2F4";
        text_light = "#26272A";
      };

      username = {
        style_user = "bold os";
        style_root = "bold os_admin";
        format = "[  $user](fg:$style) ";
        disabled = false;
        show_always = true;
      };

      os = {
        format = "on [($name)]($style) ";
        style = "bold blue";
        disabled = true;
        symbols = {
          Alpine = " ";
          Arch = " ";
          Debian = " ";
          EndeavourOS = " ";
          Fedora = " ";
          Linux = " ";
          Macos = " ";
          Manjaro = " ";
          Mint = " ";
          NixOS = " ";
          openSUSE = " ";
          Pop = " ";
          SUSE = " ";
          Ubuntu = " ";
          Windows = " ";
        };
      };

      character = {
        success_symbol = "[󰍟](fg:arrow)";
        error_symbol = "[󰍟](fg:red)";
      };

      directory = {
        format = "[$path](bold $style)[$read_only]($read_only_style) ";
        truncation_length = 2;
        style = "fg:directory";
        read_only_style = "fg:directory";
        before_repo_root_style = "fg:directory";
        truncation_symbol = "…/";
        truncate_to_repo = true;
        read_only = "  ";
      };

      time = {
        disabled = true;
        format = "at [󱑈 $time]($style)";
        time_format = "%H:%M";
        style = "bold fg:time";
      };

      cmd_duration = {
        format = "took [ $duration]($style) ";
        style = "bold fg:duration";
        min_time = 500;
      };

      git_branch = {
        format = "via [$symbol$branch]($style) ";
        style = "bold fg:git";
        symbol = " ";
      };

      git_status = {
        format = "[ $all_status$ahead_behind ]($style)";
        style = "fg:text_color bg:git";
        disabled = true;
      };

      docker_context = {
        disabled = true;
        symbol = " ";
      };

      package.disabled = true;

      fill.symbol = " ";

      nodejs = {
        format = "[ $symbol$version ]($style)";
        style = "bg:node fg:text_light";
        symbol = " ";
        version_format = "\${raw}";
        disabled = false;
      };

      python = {
        disabled = false;
        format = "[ \${symbol}\${pyenv_prefix}(\${version})( \\($virtualenv\\)) ]($style)";
        symbol = " ";
        version_format = "\${raw}";
        style = "bg:python fg:text_light";
      };

      conda = {
        format = "[ $symbol$environment ]($style)";
        style = "bg:conda fg:text_light";
        ignore_base = false;
        disabled = false;
        symbol = " ";
      };

      java = {
        format = "[ $symbol$version ]($style)";
        style = "bg:java fg:text_light";
        version_format = "\${raw}";
        symbol = " ";
        disabled = true;
      };

      c = {
        format = "[ $symbol($version(-$name)) ]($style)";
        style = "bg:clang fg:text_light";
        symbol = " ";
        version_format = "\${raw}";
        disabled = true;
      };

      rust = {
        format = "[ $symbol$version ]($style)";
        style = "bg:rust fg:text_light";
        symbol = " ";
        version_format = "\${raw}";
        disabled = true;
      };
    };
  };
}
