-- Test file for lemur plugin
local function test_function()
  local items = {
    first = "hello",
    second = "world",
    third = {
      nested = "value",
      another = function()
        return "test"
      end
    }
  }
  
  for key, value in pairs(items) do
    if type(value) == "table" then
      print(key .. " is a table")
      for k, v in pairs(value) do
        print("  " .. k .. " = " .. tostring(v))
      end
    else
      print(key .. " = " .. tostring(value))
    end
  end
end

local MyClass = {}
MyClass.__index = MyClass

function MyClass:new(name)
  local instance = {
    name = name,
    data = {}
  }
  setmetatable(instance, self)
  return instance
end

function MyClass:add_data(key, value)
  self.data[key] = value
end

function MyClass:get_data(key)
  return self.data[key]
end

test_function()
local obj = MyClass:new("test")
obj:add_data("key1", "value1")
print(obj:get_data("key1"))