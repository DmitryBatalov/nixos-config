{ pkgs, ... }:
{
  plugins = {
    # File type icons for various plugins
    web-devicons.enable = true;

    # Automatically detects and sets indentation settings
    guess-indent.enable = true;

    # Git UI inside Neovim (<leader>lg)
    lazygit.enable = true;

    # Displays LSP progress notifications in the bottom right corner
    fidget.enable = true;

    # Live markdown preview in browser (:MarkdownPreview)
    markdown-preview = {
      enable = true;
      settings = {
        plantuml_url = "http://www.plantuml.com/plantuml/svg/";
      };
    };

    # Autoformat on save
    conform-nvim = {
      enable = true;
      settings = {
        format_on_save.__raw = ''
          function(bufnr)
            if vim.bo[bufnr].filetype == 'fsharp' then
              return nil
            end
            return {
              timeout_ms = 500,
              lsp_fallback = true,
            }
          end
        '';
        formatters_by_ft = {
          nix = [ "alejandra" ];
          lua = [ "stylua" ];
        };
      };
    };

    # Syntax highlighting and code parsing
    treesitter = {
      enable = true;
      settings.highlight.enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        nix
        lua
        fsharp
        typst
        markdown
      ];
    };

    # Live Typst preview in browser
    typst-preview = {
      enable = true;
    };

    # Status line
    lualine = {
      enable = true;
      settings = {
        options = {
          theme = "tokyonight";
          component_separators = {
            left = "|";
            right = "|";
          };
          section_separators = {
            left = "";
            right = "";
          };
        };
        sections = {
          lualine_a = [ "mode" ];
          lualine_b = [
            "branch"
            "diff"
            "diagnostics"
          ];
          lualine_c = [ "filename" ];
          lualine_x = [
            "encoding"
            "fileformat"
            "filetype"
          ];
          lualine_y = [ "progress" ];
          lualine_z = [ "location" ];
        };
      };
    };

    # Useful plugin to show you pending keybinds.
    # https://nix-community.github.io/nixvim/plugins/which-key/index.html
    which-key = {
      enable = true;
      # Document existing key chains
      settings = {
        # delay between pressing a key and opening which-key (milliseconds)
        # this setting is independent of vim.opt.timeoutlen
        delay = 300;
        spec = [
          {
            __unkeyed-1 = "<leader>s";
            group = "[S]earch";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "[T]oggle";
          }
          {
            __unkeyed-1 = "<leader>d";
            group = "[D]ocument";
          }
          {
            __unkeyed-1 = "<leader>w";
            group = "[W]orkspace";
          }
          {
            __unkeyed-1 = "<leader>l";
            group = "[L]SP";
          }
          {
            __unkeyed-1 = "<leader>h";
            group = "Git [H]unk";
            mode = [
              "n"
              "v"
              "o"
              "x"
            ];
          }
        ];
      };
    };

    telescope = {
      # Telescope is a fuzzy finder that comes with a lot of different things that
      # it can fuzzy find! It's more than just a "file finder", it can search
      # many different aspects of Neovim, your workspace, LSP, and more!
      #
      # The easiest way to use Telescope, is to start by doing something like:
      #  :Telescope help_tags
      #
      # After running this command, a window will open up and you're able to
      # type in the prompt window. You'll see a list of `help_tags` options and
      # a corresponding preview of the help.
      #
      # Two important keymaps to use while in Telescope are:
      #  - Insert mode: <c-/>
      #  - Normal mode: ?
      #
      # This opens a window that shows you all of the keymaps for the current
      # Telescope picker. This is really useful to discover what Telescope can
      # do as well as how to actually do it!
      #
      # [[ Configure Telescope ]]
      # See `:help telescope` and `:help telescope.setup()`
      enable = true;

      # Enable Telescope extensions
      extensions = {
        # https://github.com/nvim-telescope/telescope-fzf-native.nvim
        fzf-native.enable = true;
        # https://github.com/nvim-telescope/telescope-ui-select.nvim
        ui-select.enable = true;
      };

      # You can put your default mappings / updates / etc. in here
      #  See `:help telescope.builtin`
      keymaps = {
        "<leader>sh" = {
          mode = "n";
          action = "help_tags";
          options = {
            desc = "[S]earch [H]elp";
          };
        };
        "<leader>sk" = {
          mode = "n";
          action = "keymaps";
          options = {
            desc = "[S]earch [K]eymaps";
          };
        };
        "<leader>sf" = {
          mode = "n";
          action = "find_files";
          options = {
            desc = "[S]earch [F]iles";
          };
        };
        "<leader>ss" = {
          mode = "n";
          action = "builtin";
          options = {
            desc = "[S]earch [S]elect Telescope";
          };
        };
        "<leader>sw" = {
          mode = "n";
          action = "grep_string";
          options = {
            desc = "[S]earch current [W]ord";
          };
        };
        "<leader>sg" = {
          mode = "n";
          action = "live_grep";
          options = {
            desc = "[S]earch by [G]rep";
          };
        };
        "<leader>sd" = {
          mode = "n";
          action = "diagnostics";
          options = {
            desc = "[S]earch [D]iagnostics";
          };
        };
        "<leader>sr" = {
          mode = "n";
          action = "resume";
          options = {
            desc = "[S]earch [R]esume";
          };
        };
        "<leader>s." = {
          mode = "n";
          action = "oldfiles";
          options = {
            desc = "[S]earch Recent Files ('.' for repeat)";
          };
        };
        "<leader><leader>" = {
          mode = "n";
          action = "buffers";
          options = {
            desc = "[ ] Find existing buffers";
          };
        };
      };
      settings = {
        extensions.__raw = "{ ['ui-select'] = { require('telescope.themes').get_dropdown() } }";
      };
    };

    # Language Server Protocol support for code intelligence
    lsp = {
      enable = true;
      keymaps = {
        lspBuf = {
          gd = {
            action = "definition";
            desc = "[G]oto [D]efinition";
          };
          gr = {
            action = "references";
            desc = "[G]oto [R]eferences";
          };
          gI = {
            action = "implementation";
            desc = "[G]oto [I]mplementation";
          };
          gD = {
            action = "declaration";
            desc = "[G]oto [D]eclaration";
          };
          K = {
            action = "hover";
            desc = "Hover Documentation";
          };
          "<leader>rn" = {
            action = "rename";
            desc = "[R]e[n]ame";
          };
          "<leader>ca" = {
            action = "code_action";
            desc = "[C]ode [A]ction";
          };
          "<leader>D" = {
            action = "type_definition";
            desc = "Type [D]efinition";
          };
          "<leader>ds" = {
            action = "document_symbol";
            desc = "[D]ocument [S]ymbols";
          };
          "<leader>ws" = {
            action = "workspace_symbol";
            desc = "[W]orkspace [S]ymbols";
          };
          "<C-s>" = {
            action = "signature_help";
            desc = "Signature Help";
          };
          "<leader>lf" = {
            action = "format";
            desc = "[L]SP [F]ormat";
          };
          "<leader>li" = {
            action = "incoming_calls";
            desc = "[L]SP [I]ncoming calls";
          };
          "<leader>lo" = {
            action = "outgoing_calls";
            desc = "[L]SP [O]utgoing calls";
          };
        };
        diagnostic = {
          "[d" = {
            action = "goto_prev";
            desc = "Previous [D]iagnostic";
          };
          "]d" = {
            action = "goto_next";
            desc = "Next [D]iagnostic";
          };
          "<leader>e" = {
            action = "open_float";
            desc = "Show Diagnostic Float";
          };
          "<leader>q" = {
            action = "setloclist";
            desc = "Diagnostics to Location List";
          };
        };
      };
      servers = {
        # Nix lsp
        nil_ls = {
          enable = true;
        };

        # F# lsp
        fsautocomplete.enable = true;

        # Typst lsp
        tinymist.enable = true;

        # Lua lsp
        lua_ls = {
          enable = true;
          settings = {
            completion = {
              callSnippet = "Replace";
            };
          };
        };
      };
    };
  };
}
