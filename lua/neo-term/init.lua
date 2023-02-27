local A = require('neo-term.utils.autocmd')
local M = {}
vim.api.nvim_create_augroup('neo-term.lua', { clear = true })
-------------------------------------------------------------------------------------------------------
local buf_open_to_term = {}
local view_of_open_buf = {}


local function remove_invalid_mappings()
  for o, t in pairs(buf_open_to_term) do
    if
      not vim.api.nvim_buf_is_valid(o)
      or (t and not vim.api.nvim_buf_is_valid(t))
    then
      buf_open_to_term[o] = nil
    end
  end
end
-------------------------------------------------------------------------------------------------------
function M.setup(opts)
  if not opts then opts = {} end

  M.term_mode_hl = opts.term_mode_hl or 'NEO_TERM_COOL_BLACK'
    if type(M.term_mode_hl) ~= 'string' then M.term_mode_hl = 'NEO_TERM_COOL_BLACK' end
  M.split_size = opts.split_size or 0.35
    if type(M.split_size) ~= 'number' then M.split_size = 0.35 end
  M.split_on_top = opts.split_on_top or false
    if type(M.split_on_top) ~= 'boolean' then M.split_on_top = true end
  M.exclude_filetypes = opts.exclude_filetypes or {}
    if type(M.exclude_filetypes) ~= 'table' then M.exclude_filetypes = {} end
  M.exclude_buftypes = opts.exclude_buftypes or {}
    if type(M.exclude_buftypes) ~= 'table' then M.exclude_buftypes = {} end

  A.create_autocmds()
end


function M.neo_term_toggle()

  -- Case1: already open.
  if -- TODO: set filetype for NeoTerm.
    vim.bo.buftype == 'terminal' then
    vim.cmd('NeoTermEnterNormal')
    local term_buf = vim.api.nvim_get_current_buf()
    -- TODO: use `nvim_win_close`.
    vim.cmd('q')

    local close_buf = vim.api.nvim_get_current_buf()
    if buf_open_to_term[close_buf] == term_buf then
      vim.fn.winrestview(view_of_open_buf[close_buf])
    end
    remove_invalid_mappings()
    return
  end

  -- Case2: might open.

  for _, v in pairs(M.exclude_filetypes) do if vim.bo.filetype == v then return end end
  for _, v in pairs(M.exclude_buftypes) do if vim.bo.buftype == v then return end end

  -- should open.
  -- if -- a term-win is there then just close it.
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(w) == buf_open_to_term[vim.api.nvim_get_current_buf()] then
      vim.api.nvim_win_close(w, true)
      return
    end
  end


  local open_win = vim.api.nvim_get_current_win()
  local open_buf = vim.api.nvim_get_current_buf()
  view_of_open_buf[open_buf] = vim.fn.winsaveview()
  local open_win_height = vim.fn.getwininfo(open_win)[1].height
  local termbuf_size = open_win_height * M.split_size
  local openbuf_size = open_win_height - termbuf_size
  local backup_splitbelow = vim.opt.splitbelow
  if M.split_on_top
  then vim.opt.splitbelow = false
  else vim.opt.splitbelow = true end

  if M.split_on_top then
    vim.cmd('normal! L')
  else
    vim.cmd('normal! H')
  end
  -- TODO: merge into one single string?
  vim.cmd('split')
  vim.cmd('resize ' .. termbuf_size)
  vim.cmd('wincmd p')
  vim.cmd('resize ' .. openbuf_size)
  vim.cmd('wincmd p') -- cursor at termbuf split

  if buf_open_to_term[open_buf]
    and vim.api.nvim_buf_is_valid(buf_open_to_term[open_buf])
  then
    vim.api.nvim_set_current_buf(buf_open_to_term[open_buf])
  else
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'neo-term')
    vim.api.nvim_set_current_buf(buf)
    vim.fn.termopen(vim.opt.shell:get())
    vim.cmd('startinsert')
    buf_open_to_term[open_buf] = vim.api.nvim_get_current_buf()
  end

  vim.opt.splitbelow = backup_splitbelow
end


local function setup_vim_commands()
  vim.api.nvim_create_user_command('NeoTermToggle', M.neo_term_toggle, {})
  vim.api.nvim_create_user_command('NeoTermEnterNormal', function ()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true), 't', true)
  end, {})
end
setup_vim_commands()


return M