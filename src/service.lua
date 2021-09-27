-- Copyright (c) 2021 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local socket = require "socket"

local class = {}
local metatable = { __index = class }

local function new()
  return {
    sockets = {};
    timers = {};
    timer_handle = 0;
    current_time = socket.gettime();
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

function class:update_timer()
  self.current_time = socket.gettime()

  for handle, timer in pairs(self.timers) do
    if timer.t <= self.current_time then
      timer.f()
      self.timers[handle] = nil
    end
  end
end

function class:add_timer(f, timeout)
  self.timer_handle = self.timer_handle + 1
  self.timers[self.timer_handle] = {
    f = f;
    t = self.current_time + timeout;
  }
  return self.timer_handle
end

function class:remove_timer(handle)
  self.timers[handle] = nil
end

return setmetatable(class, {
  __call = function ()
    return setmetatable(new(), metatable)
  end;
})
