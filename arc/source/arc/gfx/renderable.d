module arc.gfx.renderable;

import std.container;

import arc.pool;
import arc.math;
import arc.gfx.material;
import arc.gfx.mesh;
import arc.gfx.shader;

public class Renderable
{
    public Mat4 worldTransform;
    public MeshPart meshPart = new MeshPart;
    public Material material;
    public Environment environment;
    public Mat4[] bones;
    public IShader shader;

    public Renderable set(Renderable renderable)
    {
        worldTransform = renderable.worldTransform;
        material = renderable.material;
        meshPart.set(renderable.meshPart);
        bones = renderable.bones;
        environment = renderable.environment;
        shader = renderable.shader;
        return this;
    }
}

public interface IRenderableProvider
{
    void getRenderables(ref Array!Renderable, Pool!Renderable pool);
}