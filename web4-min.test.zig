const std = @import("std");
const testing = std.testing;
const web4 = @import("web4-min.zig");

const MAX_U64: u64 = 18446744073709551615;

// Mock allocator for tests
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn panic(msg: []const u8) void {
    std.debug.panic("{s}", .{msg});
}

// Mock state for tests
var mock_storage: std.StringHashMap([]const u8) = undefined;
var mock_registers: std.StringHashMap([]const u8) = undefined;
var mock_input: []const u8 = "";
var mock_register: []const u8 = "";
var mock_return_value: []const u8 = "";
var mock_signer: []const u8 = "test.near";
var mock_current_account: []const u8 = "test.near";

// Mock NEAR runtime functions
export fn input(register_id: u64) void {
    mock_registers.put(std.fmt.allocPrint(testing.allocator, "{d}", .{register_id}) catch unreachable, mock_input) catch {
        panic("Failed to store in register");
    };
}

export fn read_register(register_id: u64, ptr: u64) void {
    const key = std.fmt.allocPrint(testing.allocator, "{d}", .{register_id}) catch unreachable;
    defer testing.allocator.free(key);
    if (mock_registers.get(key)) |data| {
        const dest = @as([*]u8, @ptrFromInt(ptr));
        @memcpy(dest[0..data.len], data);
    }
}

export fn register_len(register_id: u64) u64 {
    const key = std.fmt.allocPrint(testing.allocator, "{d}", .{register_id}) catch unreachable;
    defer testing.allocator.free(key);
    if (mock_registers.get(key)) |data| {
        return data.len;
    }
    return MAX_U64; // Match NEAR behavior when register not found
}

export fn value_return(len: u64, ptr: u64) void {
    const slice = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    mock_return_value = slice;
}

export fn storage_read(key_len: u64, key_ptr: u64, _: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    if (mock_storage.get(key)) |value| {
        mock_register = value;
        return 1;
    }
    return 0;
}

export fn storage_write(key_len: u64, key_ptr: u64, value_len: u64, value_ptr: u64, _: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    const value = @as([*]const u8, @ptrFromInt(value_ptr))[0..value_len];
    mock_storage.put(key, value) catch return 0;
    return 1;
}

export fn log_utf8(_: u64, _: u64) void {
    // No-op for tests
}

export fn panic_utf8(_: u64, _: u64) void {
    // No-op for tests, or could set a flag to check if panic occurred
}

export fn signer_account_id(_: u64) void {
    mock_register = mock_signer;
}

export fn current_account_id(_: u64) void {
    mock_register = mock_current_account;
}

// Test setup/cleanup helpers
fn setupTest() !void {
    mock_storage = std.StringHashMap([]const u8).init(testing.allocator);
    mock_registers = std.StringHashMap([]const u8).init(testing.allocator);
    mock_input = "";
    mock_register = "";
    mock_return_value = "";
    mock_signer = "test.near";
    mock_current_account = "test.near";
}

fn cleanupTest() void {
    mock_storage.deinit();
    mock_registers.deinit();
    // Clear any allocated memory
    var it = mock_registers.iterator();
    while (it.next()) |entry| {
        testing.allocator.free(entry.key_ptr.*);
    }
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
