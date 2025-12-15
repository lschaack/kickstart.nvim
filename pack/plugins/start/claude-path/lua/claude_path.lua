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

  -- Get the current working directory
  local cwd = vim.fn.getcwd()

  -- Check if file is under cwd
  if not vim.startswith(file_path, cwd) then
    print('File is not under current working directory: ' .. cwd)
    return nil
  end

  -- Get the relative path from cwd
  local rel_path = string.sub(file_path, string.len(cwd) + 2)

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