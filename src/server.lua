#! /usr/bin/env lua

local mime = require "mime"
local socket = require "socket"
local brigid = require "brigid"

local host, serv = ...

local server_socket = assert(socket.bind(host, serv))
assert(server_socket:settimeout(0))

local accepted_sockets = {}
local seq_no = 0

local function crlf(source)
  return (source:gsub("\r?\n", "\r\n"))
end

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
      accepted_sockets[s] = {
        mode = 1;
        line = "",
        header_fields = "",
      }
    else
      local state = accepted_sockets[s]

      while true do
        local result, message = s:receive(1)
        if result then
          if state.mode == 1 then
            local line = state.line .. result
            if line:find "\r\n$" then
              io.write(line)
              state.line = nil
              state.method, state.uri, state.version = line:match "(%S+)%s+(%S+)%s+(%S+)"
              state.mode = 2
            else
              state.line = line
            end
          elseif state.mode == 2 then
            local header_fields = state.header_fields .. result
            if header_fields:find "\r\n\r\n$" then
              io.write(header_fields)
              state.header_fields = nil
              -- process handshake
              header_fields = header_fields:gsub("\r\n\r\n$", "\r\n")
              header_fields = header_fields:gsub("\r\n%s+", " ")
              local headers = {}
              for k, v in header_fields:gmatch "(.-):%s*(.-)\r\n" do
                local u = headers[k]
                if u then
                  headers[k] = u .. "; " .. v
                else
                  headers[k] = v
                end
              end
              state.headers = headers
              state.mode = 3

              print(state.method)
              print(state.uri)
              print(state.version)
              for k, v in pairs(headers) do
                print(k, v)
              end

              if headers["Sec-WebSocket-Version"] ~= "13" then
                s:send(crlf([[
HTTP/1.1 426 Upgrade Required
Sec-WebSocket-Version: 13

]]))
                s:close()
              else
                local accept = brigid.hasher "sha1"
                  :update(headers["Sec-WebSocket-Key"])
                  :update "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
                  :digest()
                s:send(crlf([[
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: %s

]]):format((mime.b64(accept))))
              end
            else
              state.header_fields = header_fields
            end

          elseif state.mode == 3 then
            -- ????
          end
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
