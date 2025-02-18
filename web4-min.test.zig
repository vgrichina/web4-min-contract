const std = @import("std");
const testing = std.testing;
const web4 = @import("web4-min.zig");

const MAX_U64: u64 = 18446744073709551615;

fn panic(msg: []const u8) void {
    std.debug.panic("{s}", .{msg});
}

const TestContext = struct {
    storage: std.StringHashMap([]const u8),
    registers: std.AutoHashMap(u64, []const u8),
    input: []u8,
    register: []u8,
    return_value: []u8,
    signer: []u8,
    current_account: []u8,

    pub fn init() !TestContext {
        return TestContext{
            .storage = std.StringHashMap([]const u8).init(testing.allocator),
            .registers = std.AutoHashMap(u64, []const u8).init(testing.allocator),
            .input = try testing.allocator.dupe(u8, ""),
            .register = try testing.allocator.dupe(u8, ""),
            .return_value = try testing.allocator.dupe(u8, ""),
            .signer = try testing.allocator.dupe(u8, "test.near"),
            .current_account = try testing.allocator.dupe(u8, "test.near"),
        };
    }

    pub fn deinit(self: *TestContext) void {
        self.storage.deinit();
        self.registers.deinit();
        testing.allocator.free(self.input);
        testing.allocator.free(self.register);
        testing.allocator.free(self.return_value);
        testing.allocator.free(self.signer);
        testing.allocator.free(self.current_account);
    }

    pub fn setInput(self: *TestContext, new_input: []const u8) !void {
        testing.allocator.free(self.input);
        self.input = try testing.allocator.dupe(u8, new_input);
    }

    pub fn setSigner(self: *TestContext, new_signer: []const u8) !void {
        testing.allocator.free(self.signer);
        self.signer = try testing.allocator.dupe(u8, new_signer);
    }

    pub fn setCurrentAccount(self: *TestContext, new_account: []const u8) !void {
        testing.allocator.free(self.current_account);
        self.current_account = try testing.allocator.dupe(u8, new_account);
    }
};

// Mock state for tests
var ctx: TestContext = undefined;

fn updateSigner(new_signer: []const u8) !void {
    try ctx.setSigner(new_signer);
}

fn updateCurrentAccount(new_account: []const u8) !void {
    try ctx.setCurrentAccount(new_account);
}

// Mock NEAR runtime functions
export fn input(register_id: u64) void {
    ctx.registers.put(register_id, ctx.input) catch {
        panic("Failed to store in register");
    };
}

export fn read_register(register_id: u64, ptr: u64) void {
    if (ctx.registers.get(register_id)) |data| {
        const dest = @as([*]u8, @ptrFromInt(ptr));
        @memcpy(dest[0..data.len], data);
    }
}

export fn register_len(register_id: u64) u64 {
    if (ctx.registers.get(register_id)) |data| {
        return data.len;
    }
    return MAX_U64; // Match NEAR behavior when register not found
}

export fn value_return(len: u64, ptr: u64) void {
    const slice = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    testing.allocator.free(ctx.return_value);
    ctx.return_value = testing.allocator.dupe(u8, slice) catch {
        panic("Failed to duplicate return value");
        unreachable;
    };
}

export fn storage_read(key_len: u64, key_ptr: u64, register_id: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    if (ctx.storage.get(key)) |value| {
        ctx.registers.put(register_id, value) catch {
            panic("Failed to store in register");
        };
        return 1;
    }
    return 0;
}

export fn storage_write(key_len: u64, key_ptr: u64, value_len: u64, value_ptr: u64, _: u64) u64 {
    const key = @as([*]const u8, @ptrFromInt(key_ptr))[0..key_len];
    const value = @as([*]const u8, @ptrFromInt(value_ptr))[0..value_len];
    ctx.storage.put(key, value) catch return 0;
    return 1;
}

export fn log_utf8(len: u64, ptr: u64) void {
    const msg = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    std.debug.print("LOG: {s}\n", .{msg});
}

export fn panic_utf8(_: u64, _: u64) void {
    // No-op for tests, or could set a flag to check if panic occurred
}

export fn signer_account_id(register_id: u64) void {
    ctx.registers.put(register_id, ctx.signer) catch {
        panic("Failed to store in register");
    };
}

export fn current_account_id(register_id: u64) void {
    ctx.registers.put(register_id, ctx.current_account) catch {
        panic("Failed to store in register");
    };
}

// Test setup/cleanup helpers
fn setupTest() !void {
    ctx = try TestContext.init();
}

fn cleanupTest() void {
    ctx.deinit();
}

test "web4_get returns default URL for new contract" {
    try setupTest();
    defer cleanupTest();

    // Set input JSON
    try ctx.setInput("{\"path\": \"/\"}");

    // Call the function
    web4.web4_get();

    // Verify response contains DEFAULT_STATIC_URL
    try testing.expect(std.mem.indexOf(u8, ctx.return_value, web4.DEFAULT_STATIC_URL) != null);
    try testing.expect(std.mem.indexOf(u8, ctx.return_value, "200") != null);
}

