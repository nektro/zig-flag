const std = @import("std");
const flag = @import("flag");

test {
    std.testing.refAllDeclsRecursive(flag);
}
