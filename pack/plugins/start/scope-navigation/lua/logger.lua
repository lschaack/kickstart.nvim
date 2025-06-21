-- Create a logging utility for your plugin
local M = {}

-- Log buffer reference
M.log_buffer = nil

-- Open the log buffer in a split window
function M.open_log_window()
  if not M.log_buffer or not vim.api.nvim_buf_is_valid(M.log_buffer) then
    M.init_log_buffer()
  end

  -- Create a new split window
  -- vim.cmd 'split'

  -- Set buffer in window
  -- FIXME: is this gonna work?
  -- vim.api.nvim_win_set_buf(0, M.log_buffer)
  vim.api.nvim_open_win(M.log_buffer, false, {
    split = 'below',
    win = 0,
    height = 8,
  })

  -- Optional: set window options using modern syntax
  vim.wo[0].wrap = true

  -- Scroll to the bottom when opening
  M.scroll_to_bottom(M.log_buffer)

  return M.log_buffer
end

-- Initialize the log buffer
function M.init_log_buffer()
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, 'Plugin Debug Log')

  -- Set buffer options using the modern syntax
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false

  -- Store the buffer reference
  M.log_buffer = buf

  -- FIXME: only do this if opts.debug
  M.open_log_window()

  return buf
end

-- Get windows displaying a specific buffer
function M.get_windows_for_buffer(buf_id)
  local windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf_id then
      table.insert(windows, win)
    end
  end
  return windows
end

-- Scroll windows to bottom
function M.scroll_to_bottom(buf_id)
  local windows = M.get_windows_for_buffer(buf_id)
  local line_count = vim.api.nvim_buf_line_count(buf_id)

  for _, win in ipairs(windows) do
    -- Get window height
    local win_height = vim.api.nvim_win_get_height(win)

    -- Calculate position to show the last line
    local new_topline = math.max(1, line_count - win_height + 1)

    -- Set the window view
    vim.api.nvim_win_set_cursor(win, { line_count, 0 })

    -- Force redraw
    vim.cmd 'redraw'
  end
end

-- Log a message to the buffer
function M.log(message)
  -- Make sure we have a log buffer
  if not M.log_buffer or not vim.api.nvim_buf_is_valid(M.log_buffer) then
    M.init_log_buffer()
  end

  -- Convert message to string if it's not already
  if type(message) ~= 'string' then
    message = vim.inspect(message)
  end

  -- Get buffer line count
  local line_count = vim.api.nvim_buf_line_count(M.log_buffer)

  -- Append message to buffer
  vim.api.nvim_buf_set_lines(M.log_buffer, line_count, line_count, false, { os.date '%H:%M:%S' .. ' | ' .. message })

  -- Scroll to bottom if the buffer is visible
  M.scroll_to_bottom(M.log_buffer)
end

-- Add an optional function to toggle auto-scroll
M.auto_scroll = true

function M.toggle_auto_scroll()
  M.auto_scroll = not M.auto_scroll
  local status = M.auto_scroll and 'enabled' or 'disabled'
  print('Auto-scroll ' .. status)
  return M.auto_scroll
end

return M
