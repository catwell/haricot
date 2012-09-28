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

See tests/test.lua.

## Copyright

Copyright (c) 2012 Moodstocks SAS
