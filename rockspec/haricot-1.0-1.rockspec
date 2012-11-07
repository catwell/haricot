package = "haricot"
version = "1.0-1"

source = {
   url = "http://files.catwell.info/code/releases/haricot-1.0.tar.gz",
   md5 = "6293bc305e8253f2e18b64a8ed123e9a",
}

description = {
   summary = "A beanstalkd client.",
   detailed = [[
      Haricot is a client for Beanstalkd
      (http://kr.github.com/beanstalkd/).
   ]],
   homepage = "http://github.com/catwell/haricot",
   license = "MIT/X11",
}

dependencies = {
   "lua >= 5.1",
   "luasocket",
}

build = {
   type = "none",
   install = {
      lua = {
         haricot = "haricot.lua",
      },
   },
}
