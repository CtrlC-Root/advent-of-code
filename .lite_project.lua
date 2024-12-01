local config = require "core.config"

config.ignore_files = {
  -- Fossil
  "^%.fslckout",

  -- zig
  "^/%.zig%-cache/",
}

config.plugins.trimwitespace = true
