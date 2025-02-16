const std = @import("std");
const testing = std.testing;
const web4 = @import("web4-min.zig");

const MAX_U64: u64 = 18446744073709551615;

fn panic(msg: []const u8) void {
    std.debug.panic("{s}", .{msg});
}

// Mock state for tests
var mock_storage: std.StringHashMap([]const u8) = undefined;
var mock_registers: std.AutoHashMap(u64, []const u8) = undefined;
var mock_input: []u8 = "";
var mock_register: []u8 = "";
var mock_return_value: []u8 = "";
var mock_signer: []u8 = undefined;
var mock_current_account: []u8 = undefined;

// Mock NEAR runtime functions
export fn input(register_id: u64) void {
    mock_registers.put(register_id, mock_input) catch {
        panic("Failed to store in register");
    };
}

export fn read_register(register_id: u64, ptr: u64) void {
    if (mock_registers.get(register_id)) |data| {
        const dest = @as([*]u8, @ptrFromInt(ptr));
        @memcpy(dest[0..data.len], data);
    }
}

export fn register_len(register_id: u64) u64 {
    if (mock_registers.get(register_id)) |data| {
        return data.len;
    }
    return MAX_U64; // Match NEAR behavior when register not found
}

export fn value_return(len: u64, ptr: u64) void {
    const slice = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    testing.allocator.free(mock_return_value);
    mock_return_value = testing.allocator.dupe(u8, slice) catch {
        panic("Failed to duplicate return value");
        unreachable;
    };
}

export fn storage_read(key_len: u64, key_ptr: u64, _: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    if (mock_storage.get(key)) |value| {
        testing.allocator.free(mock_register);
        mock_register = testing.allocator.dupe(u8, value) catch {
            panic("Failed to duplicate register value");
            unreachable;
        };
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
    mock_registers = std.AutoHashMap(u64, []const u8).init(testing.allocator);
    
    mock_input = try testing.allocator.dupe(u8, "");
    mock_register = try testing.allocator.dupe(u8, "");
    mock_return_value = try testing.allocator.dupe(u8, "");
    mock_signer = try testing.allocator.dupe(u8, "test.near");
    mock_current_account = try testing.allocator.dupe(u8, "test.near");
}

fn cleanupTest() void {
    mock_registers.deinit();
    mock_storage.deinit();
    
    testing.allocator.free(mock_input);
    testing.allocator.free(mock_register);
    testing.allocator.free(mock_return_value);
    testing.allocator.free(mock_signer);
    testing.allocator.free(mock_current_account);
}

test "web4_get returns default URL for new contract" {
    try setupTest();
    defer cleanupTest();

    // Set input JSON
    mock_input = try testing.allocator.dupe(u8, "{\"path\": \"/\"}");

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
    mock_input = try testing.allocator.dupe(u8, "{\"path\": \"/about\"}");

    // Call the function
    web4.web4_get();

    // Verify response redirects to index.html
    try testing.expect(std.mem.indexOf(u8, mock_return_value, "/index.html") != null);
}
