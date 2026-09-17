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

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      share = true;
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
        [╭╴](fg:arrow)$username$hostname$os$git_branch$git_status (at $directory)$cmd_duration$time(via $python$conda$nodejs$c$rust$java$docker_context)
        [╰─](fg:arrow)$character'';

      add_newline = true;

      palette = "normal";

      palettes.normal = {
        arrow = "#EDF2F4";
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

      # Starship hides the username segment by default (only shows for root/SSH);
      # force it on so it always renders.
      username = {
        style_user = "bold os";
        style_root = "bold os_admin";
        format = "[  $user](fg:$style)";
        disabled = false;
        show_always = true;
      };

      # Starship only shows the hostname over SSH by default; force it on so
      # it always renders (this config is shared across multiple hosts).
      hostname = {
        format = "[ 󰒋 $hostname](bold green) ";
        ssh_only = false;
        disabled = false;
      };

      # The os module is disabled by default in starship; opt in explicitly.
      os = {
        format = "on [($name)]($style) ";
        style = "bold blue";
        disabled = false;
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
        disabled = false;
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
        disabled = false;
      };

      docker_context = {
        disabled = false;
        symbol = " ";
      };

      package.disabled = true;

      # Only takes effect if $fill appears in `format` above; it currently doesn't.
      fill.symbol = " ";

      nodejs = {
        format = "[ $symbol$version ]($style)";
        style = "bg:node fg:text_light";
        symbol = " ";
        # Show the bare version string; starship's default prepends a "v".
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
        disabled = false;
      };

      c = {
        format = "[ $symbol($version(-$name)) ]($style)";
        style = "bg:clang fg:text_light";
        symbol = " ";
        version_format = "\${raw}";
        disabled = false;
      };

      rust = {
        format = "[ $symbol$version ]($style)";
        style = "bg:rust fg:text_light";
        symbol = " ";
        version_format = "\${raw}";
        disabled = false;
      };
    };
  };
}
