const std = @import("std");
const Allocator = std.mem.Allocator;

const FontAtlas = @import("FontAtlas.zig");

const Ui = @This();

allocator: Allocator,
font_atlas: FontAtlas,

pub fn init(allocator: Allocator) Ui {
    return .{
        .allocator = allocator,
    };
}

pub fn on_event(ui: *Ui) void {
    _ = ui;
}

pub fn deinit(ui: *Ui) void {
    _ = ui;
}
