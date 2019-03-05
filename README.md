# Run the samples

- Make sure you got D installed in your system
- Clone  the repo
- ``./run_samples.sh``

# Hello World

```D
import std.stdio;

import arc;

int main()
{
    auto game = new MyGame;
    auto engine = new Engine(game);
    engine.run();

    return 0;
}

public class MyGame : IApp
{
    public void create()
    {
        writeln("Hi");
    }
    
    public void update()
    {}

    public void render()
    {}

    public void resize(int width, int height)
    {}

    public void dispose()
    {}
}

```