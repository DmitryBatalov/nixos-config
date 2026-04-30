{
  keymaps = [
    # Exit terminal insert mode with Esc
    {
      mode = "t";
      key = "<Esc>";
      action = "<C-\\><C-n>";
      options.desc = "Exit terminal mode";
    }

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

    # fff.nvim file search and grep
    {
      mode = "n";
      key = "<leader>sf";
      action.__raw = "function() require('fff').find_files() end";
      options.desc = "[S]earch [F]iles";
    }
    {
      mode = "n";
      key = "<leader>sg";
      action.__raw = "function() require('fff').live_grep() end";
      options.desc = "[S]earch by [G]rep";
    }
    # LSP symbols via telescope (floating picker instead of quickfix)
    {
      mode = "n";
      key = "<leader>ds";
      action.__raw = "function() require('telescope.builtin').lsp_document_symbols() end";
      options.desc = "[D]ocument [S]ymbols";
    }
    {
      mode = "n";
      key = "<leader>ws";
      action.__raw = "function() require('telescope.builtin').lsp_dynamic_workspace_symbols() end";
      options.desc = "[W]orkspace [S]ymbols";
    }
    {
      mode = "n";
      key = "<leader>lh";
      action.__raw = ''
        function()
          local bufnr = vim.api.nvim_get_current_buf()
          vim.lsp.inlay_hint.enable(
            not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr },
            { bufnr = bufnr }
          )
        end
      '';
      options.desc = "[L]SP toggle inlay [H]ints";
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
    # F# Solution picker - reuses :FSharpSelectSolution (state-aware)
    {
      mode = "n";
      key = "<leader>ls";
      action = "<cmd>FSharpSelectSolution<CR>";
      options.desc = "[L]SP Select [S]olution";
    }
    # Gitsigns hunk navigation
    {
      mode = "n";
      key = "]h";
      action.__raw = "function() require('gitsigns').nav_hunk('next') end";
      options.desc = "Next [H]unk";
    }
    {
      mode = "n";
      key = "[h";
      action.__raw = "function() require('gitsigns').nav_hunk('prev') end";
      options.desc = "Previous [H]unk";
    }
    {
      mode = "n";
      key = "<leader>hs";
      action.__raw = "function() require('gitsigns').stage_hunk() end";
      options.desc = "Git [H]unk [S]tage";
    }
    {
      mode = "n";
      key = "<leader>hr";
      action.__raw = "function() require('gitsigns').reset_hunk() end";
      options.desc = "Git [H]unk [R]eset";
    }
    {
      mode = "n";
      key = "<leader>hp";
      action.__raw = "function() require('gitsigns').preview_hunk() end";
      options.desc = "Git [H]unk [P]review";
    }
    {
      mode = "n";
      key = "<leader>hb";
      action.__raw = "function() require('gitsigns').blame_line({ full = true }) end";
      options.desc = "Git [H]unk [B]lame";
    }
    # Format
    {
      mode = "n";
      key = "<leader>lf";
      action.__raw = "function() require('conform').format({ timeout_ms = 500, lsp_format = 'fallback' }) end";
      options.desc = "[L]SP [F]ormat";
    }
    # REPL (iron.nvim)
    {
      mode = "n";
      key = "<leader>rs";
      action.__raw = "function() require('iron.core').repl_for(vim.bo.filetype) end";
      options.desc = "[R]EPL [S]tart";
    }
    {
      mode = "n";
      key = "<leader>rl";
      action.__raw = "function() require('iron.core').send_line() end";
      options.desc = "[R]EPL Send [L]ine";
    }
    {
      mode = "n";
      key = "<leader>rr";
      action.__raw = "function() require('iron.core').repl_restart(vim.bo.filetype) end";
      options.desc = "[R]EPL [R]estart";
    }
    {
      mode = "n";
      key = "<leader>rh";
      action.__raw = "function() require('iron.core').hide_repl(vim.bo.filetype) end";
      options.desc = "[R]EPL [H]ide";
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
    # Database UI
    {
      mode = "n";
      key = "<leader>db";
      action = "<cmd>DBUIToggle<CR>";
      options = {
        desc = "[D]ata[B]ase UI";
      };
    }
    {
      mode = "n";
      key = "<leader>e";
      action = "vip<Plug>(DBUI_ExecuteQuery)";
      options = {
        desc = "[E]xecute query (block)";
      };
    }
    {
      mode = "v";
      key = "<leader>e";
      action = "<Plug>(DBUI_ExecuteQuery)";
      options = {
        desc = "[E]xecute query (selection)";
      };
    }
    # Diffview
    {
      mode = "n";
      key = "<leader>gd";
      action = "<cmd>DiffviewOpen<CR>";
      options = {
        desc = "[G]it [D]iff";
      };
    }
    {
      mode = "n";
      key = "<leader>gh";
      action = "<cmd>DiffviewFileHistory %<CR>";
      options = {
        desc = "[G]it File [H]istory";
      };
    }
    {
      mode = "v";
      key = "<leader>gh";
      action = "<cmd>'<,'>DiffviewFileHistory<CR>";
      options = {
        desc = "[G]it [H]istory (selected lines)";
      };
    }
    {
      mode = "n";
      key = "<leader>gq";
      action = "<cmd>DiffviewClose<CR>";
      options = {
        desc = "[G]it Diff [Q]uit";
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
    # Base64 encode/decode
    {
      mode = "v";
      key = "<leader>be";
      action = ":B64encode<CR>";
      options.desc = "[B]ase64 [E]ncode";
    }
    {
      mode = "v";
      key = "<leader>bd";
      action = ":B64decode<CR>";
      options.desc = "[B]ase64 [D]ecode";
    }
  ];
}
