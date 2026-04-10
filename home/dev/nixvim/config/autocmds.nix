{
  userCommands = {
    B64encode = {
      range = true;
      command = "'<,'>!base64 -w0";
      desc = "Base64 encode selection";
    };
    B64decode = {
      range = true;
      command = "'<,'>!base64 -d";
      desc = "Base64 decode selection";
    };
  };

  # https://nix-community.github.io/nixvim/NeovimOptions/autoGroups/index.html
  autoGroups = {
    kickstart-highlight-yank = {
      clear = true;
    };
  };

  # [[ Basic Autocommands ]]
  #  See `:help lua-guide-autocommands`
  # https://nix-community.github.io/nixvim/NeovimOptions/autoCmd/index.html
  autoCmd = [
    # Highlight when yanking (copying) text
    #  Try it with `yap` in normal mode
    #  See `:help vim.hl.on_yank()`
    {
      event = [ "TextYankPost" ];
      desc = "Highlight when yanking (copying) text";
      group = "kickstart-highlight-yank";
      callback.__raw = ''
        function()
          vim.hl.on_yank()
        end
      '';
    }
    # Expand all folds in DBUI result buffers
    {
      event = [ "FileType" ];
      pattern = [ "dbout" ];
      callback.__raw = ''
        function()
          vim.opt_local.foldenable = false
        end
      '';
    }
    # F# filetype detection (Vim defaults .fs to Forth)
    {
      event = [
        "BufNewFile"
        "BufRead"
      ];
      pattern = [
        "*.fs"
        "*.fsx"
        "*.fsi"
      ];
      callback.__raw = ''
        function()
          vim.bo.filetype = 'fsharp'
          vim.bo.commentstring = '// %s'
        end
      '';
    }
  ];

  # F# workspace notification handler - track loaded solution/projects
  extraConfigLua = ''
    -- Global state to track F# workspace
    vim.g.fsharp_workspace = {
      solution = nil,
      projects = {},
      loading = false,
    }

    vim.lsp.handlers['fsharp/notifyWorkspace'] = function(err, result, ctx, config)
      if not result or not result.content then return end

      local data = vim.json.decode(result.content)
      if not data then return end

      if data.Kind == "projectLoading" and data.Data and data.Data.Project then
        local path = data.Data.Project
        if path:match("%.sln$") then
          -- New solution loading, reset state
          vim.g.fsharp_workspace = {
            solution = path,
            projects = {},
            loading = true,
          }
        end
      elseif data.Kind == "project" and data.Data and data.Data.Project then
        -- Add project to list
        local ws = vim.g.fsharp_workspace
        table.insert(ws.projects, data.Data.Project)
        vim.g.fsharp_workspace = ws
      elseif data.Kind == "workspaceLoad" and data.Data and data.Data.Status == "finished" then
        local ws = vim.g.fsharp_workspace
        ws.loading = false
        vim.g.fsharp_workspace = ws
      end
    end
  '';
}
