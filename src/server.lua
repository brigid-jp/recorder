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

  if seq_no % 10 == 0 then
    print "ping"
    for s in pairs(accepted_sockets) do
      s:send "\x89\x04ping"
    end
  elseif seq_no % 10 == 2 then
    print "text"
    for s in pairs(accepted_sockets) do
      s:send "\x81\x04text"
    end
  end

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
              state.header_fields = ""
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
              state.frame = ""
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
            local frame = state.frame .. result
            if #frame == 2 then
              local a, b = frame:byte(1, 2)
              print(("0x%0x 0x%0x"):format(a, b))
              state.frame = nil
              state.f = {}
              state.f.fin = a & 0x80 ~= 0
              state.f.rsv1 = a & 0x40 ~= 0
              state.f.rsv2 = a & 0x20 ~= 0
              state.f.rsv3 = a & 0x10 ~= 0
              state.f.opcode = a & 0x0F
              state.f.mask = b & 0x80 ~= 0
              state.f.length = b & 0x7F
              state.f.mask_data = {}
              state.f.mask_n = 4
              state.payload = ""
              print(state.f.fin, state.f.opcode, state.f.mask, state.f.length)
              if state.f.length == 126 then
                state.f.length = 0
                state.f.len_n = 2
                state.mode = 4
              elseif state.f.length == 127 then
                state.f.length = 0
                state.f.len_n = 8
                state.mode = 4
              else
                state.mode = 5
              end
            else
              state.frame = frame
            end
          elseif state.mode == 4 then
            state.f.length = state.f.length * 256 + result:byte()
            state.f.len_n = state.f.len_n - 1
            if state.f.len_n == 0 then
              state.mode = 5
            end
          elseif state.mode == 5 then
            local mask_data = state.f.mask_data
            mask_data[#mask_data + 1] = result:byte()
            state.f.mask_n = state.f.mask_n - 1
            if state.f.mask_n == 0 then
              print(("0x%02x 0x%02x 0x%02x 0x%02x"):format(mask_data[1], mask_data[2], mask_data[3], mask_data[4]))
              state.f.n = state.f.length
              state.f.m = 0
              state.payload = ""
              if state.f.length == 0 then
                state.mode = 7
              else
                state.mode = 6
              end
            end
          elseif state.mode == 6 then
            state.payload = state.payload .. string.char(state.f.mask_data[state.f.m + 1] ~ result:byte())
            state.f.m = (state.f.m + 1) % 4
            state.f.n = state.f.n - 1
            if state.f.n == 0 then
              state.mode = 7
            end
          end

          if state.mode == 7 then
            print("<" .. state.payload .. ">")

            if state.f.opcode == 0x8 then
              print "<CLOSE>"
              s:send "\x88\x00"
              s:close()
              accepted_sockets[s] = nil
            end

            state.frame = ""
            state.mode = 3
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
