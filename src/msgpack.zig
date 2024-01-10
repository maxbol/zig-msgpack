const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const Markers = enum(u8) {
    POSITIVE_FIXINT = 0x00,
    FIXMAP = 0x80,
    FixArray = 0x90,
    FIXSTR = 0xa0,
    NIL = 0xc0,
    FALSE = 0xc2,
    TRUE = 0xc3,
    BIN8 = 0xc4,
    Bin16 = 0xc5,
    Bin32 = 0xc6,
    EXT8 = 0xc7,
    EXT16 = 0xc8,
    EXT32 = 0xc9,
    FLOAT32 = 0xca,
    FLOAT64 = 0xcb,
    DOUBLE = 0xcb,
    UINT8 = 0xcc,
    UINT16 = 0xcd,
    UINT32 = 0xce,
    UINT64 = 0xcf,
    INT8 = 0xd0,
    INT16 = 0xd1,
    INT32 = 0xd2,
    INT64 = 0xd3,
    FIXEXT1 = 0xd4,
    FIXEXT2 = 0xd5,
    FIXEXT4 = 0xd6,
    FIXEXT8 = 0xd7,
    FIXEXT16 = 0xd8,
    STR8 = 0xd9,
    STR16 = 0xda,
    STR32 = 0xdb,
    ARRAY16 = 0xdc,
    ARRAY32 = 0xdd,
    MAP16 = 0xde,
    MAP32 = 0xdf,
    NEGATIVE_FIXINT = 0xe0,
};

const MsGPackError = error{
    STR_DATA_LENGTH_TOO_LONG,
    BIN_DATA_LENGTH_TOO_LONG,
    ARRAY_LENGTH_TOO_LONG,
    MAP_LENGTH_TOO_LONG,
    INPUT_VALUE_TOO_LARGE,
    FIXED_VALUE_WRITING,
    TYPE_MARKER_READING,
    TYPE_MARKER_WRITING,
    DATA_READING,
    DATA_WRITING,
    EXT_TYPE_READING,
    EXT_TYPE_WRITING,
    INVALID_TYPE,
    LENGTH_READING,
    LENGTH_WRITING,
    INTERNAL,
};

