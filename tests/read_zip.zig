const std = @import("std");
const archive = @import("archive");

const alloc = std.heap.page_allocator;

pub fn main() !void {
    const in_dir = try std.fs.cwd().openDir("tests/zip", .{ .iterate = true });

    var it = in_dir.iterate();

    while (try it.next()) |entry| {
        const fd = try in_dir.openFile(entry.name, .{});
        defer fd.close();

        const str = try fd.readToEndAlloc(alloc, std.math.maxInt(usize));
        defer alloc.free(str);

        const stream = std.io.fixedBufferStream(@as([]const u8, str));
        var source = std.io.StreamSource{ .const_buffer = stream };

        var arc = archive.formats.zip.reader.ArchiveReader.init(alloc, &source);
        defer arc.deinit();

        // Load

        try arc.load();

        // Extract

        for (0..arc.directory.items.len) |j| {
            const hdr = arc.getHeader(j);

            if (hdr.uncompressed_size > 0) {
                const out = std.io.null_writer;

                try arc.extractFile(hdr, out, true);
            }
        }

        std.debug.print(
            \\name: {s}
            \\size: {d}
            \\directory: {d} items, {d} bytes, {d} bytes of filenames
            \\
            \\
        , .{
            entry.name,
            try source.getEndPos(),
            arc.directory.items.len,
            arc.directory_size,
            arc.filename_buf.items.len,
        });
    }
}
