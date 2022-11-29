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

    input(0);
    const inputLength = @truncate(usize, register_len(0));
    const inputData = allocator.alloc(u8, inputLength) catch unreachable;
    read_register(0, @ptrToInt(inputData.ptr));

    log_utf8(inputData.len, @ptrToInt(inputData.ptr));

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

    const body = std.fmt.allocPrint(allocator, "Hello from <b>{s}</b>!", .{path}) catch unreachable;
    const encoder = std.base64.standard.Encoder;
    const bodySize = encoder.calcSize(body.len);
    const bodyBuffer = allocator.alloc(u8, bodySize) catch unreachable;
    const base64Body = encoder.encode(bodyBuffer, body);

    const response = Web4Response{ .contentType = "text/html", .body = base64Body };
    const responseData = std.json.stringifyAlloc(allocator, response, .{}) catch unreachable;

    value_return(responseData.len, @ptrToInt(responseData.ptr));
}
