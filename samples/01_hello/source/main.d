import std.stdio;

import arc;

public class MyGame : IApp
{
    public void create()
    {
        writeln("Hi!");
    }

    public void update(float dt)
    { }

    public void render(float dt)
    { }

    public void resize(int width, int height)
    { }

    public void dispose()
    { }
}

int main()
{
    auto config = new Configuration;
    config.windowTitle = "Sample 01 - Hello";
    auto game = new MyGame;
    auto engine = new Engine(game, config);
    engine.run();
    return 0;
}
