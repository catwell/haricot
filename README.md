# Haricot

[![Build Status](https://travis-ci.org/catwell/haricot.png?branch=master)](https://travis-ci.org/catwell/haricot)

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

## Dependencies

Haricot only depends on LuaSocket.

Tests require [cwtest](https://github.com/catwell/cwtest),
a YAML parser such as [lyaml](https://github.com/gvvaughan/lyaml) or
[the one from lubyk](https://github.com/lubyk/yaml/)
and a running beanstalkd instance.

## Usage

### Creating a job

```lua
local haricot = require "haricot"
local bs = haricot.new("localhost", 11300)
bs:put(2048, 0, 60, "hello")
```

### Consuming a job

```lua
local haricot = require "haricot"
local bs = haricot.new("localhost", 11300)
local ok, job = bs:reserve(); assert(ok, job)
local id, data = job.id, job.data
print(data) -- "hello"
bs:delete(id)
```

### More

See haricot.test.lua.

## Copyright

- Copyright (c) 2012-2013 Moodstocks SAS
- Copyright (c) 2014-2017 Pierre Chapuis
