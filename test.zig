const std = @import("std");
const flag = @import("flag");

test {
    _ = &flag.init;
    _ = &flag.deinit;
    _ = &flag.addSingle;
    _ = &flag.addMulti;
    _ = &flag.parse;
    _ = &flag.parseEnv;
    _ = &flag.getSingle;
    _ = &flag.getMulti;
    _ = &flag.getBool;
}
