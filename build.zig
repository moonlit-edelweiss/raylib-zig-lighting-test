// reused build.zig file from main project
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Common modules

    // Main game executable
    const game_exe = b.addExecutable(.{
        .name = "game",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    game_exe.linkLibC();
    game_exe.addLibraryPath(.{ .cwd_relative = "raylib/lib" });
    game_exe.addIncludePath(.{ .cwd_relative = "raylib/include" });
    game_exe.linkSystemLibrary("raylib");
    game_exe.linkSystemLibrary("GL");
    game_exe.linkSystemLibrary("m");
    game_exe.linkSystemLibrary("pthread");
    game_exe.linkSystemLibrary("dl");
    b.installArtifact(game_exe);

    // Run commands
    const run_game = b.addRunArtifact(game_exe);

    // Game run step
    const run_game_step = b.step("run", "Run the main game");
    run_game_step.dependOn(&run_game.step);

    // Tests
    const test_step = b.step("test", "Run unit tests");
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    test_step.dependOn(&run_lib_tests.step);
}
