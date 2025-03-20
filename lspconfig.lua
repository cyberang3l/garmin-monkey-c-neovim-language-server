return {
  {
    -- For more configuration options, see:
    --  https://github.com/neovim/nvim-lspconfig/tree/master/lua/lspconfig/configs
    "neovim/nvim-lspconfig",
    init = function()
      -- Define a custom language server for monkeyc
      local configs = require("lspconfig.configs")
      local lspconfig = require("lspconfig")

      local function get_monkeyc_language_server_path()
        local workspace_dir = table.concat(vim.fn.readfile(vim.fn.expand("~/.Garmin/ConnectIQ/current-sdk.cfg")), "\n")
        local jar_path = workspace_dir .. "/bin/LanguageServer.jar"

        if vim.fn.filereadable(jar_path) == 1 then
          return jar_path
        end
        print("Monkey C Language Server not found: " .. jar_path)
        return nil
      end

      local monkeyc_ls_jar = get_monkeyc_language_server_path()
      if monkeyc_ls_jar then
        -- To enable tracing of the official VSCode plugin, add the following snippet
        -- under "contributes" -> "configuration" -> "properties"
        -- in ~/.vscode/extensions/garmin.monkey-c-1.1.1/package.json
        --
        -- "monkeyc.trace.server": {
        -- 	"scope": "window",
        -- 	"type": "string",
        -- 	"enum": [
        -- 		"off",
        -- 		"messages",
        -- 		"verbose"
        -- 	],
        -- 	"default": "verbose",
        -- 	"description": "Traces the communication between VS Code and the language server."
        -- },
        --
        -- Then open a MonkeyC project and check the VSCode "Output" window
        --
        -- To debug the nvim plugin:
        -- tail -f ~/.local/state/nvim/lsp.log
        --
        -- Uncomment the following to enable debug logging
        -- vim.lsp.set_log_level("debug")
        --
        -- Open a MonkeyC project and check the lsp.log output
        --
        local monkeycLspCapabilities = vim.lsp.protocol.make_client_capabilities()
        -- Need to set some variables in the client capabilities to prevent the
        -- LanguageServer from raising exceptions
        monkeycLspCapabilities.textDocument.declaration.dynamicRegistration = true
        monkeycLspCapabilities.textDocument.implementation.dynamicRegistration = true
        monkeycLspCapabilities.textDocument.typeDefinition.dynamicRegistration = true
        monkeycLspCapabilities.textDocument.documentHighlight.dynamicRegistration = true
        monkeycLspCapabilities.workspace = {
          didChangeWorkspaceFolders = {
            dynamicRegistration = true,
          },
        }
        monkeycLspCapabilities.textDocument.foldingRange = {
          lineFoldingOnly = true,
          dynamicRegistration = true,
        }

        if not configs.monkeyc_ls then
          local root = lspconfig.util.root_pattern("manifest.xml") or vim.fn.getcwd()
          configs.monkeyc_ls = {
            default_config = {
              cmd = {
                "java",
                "-Dapple.awt.UIElement=true",
                "-classpath",
                monkeyc_ls_jar,
                "com.garmin.monkeybrains.languageserver.LSLauncher",
              },
              filetypes = { "monkey-c", "monkeyc", "jungle", "mss" },
              root_dir = root,
              settings = {
                {
                  developerKeyPath = vim.g.monkeyc_connect_iq_dev_key_path
                    or vim.fn.expand("~/.Garmin/connect_iq_dev_key.der"),
                  compilerWarnings = true,
                  compilerOptions = vim.g.monkeyc_compiler_options or "",
                  developerId = "",
                  jungleFiles = "monkey.jungle",
                  javaPath = "",
                  typeCheckLevel = "Default",
                  optimizationLevel = "Default",
                  testDevices = {
                    "enduro3", -- get this dynamically from the manifest file
                  },
                  debugLogLevel = "Default",
                },
              },
              capabilities = monkeycLspCapabilities,
              init_options = {
                publishWarnings = vim.g.monkeyc_publish_warnings or true,
                compilerOptions = vim.g.monkeyc_compiler_options or "",
                typeCheckMsgDisplayed = true,
                workspaceSettings = {
                  {
                    path = root(vim.fn.getcwd()),
                    jungleFiles = {
                      root(vim.fn.getcwd()) .. "/monkey.jungle",
                    },
                  },
                },
              },
              on_attach = function(client, bufnr)
                local methods = vim.lsp.protocol.Methods
                local req = client.request

                client.request = function(method, params, handler, bufnr_req)
                  -- The Garmin LanguageServer returns broken file URIs for
                  -- "textDocument/definition" requests that look like this:
                  --
                  --   "file:/absolute/path/to/file"
                  --
                  -- This doesn't work (notice the single / after the 'file:')
                  -- and must be converted to the following (notice the three
                  -- slashes):
                  --
                  --   "file:///absolute/path/to/file"
                  --
                  -- The following code overrides the response 'handler' for
                  -- "textDocument/definition" requests
                  --
                  -- https://www.reddit.com/r/neovim/comments/1j6tv9y/comment/mgyqbha/
                  --
                  if method == methods.textDocument_definition then
                    -- Override the response handler for "textDocument/definition" requests
                    return req(method, params, function(err, result, context, config)
                      local function fix_uri(uri)
                        if uri:match("^file:/[^/]") then
                          uri = uri:gsub("^file:/", "file:///") -- Fix missing slashes
                        end
                        return uri
                      end

                      -- Fix the URLs as needed
                      if vim.islist(result) then
                        for _, res in ipairs(result) do
                          if res.uri then
                            res.uri = fix_uri(res.uri)
                          end
                        end
                      elseif result.uri then
                        result.uri = fix_uri(result.uri)
                      end

                      -- Call the response handler with the fixed URIs in the result
                      return handler(err, result, context, config)
                    end, bufnr_req)
                  else
                    -- Use the default response handlers for all other requests
                    return req(method, params, handler, bufnr_req)
                  end
                end
              end,
            },
          }
        end

        -- print(vim.lsp.client.config)
        lspconfig.monkeyc_ls.setup({})
      end

      -- Configure docs hover popup toggle with <M-h>
      vim.keymap.set({ "n" }, "\x18@sh", function()
        for _, winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
          -- if zindex > 0, it the window is a float window - hover popups are float windows
          if vim.api.nvim_win_get_config(winid).zindex then
            -- Close float windows and return
            vim.cmd.fclose()
            return
          end
        end
        -- If no hover windows found, call hover()
        vim.lsp.buf.hover()
      end, { silent = true, noremap = true, buffer = true })
      -- Configure <M-j> to enter the hover window if we need to scroll through a long docstring
      -- Double calling of hover enters the float window and allows for browsing the window. Use
      -- 'q' to exit the floating window if you've entered.
      vim.keymap.set({ "n" }, "\x18@sj", function()
        for _, winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.api.nvim_win_get_config(winid).zindex then
            vim.lsp.buf.hover()
            return
          end
        end
      end, { silent = true, noremap = true, buffer = true })
    end,
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- pyright will be automatically installed with mason and loaded with lspconfig
        pyright = {
          settings = {
            python = {
              analysis = {
                autoSearchPaths = true,
              },
              pythonPath = vim.fn.exepath("python3"),
            },
          },
        },
        ansiblels = {},
        bashls = {},
        cssls = {},
        dockerls = {},
        emmet_ls = {},
        gopls = {},
        html = {},
        jsonls = {},
        lua_ls = {},
        rust_analyzer = {},
        sqlls = {},
        tailwindcss = {},
        terraformls = {},
        tsserver = {},
        yamlls = {},
        clangd = {},
        vimls = {},
        cmake = {},
      },
      setup = {
        -- If you require more advanced setup for language server through lua/vim
        -- scripting, use this function as follows and return true to override the
        -- lspconfig options from above
        ["pyright"] = function(_, opts)
          -- The following is not taken into account unless you return "true".
          -- Keeping this code block here for reference
          --
          -- Use vim.inspect to inspect options
          -- print(vim.inspect(opts))
          -- local venv = vim.fn.getenv("VIRTUAL_ENV")
          -- print(vim.fn.exepath("python3"))
          require("lspconfig").pyright.setup({
            settings = {
              python = {
                analysis = {
                  autoSearchPaths = true,
                },
                pythonPath = vim.fn.exepath("python3"),
              },
            },
          })
          return false
        end,
        -- Specify * to use this function as a fallback for any server
        -- ["*"] = function(server, opts) end,
      },
    },
  },
}