pub fn MsgPack(
    comptime Context: type,
    comptime ErrorSet: type,
    comptime writeFn: fn (context: Context, bytes: []const u8) ErrorSet!usize,
    comptime readFn: fn (context: Context, bytes: []u8) ErrorSet!usize,
) type {
    return struct {
        context: Context,

        const Self = @This();

        pub const Error = ErrorSet;

        fn write_fn(self: Self, bytes: []const u8) ErrorSet!usize {
            return writeFn(self.context, bytes);
        }

        fn write_byte(self: Self, byte: u8) !void {
            const bytes = [_]u8{byte};
            const len = try self.write_fn(&bytes);
            if (len != 1) {
                return MsGPackError.LENGTH_WRITING;
            }
        }

        fn write_type_marker(self: Self, marker: Markers) !void {
            try self.write_byte(@intFromEnum(marker));
        }

        pub fn write_nil(self: Self) !void {
            try self.write_type_marker(Markers.NIL);
        }

        fn write_true(self: Self) !void {
            try self.write_type_marker(Markers.TRUE);
        }

        fn write_false(self: Self) !void {
            try self.write_type_marker(Markers.FALSE);
        }

        pub fn write_bool(self: Self, val: bool) !void {
            if (val) {
                try self.write_true();
            }
            try self.write_false();
        }

        fn write_pfix_int(self: Self, val: u8) !void {
            if (val <= 0x7f) {
                try self.write_byte(val);
            }
            return MsGPackError.INPUT_VALUE_TOO_LARGE;
        }

        fn write_u8(self: Self, val: u8) !void {
            try self.write_type_marker(.UINT8);
            try self.write_byte(val);
        }

        fn write_u16(self: Self, val: u16) !void {
            try self.write_type_marker(.UINT16);
            var arr: [2]u8 = std.mem.zeroes([2]u8);
            std.mem.writeInt(u16, &arr, val, .big);

            const len = try self.write_fn(&arr);
            if (len != 2) {
                return MsGPackError.LENGTH_WRITING;
            }
        }

        fn write_u32(self: Self, val: u32) !void {
            try self.write_type_marker(.UINT32);
            var arr: [4]u8 = std.mem.zeroes([4]u8);
            std.mem.writeInt(u32, &arr, val, .big);

            const len = try self.write_fn(&arr);
            if (len != 4) {
                return MsGPackError.LENGTH_WRITING;
            }
        }

        fn write_u64(self: Self, val: u64) !void {
            try self.write_type_marker(.UINT64);
            var arr: [8]u8 = std.mem.zeroes([8]u8);
            std.mem.writeInt(u64, &arr, val, .big);

            const len = try self.write_fn(&arr);
            if (len != 8) {
                return MsGPackError.LENGTH_WRITING;
            }
        }

        fn write_nfix_int(self: Self, val: i8) !void {
            if (val >= -32 and val <= -1) {
                try self.write_byte(@bitCast(val));
            }
            return MsGPackError.INPUT_VALUE_TOO_LARGE;
        }

        fn write_i8(self: Self, val: i8) !void {
            try self.write_type_marker(.INT8);
            try self.write_byte(@bitCast(val));
        }

        fn write_i16(self: Self, val: i16) !void {
            try self.write_type_marker(.INT16);
            var arr: [2]u8 = std.mem.zeroes([2]u8);
            std.mem.writeInt(i16, &arr, val, .big);

            const len = try self.write_fn(&arr);
            if (len != 2) {
                return MsGPackError.LENGTH_WRITING;
            }
        }

        fn write_i32(self: Self, val: i32) !void {
            try self.write_type_marker(.INT32);
            var arr: [4]u8 = std.mem.zeroes([4]u8);
            std.mem.writeInt(i32, &arr, val, .big);

            const len = try self.write_fn(&arr);
            if (len != 4) {
                return MsGPackError.LENGTH_WRITING;
            }
        }

        fn write_i64(self: Self, val: i64) !void {
            try self.write_type_marker(.INT64);
            var arr: [8]u8 = std.mem.zeroes([8]u8);
            std.mem.writeInt(i64, &arr, val, .big);

            const len = try self.write_fn(&arr);
            if (len != 8) {
                return MsGPackError.LENGTH_WRITING;
            }
        }

        pub fn write_uint(self: Self, val: u64) !void {
            if (val <= 0x7f) {
                try self.write_pfix_int(@intCast(val));
            } else if (val <= 0xff) {
                try self.write_u8(@intCast(val));
            } else if (val <= 0xffff) {
                try self.write_u16(@intCast(val));
            } else if (val <= 0xffffffff) {
                try self.write_u32(@intCast(val));
            }
            try self.write_u64(val);
        }

        pub fn write_int(self: Self, val: i64) !void {
            if (val >= 0) {
                try self.write_uint(@intCast(val));
            } else if (val >= -32) {
                try self.write_nfix_int(@intCast(val));
            } else if (val >= -128) {
                try self.write_i8(@intCast(val));
            } else if (val >= -32768) {
                try self.write_i16(@intCast(val));
            } else if (val >= -2147483648) {
                try self.write_i32(@intCast(val));
            }

            try self.write_i64(val);
        }

        // read

        fn read_fn(self: Self, bytes: []const u8) ErrorSet!usize {
            return readFn(self.context, bytes);
        }

        fn read_byte(self: Self) !u8 {
            var res = [1]u8{0};
            try readFn(self.context, &res);
        }

        fn read_type_marker_u8(self: Self) !u8 {
            const val = try self.read_byte();
            return val;
        }

        fn marker_u8_to(_: Self, marker_u8: u8) !Markers {
            var val = marker_u8;

            if (val <= 0x7f) {
                val = 0x00;
            } else if (0x80 <= val and val <= 0x8f) {
                val = 0x80;
            } else if (0x90 <= val and val <= 0x9f) {
                val = 0x90;
            } else if (0xa0 <= val and val <= 0xbf) {
                val = 0xa0;
            } else if (0xe0 <= val and val <= 0xff) {
                val = 0xe0;
            }

            return @enumFromInt(val);
        }

        fn read_type_marker(self: Self) !Markers {
            const val = try self.read_type_marker_u8();
            return try self.marker_u8_to(val);
        }

        pub fn read_nil(self: Self) !void {
            const marker = try self.read_type_marker();
            if (marker != .NIL) {
                return MsGPackError.TYPE_MARKER_READING;
            }
        }

        pub fn read_bool(self: Self) !bool {
            const marker = try self.read_type_marker();
            switch (marker) {
                .TRUE => return true,
                .FALSE => return false,
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_i8(self: Self) !i8 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .NEGATIVE_FIXINT, .POSITIVE_FIXINT => {
                    return @bitCast(marker_u8);
                },
                .INT8 => {
                    const val = try self.read_byte();
                    return @bitCast(val);
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    if (val <= 127) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_i16(self: Self) !i16 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .INT8, .NEGATIVE_FIXINT, .POSITIVE_FIXINT => {
                    const val: i8 = @bitCast(marker_u8);
                    return val;
                },
                .INT8 => {
                    const val = try self.read_byte();
                    return @as(i8, @bitCast(val));
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    return val;
                },
                .INT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i16, &buffer, .big);
                    return val;
                },
                .UINT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u16, &buffer, .big);
                    if (val <= 32767) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_i32(self: Self) !i32 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .INT8, .NEGATIVE_FIXINT, .POSITIVE_FIXINT => {
                    const val: i8 = @bitCast(marker_u8);
                    return val;
                },
                .INT8 => {
                    const val = try self.read_byte();
                    return @as(i8, @bitCast(val));
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    return val;
                },
                .INT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i16, &buffer, .big);
                    return val;
                },
                .UINT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u16, &buffer, .big);
                    return val;
                },
                .Int32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i32, &buffer, .big);
                    return val;
                },
                .UINT32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u32, &buffer, .big);
                    if (val <= 2147483647) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_i64(self: Self) !i64 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .INT8, .NEGATIVE_FIXINT, .POSITIVE_FIXINT => {
                    const val: i8 = @bitCast(marker_u8);
                    return val;
                },
                .INT8 => {
                    const val = try self.read_byte();
                    return @as(i8, @bitCast(val));
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    return val;
                },
                .INT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i16, &buffer, .big);
                    return val;
                },
                .UINT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u16, &buffer, .big);
                    return val;
                },
                .Int32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i32, &buffer, .big);
                    return val;
                },
                .UINT32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u32, &buffer, .big);
                    return val;
                },
                .Int64 => {
                    var buffer: [8]u8 = std.mem.zeroes([8]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 8) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i64, &buffer, .big);
                    return val;
                },
                .UINT64 => {
                    var buffer: [8]u8 = std.mem.zeroes([8]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 8) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u64, &buffer, .big);
                    if (val <= 9223372036854775807) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_u8(self: Self) !u8 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .POSITIVE_FIXINT => {
                    return marker_u8;
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    return val;
                },
                .INT8 => {
                    const val = try self.read_byte();
                    const ival: i8 = @bitCast(val);
                    if (ival >= 0) {
                        return @intCast(ival);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_u16(self: Self) !u16 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .POSITIVE_FIXINT => {
                    return marker_u8;
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    return val;
                },
                .INT8 => {
                    const val = try self.read_byte();
                    const ival: i8 = @bitCast(val);
                    if (ival >= 0) {
                        return @intCast(ival);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                .UINT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u16, &buffer, .big);
                    return val;
                },
                .INT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i16, &buffer, .big);
                    if (val >= 0) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_32(self: Self) !u32 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .POSITIVE_FIXINT => {
                    return marker_u8;
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    return val;
                },
                .INT8 => {
                    const val = try self.read_byte();
                    const ival: i8 = @bitCast(val);
                    if (ival >= 0) {
                        return @intCast(ival);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                .UINT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u16, &buffer, .big);
                    return val;
                },
                .INT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i16, &buffer, .big);
                    if (val >= 0) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                .UINT32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u32, &buffer, .big);
                    return val;
                },
                .INT32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i32, &buffer, .big);
                    if (val >= 0) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }

        pub fn read_u64(self: Self) !u64 {
            const marker_u8 = try self.read_type_marker_u8();
            const marker = try self.marker_u8_to(marker_u8);
            switch (marker) {
                .POSITIVE_FIXINT => {
                    return marker_u8;
                },
                .UINT8 => {
                    const val = try self.read_byte();
                    return val;
                },
                .INT8 => {
                    const val = try self.read_byte();
                    const ival: i8 = @bitCast(val);
                    if (ival >= 0) {
                        return @intCast(ival);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                .UINT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u16, &buffer, .big);
                    return val;
                },
                .INT16 => {
                    var buffer: [2]u8 = std.mem.zeroes([2]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 2) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i16, &buffer, .big);
                    if (val >= 0) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                .UINT32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u32, &buffer, .big);
                    return val;
                },
                .INT32 => {
                    var buffer: [4]u8 = std.mem.zeroes([4]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 4) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(i32, &buffer, .big);
                    if (val >= 0) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                .UINT64 => {
                    var buffer: [8]u8 = std.mem.zeroes([8]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 8) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u64, &buffer, .big);
                    return val;
                },
                .INT64 => {
                    var buffer: [8]u8 = std.mem.zeroes([8]u8);
                    const len = try self.read_fn(&buffer);
                    if (len != 8) {
                        return MsGPackError.LENGTH_READING;
                    }
                    const val = std.mem.readInt(u64, &buffer, .big);
                    if (val >= 0) {
                        return @intCast(val);
                    }
                    return MsGPackError.INVALID_TYPE;
                },
                else => return MsGPackError.TYPE_MARKER_READING,
            }
        }
    };
}
