const std = @import("std");
const Allocator = std.mem.Allocator;
const zlm = @import("zlm");

const c = @import("c.zig").stb;
const RenderCaps = @import("Config.zig").RenderCaps;
const UvRect = @import("draw.zig").UvRect;

const FontAtlas = @This();

const Layout = struct {
    width: u32,
    height: u32,

    cur_x: u32 = 0,
    cur_y: u32 = 0,
    advance_y: u32 = 0,

    const AllocInfo = struct {
        x: u32,
        y: u32,
        uv_rect: UvRect,
    };

    fn alloc(layout: *Layout, width: u32, height: u32) !AllocInfo {
        const padding = 1;

        if (layout.cur_x + width > layout.width) {
            layout.cur_x = 0;
            layout.cur_y += layout.advance_y + padding;
            layout.advance_y = 0;
        }

        const x = layout.cur_x;
        const y = layout.cur_y;
        const uv_rect: UvRect = .{
            .position = .{
                .x = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(layout.width)),
                .y = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(layout.height)),
            },
            .size = .{
                .x = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(layout.width)),
                .y = @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(layout.height)),
            },
        };

        layout.cur_x += width + padding;
        layout.advance_y = @max(layout.advance_y, height);

        if (layout.cur_y + layout.advance_y > layout.height) {
            return error.Overflow;
        }

        return .{
            .x = x,
            .y = y,
            .uv_rect = uv_rect,
        };
    }
};

const GlyphInfo = struct {
    advance: f32,

    offset: zlm.Vec2,
    size: zlm.Vec2,

    uv_rect: UvRect,
};

const GlyphMap = std.AutoHashMap(u8, GlyphInfo);

allocator: Allocator,

data: []u8,
width: u32,
height: u32,

advance_y: f32,

white_uv_rect: UvRect,
glyphs: GlyphMap,

pub fn init(allocator: Allocator, width: u32, height: u32, font_data: [:0]const u8, pixels_per_point: f32, scale_in_pixels: f32) !FontAtlas {
    var layout: Layout = .{
        .width = width,
        .height = height,
    };

    var font_info: c.struct_stbtt_fontinfo = undefined;
    if (c.stbtt_InitFont(&font_info, font_data, 0) == 0) {
        return error.FontInitError;
    }

    const scale_factor = c.stbtt_ScaleForPixelHeight(&font_info, scale_in_pixels);

    var ascent: c_int = undefined;
    var descent: c_int = undefined;
    var line_gap: c_int = undefined;
    c.stbtt_GetFontVMetrics(&font_info, &ascent, &descent, &line_gap);

    const data = try allocator.alloc(u8, width * height);
    @memset(data, 0);

    const white_alloc = try layout.alloc(1, 1);
    data[white_alloc.y * width + white_alloc.x] = 255;

    var glyphs = GlyphMap.init(allocator);
    {
        var x0: c_int = undefined;
        var y0: c_int = undefined;
        var x1: c_int = undefined;
        var y1: c_int = undefined;

        var advance: c_int = undefined;
        var lsb: c_int = undefined;

        var ch: u8 = 32;
        while (ch < 128) : (ch += 1) {
            c.stbtt_GetCodepointBitmapBox(&font_info, ch, scale_factor, scale_factor, &x0, &y0, &x1, &y1);
            c.stbtt_GetCodepointHMetrics(&font_info, ch, &advance, &lsb);

            const glyph_width = @as(u32, @intCast(x1 - x0));
            const glyph_height = @as(u32, @intCast(y1 - y0));

            const glyph_alloc = try layout.alloc(glyph_width, glyph_height);

            c.stbtt_MakeCodepointBitmap(
                &font_info,
                &data[glyph_alloc.y * width + glyph_alloc.x],
                @intCast(glyph_width),
                @intCast(glyph_height),
                @intCast(width),
                scale_factor,
                scale_factor,
                ch,
            );

            try glyphs.put(ch, .{
                .advance = @as(f32, @floatFromInt(advance)) * scale_factor / pixels_per_point,

                .offset = zlm.vec2(@floatFromInt(x0), @floatFromInt(y0)).div(.{ .x = pixels_per_point, .y = pixels_per_point }),
                .size = zlm.vec2(@floatFromInt(glyph_width), @floatFromInt(glyph_height)).div(.{ .x = pixels_per_point, .y = pixels_per_point }),

                .uv_rect = glyph_alloc.uv_rect,
            });
        }
    }

    return .{
        .allocator = allocator,

        .data = data,
        .width = width,
        .height = height,

        .advance_y = @as(f32, @floatFromInt(ascent - descent + line_gap)) * scale_factor / pixels_per_point,

        .white_uv_rect = white_alloc.uv_rect,
        .glyphs = glyphs,
    };
}

pub fn deinit(atlas: *FontAtlas) void {
    atlas.allocator.free(atlas.data);
    atlas.glyphs.deinit();
}
