module arc.gfx.renderable;

import std.container;

import arc.pool;
import arc.math;
import arc.gfx.material;
import arc.gfx.mesh_part;
import arc.gfx.shader;

public class Renderable
{
    public Mat4 worldTransform;
    public MeshPart meshPart;
    public Material material;
    public Environment environment;
    public Mat4[]* bones;
    public IShader shader;

    public this()
    {
        meshPart = new MeshPart;
    }
}

public interface IRenderableProvider
{
    void getRenderables(ref Array!Renderable renderables, Pool!Renderable pool);
}