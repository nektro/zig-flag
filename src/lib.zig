const std = @import("std");
const string = []const u8;
const List = std.ArrayList(string);
const extras = @import("extras");

var singles: std.StringArrayHashMap(string) = undefined;
var multis: std.StringArrayHashMap(List) = undefined;

pub fn init(alloc: *std.mem.Allocator) void {
    singles = std.StringArrayHashMap(string).init(alloc);
    multis = std.StringArrayHashMap(List).init(alloc);
}

pub fn addSingle(name: string) !void {
    try singles.putNoClobber(name, "");
}

pub fn addMulti(name: string) !void {
    try multis.putNoClobber(name, List.init(multis.allocator));
}

pub const FlagDashKind = enum {
    single,
    double,

    pub fn hypen(self: FlagDashKind) string {
        return switch (self) {
            .single => "-",
            .double => "--",
        };
    }
};

pub fn parse(k: FlagDashKind) !std.process.ArgIterator {
    const dash = k.hypen();
    var argiter = std.process.args();
    defer argiter.deinit();
    var argi: usize = 0;
    blk: while (argiter.next(singles.allocator)) |item| : (argi += 1) {
        if (argi == 0) continue;
        const data = try item;
        const name = extras.trimPrefix(data, dash);
        if (data.len == name.len) return error.BadFlag;

        for (singles.keys()) |jtem| {
            if (std.mem.eql(u8, name, jtem)) {
                const value = try argiter.next(singles.allocator).?;
                try singles.put(name, value);
                continue :blk;
            }
        }
        for (multis.keys()) |jtem| {
            if (std.mem.eql(u8, name, jtem)) {
                const value = try argiter.next(multis.allocator).?;
                try multis.get(name).?.append(value);
                continue :blk;
            }
        }
        std.log.err("Unrecognized argument: {s}{s}", .{ dash, name });
        std.os.exit(1);
    }
    return argiter;
}

pub fn getSingle(name: string) ?string {
    const x = singles.get(name).?;
    return if (x.len > 0) x else null;
}

pub fn getMulti(name: string) ?[]const string {
    const x = multis.get(name).?.toOwnedSlice();
    return if (x.len > 0) x else null;
}
