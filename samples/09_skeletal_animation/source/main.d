import std.stdio;
import core.memory;
import std.file : readText;

import bindbc.opengl;
import bindbc.glfw;

import arc.core;
import arc.engine;
import arc.math;
import arc.gfx.shader;
import arc.gfx.camera;
import arc.gfx.model;
import arc.gfx.modelloader;
import arc.gfx.rendering;
import arc.gfx.animation;
import arc.gfx.renderable;

public class MyGame : IApp
{
    PerspectiveCamera _cam;
    Model _model;
    Model _modelStatic;
    ModelInstance _modelInstance;
    ModelInstance _modelInstanceStatic;
    AnimationController _animController;


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

        {
            auto data = loadModelData("data/character_male_0.g3dj");
            assert(data !is null, "can't parse data");

            _model = new Model;
            _model.load(data);

            _modelInstance = new ModelInstance(_model);

            _animController = new AnimationController(_modelInstance);
            auto desc = _animController.animate("run_1h");
        }

        {
            auto dataStatic = loadModelData("data/tree_small_0.g3dj");
            assert(dataStatic !is null, "can't parse data");

            _modelStatic = new Model;
            _modelStatic.load(dataStatic);

            _modelInstanceStatic = new ModelInstance(_modelStatic);
        }



        _batch = new RenderableBatch(new DefaultShaderProvider("data/default.vert".readText, "data/default.frag".readText));

        GC.collect();
    }

    public void update(float dt)
    {
        _a += dt * 2;
        _animController.update(dt);
    }

    public void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _cam.update();

        glEnable(GL_DEPTH_TEST);

        _batch.begin(_cam);

        _modelInstance.transform.set(Vec3(-2,0,0), Quat.fromAxis(0, 1, 0, _a));
        _modelInstanceStatic.transform.set(Vec3(2,0,0), Quat.fromAxis(0, 1, 0, _a));

        _batch.render(_modelInstanceStatic);
        _batch.render(_modelInstance);

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
