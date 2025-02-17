const std = @import("std");

// NOTE: In smart contract context don't really have to free memory before execution ends
const builtin = @import("builtin");
var allocator = if (builtin.cpu.arch == .wasm32) 
    std.heap.wasm_allocator 
else 
    std.heap.page_allocator;

// Import host functions provided by NEAR runtime.
// See https://github.com/near/near-sdk-rs/blob/3ca87c95788b724646e0247cfd3feaccec069b97/near-sdk/src/environment/env.rs#L116
// and https://github.com/near/near-sdk-rs/blob/3ca87c95788b724646e0247cfd3feaccec069b97/sys/src/lib.rs
extern fn input(register_id: u64) void;
extern fn signer_account_id(register_id: u64) void;
extern fn current_account_id(register_id: u64) void;
extern fn read_register(register_id: u64, ptr: u64) void;
extern fn register_len(register_id: u64) u64;
extern fn value_return(value_len: u64, value_ptr: u64) void;
extern fn log_utf8(len: u64, ptr: u64) void;
extern fn panic_utf8(len: u64, ptr: u64) void;
extern fn storage_has_key(key_len: u64, key_ptr: u64) u64;
extern fn storage_read(key_len: u64, key_ptr: u64, register_id: u64) u64;
extern fn storage_write(key_len: u64, key_ptr: u64, value_len: u64, value_ptr: u64, register_id: u64) u64;

const SCRATCH_REGISTER = 0xffffffff;
pub const WEB4_STATIC_URL_KEY = "web4:staticUrl";
pub const WEB4_OWNER_KEY = "web4:owner";

// Helper wrapper functions for interacting with the host
fn log(str: []const u8) void {
    log_utf8(str.len, @intFromPtr(str.ptr));
}

fn panic(str: []const u8) void {
    panic_utf8(str.len, @intFromPtr(str.ptr));
}

fn valueReturn(value: []const u8) void {
    value_return(value.len, @intFromPtr(value.ptr));
}

fn readRegisterAlloc(register_id: u64) []const u8 {
    const len: usize = @truncate(register_len(register_id));
    // NOTE: 1 more byte is allocated as allocator.alloc() doesn't allocate 0 bytes
    const bytes = allocator.alloc(u8, len + 1) catch {
        panic("Failed to allocate memory");
        unreachable;
    };
    read_register(register_id, @intFromPtr(bytes.ptr));
    return bytes[0..len];
}

fn readInputAlloc() []const u8 {
    input(SCRATCH_REGISTER);
    return readRegisterAlloc(SCRATCH_REGISTER);
}

fn readStorageAlloc(key: []const u8) ?[]const u8 {
    const res = storage_read(key.len, @intFromPtr(key.ptr), SCRATCH_REGISTER);
    return switch (res) {
        0 => null,
        1 => readRegisterAlloc(SCRATCH_REGISTER),
        else => unreachable,
    };
}

fn storageWrite(key: []const u8, value: []const u8) bool {
    const res = storage_write(key.len, @intFromPtr(key.ptr), value.len, @intFromPtr(value.ptr), SCRATCH_REGISTER);
    return switch (res) {
        0 => false,
        1 => true,
        else => unreachable,
    };
}

fn joinAlloc(parts: anytype) []const u8 {
    var totalSize: usize = 0;
    inline for (parts) |part| {
        totalSize += part.len;
    }
    const result = allocator.alloc(u8, totalSize) catch {
        panic("Failed to allocate memory");
        unreachable;
    };
    var offset: usize = 0;
    inline for (parts) |part| {
        @memcpy(result[offset .. offset + part.len], part);
        offset += part.len;
    }
    return result;
}

