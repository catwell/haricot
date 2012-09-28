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
while true do -- clean buried jobs
  ok,res = bs:peek_buried()
  assert(ok)
  if res ~= nil then
    assert(type(res.id) == "number")
    ok = bs:delete(res.id)
    assert(ok)
  else break end
end; printf(".")
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
assert(ok and (res == nil)); printf(".")
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
-- ttr
ok,id = bs:put(0,0,2,"hello"); assert(ok); printf(".")
ok,job = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
sleep(1.5)
ok,res = bs:reserve()
assert((not ok) and (res == "DEADLINE_SOON")); printf(".")
sleep(1)
ok,job = bs:reserve()
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
-- touching
ok,id = bs:put(0,0,2,"hello"); assert(ok); printf(".")
ok,job = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
sleep(1.5)
ok,res = bs:reserve(0)
assert((not ok) and (res == "DEADLINE_SOON")); printf(".")
ok = bs:touch(id); assert(ok); printf(".")
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil)); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
print(" OK")

printf("priorities ")
local id1,id2,job1,job2
-- one way
ok,id1 = bs:put(5,0,60,"first"); assert(ok); printf(".")
ok,id2 = bs:put(10,0,60,"second"); assert(ok); printf(".")
ok,job1 = bs:reserve(); assert(ok)
assert((job1.id == id1) and (job1.data == "first")); printf(".")
ok,job2 = bs:reserve(); assert(ok)
assert((job2.id == id2) and (job2.data == "second")); printf(".")
ok = bs:delete(id1); assert(ok); printf(".")
ok = bs:delete(id2); assert(ok); printf(".")
-- reverse way
ok,id2 = bs:put(10,0,60,"second"); assert(ok); printf(".")
ok,id1 = bs:put(5,0,60,"first"); assert(ok); printf(".")
ok,job1 = bs:reserve(); assert(ok)
assert((job1.id == id1) and (job1.data == "first")); printf(".")
ok,job2 = bs:reserve(); assert(ok)
assert((job2.id == id2) and (job2.data == "second")); printf(".")
ok = bs:delete(id1); assert(ok); printf(".")
ok = bs:delete(id2); assert(ok); printf(".")
-- same priority
ok,id1 = bs:put(5,0,60,"first"); assert(ok); printf(".")
ok,id2 = bs:put(5,0,60,"second"); assert(ok); printf(".")
ok,job1 = bs:reserve(); assert(ok)
assert((job1.id == id1) and (job1.data == "first")); printf(".")
ok,job2 = bs:reserve(); assert(ok)
assert((job2.id == id2) and (job2.data == "second")); printf(".")
ok = bs:delete(id1); assert(ok); printf(".")
ok = bs:delete(id2); assert(ok); printf(".")
-- priorities + delay
t0 = gettime()
ok,id1 = bs:put(5,1,60,"first"); assert(ok); printf(".")
ok,id2 = bs:put(10,0,60,"second"); assert(ok); printf(".")
ok,job2 = bs:reserve(); assert(ok)
assert((job2.id == id2) and (job2.data == "second")); printf(".")
ok,job1 = bs:reserve(); assert(ok)
assert( math.floor((gettime()-t0-1)*10) == 0 ) -- took about 1s
assert((job1.id == id1) and (job1.data == "first")); printf(".")
ok = bs:delete(id1); assert(ok); printf(".")
ok = bs:delete(id2); assert(ok); printf(".")
print(" OK")

printf("releasing ")
ok,id = bs:put(0,0,60,"hello"); assert(ok); printf(".")
ok,job = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil)); printf(".")
ok = bs:release(id,0,0); assert(ok); printf(".")
ok,job = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
print(" OK")

printf("burying and kicking ")
ok,id = bs:put(0,0,60,"hello"); assert(ok); printf(".")
ok,job = bs:peek_ready(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok,res = bs:peek_buried(); assert(ok and (res == nil)); printf(".")
ok,job = bs:peek(id); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok,res = bs:bury(id,0); assert((not ok) and (res == "NOT_FOUND")); printf(".")
ok,res = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:bury(id,0); assert(ok); printf(".")
ok,res = bs:peek_ready(); assert(ok and (res == nil)); printf(".")
ok,job = bs:peek_buried(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok,job = bs:peek(id); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil)); printf(".")
ok,res = bs:kick(10); assert(ok and (res == 1)); printf(".")
ok,job = bs:peek_ready(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok,res = bs:peek_buried(); assert(ok and (res == nil)); printf(".")
ok,job = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
print(" OK")

-- wrap up
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil))
