# Haricot

[![CI Status](github.com/catwell/haricot/actions/workflows/ci.yml/badge.svg?branch=master)

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

Haricot only depends on LuaSocket or lsocket.

Tests require [cwtest](https://github.com/catwell/cwtest), a YAML parser such as
[tinyyaml](https://luarocks.org/modules/membphis/lua-tinyyaml), [lyaml](https://github.com/gvvaughan/lyaml) or [the one from lubyk](https://github.com/lubyk/yaml/), both LuaSocket and lsocket and a running beanstalkd instance.

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
- Copyright (c) 2014-2022 Pierre Chapuis
