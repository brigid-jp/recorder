#! /usr/bin/env lua

local socket = require "socket"

local host, serv = ...

local server_socket = assert(socket.bind(host, serv))
assert(server_socket:settimeout(0))

local accepted_sockets = {}
local seq_no = 0

while true do
  local recvt = { server_socket }
  local sendt = {}
  local timeout = 1

  for s in pairs(accepted_sockets) do
    recvt[#recvt + 1] = s
  end

  local selected_sockets = assert(socket.select(recvt, sendt, timeout))

  seq_no = seq_no + 1
  print(seq_no, #selected_sockets, #recvt)
  for i = 1, #selected_sockets do
    local s = selected_sockets[i]
    if s == server_socket then
      local s = assert(server_socket:accept())
      assert(s:settimeout(0))
      accepted_sockets[s] = {}
    else
      local state = accepted_sockets[s]

      while true do
        local result, message = s:receive(1)
        if result then
          io.write(result)
        else
          print("[" .. message .. "]")
          if message == "timeout" then
            break
          elseif message == "closed" then
            s:close()
            accepted_sockets[s] = nil
            break
          end
          break
        end
      end
    end
  end
end
