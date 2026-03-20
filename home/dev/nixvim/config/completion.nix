{ pkgs, ... }:
{
  plugins = {
    # Snippet engine
    luasnip = {
      enable = true;
      fromVscode = [
        {}
        { paths = ../snippets; }
      ];
    };
    friendly-snippets.enable = true;

    # Autocompletion
    cmp = {
      enable = true;
      settings = {
        snippet.expand = ''
          function(args)
            require('luasnip').lsp_expand(args.body)
          end
        '';
        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<C-y>" = "cmp.mapping.confirm({ select = true })";
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.abort()";
          "<Tab>".__raw = ''
            cmp.mapping(function(fallback)
              local luasnip = require('luasnip')
              if luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
              else
                fallback()
              end
            end, { "i", "s" })
          '';
          "<S-Tab>".__raw = ''
            cmp.mapping(function(fallback)
              local luasnip = require('luasnip')
              if luasnip.jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end, { "i", "s" })
          '';
        };
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "vim-dadbod-completion"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
      };
    };
  };
}