test "web4_get serves index.html for SPA routes" {
    try setupTest();
    defer cleanupTest();

    // Set input JSON
    try ctx.setInput("{\"path\": \"/about\"}");

    // Call the function
    web4.web4_get();

    // Verify response redirects to index.html
    try testing.expect(std.mem.indexOf(u8, ctx.return_value, "/index.html") != null);
}

test "web4_get uses custom static URL when set" {
    try setupTest();
    defer cleanupTest();

    // Set custom URL in storage
    const custom_url = "ipfs://custom123";
    try ctx.storage.put(web4.WEB4_STATIC_URL_KEY, custom_url);

    // Set input JSON
    try ctx.setInput("{\"path\": \"/\"}");

    // Call the function
    web4.web4_get();

    // Verify response uses custom URL
    try testing.expect(std.mem.indexOf(u8, ctx.return_value, custom_url) != null);
    try testing.expect(std.mem.indexOf(u8, ctx.return_value, web4.DEFAULT_STATIC_URL) == null);
}

test "web4_get handles paths with file extensions directly" {
    try setupTest();
    defer cleanupTest();

    // Set input JSON
    try ctx.setInput("{\"path\": \"/style.css\"}");

    // Call the function
    web4.web4_get();

    // Verify response doesn't redirect to index.html
    try testing.expect(std.mem.indexOf(u8, ctx.return_value, "/index.html") == null);
    try testing.expect(std.mem.indexOf(u8, ctx.return_value, "/style.css") != null);
}


test "access control - contract can update its own config" {
    try setupTest();
    defer cleanupTest();

    // Setup: signer = contract account
    try updateSigner("test.near");
    try updateCurrentAccount("test.near");

    // Test setStaticUrl
    const new_url = "ipfs://newurl123";
    try ctx.setInput("{\"url\": \"" ++ new_url ++ "\"}");
    web4.web4_setStaticUrl();

    // Verify URL was updated
    if (ctx.storage.get(web4.WEB4_STATIC_URL_KEY)) |stored_url| {
        try testing.expectEqualStrings(new_url, stored_url);
    } else {
        try testing.expect(false);
    }

    // Test setOwner
    const new_owner = "new.near";
    try ctx.setInput("{\"accountId\": \"" ++ new_owner ++ "\"}");
    web4.web4_setOwner();

    // Verify owner was updated
    if (ctx.storage.get(web4.WEB4_OWNER_KEY)) |stored_owner| {
        try testing.expectEqualStrings(new_owner, stored_owner);
    } else {
        try testing.expect(false);
    }
}

test "access control - owner can update contract config" {
    try setupTest();
    defer cleanupTest();

    // Setup: Set initial owner
    const initial_owner = "owner.near";
    try ctx.storage.put(web4.WEB4_OWNER_KEY, initial_owner);
    
    // Setup: signer = owner account
    try updateSigner(initial_owner);
    try updateCurrentAccount("contract.near");

    // Test setStaticUrl
    const new_url = "ipfs://ownerurl";
    try ctx.setInput("{\"url\": \"" ++ new_url ++ "\"}");
    web4.web4_setStaticUrl();

    // Verify URL was updated
    if (ctx.storage.get(web4.WEB4_STATIC_URL_KEY)) |stored_url| {
        try testing.expectEqualStrings(new_url, stored_url);
    } else {
        try testing.expect(false);
    }

    // Test setOwner
    const new_owner = "newowner.near";
    try ctx.setInput("{\"accountId\": \"" ++ new_owner ++ "\"}");
    web4.web4_setOwner();

    // Verify owner was updated
    if (ctx.storage.get(web4.WEB4_OWNER_KEY)) |stored_owner| {
        try testing.expectEqualStrings(new_owner, stored_owner);
    } else {
        try testing.expect(false);
    }
}

// Skipped: test panics as expected when access is denied
//test "access control - other accounts cannot update config" {
//    try setupTest();
//    defer cleanupTest();
//
//    // Setup: Set owner
//    const owner = "owner.near";
//    try ctx.storage.put(web4.WEB4_OWNER_KEY, owner);
//    
//    // Setup: signer = random account
//    try ctx.setSigner("random.near");
//    try ctx.setCurrentAccount("contract.near");
//
//    // Test setStaticUrl - should panic
//    try ctx.setInput("{\"url\": \"ipfs://fail\"}");
//    web4.web4_setStaticUrl();
//
//    // Test setOwner - should panic
//    try ctx.setInput("{\"accountId\": \"hacker.near\"}");
//    web4.web4_setOwner();
//}

// Skipped: test panics as expected when handling invalid JSON
// TODO: Implement proper panic testing infrastructure
//test "web4_get handles invalid JSON input" {
//    try setupTest();
//    defer cleanupTest();
//
//    // Set invalid JSON input
//    mock_input = try testing.allocator.dupe(u8, "{invalid json}");
//
//    // Call the function
//    web4.web4_get();
//
//    // Should use default path "/"
//    try testing.expect(std.mem.indexOf(u8, mock_return_value, web4.DEFAULT_STATIC_URL) != null);
//}
