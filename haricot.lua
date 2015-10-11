local lsocket = nil
local ok, socket = pcall(require, "socket")
if not ok then
  lsocket = require "lsocket"
end

-- NOTES:
-- `job` format: {id=...,data=...}

--- low level

local default_cfg = function()
  return {
    max_job_size = 2^16,
  }
end

local is_posint = function(x)
  return ( (type(x) == "number") and (math.floor(x) == x) and (x >= 0) )
end

local hyphen = string.byte("-")
local valid_name = function(x)
  local n = #x
  return (
    (type(x) == "string") and
    (n > 0) and (n <= 200) and
    (x:byte() ~= hyphen) and
    x:match("^[%w-_+/;.$()]+$")
  )
end

local ll_recv = function(self, bytes)
  assert(is_posint(bytes))
  if lsocket then
    local c, r = bytes, {}
    while c > 0 do
      local rsock = lsocket.select({self.cnx})
      assert(rsock[1] == self.cnx)
      local t = self.cnx:recv(c)
      if not t then return nil end
      r[#r+1] = t
      c = c - #t
    end
    return table.concat(r)
  else
    return self.cnx:receive(bytes)
  end
end

local ll_send = function(self, buf)
  if lsocket then
    local c = #buf
    while c > 0 do
      local _, wsock = lsocket.select(nil, {self.cnx})
      assert(wsock[1] == self.cnx)
      local sent, err = self.cnx:send(buf)
      if not sent then return nil, err end
      c = c - sent
    end
  else
    return self.cnx:send(buf)
  end
end

local getline = function(self)
  if not self.cnx then return "NOT_CONNECTED" end
  if lsocket then
    local r = {}
    while true do
      local c = ll_recv(self, 1)
      if not c then
        return "NOT_CONNECTED"
      elseif c == '\n' then
        return table.concat(r)
      elseif c ~= '\r' then
        r[#r+1] = c
      end
    end
  else
    return self.cnx:receive("*l") or "NOT_CONNECTED"
  end
end

local mkcmd = function(cmd, ...)
  return table.concat({cmd, ...}, " ") .. "\r\n"
end

local call = function(self, cmd, ...)
  if not self.cnx then return "NOT_CONNECTED" end
  ll_send(self, mkcmd(cmd, ...))
  return getline(self)
end

local recv = function(self, bytes)
  if not self.cnx then return nil end
  local r = ll_recv(self, bytes + 2)
  if r then
    return r:sub(1, bytes)
  else return nil end
end

local expect_simple = function(res, s)
  if res:match(string.format("^%s$", s)) then
    return true
  else
    return false, res
  end
end

local expect_int = function(res, s)
  local id = tonumber(res:match(string.format("^%s (%%d+)$", s)))
  if id then
    return true, id
  else
    return false, res
  end
end

local expect_data = function(self, res)
  local bytes = tonumber(res:match("^OK (%d+)$"))
  if bytes then
    local data = recv(self, bytes)
    if data then
      assert(#data == bytes)
      return true, data
    else
      return false, "NOT_CONNECTED"
    end
  else
    return false, res
  end
end

local expect_job_body = function(self, bytes, id)
  local data = recv(self, bytes)
  if data then
    assert(#data == bytes)
    return true, {id = id, data = data}
  else
    return false, "NOT_CONNECTED"
  end
end

--- methods

-- connection

local connect = function(self, server, port)
  if self.cnx ~= nil then self:disconnect() end
  local co, err
  if lsocket then
    co, err = lsocket.connect("tcp", server, port)
    if co then
      local _, wsock = lsocket.select(nil, {co})
      assert(wsock[1] == co)
      assert(co:status())
      self.cnx = co
    end
  else
    self.cnx = socket.tcp()
    co, err = self.cnx:connect(server, port)
  end
  if co == nil then return false, err end
  return true
end

local disconnect = function(self)
  if self.cnx ~= nil then
    self:quit()
    self.cnx:close()
    self.cnx = nil
    return true
  end
  return false, "NOT_CONNECTED"
end

-- producer

local put = function(self, pri, delay, ttr, data)
  if not self.cnx then return false, "NOT_CONNECTED" end
  assert(
    is_posint(pri) and (pri < 2^32) and
    is_posint(delay) and
    is_posint(ttr) and (ttr > 0)
  )
  local bytes = #data
  assert(bytes < self.cfg.max_job_size)
  local cmd = mkcmd("put", pri, delay, ttr, bytes) .. data .. "\r\n"
  ll_send(self, cmd)
  local res = getline(self)
  return expect_int(res, "INSERTED")
end

local use = function(self, tube)
  assert(valid_name(tube))
  local res = call(self, "use", tube)
  local ok = res:match("^USING ([%w-_+/;.$()]+)$")
  ok = (ok == tube)
  if ok then
    return true
  else
    return false, res
  end
end

-- consumer

local reserve = function(self)
  local res = call(self, "reserve")
  local id, bytes = res:match("^RESERVED (%d+) (%d+)$")
  if id --[[and bytes]] then
    id, bytes = tonumber(id), tonumber(bytes)
    return expect_job_body(self, bytes, id)
  else
    return false, res
  end
end

local reserve_with_timeout = function(self, timeout)
  assert(is_posint(timeout))
  local res = call(self, "reserve-with-timeout", timeout)
  local id, bytes = res:match("^RESERVED (%d+) (%d+)$")
  if id --[[and bytes]] then
    id, bytes = tonumber(id), tonumber(bytes)
    return expect_job_body(self, bytes, id)
  else
    return expect_simple(res, "TIMED_OUT")
  end
end

local delete = function(self, id)
  assert(is_posint(id))
  local res = call(self, "delete", id)
  return expect_simple(res, "DELETED")
end

local release = function(self, id, pri, delay)
  assert(
    is_posint(id) and
    is_posint(pri) and (pri < 2^32) and
    is_posint(delay)
  )
  local res = call(self, "release", id, pri, delay)
  return(expect_simple(res, "RELEASED"))
end

local bury = function(self, id, pri)
  assert(
    is_posint(id) and
    is_posint(pri) and (pri < 2^32)
  )
  local res = call(self, "bury", id, pri)
  return expect_simple(res, "BURIED")
end

local touch = function(self, id)
  assert(is_posint(id))
  local res = call(self, "touch", id)
  return expect_simple(res, "TOUCHED")
end

local watch = function(self, tube)
  assert(valid_name(tube))
  local res = call(self, "watch", tube)
  return expect_int(res, "WATCHING")
end

local ignore = function(self, tube)
  assert(valid_name(tube))
  local res = call(self, "ignore", tube)
  return expect_int(res, "WATCHING")
end

-- other

local _peek_result = function(self, res) -- private
  local id, bytes = res:match("^FOUND (%d+) (%d+)$")
  if id --[[and bytes]] then
    id, bytes = tonumber(id), tonumber(bytes)
    return expect_job_body(self, bytes, id)
  else
    return expect_simple(res, "NOT_FOUND")
  end
end

local peek = function(self, id)
  assert(is_posint(id))
  local res = call(self, "peek", id)
  return _peek_result(self, res)
end

local make_peek = function(state)
  return function(self)
    local res = call(self, string.format("peek-%s", state))
    return _peek_result(self, res)
  end
end

local kick = function(self, bound)
  assert(is_posint(bound))
  local res = call(self, "kick", bound)
  return expect_int(res, "KICKED")
end

local kick_job = function(self, id)
  assert(is_posint(id))
  local res = call(self, "kick-job", id)
  return expect_simple(res, "KICKED")
end

local stats_job = function(self, id)
  assert(is_posint(id))
  local res = call(self, "stats-job", id)
  return expect_data(self, res)
end

local stats_tube = function(self, tube)
  assert(valid_name(tube))
  local res = call(self, "stats-tube", tube)
  return expect_data(self, res)
end

local stats = function(self)
  local res = call(self, "stats")
  return expect_data(self, res)
end

local list_tubes = function(self)
  local res = call(self, "list-tubes")
  return expect_data(self, res)
end

local list_tube_used = function(self)
  local res = call(self, "list-tube-used")
  local tube = res:match("^USING ([%w-_+/;.$()]+)$")
  if tube then
    return true, tube
  else
    return false, res
  end
end

local list_tubes_watched = function(self)
  local res = call(self, "list-tubes-watched")
  return expect_data(self, res)
end

local quit = function(self)
  if not self.cnx then return false, "NOT_CONNECTED" end
  ll_send(self, mkcmd("quit"))
  return true
end

local pause_tube = function(self, tube, delay)
  assert(valid_name(tube) and is_posint(delay))
  local res = call(self, "pause-tube", tube, delay)
  return expect_simple(res, "PAUSED")
end

--- class

local methods = {
  -- connection
  connect = connect, -- (server,port) -> ok,[err]
  disconnect = disconnect, -- () -> ok,[err]

  -- producer
  put = put, -- (pri,delay,ttr,data) -> ok,[id|err]
  use = use, -- (tube) -> ok,[err]
  -- consumer
  reserve = reserve, -- () -> ok,[job|err]
  reserve_with_timeout = reserve_with_timeout, -- () -> ok,[job|nil|err]
  delete = delete, -- (id) -> ok,[err]
  release = release, -- (id,pri,delay) -> ok,[err]
  bury = bury, -- (id,pri) -> ok,[err]
  touch = touch, -- (id) -> ok,[err]
  watch = watch, -- (tube) -> ok,[count|err]
  ignore = ignore, -- (tube) -> ok,[count|err]
  -- other
  peek = peek, -- (id) -> ok,[job|nil|err]
  peek_ready = make_peek("ready"), -- () -> ok,[job|nil|err]
  peek_delayed = make_peek("delayed"), -- () -> ok,[job|nil|err]
  peek_buried = make_peek("buried"), -- () -> ok,[job|nil|err]
  kick = kick, -- (bound) -> ok,[count|err]
  kick_job = kick_job, -- (id) -> ok,[err]
  stats_job = stats_job, -- (id) -> ok,[yaml|err]
  stats_tube = stats_tube, -- (tube) -> ok,[yaml|err]
  stats = stats, -- () -> ok,[yaml|err]
  list_tubes = list_tubes, -- () -> ok,[yaml|err]
  list_tube_used = list_tube_used, -- () -> ok,[tube|err]
  list_tubes_watched = list_tubes_watched, -- () -> ok,[tube|err]
  quit = quit, -- () -> ok
  pause_tube = pause_tube, -- (tube,delay) -> ok,[err]
}

local new = function(server, port)
  local r = {cfg = default_cfg()}
  local ok, err = connect(r, server, port)
  return setmetatable(r, {__index = methods}), ok, err
end

return {
  new = new, -- instance,conn_ok,[err]
}

-- vim: set tabstop=2 softtabstop=2 shiftwidth=2 expandtab : --
