-- github_url.lua
-- A Neovim extension to copy the GitHub URL for the current file
-- Supports both GitHub.com and GitHub Enterprise instances

local M = {}

local function get_github_url()
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

  -- Get the remote URL
  local remote_url_cmd = string.format('cd %s && git config --get remote.origin.url', vim.fn.shellescape(git_root))
  local remote_url = vim.fn.trim(vim.fn.system(remote_url_cmd))

  if vim.v.shell_error ~= 0 or remote_url == '' then
    print 'No remote origin found'
    return nil
  end

  -- Transform URL to HTTPS URL
  local github_url

  -- Handle SSH GitHub Enterprise URLs: git@github.example.com:org/repo.git
  if string.match(remote_url, '^git@([^:]+):') then
    local domain = string.match(remote_url, '^git@([^:]+):')
    local repo_path = string.match(remote_url, '^git@[^:]+:(.+)')
    repo_path = string.gsub(repo_path, '%.git$', '')
    github_url = 'https://' .. domain .. '/' .. repo_path

  -- Handle HTTPS GitHub Enterprise URLs: https://github.example.com/org/repo.git
  elseif string.match(remote_url, '^https://') then
    github_url = string.gsub(remote_url, '%.git$', '')

  -- Handle git protocol URLs: git://github.example.com/org/repo.git
  elseif string.match(remote_url, '^git://([^/]+)/') then
    local domain = string.match(remote_url, '^git://([^/]+)/')
    local repo_path = string.match(remote_url, '^git://[^/]+/(.+)')
    repo_path = string.gsub(repo_path, '%.git$', '')
    github_url = 'https://' .. domain .. '/' .. repo_path

  -- Handle other URL formats or return error
  else
    print('Unsupported git remote URL format: ' .. remote_url)
    return nil
  end

  -- Get the currently checked out branch
  local current_branch_cmd = string.format('cd %s && git rev-parse --abbrev-ref HEAD', vim.fn.shellescape(git_root))
  local current_branch = vim.fn.trim(vim.fn.system(current_branch_cmd))

  if vim.v.shell_error ~= 0 or current_branch == '' then
    print 'Could not determine current branch'
    return nil
  end

  -- Check if the GitHub instance uses the standard /blob/ URL format
  -- (Some enterprise instances might have different URL structures)
  local blob_path = '/blob/'

  -- Combine to form the GitHub blob URL
  local full_url = github_url .. blob_path .. current_branch .. '/' .. rel_path

  -- Add line number if cursor is on a specific line
  local current_line = vim.fn.line '.'
  if current_line > 0 then
    full_url = full_url .. '#L' .. current_line
  end

  return full_url
end

function M.copy_github_url()
  local url = get_github_url()
  if url then
    vim.fn.setreg('+', url) -- Copy to system clipboard
    vim.fn.setreg('"', url) -- Copy to unnamed register
    print('GitHub URL copied to clipboard: ' .. url)
    return url
  end
  return nil
end

-- Command to copy GitHub URL
vim.api.nvim_create_user_command('CopyGitHubURL', function()
  M.copy_github_url()
end, {})

-- Optional: create a keybinding
-- vim.api.nvim_set_keymap('n', '<leader>gu', "<cmd>lua require('github_url').copy_github_url()<CR>", {noremap = true, silent = true})

return M
