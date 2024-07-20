const std = @import("std");
const Allocator = std.mem.Allocator;
const zlm = @import("zlm");
const c = @import("c.zig").stb;

const Font = @This();

pub const CharInfo = struct {
    pix_pos: zlm.Vec2,
    pix_size: zlm.Vec2,
    tex_pos: zlm.Vec2,
    tex_size: zlm.Vec2,
    advance: f32,
    lsb: f32,
};

const CharMap = std.AutoHashMap(u8, CharInfo);

allocator: Allocator,
atlas_data: []u8,
atlas_width: u32,
atlas_height: u32,
ascent: f32,
chars: CharMap,

pub fn load(allocator: Allocator, data: [:0]const u8, height: f32) !Font {
    var info: c.struct_stbtt_fontinfo = undefined;
    if (c.stbtt_InitFont(&info, data, 0) == 0) {
        return error.FontInitError;
    }

    const scale = c.stbtt_ScaleForPixelHeight(&info, height);

    var ascent: c_int = undefined;
    var descent: c_int = undefined;
    var line_gap: c_int = undefined;
    c.stbtt_GetFontVMetrics(&info, &ascent, &descent, &line_gap);

    var atlas_width: u32 = 0;
    const atlas_height: u32 = @intFromFloat(@ceil(height));

    var x0: c_int = undefined;
    var y0: c_int = undefined;
    var x1: c_int = undefined;
    var y1: c_int = undefined;
    var advance: c_int = undefined;
    var lsb: c_int = undefined;

    var ch: u8 = 32;
    while (ch < 128) : (ch += 1) {
        c.stbtt_GetCodepointBitmapBox(&info, ch, scale, scale, &x0, &y0, &x1, &y1);
        atlas_width += @intCast(x1 - x0);
    }

    var atlas_data = try allocator.alloc(u8, atlas_width * atlas_height);
    @memset(atlas_data, 0);

    var chars = CharMap.init(allocator);

    var offset: u32 = 0;
    ch = 32;
    while (ch < 128) : (ch += 1) {
        c.stbtt_GetCodepointBitmapBox(&info, ch, scale, scale, &x0, &y0, &x1, &y1);
        c.stbtt_MakeCodepointBitmap(&info, &atlas_data[offset], x1 - x0, y1 - y0, @intCast(atlas_width), scale, scale, ch);
        c.stbtt_GetCodepointHMetrics(&info, ch, &advance, &lsb);

        try chars.put(ch, .{
            .pix_pos = zlm.vec2(@floatFromInt(x0), @floatFromInt(y0)),
            .pix_size = zlm.vec2(@floatFromInt(x0), @floatFromInt(y0)),
            .tex_pos = zlm.vec2(@as(f32, @floatFromInt(offset)) / @as(f32, @floatFromInt(atlas_width)), 0.0),
            .tex_size = zlm.vec2(
                @as(f32, @floatFromInt(x1 - x0)) / @as(f32, @floatFromInt(atlas_width)),
                @as(f32, @floatFromInt(y1 - y0)) / @as(f32, @floatFromInt(atlas_height)),
            ),
            .advance = @as(f32, @floatFromInt(advance)) * scale,
            .lsb = @as(f32, @floatFromInt(lsb)) * scale,
        });

        offset += @intCast(x1 - x0);
    }

    return .{
        .allocator = allocator,
        .atlas_data = atlas_data,
        .atlas_width = atlas_width,
        .atlas_height = atlas_height,
        .ascent = @as(f32, @floatFromInt(ascent)) * scale,
        .chars = chars,
    };
}

pub fn deinit(font: *Font) void {
    font.allocator.free(font.atlas_data);
    font.chars.deinit();
}
