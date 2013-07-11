local cwtest = require "cwtest"
local haricot = require "haricot"
local socket = require "socket"
local gettime = socket.gettime
local sleep = function(s) socket.select(nil,nil,s) end
local pk = function(...) return {...} end
require "yaml"

local ok,res,id,job,t0
local tube1 = "$haricot$-test1"

local T = cwtest.new()
local bs = haricot.new("localhost",11300)
T:start("basic"); do
  T:yes(bs)
  T:eq( pk(bs:watch(tube1)), {true,2} )
  T:eq( pk(bs:ignore("default")), {true,1} )
  while true do -- empty tube
    ok,res = bs:reserve_with_timeout(0)
    assert(ok,"Do you have beanstalkd running locally on port 11300?")
    if res ~= nil then
      assert(type(res.id) == "number")
      ok = bs:delete(res.id)
      assert(ok)
    else break end
  end
  T:yes( bs:use(tube1) )
  while true do -- clean buried jobs
    ok,res = bs:peek_buried()
    assert(ok)
    if res ~= nil then
      assert(type(res.id) == "number")
      ok = bs:delete(res.id)
      assert(ok)
    else break end
  end
  ok,id = bs:put(0,0,60,"hello"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  T:yes( bs:delete(id) )
end; T:done()

T:start("timeouts"); do
  -- reserve with timeout
  t0 = gettime()
  T:eq( pk(bs:reserve_with_timeout(3)), {true,nil} )
  T:eq( math.floor((gettime()-t0-3)*10), 0 ) -- took about 3s
  ok,id = bs:put(0,0,60,"hello"); T:yes(ok)
  t0 = gettime()
  T:eq( pk(bs:reserve_with_timeout(3)), {true,{id = id,data = "hello"}} )
  assert( (gettime()-t0) < 0.1 ) -- did not take 3s
  T:yes( bs:delete(id) )
  -- delay
  ok,id = bs:put(0,3,60,"hello"); T:yes(ok)
  T:eq( pk(bs:reserve_with_timeout(0)), {true,nil} )
  sleep(1.5)
  T:eq( pk(bs:reserve_with_timeout(0)), {true,nil} )
  sleep(2)
  T:eq( pk(bs:reserve_with_timeout(0)), {true,{id = id,data = "hello"}} )
  T:yes( bs:delete(id) )
  -- ttr
  ok,id = bs:put(0,0,2,"hello"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  sleep(1.5)
  T:eq( pk(bs:reserve()), {false,"DEADLINE_SOON"} )
  sleep(1)
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  T:yes( bs:delete(id) )
  -- touching
  ok,id = bs:put(0,0,2,"hello"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  sleep(1.5)
  T:eq( pk(bs:reserve()), {false,"DEADLINE_SOON"} )
  T:yes( bs:touch(id) )
  T:eq( pk(bs:reserve_with_timeout(0)), {true,nil} )
  T:yes( bs:delete(id) )
  -- pausing
  ok,id = bs:put(0,0,2,"hello"); T:yes(ok)
  T:yes( bs:pause_tube(tube1,2) )
  T:eq( pk(bs:reserve_with_timeout(0)), {true,nil} )
  sleep(1.5)
  T:eq( pk(bs:reserve_with_timeout(0)), {true,nil} )
  sleep(1)
  T:eq( pk(bs:reserve_with_timeout(0)), {true,{id = id,data = "hello"}} )
  T:yes( bs:delete(id) )
end; T:done()

T:start("priorities"); do
  local id1,id2,job1,job2
  -- one way
  ok,id1 = bs:put(5,0,60,"first"); T:yes(ok)
  ok,id2 = bs:put(10,0,60,"second"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id1,data = "first"}} )
  T:eq( pk(bs:reserve()), {true,{id = id2,data = "second"}} )
  T:yes( bs:delete(id1) )
  T:yes( bs:delete(id2) )
  -- reverse way
  ok,id2 = bs:put(10,0,60,"second"); T:yes(ok)
  ok,id1 = bs:put(5,0,60,"first"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id1,data = "first"}} )
  T:eq( pk(bs:reserve()), {true,{id = id2,data = "second"}} )
  T:yes( bs:delete(id1) )
  T:yes( bs:delete(id2) )
  -- same priority
  ok,id1 = bs:put(5,0,60,"first"); T:yes(ok)
  ok,id2 = bs:put(5,0,60,"second"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id1,data = "first"}} )
  T:eq( pk(bs:reserve()), {true,{id = id2,data = "second"}} )
  T:yes( bs:delete(id1) )
  T:yes( bs:delete(id2) )
  -- priorities + delay
  t0 = gettime()
  ok,id1 = bs:put(5,1,60,"first"); T:yes(ok)
  ok,id2 = bs:put(10,0,60,"second"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id2,data = "second"}} )
  T:eq( pk(bs:reserve()), {true,{id = id1,data = "first"}} )
  T:eq( math.floor((gettime()-t0-1)*10), 0 ) -- took about 1s
  T:yes( bs:delete(id1) )
  T:yes( bs:delete(id2) )
