const std = @import("std");
const string = []const u8;
const List = std.ArrayList(string);
const extras = @import("extras");
const range = @import("range").range;

var singles: std.StringArrayHashMap(string) = undefined;
var multis: std.StringArrayHashMap(List) = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    singles = std.StringArrayHashMap(string).init(alloc);
    multis = std.StringArrayHashMap(List).init(alloc);
}

pub fn deinit() void {
    var iter1 = singles.iterator();
    while (iter1.next()) |entry| singles.allocator.free(entry.value_ptr.*);
    singles.deinit();

    var iter2 = multis.iterator();
    while (iter2.next()) |entry| {
        for (entry.value_ptr.items) |item| multis.allocator.free(item);
        entry.value_ptr.deinit();
    }
    multis.deinit();
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
    blk: while (argiter.next()) |item| : (argi += 1) {
        const data = item;
        if (argi == 0) continue;
        const name = extras.trimPrefix(data, dash);
        if (data.len == name.len) return error.BadFlag;

        for (singles.keys()) |jtem| {
            if (std.mem.eql(u8, name, jtem)) {
                const value = argiter.next().?;
                try singles.put(name, value);
                continue :blk;
            }
        }
        for (multis.keys()) |jtem| {
            if (std.mem.eql(u8, name, jtem)) {
                const value = argiter.next().?;
                try multis.getEntry(name).?.value_ptr.append(value);
                continue :blk;
            }
        }
        std.log.err("Unrecognized argument: {s}{s}", .{ dash, name });
        std.os.exit(1);
    }
    return argiter;
}

pub fn parseEnv() !void {
    const alloc = singles.allocator;

    for (singles.keys()) |jtem| {
        const u = try fixNameForEnv(alloc, jtem);
        defer alloc.free(u);
        if (std.os.getenv(u)) |value| {
            try singles.put(jtem, value);
        }
    }
    for (multis.keys()) |jtem| {
        const e = multis.getEntry(jtem).?;
        var n: usize = 1;
        while (true) : (n += 1) {
            const u = try fixNameForEnv(alloc, e.key_ptr.*);
            defer alloc.free(u);
            const k = try std.fmt.allocPrint(alloc, "{s}_{d}", .{ u, n });
            defer alloc.free(k);
            if (std.os.getenv(k)) |value| {
                try e.value_ptr.append(value);
                continue;
            }
            break;
        }
    }
}

fn fixNameForEnv(alloc: std.mem.Allocator, input: string) !string {
    var ret = try extras.asciiUpper(alloc, input);
    for (range(ret.len)) |_, i| {
        if (ret[i] == '-') {
            ret[i] = '_';
        }
    }
    return ret;
}

pub fn getSingle(name: string) ?string {
    const x = singles.get(name).?;
    return if (x.len > 0) x else null;
}

pub fn getMulti(name: string) ?[]const string {
    const x = multis.get(name).?.toOwnedSlice();
    return if (x.len > 0) x else null;
}