fn assertSelfOrOwner() void {
    current_account_id(SCRATCH_REGISTER);
    const contractName = readRegisterAlloc(SCRATCH_REGISTER);
    signer_account_id(SCRATCH_REGISTER);
    const signerName = readRegisterAlloc(SCRATCH_REGISTER);
    const ownerName = readStorageAlloc(WEB4_OWNER_KEY) orelse contractName;

    log(joinAlloc(.{ "contractName: ", contractName, ", signerName: ", signerName, ", ownerName: ", ownerName }));
    if (!std.mem.eql(u8, contractName, signerName) and !std.mem.eql(u8, ownerName, signerName)) {
        panic("Access denied");
        unreachable;
    }
    log("Access allowed");
}

// Default URL, contains some instructions on what to do next
pub const DEFAULT_STATIC_URL = "ipfs://bafybeidc4lvv4bld66h4rmy2jvgjdrgul5ub5s75vbqrcbjd3jeaqnyd5e";

// Helper function to check if a path has a file extension
fn hasFileExtension(path: []const u8) bool {
    var i: usize = path.len;
    while (i > 0) : (i -= 1) {
        if (path[i - 1] == '/') return false;
        if (path[i - 1] == '.') return true;
    }
    return false;
}


// Main entry point for web4 contract.
pub export fn web4_get() void {
    // Read method arguments blob
    const inputData = readInputAlloc();

    // Parse method arguments JSON and extract path
    const path = extract_string(inputData, "path") orelse "/";

    // Log request path
    log(joinAlloc(.{ "path: ", path }));

    // Read static URL from storage
    const staticUrl = readStorageAlloc(WEB4_STATIC_URL_KEY) orelse DEFAULT_STATIC_URL;

    // For paths without file extensions, serve index.html (SPA)
    const adjustedPath = if (!hasFileExtension(path) and path.len > 1) "/index.html" else path;

    // Construct response object
    const responseData = joinAlloc(.{
        "{\"status\":200,\"bodyUrl\":\"",
        staticUrl,
        adjustedPath,
        "\"}",
    });

    // Return method result
    valueReturn(responseData);
}

// Parse method arguments JSON
// NOTE: Parsing using std.json.Scanner results in smaller binary than deserializing into object
fn extract_string(inputData: []const u8, keyName: []const u8) ?[]const u8 {
    var lastKey: []const u8 = "";
    var tokenizer = std.json.Scanner.initCompleteInput(allocator, inputData);
    defer tokenizer.deinit();
    return while (true) {
        _ = switch (tokenizer.next() catch {
            panic("Failed to parse JSON");
            unreachable;
        }) {
            .string => |str| {
                if (tokenizer.string_is_object_key) {
                    lastKey = str;
                } else if (std.mem.eql(u8, lastKey, keyName)) {
                    break str;
                }
            },
            .end_of_document => break null,
            else => null,
        };
    };
}

// Update current static content URL in smart contract storage
// NOTE: This is useful for web4-deploy tool
pub export fn web4_setStaticUrl() void {
    assertSelfOrOwner();

    // Read method arguments blob
    const inputData = readInputAlloc();

    // Parse method arguments JSON and extract staticUrl
    const staticUrl = extract_string(inputData, "url") orelse DEFAULT_STATIC_URL;

    // Log updated URL
    log(joinAlloc(.{ "staticUrl: ", staticUrl }));

    // Write parsed static URL to storage
    _ = storageWrite(WEB4_STATIC_URL_KEY, staticUrl);
}

// Update current owner account ID – if set this account can update contract config
// NOTE: This is useful to deploy contract to subaccount like web4.<account_id>.near and then transfer ownership to <account_id>.near
pub export fn web4_setOwner() void {
    assertSelfOrOwner();

    // Read method arguments blob
    const inputData = readInputAlloc();

    // Parse method arguments JSON and extract owner
    const owner = extract_string(inputData, "accountId") orelse "";

    // Log updated owner
    log(joinAlloc(.{ "owner: ", owner }));

    // Write parsed owner to storage
    _ = storageWrite(WEB4_OWNER_KEY, owner);
}