end;T:done()

T:start("releasing"); do
  ok,id = bs:put(0,0,60,"hello"); T:yes(ok)
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  T:eq( pk(bs:reserve_with_timeout(0)), {true,nil} )
  T:yes( bs:release(id,0,0) )
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  T:yes( bs:delete(id) )
end; T:done()

T:start("burying and kicking"); do
  ok,id = bs:put(0,0,60,"hello"); T:yes(ok)
  T:eq( pk(bs:peek_ready()), {true,{id = id,data = "hello"}} )
  T:eq( pk(bs:peek_buried()), {true,nil} )
  T:eq( pk(bs:peek(id)), {true,{id = id,data = "hello"}} )
  T:eq( pk(bs:bury(id,0)), {false,"NOT_FOUND"} )
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  T:yes( bs:bury(id,0) )
  T:eq( pk(bs:peek_ready()), {true,nil} )
  T:eq( pk(bs:peek_buried()), {true,{id = id,data = "hello"}} )
  T:eq( pk(bs:peek(id)), {true,{id = id,data = "hello"}} )
  T:eq( pk(bs:reserve_with_timeout(0)), {true,nil} )
  T:eq( pk(bs:kick(10)), {true,1} )
  T:eq( pk(bs:peek_ready()), {true,{id = id,data = "hello"}} )
  T:eq( pk(bs:peek_buried()), {true,nil} )
  T:eq( pk(bs:reserve()), {true,{id = id,data = "hello"}} )
  T:yes( bs:delete(id) )
end; T:done()

T:start("stats"); do
  ok,id = bs:put(0,0,60,"hello"); T:yes(ok)
  T:eq( pk(bs:peek_ready()), {true,{id = id,data = "hello"}} )
  ok,res = bs:stats_job(id); T:yes(ok and res)
  res = yaml.load(res)
  T:yes( res and (res.id == id) and (res.tube == tube1) )
  ok,res = bs:stats_tube(tube1); T:yes(ok and res)
  res = yaml.load(res)
  T:yes( res and (res["current-jobs-ready"] == 1) )
  ok,res = bs:stats(); T:yes(ok and res)
  res = yaml.load(res)
  T:yes( res and (res["current-jobs-ready"] == 1) )
  ok = bs:delete(id); T:yes(ok)
  T:eq( pk(bs:list_tube_used()), {true,tube1} )
  ok,res = bs:list_tubes_watched(); T:yes(ok and res)
  res = yaml.load(res)
  T:eq( res, {tube1} )
  ok,res = bs:list_tubes(); T:yes(ok and res)
  res = yaml.load(res); T:eq( type(res), "table" )
end; T:done()

-- wrap up
ok,res = bs:reserve_with_timeout(0); assert(ok and (res == nil))
ok = bs:quit(); assert(ok)
ok,res = bs:reserve(); assert((not ok) and (res == "NOT_CONNECTED"))
