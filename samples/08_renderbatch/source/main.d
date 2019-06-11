import std.stdio;
import core.memory;
import std.container;
import std.file : readText;

import bindbc.opengl;
import bindbc.glfw;

import arc.core;
import arc.engine;
import arc.math;
import arc.gfx.shader;
import arc.gfx.shader_provider;
import arc.gfx.camera;
import arc.gfx.model;
import arc.gfx.modelloader;
import arc.gfx.rendering;
import arc.gfx.animation;

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
        instance.transform.set(position, Quat.fromAxis(0, 1, 0, a));

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
        _cam.position = Vec3(0, 10, 5) * 2.5f;
        _cam.lookAt(0, 0, 0);
        _cam.update();

        auto dataA = loadModelData("data/character_male_0.g3dj");
        assert(dataA !is null, "can't parse dataA");

        auto dataB = loadModelData("data/tree_small_0.g3dj");
        assert(dataB !is null, "can't parse dataB");

        _modelA = new Model;
        _modelA.load(dataA);

        _modelB = new Model;
        _modelB.load(dataB);

        _batch = new RenderableBatch(new DefaultShaderProvider("data/default.vert".readText, "data/default.frag".readText));


        int s = 8;
        int id = 0;
        for(int x = -s; x < s; x++)
        {
            for(int y = -s; y < s; y++)
            {
                auto e = new Entity;
                e.id = ++id;
                e.position = Vec3(x*2, 0, y*2);

                auto v = id % 2;
                if(v == 0)
                {
                    e.instance = new ModelInstance(_modelA);
                    e.controller = new AnimationController(e.instance);
                    e.controller.animate("run_1h");
                }
                else //if(v == 1)
                {
                    e.instance = new ModelInstance(_modelB);
                }
                //else
                //{
                //    e.instance = new ModelInstance(_model);
                //    e.controller = new AnimationController(e.instance);
                //    e.controller.animate("run_1h");
                //}
                
                entities.insert(e);
            }
        }

        writeln("Added: ", entities.length," entities");
        GC.collect();
    }

    public void update(float dt)
    {
        foreach(entity; entities)
            entity.update(dt);
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
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();

    return 0;
}
