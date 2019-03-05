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
import arc.gfx.buffers;
import arc.gfx.mesh;
import arc.gfx.texture;
import arc.gfx.batch;
import arc.gfx.camera;

string vs = "
#version 330

in vec3 a_position;

uniform mat4 u_proj;
uniform mat4 u_view;
uniform mat4 u_world;

void main()
{
    gl_Position = u_proj * u_view * u_world * vec4(a_position, 1.0);
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

public class MyGame : IApp
{
    PerspectiveCamera _cam;
    Mesh _mesh;
    ShaderProgram _shader;
    Mat4 _cubeTransform = Mat4.identity;
    public void create()
    {
        _cam = new PerspectiveCamera(64, Core.graphics.getWidth(), Core.graphics.getHeight());
        _cam.near = 1f;
        _cam.far = 100f;
        _cam.position = Vec3(0, 10, 5) * 1.25f;
        _cam.lookAt(0, 0, 0);
        _cam.update();

        _shader = new ShaderProgram(vs, fs);
        assert(_shader.isCompiled(), _shader.getLog());

        _mesh = new Mesh(true, 3, 3, new VertexAttribute(Usage.Position, 3, "a_position"));

        float[] cubeVerts = [-0.5f, -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, 0.5f, -0.5f, 0.5f, 0.5f, -0.5f, -0.5f, -0.5f, 0.5f, -0.5f,
            -0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, -0.5f, -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, -0.5f, 0.5f, 0.5f, -0.5f,
            0.5f, -0.5f, -0.5f, -0.5f, -0.5f, 0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, -0.5f, 0.5f, -0.5f, -0.5f, -0.5f,
            -0.5f, -0.5f, 0.5f, -0.5f, 0.5f, 0.5f, -0.5f, 0.5f, -0.5f, 0.5f, -0.5f, -0.5f, 0.5f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
            0.5f, 0.5f, -0.5f];

        //float[] cubeNormals = {0.0f, -1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f,
        //	1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f,
        //	-1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, -1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f,
        //	-1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f,};

        //float[] cubeTex = {0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f,
        //	0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f,
        //	1.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.0f,};

        float[] vertices;
        vertices.length = 24 * 3; // 8
        int pIdx = 0;
        //int nIdx = 0;
        //int tIdx = 0;
        for (int i = 0; i < vertices.length;)
        {
            vertices[i++] = cubeVerts[pIdx++];
            vertices[i++] = cubeVerts[pIdx++];
            vertices[i++] = cubeVerts[pIdx++];
            //vertices[i++] = cubeNormals[nIdx++];
            //vertices[i++] = cubeNormals[nIdx++];
            //vertices[i++] = cubeNormals[nIdx++];
            //vertices[i++] = cubeTex[tIdx++];
            //vertices[i++] = cubeTex[tIdx++];
        }

        short[] indices = [0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 8, 9, 10, 8, 10, 11, 12, 15, 14, 12, 14, 13, 16, 17, 18, 16,
            18, 19, 20, 23, 22, 20, 22, 21];

        _mesh.setVertices(vertices);
        _mesh.setIndices(indices);
    }

    public void update(float dt)
    {
        _cubeTransform.rotate(30 * dt, 0, 1, 0);
    }

    public void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _cam.update();

        _shader.begin();
        _shader.setUniformMat4("u_proj", _cam.projection);
        _shader.setUniformMat4("u_view", _cam.view);
        _shader.setUniformMat4("u_world", _cubeTransform);

        _mesh.render(_shader, GL_TRIANGLES);
        _shader.end();
    }

    public void resize(int width, int height)
    {
        _cam.viewportWidth = width;
        _cam.viewportHeight = height;
    }

    public void dispose()
    {
    }
}

int main()
{
    auto config = new Configuration;
    config.windowTitle = "Sample 06 - Cube";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

    return 0;
}
