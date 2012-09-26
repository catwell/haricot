require "pl.strict"
local haricot = require "haricot"

local printf = function(p,...)
  io.stdout:write(string.format(p,...)); io.stdout:flush()
end

local socket = require "socket"
local gettime = socket.gettime
local sleep = function(s)
  socket.select(nil,nil,s)
end

local ok,res,id,job,t0
local tube1 = "$haricot$-test1"

printf("basic ")
local bs = haricot.new("localhost",11300); assert(bs); printf(".")
ok,res = bs:watch(tube1); assert(ok and (res == 2)); printf(".")
ok,res = bs:ignore("default"); assert(ok and (res == 1)); printf(".")
while true do -- empty tube
  ok,res = bs:reserve_with_timeout(0)
  assert(ok)
  if res ~= nil then
    assert(type(res.id) == "number")
    ok = bs:delete(res.id)
    assert(ok)
  else break end
end; printf(".")
ok,err = bs:use(tube1); assert(ok); printf(".")
ok,id = bs:put(0,0,60,"hello"); assert(ok); printf(".")
ok,job = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
print(" OK")

printf("timeouts ")
-- reserve with timeout
t0 = gettime()
ok,res = bs:reserve_with_timeout(3)
assert( math.floor((gettime()-t0-3)*10) == 0 ) -- took about 3s
assert(ok); assert(res == nil); printf(".")
ok,id = bs:put(0,0,60,"hello"); assert(ok); printf(".")
t0 = gettime()
ok,job = bs:reserve_with_timeout(3)
assert( (gettime()-t0) < 0.1 ) -- did not take 3s
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
-- delay
ok,id = bs:put(0,3,60,"hello"); assert(ok); printf(".")
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil)); printf(".")
sleep(1.5)
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil)); printf(".")
sleep(2)
ok,job = bs:reserve_with_timeout(0); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
-- ttr: TODO
print(" OK")

-- wrap up
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil))
