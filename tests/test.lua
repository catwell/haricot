require "pl.strict"
local haricot = require "haricot"

local printf = function(p,...)
  io.stdout:write(string.format(p,...)); io.stdout:flush()
end

local ok,res,id,job
local tube1 = "$haricot$-test1"

printf("simple ")
local bs = haricot.new("localhost",11300); assert(bs); printf(".")
ok,res = bs:watch(tube1); assert(ok and (res == 2)); printf(".")
ok,res = bs:ignore("default"); assert(ok and (res == 1)); printf(".")
ok,err = bs:use(tube1); assert(ok); printf(".")
ok,id = bs:put(0,0,60,"hello"); assert(ok); printf(".")
ok,job = bs:reserve(); assert(ok)
assert((job.id == id) and (job.data == "hello")); printf(".")
ok = bs:delete(id); assert(ok); printf(".")
print(" OK")
