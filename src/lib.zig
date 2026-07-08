const std = @import("std");
const builtin = @import("builtin");
const string = [:0]const u8;
const List = std.array_list.Managed(string);
const extras = @import("extras");
const linux = @import("sys-linux");

const sys = switch (builtin.target.os.tag) {
    .linux => linux,
    else => unreachable, // TODO:
};

var allocator: std.mem.Allocator = undefined;
var singles: std.array_hash_map.String(string) = .empty;
var multis: std.array_hash_map.String(List) = .empty;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn deinit() void {
    singles.deinit(allocator);
    for (multis.values()) |array_list| {
        array_list.deinit();
    }
    multis.deinit(allocator);
}

pub fn addSingle(name: string) !void {
    try singles.putNoClobber(allocator, name, "");
}

pub fn addMulti(name: string) !void {
    try multis.putNoClobber(allocator, name, List.init(allocator));
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

pub fn parse(k: FlagDashKind, args: std.process.Args) !std.process.Args.Iterator {
    const dash = k.hypen();
    var argiter = args.iterate();
    defer argiter.deinit();
    var argi: usize = 0;
    blk: while (argiter.next()) |item| : (argi += 1) {
        const data = item;
        if (argi == 0) continue;
        const name: string = @ptrCast(extras.trimPrefix(data, dash));
        if (data.len == name.len) return error.BadFlag;

        for (singles.keys()) |jtem| {
            if (std.mem.eql(u8, name, jtem)) {
                const value = argiter.next().?;
                argi += 1;
                try singles.put(allocator, name, value);
                continue :blk;
            }
        }
        for (multis.keys()) |jtem| {
            if (std.mem.eql(u8, name, jtem)) {
                const value = argiter.next().?;
                argi += 1;
                try multis.getEntry(name).?.value_ptr.append(value);
                continue :blk;
            }
        }
        std.log.err("Unrecognized argument: {s}{s}", .{ dash, name });
        sys.exit(1);
    }
    return argiter;
}

pub fn parseEnv() !void {
    for (singles.keys(), singles.values()) |k, *v| {
        var buf: [64]u8 = @splat(0);
        for (k, 0..) |c, i| buf[i] = switch (c) {
            'A'...'Z', '_', '0'...'9' => |a| a,
            'a'...'z' => |a| a - 'a' + 'A',
            '-' => '_',
            else => unreachable,
        };
        if (sys.getenv(buf[0..k.len :0])) |value| {
            v.* = value;
        }
    }
    for (multis.keys(), multis.values()) |k, *v| {
        var n: usize = 1;
        while (true) : (n += 1) {
            var buf: [64]u8 = @splat(0);
            for (k, 0..) |c, i| buf[i] = switch (c) {
                'A'...'Z', '_', '0'...'9' => |a| a,
                'a'...'z' => |a| a - 'a' + 'A',
                '-' => '_',
                else => unreachable,
            };
            const buf2 = try std.fmt.bufPrint(buf[k.len..], "_{d}", .{n});
            const w = buf[0 .. k.len + buf2.len :0];
            const value = sys.getenv(w) orelse break;
            try v.append(value);
        }
    }
}

fn fixNameForEnv(alloc: std.mem.Allocator, input: string) ![:0]const u8 {
    var ret = try extras.asciiUpper(alloc, input);
    for (0..ret.len) |i| {
        if (ret[i] == '-') {
            ret[i] = '_';
        }
    }
    return ret;
}

pub fn getSingle(name: string) ?string {
    const x = singles.get(name) orelse return null;
    return if (x.len > 0) x else null;
}

pub fn getMulti(name: string) ?[]const string {
    const x = (multis.get(name) orelse return null).items;
    return if (x.len > 0) x else null;
}

pub fn getBool(name: string, default: bool) bool {
    const x = getSingle(name) orelse return default;
    if (std.mem.eql(u8, x, "true")) return true;
    const y = extras.parseDigits(u1, x, 2) catch return default;
    return y > 0;
}
