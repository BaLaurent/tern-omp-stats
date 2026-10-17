--!strict
local check = require("./check")
require("./test_fmt")
require("./test_ranges")
require("./test_queries")
require("./test_host")
print(`all {check.count} checks passed`)
