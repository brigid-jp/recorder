-- Copyright (c) 2021 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local class = {}
local metatable = { __index = class }

local function new()
  return {
    sockets = {};
    timers = {};
  }
end

function class:add_socket(s, ws)
  self.sockets[s] = ws
end

function class:remove_socket(s)
  self.sockets[s] = nil
end

function class:get_socket(s)
  return self.sockets[s]
end

function class:each_socket()
  return next, self.sockets
end

return setmetatable(class, {
  __call = function ()
    return setmetatable(new(), metatable)
  end;
})
