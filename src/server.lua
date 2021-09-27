#! /usr/bin/env lua

-- Copyright (c) 2021 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local socket = require "socket"
local service = require "service"
local websocket = require "websocket"

local select_timer = 1
local ping_timer = 10

local host, serv = ...

local service = service()
local server = assert(socket.bind(host, serv))
assert(server:settimeout(0))

local function ping(ws)
  ws:send_ping()
  ws.ping_timer = service:add_timer(function () ping(ws) end, ping_timer)
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
        io.write(("on_open[%s,%s,%s]\n"):format(host, serv, family))
      end
      function ws:on_close(host, serv, family)
        io.write(("on_close[%s,%s,%s]\n"):format(host, serv, family))
        if self.ping_timer then
          service:remove_timer(self.ping_timer)
        end
      end
      function ws:on_text()
        io.write(("on_text[opcode=0x%X][%s]\n"):format(self.opcode, self.payload))
      end
      function ws:on_binary()
        io.write(("on_binary[opcode=0x%X][%s]\n"):format(self.opcode, self.payload))
      end
      function ws:on_pong()
        io.write(("on_pong[opcode=0x%X][%s]\n"):format(self.opcode, self.payload))
      end

      ws.ping_timer = service:add_timer(function () ping(ws) end, ping_timer)
    else
      local ws = service:get_socket(s)
      local result, message, data = s:receive(4096)
      if result then
        ws:read(data)
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
