{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.alacritty;
in
{
  options.custom.alacritty = {
    enable = lib.mkEnableOption "Alacritty terminal (Nord colours, shared keybindings)";
    fontFamily = lib.mkOption {
      type = lib.types.str;
      # Installed by the custom.fonts system module on every host
      default = "Hack Nerd Font Mono";
      description = "Font family used for all Alacritty font styles";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        env = {
          TERM = "xterm-256color";
          WINIT_X11_SCALE_FACTOR = "1";
        };

        window = {
          dynamic_padding = true;
          decorations = "full";
          title = "Alacritty@NixOS";
          opacity = 0.8;
          decorations_theme_variant = "Dark";
          dimensions = {
            columns = 100;
            lines = 30;
          };
          class = {
            instance = "Alacritty";
            general = "Alacritty";
          };
        };

        scrolling = {
          history = 10000;
          multiplier = 3;
        };

        colors = {
          draw_bold_text_with_bright_colors = true;
          primary = {
            background = "0x2E3440";
            foreground = "0xD8DEE9";
          };
          normal = {
            black = "0x3B4252";
            red = "0xBF616A";
            green = "0xA3BE8C";
            yellow = "0xEBCB8B";
            blue = "0x81A1C1";
            magenta = "0xB48EAD";
            cyan = "0x88C0D0";
            white = "0xE5E9F0";
          };
          bright = {
            black = "0x4C566A";
            red = "0xBF616A";
            green = "0xA3BE8C";
            yellow = "0xEBCB8B";
            blue = "0x81A1C1";
            magenta = "0xB48EAD";
            cyan = "0x8FBCBB";
            white = "0xECEFF4";
          };
        };

        font = {
          size = 12;
          normal = {
            family = cfg.fontFamily;
            style = "Regular";
          };
          bold = {
            family = cfg.fontFamily;
            style = "Bold";
          };
          italic = {
            family = cfg.fontFamily;
            style = "Italic";
          };
          bold_italic = {
            family = cfg.fontFamily;
            style = "Bold Italic";
          };
        };

        selection = {
          semantic_escape_chars = ",│`|:\"' ()[]{}<>\t";
          save_to_clipboard = true;
        };

        cursor = {
          style = "Underline";
          vi_mode_style = "None";
          unfocused_hollow = true;
          thickness = 0.15;
        };

        mouse = {
          hide_when_typing = true;
          bindings = [
            {
              mouse = "Middle";
              action = "PasteSelection";
            }
          ];
        };

        keyboard = {
          bindings = [
            {
              key = "Paste";
              action = "Paste";
            }
            {
              key = "Copy";
              action = "Copy";
            }
            {
              key = "L";
              mods = "Control";
              action = "ClearLogNotice";
            }
            {
              key = "L";
              mods = "Control";
              mode = "~Vi";
              chars = "\f";
            }
            {
              key = "PageUp";
              mods = "Shift";
              mode = "~Alt";
              action = "ScrollPageUp";
            }
            {
              key = "PageDown";
              mods = "Shift";
              mode = "~Alt";
              action = "ScrollPageDown";
            }
            {
              key = "Home";
              mods = "Shift";
              mode = "~Alt";
              action = "ScrollToTop";
            }
            {
              key = "End";
              mods = "Shift";
              mode = "~Alt";
              action = "ScrollToBottom";
            }
            {
              key = "V";
              mods = "Control|Shift";
              action = "Paste";
            }
            {
              key = "C";
              mods = "Control|Shift";
              action = "Copy";
            }
            {
              key = "F";
              mods = "Control|Shift";
              action = "SearchForward";
            }
            {
              key = "B";
              mods = "Control|Shift";
              action = "SearchBackward";
            }
            {
              key = "C";
              mods = "Control|Shift";
              mode = "Vi";
              action = "ClearSelection";
            }
            {
              key = "Key0";
              mods = "Control";
              action = "ResetFontSize";
            }
          ];
        };

        general = {
          live_config_reload = true;
          working_directory = "None";
        };
      };
    };
  };
}
