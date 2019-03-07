module arc.gfx.animation;

import arc.math;
import arc.gfx.node;

public class Animation
{
    public string id;
    public float duration;
    public NodeAnimation[] nodeAnimations;
}

public class NodeAnimation
{
    public Node node;

    public NodeKeyframe!Vec3[] translation;
    public NodeKeyframe!Quat[] rotation;
    public NodeKeyframe!Vec3[] scaling;
}

public class NodeKeyframe(T)
{
    public float keytime;
    public T value;

    public this(float keytime, T value)
    {
        this.keytime = keytime;
        this.value = value;
    }
}
