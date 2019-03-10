import std.stdio;
import std.conv;
import std.string;
import std.random;
import core.memory;
import std.path;
import std.file : readText;
import core.thread;

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
import arc.gfx.model;
import arc.gfx.modelloader;
import arc.gfx.material;
import arc.gfx.renderable;
import arc.gfx.rendering;

public class MyGame : IApp
{
    PerspectiveCamera _cam;
    Model _model;
    ModelInstance _modelInstance;

    float _a = 0f;

    RenderableBatch _batch;

    public void create()
    {
        _cam = new PerspectiveCamera(67, Core.graphics.getWidth(), Core.graphics.getHeight());
        _cam.near = 1f;
        _cam.far = 100f;
        _cam.position = Vec3(0, 10, 5);
        _cam.lookAt(0, 0, 0);
        _cam.update();

        auto data = loadModelData("data/character_male_0.g3dj");
        assert(data !is null, "can't parse data");

        _model = new Model;
        _model.load(data);

        writeln("INFO: Model has: ", _model.nodes.length, " nodes");

        _modelInstance = new ModelInstance(_model);

        _batch = new RenderableBatch(new DefaultShaderProvider("data/default.vert".readText, "data/default.frag".readText));

        GC.collect();
    }

    public void update(float dt)
    {
        _a += dt * 2;
    }

    public void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _cam.update();

        glEnable(GL_DEPTH_TEST);

        _batch.begin(_cam);

        for(int x = -2; x < 3; x++)
        {
            for(int y = -2; y < 3; y++)
            {
                _modelInstance.transform.set(Vec3(x*2, 0, y*2), Quat.fromAxis(0, 1, 0, _a));
                _modelInstance.calculateTransforms();
                _batch.render(_modelInstance);
            }
        }
        _batch.end();
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
    config.windowTitle = "Sample 09 - Skeletal Animation";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

    return 0;
}
