#! /usr/bin/env lua

local socket = require "socket"
local websocket = require "websocket"

local host, serv = ...

local server = assert(socket.bind(host, serv))
assert(server:settimeout(0))

local websockets = {}
local seq_no = 0

while true do
  local recv = { server }
  local send = {}
  local timeout = 1

  for s in pairs(websockets) do
    recv[#recv + 1] = s
  end

  local recv, send, message = assert(socket.select(recv, send, timeout))

  seq_no = seq_no + 1
  if seq_no % 10 == 0 then
    for s, ws in pairs(websockets) do
      ws:send_ping "test"
    end
  end
  if seq_no % 10 == 5 then
    for s, ws in pairs(websockets) do
      ws:send_text "あいうえおかきくけこさしすせそ"
    end
  end

  for i = 1, #recv do
    local s = recv[i]
    if s == server then
      local s = assert(server:accept())
      assert(s:settimeout(0))
      local ws = websocket(websockets, s)
      function ws:on_message()
        io.write(("[opcode=%x][%s]\n"):format(self.opcode, self.payload))
      end
    else
      local ws = websockets[s]
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
