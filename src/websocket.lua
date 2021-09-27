-- Copyright (c) 2021 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local brigid = require "brigid"
local mime = require "mime"

local class = {}
local metatable = { __index = class }

local RESPONSE_426 = ([[
HTTP/1.1 426 Upgrade Required
Sec-WebSocket-Version: %d

]]):gsub("\n", "\r\n")

local RESPONSE_101 = ([[
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: upgrade
Sec-WebSocket-Accept: %s

]]):gsub("\n", "\r\n")

local function new(sockets, socket)
  local self = setmetatable({
    sockets = sockets;
    socket = socket;
    buffer = "";
    state = 1
  }, metatable)
  sockets[socket] = self
  return self
end

function class:close()
  local host, serv, family = assert(self.socket:getpeername())
  self.socket:close()
  self.sockets[self.socket] = nil
  if self.on_close then
    self:on_close(host, serv, family)
  end
end

function class:send(opcode, payload)
  if not payload then
    payload = ""
  end

  local data = { string.char(0x80 | opcode) }

  local n = #payload
  if n < 126 then
    data[2] = string.char(n)
  elseif n < 65536 then
    data[2] = "\126"
    local b = n & 0xFF
    local a = n >> 8
    data[3] = string.char(a, b)
  else
    assert(n < 0x1000000000000)
    data[2] = "\127\0\0"
    local h = n & 0xFF n = n >> 8
    local g = n & 0xFF n = n >> 8
    local f = n & 0xFF n = n >> 8
    local e = n & 0xFF n = n >> 8
    local d = n & 0xFF n = n >> 8
    local c = n & 0xFF
    data[3] = string.char(c, d, e, f, g, h)
  end

  data[#data + 1] = payload

  self.socket:send(table.concat(data))
end

function class:send_text(payload)
  self:send(0x1, payload)
end

function class:send_binary(payload)
  self:send(0x2, payload)
end

function class:send_ping(payload)
  self:send(0x9, payload)
end

function class:read(data)
  if not data then
    return self:close()
  end

  self.buffer = self.buffer .. data

  if self.state == 1 then
    local line, buffer_next = self.buffer:match "^(.-)\r\n(.*)"
    if line then
      self.method, self.uri, self.version = assert(line:match "^(%S+)%s+(%S+)%s+(%S+)$")

      self.buffer = buffer_next
      self.state = 2
    end
  end

  if self.state == 2 then
    local header_fields, buffer_next = self.buffer:match "^(.-)\r\n\r\n(.*)"
    if header_fields then
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
      self.headers = headers

      if headers["Sec-WebSocket-Version"] ~= "13" then
        self.socket:send(RESPONSE_426:format(13))
        return self:close()
      else
        self.socket:send(RESPONSE_101:format(mime.b64(
          brigid.hasher "sha1"
            :update(headers["Sec-WebSocket-Key"])
            :update "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
            :digest()
        )))
        if self.on_open then
          self:on_open(assert(self.socket:getpeername()))
        end
      end

      self.buffer = buffer_next
      self.state = 3
    end
  end

  if self.state == 3 then
    if #self.buffer >= 2 then
      local a, b = self.buffer:byte(1, 2)
      self.fin = a & 0x80 ~= 0
      self.rsv1 = a & 0x40 ~= 0
      self.rsv2 = a & 0x20 ~= 0
      self.rsv3 = a & 0x10 ~= 0
      self.opcode = a & 0x0F
      self.mask = b & 0x80 ~= 0
      self.length = b & 0x7F

      self.buffer = self.buffer:sub(3)
      self.state = 4
    end
  end

  if self.state == 4 then
    if self.length == 126 then
      -- 16bit
      if #self.buffer >= 2 then
        local a, b = self.buffer:byte(1, 2)
        self.length = a * 0x100 + b

        self.buffer = self.buffer:sub(3)
        self.state = 5
      end
    elseif self.length == 127 then
      -- 64bit
      if #self.buffer >= 8 then
        local a, b, c, d, e, f, g, h = self.buffer:byte(1, 8)
        assert(a == 0)
        assert(b == 0)
        self.length = c * 0x10000000000 + d * 0x100000000 + e * 0x1000000 + f * 0x10000 + g * 0x100 + h

        self.buffer = self.buffer:sub(9)
        self.state = 5
      end
    else
      self.state = 5
    end
  end

  if self.state == 5 then
    if self.mask then
      if #self.buffer >= 4 then
        self.mask_key = { self.buffer:byte(1, 4) }

        self.buffer = self.buffer:sub(5)
        self.state = 6
      end
    else
      self.state = 6
    end
  end

  if self.state == 6 then
    if #self.buffer >= self.length then
      local payload = {}
      for i = 1, self.length do
        payload[i] = string.char(self.mask_key[(i - 1) % 4 + 1] ~ self.buffer:byte(i))
      end
      self.payload = table.concat(payload)

      if self.opcode == 0x01 then
        if self.on_text then
          self:on_text()
        end
      elseif self.opcode == 0x02 then
        if self.on_binary then
          self:on_binary()
        end
      elseif self.opcode == 0x8 then
        self:send(0x8)
        return self:close()
      elseif self.opcode == 0x9 then
        self:send(0xA, self.payload)
      elseif self.opcode == 0xA then
        if self.on_pong then
          self:on_pong()
        end
      end

      self.buffer = self.buffer:sub(self.length + 1)
      self.state = 3
    end
  end
end

return setmetatable(class, {
  __call = function (_, sockets, socket)
    return setmetatable(new(sockets, socket), metatable)
  end;
})
