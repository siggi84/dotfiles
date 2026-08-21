-- set <space> as the leader key
-- must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable unused remote providers to keep :checkhealth focused on relevant issues.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0

-- enable true color support
vim.opt.termguicolors = true

-- make line numbers default
vim.opt.number = true
vim.opt.relativenumber = true

-- Change the active window after split
vim.opt.splitbelow = true -- horizontal splits go below
vim.opt.splitright = true -- vertical splits go right

-- enable mouse mode, can be useful for resizing splits
vim.opt.mouse = "a"

-- sync clipboard between OS and neovim.
--  remove this option if you want your OS clipboard to remain independent.
--  see `:help 'clipboard'`
vim.opt.clipboard = "unnamedplus"

-- keep signcolumn on by default
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "89"
vim.opt.showmatch = true -- highlight matching brackets
-- vim.opt.cmdheight = 0 -- single line command line

local undodir = vim.fn.expand("~/.vim/undodir")
if
	vim.fn.isdirectory(undodir) == 0 -- create undodir if nonexistent
then
	vim.fn.mkdir(undodir, "p")
end

vim.opt.backup = false -- do not create a backup file
vim.opt.writebackup = false -- do not write to a backup file
vim.opt.swapfile = false -- do not create a swapfile
vim.opt.undofile = true -- do create an undo file
vim.opt.undodir = undodir -- set the undo directory
vim.opt.updatetime = 300 -- faster completion

