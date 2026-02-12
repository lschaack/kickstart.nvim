-- github_url.lua
-- A Neovim extension to copy the GitHub URL for the current file
-- Supports both GitHub.com and GitHub Enterprise instances

local M = {}

-- Detect the default/main branch name
local function get_default_branch(git_root)
  -- Try to get the default branch from remote HEAD
  local cmd = string.format('cd %s && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null', vim.fn.shellescape(git_root))
  local result = vim.fn.trim(vim.fn.system(cmd))
  if vim.v.shell_error == 0 and result ~= '' then
    local branch = string.match(result, 'refs/remotes/origin/(.+)')
    if branch and branch ~= '' then
      return branch
    end
  end

  -- Fallback: try common branch names
  local common_branches = { 'main', 'master', 'develop', 'staging' }
  for _, branch in ipairs(common_branches) do
    local check_cmd = string.format('cd %s && git rev-parse --verify %s 2>/dev/null', vim.fn.shellescape(git_root), branch)
    local output = vim.fn.trim(vim.fn.system(check_cmd))
    if vim.v.shell_error == 0 and output ~= '' then
      return branch
    end
  end

  return nil
end

-- Get the merge base commit between HEAD and the default branch
local function get_merge_base_ref(git_root)
  local default_branch = get_default_branch(git_root)
  if not default_branch then
    return nil, nil
  end

  local cmd = string.format('cd %s && git merge-base HEAD origin/%s 2>/dev/null', vim.fn.shellescape(git_root), default_branch)
  local merge_base = vim.fn.trim(vim.fn.system(cmd))

  if vim.v.shell_error == 0 and merge_base ~= '' then
    return merge_base, default_branch
  end

  return nil, nil
end

-- Check if a specific line content exists at a given line number in a ref
local function line_exists_at_ref(git_root, ref, rel_path, line_num, line_content)
  local cmd = string.format(
    'cd %s && git show %s:%s 2>/dev/null | sed -n %dp',
    vim.fn.shellescape(git_root),
    ref,
    vim.fn.shellescape(rel_path),
    line_num
  )
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false
  end

  -- Compare trimmed content to handle whitespace differences
  return vim.fn.trim(result) == vim.fn.trim(line_content)
end

-- Get the remote ref for the current branch
local function get_remote_branch_ref(git_root)
  local current_branch_cmd = string.format('cd %s && git rev-parse --abbrev-ref HEAD', vim.fn.shellescape(git_root))
  local current_branch = vim.fn.trim(vim.fn.system(current_branch_cmd))

  if vim.v.shell_error ~= 0 or current_branch == '' then
    return nil, nil
  end

  -- Check if the remote tracking branch exists
  local remote_ref = 'origin/' .. current_branch
  local check_cmd = string.format('cd %s && git rev-parse --verify %s 2>/dev/null', vim.fn.shellescape(git_root), remote_ref)
  local commit = vim.fn.trim(vim.fn.system(check_cmd))

  if vim.v.shell_error == 0 and commit ~= '' then
    return commit, current_branch
  end

  return nil, current_branch
end

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

  -- Get current line info
  local current_line = vim.fn.line '.'
  local current_line_content = vim.fn.getline(current_line)

  -- Determine the best ref for the URL
  local ref = nil

  -- First, try the merge base (most stable)
  local merge_base, default_branch = get_merge_base_ref(git_root)
  if merge_base and line_exists_at_ref(git_root, merge_base, rel_path, current_line, current_line_content) then
    ref = merge_base
  end

  -- If line doesn't exist at merge base, try the remote version of current branch
  if not ref then
    local remote_commit, current_branch = get_remote_branch_ref(git_root)
    if remote_commit and line_exists_at_ref(git_root, remote_commit, rel_path, current_line, current_line_content) then
      ref = remote_commit
    elseif not remote_commit and current_branch then
      -- Remote branch doesn't exist
      print(string.format('Line %d is not present on remote (branch %s not pushed)', current_line, current_branch))
      return nil
    else
      -- Line doesn't exist at remote branch either
      print(string.format('Line %d is not present on remote (uncommitted or unpushed change)', current_line))
      return nil
    end
  end

  -- Combine to form the GitHub blob URL
  local full_url = github_url .. '/blob/' .. ref .. '/' .. rel_path

  -- Add line number
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
