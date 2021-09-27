#! /usr/bin/env lua

-- Copyright (c) 2021 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local socket = require "socket"
local service = require "service"
local websocket = require "websocket"

local host, serv, ping_timer = ...

local select_timer = 1
local ping_timer = tonumber(ping_timer) or 60

local service = service()
local rooms = {}
local server = assert(socket.bind(host, serv))
assert(server:settimeout(0))

local function ping(ws)
  ws.ping_time = socket.gettime()
  ws:send_ping()
  ws.ping_timer = service:add_timer(function () ping(ws) end, ping_timer)
end

local function write(...)
  local current_time = socket.gettime()
  local t = math.floor(current_time)
  local s = math.floor((current_time - t) * 1000)
  io.write("[", os.date("!%Y-%m-%dT%H:%M:%S", t), ".", ("%03d"):format(s), "] ", ...)
end

while true do
  local recv = { server }
  local send = {}

  for s in service:each_socket() do
    recv[#recv + 1] = s
  end

  local recv, send, message = assert(socket.select(recv, send, select_timer))
  service:update_timer()

  for i = 1, #recv do
    local s = recv[i]
    if s == server then
      local s = assert(server:accept())
      assert(s:settimeout(0))
      local ws = websocket(service, s)

      function ws:on_open(host, serv, family)
        write(("on_open[uri=%s][host=%s][serv=%s][family=%s]\n"):format(self.uri, host, serv, family))
        local mode, key = self.uri:match "/([^/]+)/([^/]+)$"
        if mode == "recorder" then
          self.mode = "recorder"
          self.key = key
          if not rooms[self.key] then
            rooms[self.key] = { controls = {} }
          end
          rooms[self.key].recorder = self
        elseif mode == "control" then
          self.mode = "control"
          self.key = key
          if not rooms[self.key] then
            rooms[self.key] = { controls = {} }
          end
          rooms[self.key].controls[s] = self
        else
          return false
        end
      end
      function ws:on_close(host, serv, family)
        write(("on_close[uri=%s][host=%s][serv=%s][family=%s]\n"):format(self.uri, host, serv, family))
        if self.ping_timer then
          service:remove_timer(self.ping_timer)
        end
        if self.mode == "recorder" then
          if rooms[self.key].recorder == self then
            rooms[self.key].recorder = nil
          end
        elseif self.mode == "control" then
          rooms[self.key].controls[self.socket] = nil
        end
      end
      function ws:on_text()
        write(("on_text[uri=%s][fin=%s][payload=%s]\n"):format(self.uri, self.fin, self.payload))
        if self.mode == "recorder" then
          for _, ws in pairs(rooms[self.key].controls) do
            ws:send(self.fin, self.opcode, self.payload)
          end
        elseif self.mode == "control" then
          local recorder = rooms[self.key].recorder
          if recorder then
            recorder:send(self.fin, self.opcode, self.payload)
          end
        end
      end
      function ws:on_binary()
        write(("on_binary[uri=%s][fin=%s][size=%d]\n"):format(self.uri, self.fin, #self.payload))
        if self.mode == "recorder" then
          for _, ws in pairs(rooms[self.key].controls) do
            ws:send(self.fin, self.opcode, self.payload)
          end
        elseif self.mode == "control" then
          if recorder then
            recorder:send(self.fin, self.opcode, self.payload)
          end
        end
      end
      function ws:on_pong()
        local pong_time = socket.gettime()
        write(("on_pong[uri=%s][time=%g]\n"):format(self.uri, pong_time - self.ping_time))
      end

      ws.ping_timer = service:add_timer(function () ping(ws) end, ping_timer)
    else
      local ws = service:get_socket(s)
      local result, message, data = s:receive(4096)
      if result then
        ws:read(result)
      else
        if message == "timeout" then
          if data then
            ws:read(data)
          end
        elseif message == "closed" then
          if data then
            ws:read(data)
          end
          ws:read()
        end
      end
    end
  end
end