vim.opt.autoread = true -- auto-reload changes if outside of neovim
vim.opt.autowrite = false -- do not auto-save
-- sets how neovim will display certain whitespace characters in the editor.
--  see `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣", }

-- enable live preview of substitutions
vim.opt.inccommand = "split"

-- Keep 10 lines above/below or to the sides of cursor
vim.opt.scrolloff = 5
vim.opt.sidescrolloff = 5

-- show which line your cursor is on
vim.opt.cursorline = true

-- set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true

-- set search related case sensitivity
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true

-- enable break indent
vim.opt.breakindent = true

-- formatting
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.textwidth = 88
vim.opt.smartindent = true
vim.opt.autoindent = true

vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.INFO] = " ",
      [vim.diagnostic.severity.HINT] = " ",
    },
  },
  virtual_text = true, -- show inline diagnostics
})


-- clear search highlights with <Esc>
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Undotree (built-in)
vim.keymap.set("n", "<leader>su", function()
  vim.cmd("packadd nvim.undotree")
  vim.cmd.Undotree()
end, { desc = "Open undo tree" })

-- INFO: formatting and syntax highlighting
vim.pack.add({
	{
		src = "https://github.com/nvim-treesitter/nvim-treesitter",
		branch = "main",
	},
}, { confirm = false })

local treesitter = require("nvim-treesitter")
treesitter.setup()
treesitter.install({ "json", "lua", "python", "regex", "rust" })


-- INFO: completion engine
-- Build the fuzzy matcher with `:BlinkCmp build` after installing `rustup`.
-- If no default toolchain is configured yet, run `rustup default stable` once.
vim.pack.add({
  {
    src = "https://github.com/saghen/blink.cmp",
    branch = "v1"
  },
}, { confirm = false })

require("blink.cmp").setup({
  completion = {
    documentation = {
      auto_show = true,
    },
  },
  -- default blink keymaps
  keymap = {
    ['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
    ['<C-n>'] = { 'select_next', 'fallback_to_mappings' },

    ['<C-y>'] = { 'select_and_accept', 'fallback' },
    ['<CR>'] = { 'accept', 'fallback' },
    ['<C-e>'] = { 'cancel', 'fallback' },
    ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },

    ['<Tab>'] = { 'snippet_forward', 'fallback' },
    ['<S-Tab>'] = { 'snippet_backward', 'fallback' },

    ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },

    ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },

    ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },

  },
  fuzzy = {
    implementation = "prefer_rust",
  },
})

vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig", -- default configs for lsps
}, { confirm = false })

-- lsp servers we want to use and their configuration
-- see `:h lspconfig-all` for available servers and their settings
local lsp_servers = {
  lua_ls = {

    -- https://luals.github.io/wiki/settings/ | `:h nvim_get_runtime_file`
    Lua = { workspace = { library = vim.api.nvim_get_runtime_file("lua", true) }, },

  },
  basedpyright = {},
}


-- Filter code actions down to "source" actions so <leader>cA behaves like
-- LazyVim's source-action binding. Neovim exposes code_action(), but not a
-- separate built-in helper specifically for source actions.
local function lsp_source_action()
  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source" },
      diagnostics = vim.diagnostic.get(0),
    },
  })
end

-- configure each lsp server on the table
-- to check what clients are attached to the current buffer, use
-- `:checkhealth vim.lsp`. to view default lsp keybindings, use `:h lsp-defaults`.
for server, config in pairs(lsp_servers) do
  vim.lsp.config(server, {
    settings = config,
    capabilities = require("blink.cmp").get_lsp_capabilities(),

    -- only create the keymaps if the server attaches successfully
    on_attach = function(_, bufnr)
      vim.keymap.set("n", "grf", vim.lsp.buf.format,
        { buffer = bufnr, desc = "Format buffer", })

      vim.keymap.set("n", "gK", vim.lsp.buf.signature_help,
        { buffer = bufnr, desc = "Signature help", })

      vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help,
        { buffer = bufnr, desc = "Signature help", })

      vim.keymap.set("n", "<leader>cl", function() Snacks.picker.lsp_config() end,
        { buffer = bufnr, desc = "Lsp Info", })

      vim.keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action,
        { buffer = bufnr, desc = "Code Action", })

      vim.keymap.set({ "n", "x" }, "<leader>cc", vim.lsp.codelens.run,
        { buffer = bufnr, desc = "Run Codelens", })

      vim.keymap.set("n", "<leader>cC", vim.lsp.codelens.refresh,
        { buffer = bufnr, desc = "Refresh & Display Codelens", })

      vim.keymap.set("n", "<leader>cR", function() Snacks.rename.rename_file() end,
        { buffer = bufnr, desc = "Rename File", })

      vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename,
        { buffer = bufnr, desc = "Rename", })

      vim.keymap.set("n", "<leader>cA", lsp_source_action,
        { buffer = bufnr, desc = "Source Action", })
    end,
  })

  vim.lsp.enable(server)
end

-- Flash.nvim
vim.pack.add({ "https://github.com/folke/flash.nvim" }, { confirm = false })
require("flash").setup({
  labels = "arstgmneioqwfpbjluyzxcdvkh",
})

vim.keymap.set({ "n", "x", "o" }, "s", function()
  require("flash").jump()
end, { desc = "Flash" })

vim.keymap.set({ "n", "x", "o" }, "S", function()
  require("flash").treesitter({
    actions = {
      [";"] = "next",
      [","] = "prev",
    },
  })
end, { desc = "Treesitter incremental selection" })

vim.keymap.set("o", "r", function()
  require("flash").remote()
end, { desc = "Remote Flash" })

vim.keymap.set({ "o", "x" }, "R", function()
  require("flash").treesitter_search()
end, { desc = "Treesitter Search" })

vim.keymap.set("c", "<C-s>", function()
  require("flash").toggle()
end, { desc = "Toggle Flash Search" })

-- Mini
vim.pack.add({ "https://github.com/nvim-mini/mini.nvim" }, { confirm = false })
require('mini.surround').setup({
  mappings = {
    add = 'gsa',
    delete = 'gsd',
    find = 'gsf',
    find_left = 'gsF',
    highlight = 'gsh',
    replace = 'gsr',
    suffix_last = 'l',
    suffix_next = 'n',
  },
})
require('mini.bracketed').setup({})
require('mini.comment').setup({})
require('mini.pairs').setup({})
require('mini.ai').setup({})
require("mini.trailspace").setup({})
require("mini.bufremove").setup({})
require("mini.notify").setup({
  lsp_progress = {
    enable = false,
  },
})
require("mini.files").setup({
  mappings = {
    close       = "q",
    go_in       = "",
    go_in_plus  = "<CR>",
    go_out      = "<BS>",
    go_out_plus = "H",
    mark_goto   = "'",
    mark_set    = "m",
    reset       = "g<BS>",
    reveal_cwd  = "@",
    show_help   = "g?",
    synchronize = "=",
    trim_left   = "<",
    trim_right  = ">",
  },
})
vim.keymap.set("n", "<leader>e", function()
  MiniFiles.open()
end, { desc = "Open Files" })


-- Snacks
vim.pack.add({ "https://github.com/folke/snacks.nvim" }, { confirm = false })
require("snacks").setup({
  picker = { enabled = true, ui_select = true},
  lazygit = { enabled = true },
  terminal = { enabled = true },
  zen = { enabled = true },
})
vim.ui.select = Snacks.picker.select


-- Zoom mode
local zoom_toggle = require("snacks.toggle").zoom()
  vim.keymap.set("n", "<leader>z", function()
    zoom_toggle:toggle()
  end, { desc = "Toggle zoom" })

-- Spell toggle
local spell_toggle = require("snacks.toggle").option("spell", { name = "Spelling" })
vim.keymap.set("n", "<leader>us", function()
  spell_toggle:toggle()
end, { desc = "Toggle spelling" })

local line_number_toggle = require("snacks.toggle").line_number()
vim.keymap.set("n", "<leader>ul", function()
  line_number_toggle:toggle()
end, { desc = "Toggle line numbers" })

local relative_number_toggle = require("snacks.toggle").option("relativenumber", { name = "Relative Number" })
vim.keymap.set("n", "<leader>uL", function()
  relative_number_toggle:toggle()
end, { desc = "Toggle relative numbers" })

local inlay_hints_toggle = require("snacks.toggle").inlay_hints()
vim.keymap.set("n", "<leader>uh", function()
  inlay_hints_toggle:toggle()
end, { desc = "Toggle inlay hints" })

vim.keymap.set("n", "<leader>ff", function() require("snacks").picker.files() end, { desc = "Find files" })
vim.keymap.set("n", "<leader>/", function() require("snacks").picker.grep() end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", function() require("snacks").picker.buffers() end, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fg", function() require("snacks").picker.git_files() end, { desc = "Find git files" })
vim.keymap.set("n", "<leader>gb", function() require("snacks").picker.git_branches() end, { desc = "Git branches" })
vim.keymap.set("n", "<leader>fr", function() require("snacks").picker.recent() end, { desc = "Recent files" })
vim.keymap.set("n", "<leader>fC", function() require("snacks").picker.colorschemes() end, { desc = "Find colorschemes" })

vim.keymap.set("n", "gd", function() require("snacks").picker.lsp_definitions() end, { desc = "LSP definitions" })
vim.keymap.set("n", "gD", function() require("snacks").picker.lsp_declarations() end, { desc = "LSP declarations" })
vim.keymap.set("n", "gr", function() require("snacks").picker.lsp_references() end, { desc = "LSP references" })
vim.keymap.set("n", "gI", function() require("snacks").picker.lsp_implementations() end, { desc = "LSP implementations" })
vim.keymap.set("n", "gy", function() require("snacks").picker.lsp_type_definitions() end, { desc = "LSP type definitions" })

vim.keymap.set("n", "<leader>gg", function()
  Snacks.lazygit()
end, { desc = "Open lazygit" })
vim.keymap.set({ "n", "t" }, "<c-t>", function() Snacks.terminal() end, { desc = "Toggle terminal" })

-- Nightfox theme
vim.pack.add({ "https://github.com/EdenEast/nightfox.nvim" }, { confirm = false })
require("nightfox").setup({
  options = {
    colorblind = {
     enable = true,
      severity = {
        protan = 0.5,
        deutan = 1.0,
        tritan = 0.0,
      },
    },
  },
})

-- Lualine.nvim
vim.pack.add({
  {
    src = "https://github.com/nvim-lualine/lualine.nvim",
  },
}, { confirm = false })
require('lualine').setup()


vim.pack.add({"https://github.com/nvim-lua/plenary.nvim"}, {confirm = false})
vim.pack.add({"https://github.com/neogitorg/neogit"},  { confirm = false})
require("neogit").setup({})

-- INFO: colorscheme
vim.cmd.colorscheme("nightfox")

local augroup = vim.api.nvim_create_augroup("user_config", { clear = true })

-- return to last cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup,
	desc = "Restore last cursor position",
	callback = function()
		if vim.o.diff then -- except in diff mode
			return
		end

		local last_pos = vim.api.nvim_buf_get_mark(0, '"') -- {line, col}
		local last_line = vim.api.nvim_buf_line_count(0)

		local row = last_pos[1]
		if row < 1 or row > last_line then
			return
		end

		pcall(vim.api.nvim_win_set_cursor, 0, last_pos)
	end,
})

-- wrap, linebreak and spellcheck on markdown and text files
vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = { "text", "gitcommit" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true
		vim.opt_local.spell = true
	end,
})

-- wrap, linebreak and spellcheck on markdown and text files
vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = { "markdown" },
	callback = function()
    vim.opt_local.conceallevel = 2 -- Or 3 for complete hiding
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true
		vim.opt_local.spell = true
	end,
})

-- Keymaps
-- Move to window using the <alt> mnei keys
vim.keymap.set("n", "<A-m>", "<C-w>h", { desc = "Go to left window", remap = true })
vim.keymap.set("n", "<A-n>", "<C-w>j", { desc = "Go to lower window", remap = true })
vim.keymap.set("n", "<A-e>", "<C-w>k", { desc = "Go to upper window", remap = true })
vim.keymap.set("n", "<A-i>", "<C-w>l", { desc = "Go to right window", remap = true })

vim.keymap.set("i", "<A-m>", "<Esc><C-w>h", { desc = "Go to left window", remap = true })
vim.keymap.set("i", "<A-n>", "<Esc><C-w>j", { desc = "Go to lower window", remap = true })
vim.keymap.set("i", "<A-e>", "<Esc><C-w>k", { desc = "Go to upper window", remap = true })
vim.keymap.set("i", "<A-i>", "<Esc><C-w>l", { desc = "Go to right window", remap = true })

vim.keymap.set("t", "<A-m>", "<c-\\><c-n><c-w>h", { desc = "Go to left window", remap = true })
vim.keymap.set("t", "<A-n>", "<c-\\><c-n><c-w>j", { desc = "Go to lower window", remap = true })
vim.keymap.set("t", "<A-e>", "<c-\\><c-n><c-w>k", { desc = "Go to upper window", remap = true })
vim.keymap.set("t", "<A-i>", "<c-\\><c-n><c-w>l", { desc = "Go to right window", remap = true })

vim.keymap.set("n", "<A-Left>", "<Cmd>vertical resize -2<cr>", { desc = "Decrease window width", remap = true })
vim.keymap.set("n", "<A-Down>", "<Cmd>resize -2<cr>", { desc = "Decrease window height", remap = true })
vim.keymap.set("n", "<A-Up>", "<Cmd>resize +2<cr>", { desc = "Increase window height", remap = true })
vim.keymap.set("n", "<A-Right>", "<Cmd>vertical resize +2<cr>", { desc = "Increase window width", remap = true })

-- Convenience
vim.keymap.set("n", "<leader>uw", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle wrap" })

vim.keymap.set("x", "<leader>p", '"_dP', { desc = "Paste without yanking" })
vim.keymap.set({ "n", "v" }, "<leader>x", '"_d', { desc = "Delete without yanking" })

vim.keymap.set("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Delete other buffers" })

vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })
