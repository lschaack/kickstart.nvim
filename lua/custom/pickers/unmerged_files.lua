-- Telescope picker for unmerged files during merge conflict resolution
local M = {}

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local make_entry = require 'telescope.make_entry'

-- Open telescope picker for unmerged files
function M.unmerged_files()
  -- Get git root directory
  local git_root_handle = io.popen 'git rev-parse --show-toplevel 2>/dev/null'
  if not git_root_handle then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end
  local git_root = vim.trim(git_root_handle:read '*a')
  git_root_handle:close()

  if git_root == '' then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end

  -- Get unmerged files using git diff with unmerged filter
  local handle = io.popen 'git diff --name-only --diff-filter=U 2>/dev/null'
  local unmerged_files = {}
  if handle then
    local result = handle:read '*a'
    handle:close()
    for file in result:gmatch '[^\r\n]+' do
      local absolute_path = git_root .. '/' .. file
      if vim.fn.filereadable(absolute_path) == 1 then
        table.insert(unmerged_files, absolute_path)
      end
    end
  end

  if #unmerged_files == 0 then
    vim.notify('No unmerged files (no merge conflicts)', vim.log.levels.INFO)
    return
  end

  -- Create telescope picker for finding files
  pickers
    .new({}, {
      prompt_title = string.format('Unmerged Files (%d conflicts)', #unmerged_files),
      finder = finders.new_table {
        results = unmerged_files,
        entry_maker = make_entry.gen_from_file {},
      },
      sorter = conf.file_sorter {},
      previewer = conf.file_previewer {},
    })
    :find()
end

return M
