-- Telescope picker for grepping through only the changed lines in git (committed + uncommitted)
local M = {}

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local make_entry = require 'telescope.make_entry'

-- Detect the default/main branch name
local function get_default_branch()
  local handle = io.popen 'git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null'
  if handle then
    local result = handle:read '*a'
    handle:close()
    local branch = result:match 'refs/remotes/origin/(.+)'
    if branch and branch ~= '' then
      return vim.trim(branch)
    end
  end

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

-- Parse git diff output to extract changed lines
-- Returns table of entries in vimgrep format: {filename = "", lnum = 1, col = 1, text = ""}
local function parse_diff(diff_output, git_root)
  local entries = {}
  local current_file = nil
  local current_line = nil

  for line in diff_output:gmatch '[^\r\n]+' do
    -- Match file header: +++ b/filename
    local file = line:match '^%+%+%+ b/(.+)$'
    if file then
      current_file = file
    end

    -- Match hunk header: @@ -old +new @@
    -- Format: @@ -start,count +start,count @@
    local new_start, new_count = line:match '^@@ %-[%d,]+ %+(%d+),?(%d*) @@'
    if new_start then
      current_line = tonumber(new_start)
    end

    -- Match added lines (changed or new)
    if current_file and current_line and line:match '^%+' and not line:match '^%+%+%+' then
      local content = line:sub(2) -- Remove the leading '+'
      local absolute_path = git_root .. '/' .. current_file

      table.insert(entries, {
        filename = absolute_path,
        lnum = current_line,
        col = 1,
        text = content,
      })

      current_line = current_line + 1
    elseif current_line and not line:match '^%-' and not line:match '^@@' and not line:match '^diff' and not line:match '^index' and not line:match '^%%%' then
      -- Context line or unchanged line in the hunk
      if not line:match '^%+' then
        current_line = current_line + 1
      end
    end
  end

  return entries
end

-- Open telescope picker for changed lines
function M.grep_changed_lines()
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

  local all_entries = {}

  -- Get committed changes
  local cmd_committed = string.format('git diff -U0 $(git merge-base HEAD %s)...HEAD 2>/dev/null', base_branch)
  local handle_committed = io.popen(cmd_committed)
  if handle_committed then
    local diff_output = handle_committed:read '*a'
    handle_committed:close()
    local committed_entries = parse_diff(diff_output, git_root)
    for _, entry in ipairs(committed_entries) do
      table.insert(all_entries, entry)
    end
  end

  -- Get uncommitted changes
  local cmd_uncommitted = 'git diff -U0 2>/dev/null'
  local handle_uncommitted = io.popen(cmd_uncommitted)
  if handle_uncommitted then
    local diff_output = handle_uncommitted:read '*a'
    handle_uncommitted:close()
    local uncommitted_entries = parse_diff(diff_output, git_root)
    for _, entry in ipairs(uncommitted_entries) do
      table.insert(all_entries, entry)
    end
  end

  -- Get staged but uncommitted changes
  local cmd_staged = 'git diff --staged -U0 2>/dev/null'
  local handle_staged = io.popen(cmd_staged)
  if handle_staged then
    local diff_output = handle_staged:read '*a'
    handle_staged:close()
    local staged_entries = parse_diff(diff_output, git_root)
    for _, entry in ipairs(staged_entries) do
      table.insert(all_entries, entry)
    end
  end

  if #all_entries == 0 then
    vim.notify('No changed lines in current branch compared to ' .. base_branch, vim.log.levels.WARN)
    return
  end

  -- Convert entries to vimgrep string format: "filename:line:col:text"
  local entry_strings = {}
  for _, entry in ipairs(all_entries) do
    local entry_string = string.format('%s:%d:%d:%s', entry.filename, entry.lnum, entry.col, entry.text)
    table.insert(entry_strings, entry_string)
  end

  -- Create telescope picker
  pickers
    .new({}, {
      prompt_title = string.format('Changed Lines (%d lines vs %s)', #entry_strings, base_branch),
      finder = finders.new_table {
        results = entry_strings,
        entry_maker = make_entry.gen_from_vimgrep {},
      },
      sorter = conf.generic_sorter {},
      previewer = conf.grep_previewer {},
    })
    :find()
end

return M
