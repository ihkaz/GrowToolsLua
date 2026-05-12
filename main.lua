local MODULES = {
    { public_name = "GTLua.binary", internal_name = "src.binary" },
    { public_name = "GTLua.checksum", internal_name = "src.checksum" },
    { public_name = "GTLua.zlib", internal_name = "src.zlib" },
    { public_name = "GTLua.png", internal_name = "src.png" },
    { public_name = "GTLua.rttex", internal_name = "src.rttex" },
    { public_name = "GTLua.items_dat", internal_name = "src.items_dat" },
    { public_name = "GTLua.cbor", internal_name = "src.cbor" },
    { public_name = "GTLua.world_dat", internal_name = "src.world_dat" },
    { public_name = "GTLua.dialog_builder", internal_name = "src.dialog_builder" },
    { public_name = "GTLua.inspect", internal_name = "src.inspect" },
    { public_name = "GTLua.cli", internal_name = "src.cli" },
}

for _, module in ipairs(MODULES) do
    package.preload[module.public_name] = function()
        return require(module.internal_name)
    end
end

local GTLua = {
    binary = require("GTLua.binary"),
    checksum = require("GTLua.checksum"),
    zlib = require("GTLua.zlib"),
    png = require("GTLua.png"),
    rttex = require("GTLua.rttex"),
    items_dat = require("GTLua.items_dat"),
    cbor = require("GTLua.cbor"),
    world_dat = require("GTLua.world_dat"),
    dialog_builder = require("GTLua.dialog_builder"),
}

GTLua.RTTEXPack = GTLua.rttex.RTTEXPack
GTLua.RTTEXUnpack = GTLua.rttex.RTTEXUnpack

if ... ~= "main" then
    require("GTLua.cli").run(arg)
end

return GTLua
