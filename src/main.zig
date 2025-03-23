const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("rcamera.h");
    @cInclude("rlgl.h");
    @cInclude("raymath.h");
});

fn createModelMatrix(rotation: f32) c.Matrix {
    return c.MatrixRotateXYZ(.{ .x = rotation * 0.5, .y = rotation * 1.0, .z = rotation * 0.0 });
}

fn createViewMatrix(camera: c.Camera3D) c.Matrix {
    return c.MatrixLookAt(camera.position, camera.target, camera.up);
}

fn createProjectionMatrix(camera: c.Camera3D, screen_width: i32, screen_height: i32) c.Matrix {
    return c.MatrixPerspective(camera.fovy * std.math.pi / 180.0, @as(f32, @floatFromInt(screen_width)) / @as(f32, @floatFromInt(screen_height)), 0.1, 1000.0);
}

pub fn main() void {
    const screen_width = 800;
    const screen_height = 600;

    c.InitWindow(screen_width, screen_height, "Spinning Cube with Lighting");
    defer c.CloseWindow();

    var camera = c.Camera3D{
        .position = .{ .x = 3.0, .y = 3.0, .z = 3.0 },
        .target = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = c.CAMERA_PERSPECTIVE,
    };

    // generate cube mesh with normals
    const cube = c.GenMeshCube(2.0, 2.0, 2.0);
    const model = c.LoadModelFromMesh(cube);
    defer c.UnloadModel(model);

    // Load shaders
    const shader = c.LoadShader(
        "shaders/lighting.vert",
        "shaders/lighting.frag",
    );
    defer c.UnloadShader(shader);
    model.materials[0].shader = shader;

    // get shader locations
    const view_pos_loc = c.GetShaderLocation(shader, "viewPos");
    const light_pos_loc = c.GetShaderLocation(shader, "lightPos");
    const light_color_loc = c.GetShaderLocation(shader, "lightColor");

    // init light
    var light_pos = c.Vector3{ .x = 2.0, .y = 2.0, .z = 2.0 };
    const light_color = c.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

    // state vars
    var rotation: f32 = 0.0;
    var mouse_locked = false;
    var spin_active = true;
    var draw_light = true;
    var camera_theta: f32 = 45.0;
    var camera_phi: f32 = 45.0;
    const camera_distance: f32 = 5.0;

    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        // Toggle mouse lock with L
        if (c.IsKeyPressed(c.KEY_L)) {
            mouse_locked = !mouse_locked;
            if (mouse_locked) {
                c.DisableCursor();
            } else {
                c.EnableCursor();
            }
        }

        // Toggle spin with S
        if (c.IsKeyPressed(c.KEY_S)) {
            spin_active = !spin_active;
            if (!spin_active) {
                rotation = 0.0;
            }
        }

        // Toggle light debug draw with D
        if (c.IsKeyPressed(c.KEY_D)) {
            draw_light = !draw_light;
        }

        // Move light with scroll wheel
        const scroll = c.GetMouseWheelMove();
        light_pos.y += scroll * 0.5;
        light_pos.y = @max(-5.0, @min(10.0, light_pos.y)); // keep light within bounds

        // cube rotation loop
        if (spin_active) {
            rotation += 1.0 * c.GetFrameTime();
        }

        // Update camera position with mouse (when locked)
        if (mouse_locked) {
            const mouse_delta = c.GetMouseDelta();
            camera_theta -= mouse_delta.x * 0.5;
            camera_phi -= mouse_delta.y * 0.5;

            // expand phi range to allow looking from below
            camera_phi = @max(-85.0, @min(85.0, camera_phi));
        }

        // Convert spherical coordinates to cartesian
        const theta = camera_theta * (std.math.pi / 180.0);
        const phi = camera_phi * (std.math.pi / 180.0);
        camera.position.x = camera_distance * @sin(theta) * @cos(phi);
        camera.position.y = camera_distance * @sin(phi);
        camera.position.z = camera_distance * @cos(theta) * @cos(phi);

        // Update shader values
        const view_pos = [3]f32{ camera.position.x, camera.position.y, camera.position.z };
        c.SetShaderValue(shader, view_pos_loc, &view_pos, c.SHADER_UNIFORM_VEC3);

        const light_pos_array = [3]f32{ light_pos.x, light_pos.y, light_pos.z };
        c.SetShaderValue(shader, light_pos_loc, &light_pos_array, c.SHADER_UNIFORM_VEC3);

        const light_color_array = [3]f32{
            @as(f32, @floatFromInt(light_color.r)) / 255.0,
            @as(f32, @floatFromInt(light_color.g)) / 255.0,
            @as(f32, @floatFromInt(light_color.b)) / 255.0,
        };
        c.SetShaderValue(shader, light_color_loc, &light_color_array, c.SHADER_UNIFORM_VEC3);

        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.BLACK);
        c.BeginMode3D(camera);

        // Draw cube with lighting
        c.rlPushMatrix();
        c.rlRotatef(rotation * 50, 0.5, 1.0, 0.0);
        c.DrawModel(model, .{ .x = 0, .y = 0, .z = 0 }, 1.0, c.WHITE);
        c.rlPopMatrix();

        // Draw light source and grid
        if (draw_light) {
            c.DrawSphere(light_pos, 0.1, light_color);
        }
        c.DrawGrid(10, 1.0);

        c.EndMode3D();

        // Draw UI text
        var buffer: [128]u8 = undefined;
        const white = c.RAYWHITE;

        // Static texts
        c.DrawText("Controls:", 10, 10, 20, white);
        c.DrawText("L - Toggle mouse lock", 10, 40, 20, white);
        c.DrawText("S - Toggle cube spin", 10, 70, 20, white);
        c.DrawText("D - Toggle light debug", 10, 100, 20, white);
        c.DrawText("Scroll - Move light Y", 10, 130, 20, white);

        // Dynamic texts
        const mouse_text = std.fmt.bufPrintZ(
            &buffer,
            "Mouse locked: {s}",
            .{if (mouse_locked) "YES" else "NO"},
        ) catch unreachable;
        c.DrawText(mouse_text, 10, 160, 20, white);

        const spin_text = std.fmt.bufPrintZ(
            &buffer,
            "Spinning: {s}",
            .{if (spin_active) "YES" else "NO"},
        ) catch unreachable;
        c.DrawText(spin_text, 10, 190, 20, white);

        const light_y_text = std.fmt.bufPrintZ(
            &buffer,
            "Light Y: {d:.1}",
            .{light_pos.y},
        ) catch unreachable;
        c.DrawText(light_y_text, 10, 220, 20, white);

        const fps_text = std.fmt.bufPrintZ(
            &buffer,
            "FPS: {d}",
            .{c.GetFPS()},
        ) catch unreachable;
        c.DrawText(fps_text, 10, screen_height - 30, 20, white);
    }
}
