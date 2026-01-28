{
  keymaps = [
    # Clear highlights on search when pressing <Esc> in normal mode
    #  See `:help hlsearch`
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
    }

    # Keybinds to make split navigation easier.
    #  Use CTRL+<hjkl> to switch between windows
    #
    #  See `:help wincmd` for a list of all window commands
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w><C-h>";
      options = {
        desc = "Move focus to the left window";
      };
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w><C-l>";
      options = {
        desc = "Move focus to the right window";
      };
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w><C-j>";
      options = {
        desc = "Move focus to the lower window";
      };
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w><C-k>";
      options = {
        desc = "Move focus to the upper window";
      };
    }

    # Slightly advanced example of overriding default behavior and theme
    {
      mode = "n";
      key = "<leader>/";
      # You can pass additional configuration to Telescope to change the theme, layout, etc.
      action.__raw = ''
        function()
          require('telescope.builtin').current_buffer_fuzzy_find(
            require('telescope.themes').get_dropdown {
              winblend = 10,
              previewer = false
            }
          )
        end
      '';
      options = {
        desc = "[/] Fuzzily search in current buffer";
      };
    }
    {
      mode = "n";
      key = "<leader>s/";
      # It's also possible to pass additional configuration options.
      #  See `:help telescope.builtin.live_grep()` for information about particular keys
      action.__raw = ''
        function()
          require('telescope.builtin').live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files'
          }
        end
      '';
      options = {
        desc = "[S]earch [/] in Open Files";
      };
    }
    # Shortcut for searching your Neovim configuration files
    {
      mode = "n";
      key = "<leader>sn";
      action.__raw = ''
        function()
          require('telescope.builtin').find_files {
            cwd = vim.fn.stdpath 'config'
          }
        end
      '';
      options = {
        desc = "[S]earch [N]eovim files";
      };
    }
    # F# Solution picker - load a specific solution with fsautocomplete
    {
      mode = "n";
      key = "<leader>ls";
      action.__raw = ''
        function()
          local pickers = require('telescope.pickers')
          local finders = require('telescope.finders')
          local conf = require('telescope.config').values
          local actions = require('telescope.actions')
          local action_state = require('telescope.actions.state')

          -- Find .sln files starting from current directory going up
          local cwd = vim.fn.getcwd()
          local sln_files = vim.fn.globpath(cwd, '**/*.sln', false, true)

          if #sln_files == 0 then
            vim.notify('No .sln files found', vim.log.levels.WARN)
            return
          end

          pickers.new({}, {
            prompt_title = 'Select F# Solution',
            finder = finders.new_table {
              results = sln_files,
              entry_maker = function(entry)
                return {
                  value = entry,
                  display = vim.fn.fnamemodify(entry, ':t'),
                  ordinal = entry,
                }
              end,
            },
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                local sln_path = selection.value

                -- Find fsautocomplete client
                local clients = vim.lsp.get_clients({ name = 'fsautocomplete' })
                if #clients == 0 then
                  vim.notify('fsautocomplete LSP not running', vim.log.levels.ERROR)
                  return
                end

                local client = clients[1]
                local sln_name = vim.fn.fnamemodify(sln_path, ":t")
                vim.notify("Loading " .. sln_name .. "...", vim.log.levels.INFO)

                -- Use correct WorkspaceLoadParms structure from Ionide-vim
                client.request("fsharp/workspaceLoad", {
                  TextDocuments = {
                    { Uri = "file://" .. sln_path }
                  }
                }, function(err, result)
                  if err then
                    vim.notify("Failed to load " .. sln_name .. ": " .. vim.inspect(err), vim.log.levels.ERROR)
                  else
                    vim.notify("Loaded " .. sln_name, vim.log.levels.INFO)
                    -- Reload buffer to trigger LSP re-analysis
                    vim.cmd("e")
                  end
                end)
              end)
              return true
            end,
          }):find()
        end
      '';
      options = {
        desc = "[L]SP Load [S]olution";
      };
    }
    # Open LazyGit
    {
      mode = "n";
      key = "<leader>lg";
      action = "<cmd>LazyGit<CR>";
      options = {
        desc = "[L]azy[G]it";
      };
    }
    # Markdown Preview
    {
      mode = "n";
      key = "<leader>mp";
      action = "<cmd>MarkdownPreview<CR>";
      options = {
        desc = "[M]arkdown [P]review";
      };
    }
    {
      mode = "n";
      key = "<leader>mt";
      action = "<cmd>MarkdownPreviewToggle<CR>";
      options = {
        desc = "[M]arkdown Preview [T]oggle";
      };
    }
    # Typst Preview
    {
      mode = "n";
      key = "<leader>tp";
      action = "<cmd>TypstPreview<CR>";
      options = {
        desc = "[T]ypst [P]review";
      };
    }
    {
      mode = "n";
      key = "<leader>tt";
      action = "<cmd>TypstPreviewToggle<CR>";
      options = {
        desc = "[T]ypst Preview [T]oggle";
      };
    }
    # F# Show loaded projects (from tracked workspace state)
    {
      mode = "n";
      key = "<leader>lp";
      action.__raw = ''
        function()
          local ws = vim.g.fsharp_workspace
          if not ws or not ws.solution then
            vim.notify("No F# solution loaded", vim.log.levels.WARN)
            return
          end

          local lines = { "F# Workspace:", "" }

          if ws.loading then
            table.insert(lines, "Status: Loading...")
          else
            table.insert(lines, "Status: Ready")
          end

          table.insert(lines, "")
          table.insert(lines, "Solution: " .. vim.fn.fnamemodify(ws.solution, ":t"))
          table.insert(lines, "")

          if ws.projects and #ws.projects > 0 then
            table.insert(lines, "Projects (" .. #ws.projects .. "):")
            for _, proj in ipairs(ws.projects) do
              table.insert(lines, "  " .. vim.fn.fnamemodify(proj, ":t"))
            end
          end

          -- Show in floating window
          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          local width = 60
          local height = math.min(#lines, 20)
          vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            col = (vim.o.columns - width) / 2,
            row = (vim.o.lines - height) / 2,
            style = "minimal",
            border = "rounded",
          })
          vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf })
        end
      '';
      options = {
        desc = "[L]SP Show [P]rojects";
      };
    }
  ];
}
