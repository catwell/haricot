require "pl.strict"

local ok,res,err,id,job
local haricot = require "haricot"
local beanstalk = haricot.new("localhost",11300)

ok,res = beanstalk:put(0,0,60,"hello"); assert(ok)
id = res
ok,res = beanstalk:reserve(); assert(ok)
job = res
assert(job.id == id)
assert(job.data == "hello")

ok,err = beanstalk:delete(id)
assert(ok,err)
