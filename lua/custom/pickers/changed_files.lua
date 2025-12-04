-- Telescope picker for grepping through git changed files (committed + uncommitted)
local M = {}

-- Detect the default/main branch name
local function get_default_branch()
  -- Try to get the default branch from remote HEAD
  local handle = io.popen 'git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null'
  if handle then
    local result = handle:read '*a'
    handle:close()
    local branch = result:match 'refs/remotes/origin/(.+)'
    if branch and branch ~= '' then
      return vim.trim(branch)
    end
  end

  -- Fallback: try common branch names
  local common_branches = { 'main', 'master', 'develop', 'staging' }
  for _, branch in ipairs(common_branches) do
    local check = io.popen('git rev-parse --verify ' .. branch .. ' 2>/dev/null')
    if check then
      local output = check:read '*a'
      check:close()
      if output ~= '' then
        return branch
      end
    end
  end

  return nil
end

-- Open telescope picker for changed files
function M.grep_changed_files()
  local builtin = require 'telescope.builtin'

  local base_branch = get_default_branch()
  if not base_branch then
    vim.notify('Could not detect default branch (tried main, master, develop, staging)', vim.log.levels.ERROR)
    return
  end

  -- Get git root directory
  local git_root_handle = io.popen 'git rev-parse --show-toplevel'
  if not git_root_handle then
    vim.notify('Failed to get git root directory', vim.log.levels.ERROR)
    return
  end
  local git_root = vim.trim(git_root_handle:read '*a')
  git_root_handle:close()

  -- Get files changed in commits on the branch
  local cmd_committed = string.format('git diff --name-only $(git merge-base HEAD %s)...HEAD', base_branch)
  local handle_committed = io.popen(cmd_committed)
  local committed_files = {}
  if handle_committed then
    local result = handle_committed:read '*a'
    handle_committed:close()
    for file in result:gmatch '[^\r\n]+' do
      committed_files[file] = true
    end
  end

  -- Get files with uncommitted changes
  local cmd_uncommitted = 'git diff --name-only'
  local handle_uncommitted = io.popen(cmd_uncommitted)
  if handle_uncommitted then
    local result = handle_uncommitted:read '*a'
    handle_uncommitted:close()
    for file in result:gmatch '[^\r\n]+' do
      committed_files[file] = true -- Use same table to deduplicate
    end
  end

  -- Convert to array with absolute paths and filter for existing files
  local changed_files = {}
  for file, _ in pairs(committed_files) do
    local absolute_path = git_root .. '/' .. file
    if vim.fn.filereadable(absolute_path) == 1 then
      table.insert(changed_files, absolute_path)
    end
  end

  if #changed_files == 0 then
    vim.notify('No changed files in current branch compared to ' .. base_branch, vim.log.levels.WARN)
    return
  end

  builtin.live_grep {
    search_dirs = changed_files,
    prompt_title = string.format('Live Grep in Changed Files (%d files vs %s)', #changed_files, base_branch),
  }
end

return M
