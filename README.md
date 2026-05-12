# GrowToolsLua

Pure Lua 5.4 tools for Growtopia assets. The project includes RTTEX/RTPACK conversion, `items.dat` parsing, `world.dat` parsing, zlib/PNG helpers, and vendored CBOR support without external Lua libraries.

## Features

- Convert PNG files to RTPACK-wrapped RTTEX.
- Convert RTTEX or RTPACK files back to PNG.
- Parse Growtopia `items.dat` files.
- Parse Growtopia world dumps / `world.dat` files.
- Decode world tile CBOR payloads for supported tile data.
- Build Growtopia dialog strings with `DialogBuilder`.
- Build a single-file bundle for distribution.

## Usage

### CLI

```bash
lua5.4 main.lua pack input.png output.rttex
lua5.4 main.lua unpack input.rttex output.png
lua5.4 main.lua items items.dat
lua5.4 main.lua items items.dat 0
lua5.4 main.lua world world.dat
lua5.4 main.lua world-tile world.dat 0 0
```

### Module

```lua
local GTLua = require("main")

local rtpack_bytes = GTLua.RTTEXPack("input.png")
local png_bytes = GTLua.RTTEXUnpack("input.rttex")

local ItemsDat = require("GTLua.items_dat")
local items = ItemsDat.load_file("items.dat")
local item = ItemsDat.get_item(items, 0)

local WorldDat = require("GTLua.world_dat")
local world = WorldDat.load_file("world.dat")
local tile = WorldDat.get_tile(world, 0, 0)
```

You can also require `main` only to register the public preload names:

```lua
require("main")

local DialogBuilder = require("GTLua.dialog_builder")
local dialog = DialogBuilder.new("`o"):add_button("ok", "OK"):to_string()
```

### Dialog Builder

```lua
require("main")

local DialogBuilder = require("GTLua.dialog_builder")

local dialog = DialogBuilder
    .new("`o")
    :add_label_icon(true, 242, "`wExample Dialog``")
    :add_spacer(false)
    :add_textbox("Hello from GrowToolsLua.")
    :add_text_input(32, "name", "Name:", "")
    :add_checkbox(true, "enabled", "Enabled")
    :end_dialog("example", "Cancel", "OK")
    :add_quick_exit()
    :to_string()
```

## Project Structure

```text
main.lua          CLI entrypoint and compatibility module
src/binary.lua    Binary IO and endian helpers
src/checksum.lua  CRC-32 and Adler-32 helpers
src/zlib.lua      Pure Lua zlib inflate and deflate
src/png.lua       Pure Lua PNG decoder and encoder
src/rttex.lua     RTTEX/RTPACK pack and unpack logic
src/items_dat.lua Pure Lua items.dat parser
src/cbor.lua      Vendored Lua-CBOR decoder/encoder
src/world_dat.lua Pure Lua world.dat parser
src/dialog_builder.lua Growtopia dialog string builder
src/inspect.lua   Human-readable CLI output helpers
src/cli.lua       Command-line interface
```

## Bundle

Build a single-file Lua script:

```bash
lua5.4 tools/bundle.lua
```

The generated file is written to `dist/GrowToolsLua.lua` and supports the same CLI:

```bash
lua5.4 dist/GrowToolsLua.lua pack input.png output.rttex
lua5.4 dist/GrowToolsLua.lua unpack input.rttex output.png
lua5.4 dist/GrowToolsLua.lua items items.dat 0
lua5.4 dist/GrowToolsLua.lua world world.dat
lua5.4 dist/GrowToolsLua.lua world-tile world.dat 0 0
```

The bundle exposes public preload names under `GTLua.*`:

```lua
local GTLua = dofile("dist/GrowToolsLua.lua")

local rttex = require("GTLua.rttex")
local items_dat = require("GTLua.items_dat")
local world_dat = require("GTLua.world_dat")
local cbor = require("GTLua.cbor")
local DialogBuilder = require("GTLua.dialog_builder")

local packed = GTLua.RTTEXPack("input.png")
```

## Notes

- The PNG decoder supports 8-bit PNG color types 0, 2, 3, 4, and 6.
- Output PNG files are encoded as RGBA.
- The pure Lua deflate encoder uses fixed Huffman compression. It is valid zlib, but may be larger than native dynamic-Huffman zlib output.
- World parser support is based on modern version 25 world dumps and has been smoke-tested with sample worlds from `CLOEI/gtworld-r`.
- `src.cbor` is used by `src.world_dat` for world tile CBOR payloads. It is not needed for RTTEX or `items.dat`.

## Vendored Code

`src/cbor.lua` is Lua-CBOR by Kim Alvefur, licensed under the MIT license. The license text is included in `licenses/lua-cbor-MIT.txt`.

## References

- `DialogBuilder` API is based on `Dialog.h` from Growhoshi by LyNnz01:
  https://raw.githubusercontent.com/LyNnz01/Growhoshi/589fa8c5ae96a4ffdb33ca5bcf6603752be45c50/Server.sh/Dialog.h
- `items.dat` parser layout references `CLOEI/gtitem-r`:
  https://github.com/CLOEI/gtitem-r
- `world.dat` parser layout references `CLOEI/gtworld-r`:
  https://github.com/CLOEI/gtworld-r
- Lua-CBOR is vendored from Kim Alvefur's Lua-CBOR:
  https://www.zash.se/lua-cbor.html
