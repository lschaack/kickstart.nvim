-- claude_path.lua
-- A Neovim extension to copy the current file path as a Claude Code context path

local M = {}

local function get_claude_path()
  -- Get the current file path
  local file_path = vim.fn.expand '%:p'
  if file_path == '' then
    print 'No file is open'
    return nil
  end

  -- Get the git root directory
  local git_root_cmd = string.format('cd %s && git rev-parse --show-toplevel 2>/dev/null', vim.fn.shellescape(vim.fn.fnamemodify(file_path, ':h')))
  local git_root = vim.fn.trim(vim.fn.system(git_root_cmd))

  if vim.v.shell_error ~= 0 then
    print 'Not in a git repository'
    return nil
  end

  -- Get the relative path within the repository
  local rel_path = string.sub(file_path, string.len(git_root) + 2)

  -- Format as Claude Code context path
  return '@' .. rel_path
end

function M.copy_claude_path()
  local path = get_claude_path()
  if path then
    vim.fn.setreg('+', path) -- Copy to system clipboard
    vim.fn.setreg('"', path) -- Copy to unnamed register
    print('Claude path copied to clipboard: ' .. path)
    return path
  end
  return nil
end

-- Command to copy Claude path
vim.api.nvim_create_user_command('CopyClaudePath', function()
  M.copy_claude_path()
end, {})

return M