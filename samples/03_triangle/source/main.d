import std.stdio;
import std.conv;
import std.string;
import core.memory;

import bindbc.opengl;
import bindbc.glfw;

import arc.core;
import arc.engine;
import arc.input;
import arc.math;
import arc.gfx.shader;
import arc.gfx.shader_program;
import arc.gfx.buffers;
import arc.gfx.mesh;

public class MyGame : IApp
{
    string vs = "
#version 330

in vec3 a_position;


void main()
{
    gl_Position = vec4(a_position, 1.0);
}
";
    string fs = "
#version 330

out vec4 f_color;

void main()
{
	f_color = vec4(1.0, 0.0, 0.0, 1.0);
}
";
    ShaderProgram _shader;
    Mesh _mesh;

    public void create()
    {
        _mesh = new Mesh(true, 3, 3, new VertexAttribute(Usage.Position, 3, "a_position"));

        _mesh.setVertices([
            -1.0f, -1.0f, 0.0f,
            1.0f, -1.0f, 0.0f,
            0.0f,  1.0f, 0.0f,
            ]);

        _mesh.setIndices([ 
            0, 1, 2,   // first triangle
            ]);

        _shader = new ShaderProgram(vs, fs);

        assert(_shader.isCompiled(), _shader.getLog());
    }

    public void update(float dt)
    {
    }

    public void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _shader.begin();

        _mesh.render(_shader, GL_TRIANGLES);

        _shader.end();
    }

    public void resize(int width, int height)
    {
    }

    public void dispose()
    {
    }
}

int main()
{
    auto config = new Configuration;
    config.windowTitle = "Sample 03 - Triangle";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();
    return 0;
}
