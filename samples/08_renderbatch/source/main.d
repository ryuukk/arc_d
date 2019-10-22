import std.stdio;
import core.memory;
import std.container;
import std.file : readText;

import bindbc.opengl;
import bindbc.glfw;

import arc.core;
import arc.engine;
import arc.math;
import arc.util.camera_controller;
import arc.gfx.shader;
import arc.gfx.shader_provider;
import arc.gfx.camera;
import arc.gfx.model;
import arc.gfx.model_instance;
import arc.gfx.model_loader;
import arc.gfx.rendering;
import arc.gfx.animation;


struct Test
{
    int[]* test;
}

public class Entity
{
    public int id;

    public Vec3 position;
    public ModelInstance instance;
    public AnimationController controller;
    float a = 0.0f;

    public void update(float dt)
    {
        a += dt;
        instance.transform = Mat4.set(position, Quat.fromAxis(0, 1, 0, a), Vec3(1,1,1));


        if(controller !is null)
            controller.update(dt);
    }

    public void render(RenderableBatch batch)
    {
        batch.render(instance);
    }
}

public class MyGame : IApp
{
    CameraController _controller;
    PerspectiveCamera _cam;
    Model _modelA;
    Model _modelB;

    Array!Entity entities;

    RenderableBatch _batch;

    public void create()
    {
        _cam = new PerspectiveCamera(67, Core.graphics.getWidth(), Core.graphics.getHeight());
        _cam.near = 1f;
        _cam.far = 100f;
        _cam.update();

        _controller = new CameraController(_cam);

        auto dataA = loadModelData("data/Knight.g3dj");
        assert(dataA !is null, "can't parse dataA");

        auto dataB = loadModelData("data/tree_small_0.g3dj");
        assert(dataB !is null, "can't parse dataB");


        _modelA = new Model;
        _modelA.load(dataA);

        _modelB = new Model;
        _modelB.load(dataB);

        _batch = new RenderableBatch(new DefaultShaderProvider("data/default.vert".readText, "data/default.frag".readText));

        auto e = new Entity;
        e.id = 0;
        e.position = Vec3(0,0,0);

        e.instance = new ModelInstance(_modelA);
        e.controller = new AnimationController(e.instance);
        e.controller.animate("Attack");
        entities.insert(e);
        //int s = 10;
        //int pad = 2;
        //int id = 0;
        //for(int x = -s; x < s; x++)
        //{
        //    for(int y = -s; y < s; y++)
        //    {
        //        auto e = new Entity;
        //        e.id = ++id;
        //        e.position = Vec3(x*pad, 0, y*pad);
        //
        //        auto v = id % 2;
        //        //if(v == 0)
        //        {
        //            e.instance = new ModelInstance(_modelA);
        //            e.controller = new AnimationController(e.instance);
        //            e.controller.animate("Attack");
        //        }
        //        //else //if(v == 1)
        //        //{
        //        //    e.instance = new ModelInstance(_modelB);
        //        //}
        //        //else
        //        //{
        //        //    e.instance = new ModelInstance(_model);
        //        //    e.controller = new AnimationController(e.instance);
        //        //    e.controller.animate("run_1h");
        //        //}
        //        
        //        entities.insert(e);
        //    }
        //}

        writeln("Added: ", entities.length," entities");
        Core.input.setInputProcessor(_controller);
        GC.collect();
    }

    int fpsAcc = 0;
    int c = 0;
    float timer = 0.0f;
    public void update(float dt)
    {
        auto fps = Core.graphics.fps();
        fpsAcc += fps;
        timer += dt;
        c++;

        if (timer > 1.0f)
        {
            int f = fpsAcc / c;
            writeln("FPS: ",fps," AVG: ",f);

            c = 0;
            fpsAcc = 0;
            timer = 0;
        }
        foreach(entity; entities)
            entity.update(dt);

        _controller.update(dt);
    }

    public void render(float dt)
    {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);

        _cam.update();

        glEnable(GL_DEPTH_TEST);

        _batch.begin(_cam);

        foreach(entity; entities)
            entity.render(_batch);

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

extern(C) __gshared string[] rt_options = [
    "gcopt=gc:precise"
];

int main()
{
    auto config = new Configuration;
    config.windowTitle = "Sample 08 - RenderableBatch";
    config.vsync = false;
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

    return 0;
}
