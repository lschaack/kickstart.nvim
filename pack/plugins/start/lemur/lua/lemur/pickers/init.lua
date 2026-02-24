local M = {}

-- Sticky mode picker factory
-- A picker is a table with:
--   activate(nodes, name) - enter the picker UI with the given nodes
--   deactivate()          - exit the picker UI
--   is_active()           - returns boolean
M.sticky = require 'lemur.pickers.sticky'

return M
