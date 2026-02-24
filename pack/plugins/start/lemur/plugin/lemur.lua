-- Auto-setup with defaults if not already configured via lazy.nvim
-- When using lazy.nvim with a config function, that runs after this file,
-- so we defer to let lazy.nvim's config take precedence.
vim.defer_fn(function()
  local lemur = require 'lemur'
  if vim.tbl_isempty(lemur._registry) then
    lemur.setup()
  end
end, 0)
