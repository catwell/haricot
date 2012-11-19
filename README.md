# Haricot

## Presentation

Haricot is a [Beanstalk](http://kr.github.com/beanstalkd/) client for Lua.

## Note about YAML

Haricot does not decode the YAML data returned by the following methods:

- stats-job
- stats-tube
- stats
- list-tubes
- list-tubes-watched

It returns raw YAML. Use your own decoding library if needed.

## Usage

### Creating a job

```lua
local haricot = require "haricot"
local bs = haricot.new("localhost",11300)
bs:put(2048,0,60,"hello")
```

### Consuming a job

```lua
local haricot = require "haricot"
local bs = haricot.new("localhost",11300)
local ok,job = bs:reserve(); assert(ok,job)
local id,data = job.id,job.data
print(data) -- "hello"
bs:delete(id)
```

### More

See haricot.test.lua.

## Copyright

Copyright (c) 2012 Moodstocks SAS
