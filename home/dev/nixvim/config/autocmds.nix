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
      event = ["TextYankPost"];
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
      event = ["FileType"];
      pattern = ["dbout"];
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

    -- FSAC appends a VS Code-only widget to every hover for a symbol that has
    -- an XmlDocSig:
    --   <a href='command:fsharp.showDocumentation?...'>Open the documentation</a>
    -- command: URIs are a VS Code mechanism -- Ionide registers the command and
    -- VS Code's markdown renderer whitelists the link. Neovim renders hover as
    -- plain markdown with no HTML parsing, so the raw tag shows up instead.
    -- FSAC 0.83 has no setting to suppress it, so strip it client-side.
    --
    -- This has to hook open_floating_preview, NOT a textDocument/hover handler:
    -- since 0.11 vim.lsp.buf.hover() passes its own callback to buf_request_all
    -- and renders the result itself, so neither client.handlers nor
    -- vim.lsp.handlers.hover is ever consulted (see runtime lua/vim/lsp/buf.lua).
    -- By open_floating_preview time the payload is already a string[] of
    -- markdown lines, so scrub per line and drop lines that were only the widget.
    local function fsharp_scrub_vscode_links(s)
      return (s:gsub("<a href='command:[^']*'>.-</a>", ""))
    end

    local _open_floating_preview = vim.lsp.util.open_floating_preview
    vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
      if type(contents) == 'table' then
        -- Cheap scan first: leave every other hover's table untouched, so this
        -- is a genuine no-op for non-F# servers rather than a rebuild-per-hover.
        local found = false
        for _, line in ipairs(contents) do
          if type(line) == 'string' and line:find("<a href='command:", 1, true) then
            found = true
            break
          end
        end
        if found then
          local kept = {}
          for _, line in ipairs(contents) do
            if type(line) == 'string' then
              local had_link = line:find("<a href='command:", 1, true) ~= nil
              local scrubbed = fsharp_scrub_vscode_links(line)
              -- drop the line entirely if the widget was all it contained
              if not (had_link and scrubbed:match('^%s*$')) then
                kept[#kept + 1] = scrubbed
              end
            else
              kept[#kept + 1] = line
            end
          end
          contents = kept
        end
      end
      return _open_floating_preview(contents, syntax, opts, ...)
    end

    -- Disable AutomaticWorkspaceInit. With multiple .sln files in one
    -- workspace root fsautocomplete picks one alphabetically; here we let
    -- the user choose explicitly via a telescope prompt on attach (or
    -- :FSharpSelectSolution).
    vim.lsp.config('fsautocomplete', {
      init_options = { AutomaticWorkspaceInit = false },
    })

    local fsharp_state_file = vim.fn.stdpath('state') .. '/fsharp-solution-by-root.json'
    local fsharp_prompted = {}

    local function fidget_notify(msg, level)
      require('fidget').notify(msg, level)
    end

    local function fsharp_load_state()
      if vim.fn.filereadable(fsharp_state_file) ~= 1 then return {} end
      local lines = vim.fn.readfile(fsharp_state_file)
      if #lines == 0 then return {} end
      local ok, decoded = pcall(vim.json.decode, table.concat(lines, '\n'))
      return ok and decoded or {}
    end

    local function fsharp_save_state(state)
      vim.fn.mkdir(vim.fn.fnamemodify(fsharp_state_file, ':h'), 'p')
      vim.fn.writefile({ vim.json.encode(state) }, fsharp_state_file)
    end

    local function fsharp_parse_sln(sln_path)
      local sln_dir = vim.fn.fnamemodify(sln_path, ':h')
      local projects = {}
      local f = io.open(sln_path, 'r')
      if not f then return projects end
      for line in f:lines() do
        local rel = line:match('"([^"]+%.[fc]sproj)"')
        if rel then
          rel = rel:gsub('\\', '/')
          table.insert(projects, vim.fs.normalize(sln_dir .. '/' .. rel))
        end
      end
      f:close()
      return projects
    end

    local function fsharp_load_solution(client, sln_path)
      local projects = fsharp_parse_sln(sln_path)
      if #projects == 0 then
        fidget_notify('No project entries in ' .. sln_path, vim.log.levels.WARN)
        return
      end
      local docs = vim.tbl_map(function(p)
        return { Uri = vim.uri_from_fname(p) }
      end, projects)
      vim.g.fsharp_workspace = { solution = sln_path, projects = {}, loading = true }
      client:request('fsharp/workspaceLoad', { TextDocuments = docs }, function(err)
        if err then
          fidget_notify('F# workspaceLoad failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
          return
        end
        fidget_notify('F# loaded ' .. vim.fn.fnamemodify(sln_path, ':t') .. ' (' .. #projects .. ' projects)')
        local state = fsharp_load_state()
        state[client.config.root_dir] = sln_path
        fsharp_save_state(state)
      end)
    end

    -- Pre-select the .sln whose project list contains the buffer that
    -- triggered LspAttach (or the current buffer for manual invocation).
    local function fsharp_default_idx(slns, bufnr)
      local fname = bufnr and vim.api.nvim_buf_get_name(bufnr) or ""
      if fname == "" then return 1 end
      for i, sln in ipairs(slns) do
        for _, proj in ipairs(fsharp_parse_sln(sln)) do
          local proj_dir = vim.fn.fnamemodify(proj, ':h') .. '/'
          if vim.startswith(fname, proj_dir) then return i end
        end
      end
      return 1
    end

    local function fsharp_pick_solution(client, bufnr, on_pick)
      local slns = vim.fn.glob(client.config.root_dir .. '/*.sln', false, true)
      if #slns == 0 then
        fidget_notify('No .sln files in ' .. client.config.root_dir, vim.log.levels.WARN)
        return
      end
      if #slns == 1 then on_pick(slns[1]); return end

      local pickers = require('telescope.pickers')
      local finders = require('telescope.finders')
      local conf = require('telescope.config').values
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')
      local themes = require('telescope.themes')

      pickers.new(themes.get_dropdown({
        layout_config = { width = 0.4, height = 0.3 },
      }), {
        prompt_title = 'Choose F# solution',
        finder = finders.new_table({
          results = slns,
          entry_maker = function(p)
            return { value = p, display = vim.fn.fnamemodify(p, ':t'), ordinal = p }
          end,
        }),
        sorter = conf.generic_sorter({}),
        default_selection_index = fsharp_default_idx(slns, bufnr),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local sel = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if sel then on_pick(sel.value) end
          end)
          return true
        end,
      }):find()
    end

    local function fsharp_pick_and_load(client, bufnr)
      fsharp_pick_solution(client, bufnr, function(sln)
        fsharp_load_solution(client, sln)
      end)
    end

    vim.api.nvim_create_autocmd('LspAttach', {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= 'fsautocomplete' then return end
        local root = client.config.root_dir
        if not root or fsharp_prompted[root] then return end
        fsharp_prompted[root] = true

        local state = fsharp_load_state()
        if state[root] and vim.fn.filereadable(state[root]) == 1 then
          fsharp_load_solution(client, state[root])
          return
        end
        fsharp_pick_and_load(client, args.buf)
      end,
    })

    vim.api.nvim_create_autocmd('LspDetach', {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= 'fsautocomplete' then return end
        local root = client.config.root_dir
        if root then fsharp_prompted[root] = nil end
      end,
    })

    vim.api.nvim_create_user_command('FSharpSelectSolution', function()
      local clients = vim.lsp.get_clients({ name = 'fsautocomplete' })
      if #clients == 0 then
        fidget_notify('No fsautocomplete client attached', vim.log.levels.WARN)
        return
      end
      fsharp_pick_and_load(clients[1], vim.api.nvim_get_current_buf())
    end, { desc = 'Pick which .sln fsautocomplete should load' })
  '';
}
