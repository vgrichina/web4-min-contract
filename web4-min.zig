const std = @import("std");

// NOTE: In smart contract context don't really have to free memory before execution ends
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var allocator = arena.allocator();

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
extern fn storage_has_key(key_len: u64, key_ptr: u64) u64;
extern fn storage_read(key_len: u64, key_ptr: u64, register_id: u64) u64;
extern fn storage_write(key_len: u64, key_ptr: u64, value_len: u64, value_ptr: u64, register_id: u64) u64;

const SCRATCH_REGISTER = 0xffffffff;
const WEB4_STATIC_URL_KEY = "web4:staticUrl";

// Helper wrapper functions for interacting with the host
fn log(str: []const u8) void {
    log_utf8(str.len, @ptrToInt(str.ptr));
}

fn valueReturn(value: []const u8) void {
    value_return(value.len, @ptrToInt(value.ptr));
}

fn readRegisterAlloc(register_id: u64) []u8 {
    const len = @truncate(usize, register_len(register_id));
    // TODO: Explicit NEAR-compatible panic instead of unreachable?
    const bytes = allocator.alloc(u8, len) catch unreachable;
    read_register(register_id, @ptrToInt(bytes.ptr));
    return bytes;
}

fn readInputAlloc() []u8 {
    input(SCRATCH_REGISTER);
    return readRegisterAlloc(SCRATCH_REGISTER);
}

fn readStorageAlloc(key: []const u8) ?[]u8 {
    const res = storage_read(key.len, @ptrToInt(key.ptr), SCRATCH_REGISTER);
    return switch (res) {
        0 => null,
        1 => readRegisterAlloc(SCRATCH_REGISTER),
        // TODO: Check if generates proper wasm unreachable when optimized
        else => unreachable,
    };
}

fn storageWrite(key: []const u8, value: []const u8) bool {
    const res = storage_write(key.len, @ptrToInt(key.ptr), value.len, @ptrToInt(value.ptr), SCRATCH_REGISTER);
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
    const result = allocator.alloc(u8, totalSize) catch unreachable;
    var offset: usize = 0;
    inline for (parts) |part| {
        std.mem.copy(u8, result[offset..offset + part.len], part);
        offset += part.len;
    }
    return result;
}

fn assertSelf() void {
    current_account_id(SCRATCH_REGISTER);
    const contractName = readRegisterAlloc(SCRATCH_REGISTER);
    signer_account_id(SCRATCH_REGISTER);
    const signerName = readRegisterAlloc(SCRATCH_REGISTER);
    if (!std.mem.eql(u8, contractName, signerName)) {
        // Access not allowed
        unreachable;
    }
}

// Default URL, contains some instructions on what to do next
const DEFAULT_STATIC_URL = "ipfs://bafybeidc4lvv4bld66h4rmy2jvgjdrgul5ub5s75vbqrcbjd3jeaqnyd5e";

// Main entry point for web4 contract.
export fn web4_get() void {
    // Read method arguments blob
    const inputData = readInputAlloc();

    // Parse method arguments JSON
    // NOTE: Parsing using TokenStream results in smaller binary than deserializing into object
    var requestStream = std.json.TokenStream.init(inputData);
    var lastString: [] const u8 = "";
    var path = while (requestStream.next() catch unreachable) |token| {
        switch (token) {
            .String => |stringToken| {
                const str = stringToken.slice(requestStream.slice, requestStream.i - 1);
                if (std.mem.eql(u8, lastString, "path")) {
                    break str;
                }
                lastString = str;
            },
            else => {},
        }
    } else "/";

    // Log request path
    log(joinAlloc(.{"path: ", path}));

    // Read static URL from storage
    const staticUrl = readStorageAlloc(WEB4_STATIC_URL_KEY) orelse DEFAULT_STATIC_URL;
    // Construct response object
    const responseData = joinAlloc(.{
        \\{
        \\  "status": 200,
        \\  "contentType": "text/html",
        \\  "bodyUrl":
        , "\"",
        staticUrl,
        path,
        "\"",
        \\ }
    });

    // Return method result
    valueReturn(responseData);
}

// Update current static content URL in smart contract storage
// NOTE: This is useful for web4-deploy tool
export fn web4_setStaticUrl() void {
    // NOTE: Can change this check to alow different owners
    assertSelf();

    // Read method arguments blob
    const inputData = readInputAlloc();

    // Parse method arguments JSON
    // NOTE: Parsing using TokenStream results in smaller binary than deserializing into object
    var requestStream = std.json.TokenStream.init(inputData);
    var lastString: [] const u8 = "";
    var staticUrl = while (requestStream.next() catch unreachable) |token| {
        switch (token) {
            .String => |stringToken| {
                const str = stringToken.slice(requestStream.slice, requestStream.i - 1);
                if (std.mem.eql(u8, lastString, "url")) {
                    break str;
                }
                lastString = str;
            },
            else => {},
        }
    } else "";

    // Log updated URL
    log(joinAlloc(.{"staticUrl: ", staticUrl}));

    // Write parsed static URL to storage
    _ = storageWrite(WEB4_STATIC_URL_KEY, staticUrl);
}