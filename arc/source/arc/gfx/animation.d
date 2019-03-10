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

import arc.math;

public struct Transform
{
    public Vec3 translation;
    public Quat rotation;
    public Vec3 scale;

    public Mat4 toMat4()
    {
        Mat4 ret = Mat4.identity;
        ret.set(translation.x, translation.y, translation.z, rotation.x,
                rotation.y, rotation.z, rotation.w, scale.x, scale.y, scale.z);
        return ret;
    }

    public ref Transform idt()
    {
        translation = Vec3();
        rotation = Quat.identity;
        scale = Vec3(1f, 1f, 1f);
        return this;
    }

    public ref Transform lerp(ref Vec3 targetT, ref Quat targetR,
            ref Vec3 targetS, float alpha)
    {
        //Vec3.lerp(ref translation, ref targetT, alpha, out translation);
        translation = Vec3.lerp(translation, targetT, alpha);

        //Quat.slerp(ref rotation, ref targetR, alpha, out rotation);
        rotation = Quat.slerp(rotation, targetR, alpha);


        //Vec3.lerp(ref scale, ref targetS, alpha, out scale);
        scale = Vec3.lerp(scale, targetS, alpha);
        return this;
    }

    
        public ref Transform lerp(ref Transform transform, float alpha)
        {
            return lerp(transform.translation, transform.rotation, transform.scale, alpha);
        }
}

import arc.gfx.model;

public class BaseAnimationController
{
    public static Transform[Node] transforms;

    private bool _applying;
    public ModelInstance target;

    public this(ModelInstance target)
    {
        this.target = target;
    }

    protected void begin()
    {
        assert(!_applying);
        _applying = true;
    }

    protected void apply(Animation animation, float time, float weight)
    {
        assert(!_applying);
        applyAnimation(transforms, weight, animation, time);
    }

    protected void end()
    {
        assert(_applying);
        foreach (item; transforms.byKeyValue())
        {
            item.key.localTransform = item.value.toMat4();
        }
        transforms.clear();
        target.calculateTransforms();
        _applying = false;
    }

    private static int getFirstKeyframeIndexAtTime(T)(ref NodeKeyframe!T[] arr, float time)
    {
        int n = cast(int) arr.length - 1;
        for (int i = 0; i < n; i++)
        {
            if (time >= arr[i].keytime && time <= arr[i + 1].keytime)
            {
                return i;
            }
        }
        return 0;
    }

    private static Vec3 getTranslationAtTime(NodeAnimation nodeAnim, float time)
    {
        if (nodeAnim.translation.length == 0)
            return nodeAnim.node.translation;
        if (nodeAnim.translation.length == 1)
            return nodeAnim.translation[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.translation, time);

        auto firstKeyframe = nodeAnim.translation[index];
        Vec3 result = firstKeyframe.value;

        if (++index < nodeAnim.translation.length)
        {
            auto secondKeyframe = nodeAnim.translation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Vec3.lerp(result, secondKeyframe.value, t);
        }
        return result;
    }

    private static Quat getRotationAtTime(NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.rotation.length == 0)
            return nodeAnim.node.rotation;
        if (nodeAnim.rotation.length == 1)
            return nodeAnim.rotation[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.rotation, time);

        auto firstKeyframe = nodeAnim.rotation[index];
        Quat result = firstKeyframe.value;

        if (++index < nodeAnim.rotation.length)
        {
            auto secondKeyframe = nodeAnim.rotation[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Quat.slerp(result, secondKeyframe.value, t);
        }
        return result;
    }

    private static Vec3 getScalingAtTime(NodeAnimation nodeAnim, float time)
    {

        if (nodeAnim.scaling.length == 0)
            return nodeAnim.node.scale;
        if (nodeAnim.scaling.length == 1)
            return nodeAnim.scaling[0].value;

        int index = getFirstKeyframeIndexAtTime(nodeAnim.scaling, time);

        auto firstKeyframe = nodeAnim.scaling[index];
        Vec3 result = firstKeyframe.value;

        if (++index < nodeAnim.scaling.length)
        {
            auto secondKeyframe = nodeAnim.scaling[index];
            float t = (time - firstKeyframe.keytime) / (
                    secondKeyframe.keytime - firstKeyframe.keytime);
            result = Vec3.lerp(result, secondKeyframe.value, t);
        }
        return result;
    }

    private static Transform getNodeAnimationTransform(NodeAnimation nodeAnim, float time)
    {
        Transform transform = Transform().idt();
        transform.translation = getTranslationAtTime(nodeAnim, time);
        transform.rotation = getRotationAtTime(nodeAnim, time);
        transform.scale = getScalingAtTime(nodeAnim, time);
        return transform;
    }

    private static void applyNodeAnimationDirectly(NodeAnimation nodeAnim, float time)
    {
        Node node = nodeAnim.node;
        node.isAnimated = true;
        Transform transform = getNodeAnimationTransform(nodeAnim, time);
        node.localTransform = transform.toMat4();
    }

    private static void applyNodeAnimationBlending(NodeAnimation nodeAnim, Transform[Node] outt, float alpha, float time)
    {
        Node node = nodeAnim.node;
        node.isAnimated = true;
        Transform transform = getNodeAnimationTransform(nodeAnim, time);

        if( node in outt)
        {
            if(alpha > 0.99999f)
                outt[node] = transform;
            else
                outt[node].lerp(transform, alpha);
        }
        else
        {
            if(alpha > 0.99999f)
                outt[node] = transform;
            else
                outt[node] = Transform(node.translation, node.rotation, node.scale).lerp(transform, alpha);
        }
    }

    protected static void applyAnimation(Transform[Node] outt, float alpha,
            Animation animation, float time)
    {
        if (outt is null)
        {
            foreach (nodeAnim; animation.nodeAnimations)
            {
                applyNodeAnimationDirectly(nodeAnim, time);
            }
        }
        else
        {
            foreach (node; outt.keys)
            {
                node.isAnimated = false;
            }

            foreach (nodeAnim; animation.nodeAnimations)
            {
                applyNodeAnimationBlending(nodeAnim, outt, alpha, time);
            }

            foreach (e; outt.byKeyValue())
            {
                if (!e.key.isAnimated)
                {
                    e.key.isAnimated = true;

                }
            }
        }
    }
}
