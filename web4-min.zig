const std = @import("std");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var allocator = arena.allocator();

extern fn input(register_id: u64) void;
extern fn read_register(register_id: u64, ptr: u64) void;
extern fn register_len(register_id: u64) u64;
extern fn value_return(value_len: u64, value_ptr: u64) void;
extern fn log_utf8(len: u64, ptr: u64) void;

export fn web4_get() void {
    const Web4Response = struct {
        contentType: []const u8,
        status: u32 = 200,
        body: []const u8,
        // bodyUrl: ?[]const u8,
        // preloadUrls: ?[]const []const u8,
        // cacheControl: ?[]const u8,
    };

    const Web4Request = struct {
        // accountId: ?[]const u8,
        path: []const u8,
        // params: std.StringHashMap([][]const u8),
        // query: std.StringHashMap(Web4Response),
    };

    const Web4Args = struct {
        request: Web4Request,
    };
    _ = Web4Args;

    input(0);
    const inputLength = @truncate(usize, register_len(0));
    const inputData = allocator.alloc(u8, inputLength) catch unreachable;
    read_register(0, @ptrToInt(inputData.ptr));

    log_utf8(inputData.len, @ptrToInt(inputData.ptr));

    // NOTE: If you uncomment JSON parsing – generated WASM goes from 9 KB to 50 KB

    // var requestStream = std.json.TokenStream.init(inputData);
    // const args = std.json.parse(Web4Args, &requestStream, .{
    //     .ignore_unknown_fields = true,
    //     .allocator = allocator,
    // }) catch unreachable;
    
    // catch |err| {
    //     // const errorStr = std.fmt.allocPrint(allocator, "Error: {}", .{err}) catch unreachable;
    //     // log_utf8(errorStr.len, @ptrToInt(errorStr.ptr));
    //     return;
    // };
    // _ = args;

    // const body = std.fmt.allocPrint(allocator, "Hello from <b>{s}</b>!", .{args.request.path}) catch unreachable;
    const body = "Hello from <b>Web4</b>!";
    const encoder = std.base64.standard.Encoder;
    const bodySize = encoder.calcSize(body.len);
    const bodyBuffer = allocator.alloc(u8, bodySize) catch unreachable;
    const base64Body = encoder.encode(bodyBuffer, body);

    const response = Web4Response{ .contentType = "text/html", .body = base64Body };
    const responseData = std.json.stringifyAlloc(allocator, response, .{}) catch unreachable;

    value_return(responseData.len, @ptrToInt(responseData.ptr));
}
