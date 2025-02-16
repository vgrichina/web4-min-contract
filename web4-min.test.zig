const std = @import("std");
const testing = std.testing;
const web4 = @import("web4-min.zig");

// Mock allocator for tests
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Mock NEAR runtime functions for testing
var mock_storage: std.StringHashMap([]const u8) = undefined;
var mock_input: []const u8 = "";
var mock_register: []const u8 = "";
var mock_return_value: []const u8 = "";

export fn input(_: u64) void {
    mock_register = mock_input;
}

export fn read_register(_: u64, _: u64) void {
    mock_register = mock_register;
}

export fn register_len(_: u64) u64 {
    return mock_register.len;
}

export fn value_return(len: u64, ptr: u64) void {
    const slice = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    mock_return_value = slice;
}

export fn storage_read(key_len: u64, key_ptr: u64, _: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    if (mock_storage.get(key)) |_| {
        return 1;
    }
    return 0;
}

fn setupTest() !void {
    mock_storage = std.StringHashMap([]const u8).init(testing.allocator);
    mock_input = "";
    mock_register = "";
    mock_return_value = "";
}

fn cleanupTest() void {
    mock_storage.deinit();
}

test "web4_get returns default URL for new contract" {
    try setupTest();
    defer cleanupTest();

    // Set input JSON
    mock_input = \\{"path": "/"}
    ;

    // Call the function
    web4.web4_get();

    // Verify response contains DEFAULT_STATIC_URL
    try testing.expect(std.mem.indexOf(u8, mock_return_value, web4.DEFAULT_STATIC_URL) != null);
    try testing.expect(std.mem.indexOf(u8, mock_return_value, "200") != null);
}

test "web4_get serves index.html for SPA routes" {
    try setupTest();
    defer cleanupTest();

    // Set input JSON
    mock_input = \\{"path": "/about"}
    ;

    // Call the function
    web4.web4_get();

    // Verify response redirects to index.html
    try testing.expect(std.mem.indexOf(u8, mock_return_value, "/index.html") != null);
}
