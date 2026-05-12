# GrowToolsLua

Pure Lua 5.4 tools for Growtopia assets. The project includes RTTEX/RTPACK conversion and `items.dat` parsing without external Lua libraries.

## Usage

Pack a PNG into RTPACK-wrapped RTTEX:

```bash
lua5.4 main.lua pack input.png output.rttex
```

Unpack RTTEX or RTPACK into PNG:

```bash
lua5.4 main.lua unpack input.rttex output.png
```

Use it as a module:

```lua
local rttex = require("main")

local rtpack_bytes = rttex.RTTEXPack("input.png")
local png_bytes = rttex.RTTEXUnpack("input.rttex")
```

Inspect an `items.dat` file:

```bash
lua5.4 main.lua items items.dat
lua5.4 main.lua items items.dat 0
```

Inspect a world dump:

```bash
lua5.4 main.lua world world.dat
lua5.4 main.lua world-tile world.dat 0 0
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
src/world_dat.lua Pure Lua world.dat parser
src/inspect.lua   Human-readable CLI output helpers
src/cli.lua       Command-line interface
```

## Bundle

Build a single-file Lua script:

```bash
lua5.4 tools/bundle.lua
```

The generated file is written to `dist/rttex_tools.lua` and supports the same CLI:

```bash
lua5.4 dist/rttex_tools.lua pack input.png output.rttex
lua5.4 dist/rttex_tools.lua unpack input.rttex output.png
lua5.4 dist/rttex_tools.lua items items.dat 0
```

## Notes

The PNG decoder supports 8-bit PNG color types 0, 2, 3, 4, and 6. Output PNG files are encoded as RGBA.
