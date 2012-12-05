package = "haricot"
version = "scm-1"

source = {
   url = "git://github.com/catwell/haricot.git",
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
   copy_directories = {},
}
