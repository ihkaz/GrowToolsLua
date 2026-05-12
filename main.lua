local Rttex = require("src.rttex")

if ... ~= "main" then
    require("src.cli").run(arg)
end

return Rttex
