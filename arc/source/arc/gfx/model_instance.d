module arc.gfx.model_instance;

import std.container;
import std.stdio;
import std.format;
import std.typecons;

import arc.pool;
import arc.math;
import arc.color;
import arc.core;
import arc.collections.arraymap;
import arc.gfx.node;
import arc.gfx.node_part;
import arc.gfx.material;
import arc.gfx.animation;
import arc.gfx.mesh;
import arc.gfx.mesh_part;
import arc.gfx.buffers;
import arc.gfx.node;
import arc.gfx.renderable;
import arc.gfx.model;
import arc.gfx.model_loader;

// BUG
/*
    For some reasons animation -> global transform is wrong, when compared to working C# version
*/

public class ModelInstance : IRenderableProvider
{
    public static bool defaultShareKeyframes = false;

    public Material[] materials;
    public Node[] nodes;
    public Animation[] animations;
    public Model model;

    public Mat4 transform = Mat4.identity;

    public this(Model model)
    {
        this.model = model;
        copyNodes(this.model);

        invalidate();
        copyAnimations(this.model);
        calculateTransforms();
    }

    private void copyNodes(Model model)
    {
        nodes.length = model.nodes.length;

        for (int i = 0; i < model.nodes.length; i++)
        {
            auto node = model.nodes[i];
            auto copy = new Node;
            copy.set(node);
            nodes[i] = copy;
        }
    }

    private void copyAnimations(Model model)
    {
        foreach(anim; model.animations)
        {
            copyAnimation(anim, false);
        }
    }

    private void copyAnimation(Animation sourceAnim, bool shareKeyFrames)
    {
        Animation animation = new Animation;
        animation.id = sourceAnim.id;
        animation.duration = sourceAnim.duration;

        foreach (i, NodeAnimation nanim; sourceAnim.nodeAnimations)
        {
            auto node = getNode(nodes, nanim.node.id);
            if(node is null) throw new Exception("node can't be found...");

            auto nodeAnim = new NodeAnimation;
            nodeAnim.node = node;

            if (shareKeyFrames)
            {
                nodeAnim.translation = nanim.translation;
                nodeAnim.rotation = nanim.rotation;
                nodeAnim.scaling = nanim.scaling;
            }
            else
            {
                //nodeAnim.translation.length = nanim.translation.length;
                //nodeAnim.rotation.length = nanim.rotation.length;
                //nodeAnim.scaling.length = nanim.scaling.length;
                foreach (j, kf; nanim.translation)
                {
                    if (kf.keytime > animation.duration)
                        animation.duration = kf.keytime;

                    auto nkt = NodeKeyframe!Vec3();
                    nkt.keytime = kf.keytime;
                    nkt.value = kf.value;
                    nodeAnim.translation ~= nkt;
                }
                foreach (j, kf; nanim.rotation)
                {
                    if (kf.keytime > animation.duration)
                        animation.duration = kf.keytime;

                    auto nkt = NodeKeyframe!Quat();
                    nkt.keytime = kf.keytime;
                    nkt.value = kf.value;
                    nodeAnim.rotation ~= nkt;
                }
                foreach (j, kf; nanim.scaling)
                {
                    if (kf.keytime > animation.duration)
                        animation.duration = kf.keytime;

                    auto nkt = NodeKeyframe!Vec3();
                    nkt.keytime = kf.keytime;
                    nkt.value = kf.value;
                    nodeAnim.scaling ~= nkt;
                }
            }
            if (nodeAnim.translation.length > 0 || nodeAnim.rotation.length > 0
                    || nodeAnim.scaling.length > 0)
                animation.nodeAnimations ~= nodeAnim;
            else
                throw new Exception("what");
        }

        if (animation.nodeAnimations.length > 0)
            animations ~= animation;
    }

    public void calculateTransforms()
    {
        int n = cast(int) nodes.length;

        for (int i = 0; i < n; i++)
        {
            nodes[i].calculateTransforms(true);
        }
        for (int i = 0; i < n; i++)
        {
            nodes[i].calculateBoneTransforms(true);
        }
    }

    public void invalidate()
    {
		for (int i = 0, n = cast(int)nodes.length; i < n; ++i) {
			invalidate(nodes[i]);
		}
    }

    private void invalidate(Node node)
    {
        import std.algorithm: canFind;

        for (int i = 0; i < cast(int)node.parts.length; ++i)
        {
	        auto part = node.parts[i];
			auto bindPose = part.invBoneBindTransforms;
            for (int j = 0; j < bindPose.length; ++j)
            {
                auto nn = getNode(nodes, bindPose[j].node.id);
                if(nn is null) throw new Exception("node can't be found...");
                auto t = bindPose[j].transform;
                part.invBoneBindTransforms[j] = InvBoneBind(nn, t);
            }
            // todo: finish
            if (!materials.canFind(part.material))
            {
                //int midx = 
            }

			//if (!materials.contains(part.material, true)) {
			//	final int midx = materials.indexOf(part.material, false);
			//	if (midx < 0)
			//		materials.add(part.material = part.material.copy());
			//	else
			//		part.material = materials.get(midx);
			//}

            foreach(Node child; node.children)
            {
                invalidate(child);
            }
        }
    }

    public Animation getAnimation(string id, bool ignoreCase = false)
    {
        int n = cast(int) animations.length;

        if(ignoreCase)
        {
            throw new Exception("Not supported yet");
        }
        else
        {
            foreach(animation; animations)
            {
                if(animation.id == id) return animation;
            }
        }

        return null;
    }

    public void getRenderables(ref Array!Renderable renderables, Pool!Renderable pool)
    {
        void checkNode(Node node)
        {
            foreach (NodePart part; node.parts)
            {
                if (part.enabled == false)
                    continue;

                auto renderable = pool.obtain();
                renderable.material = part.material;
                renderable.bones = &part.bones;
                renderable.meshPart.set(part.meshPart);
                if (part.bones.length == 0)
                    renderable.worldTransform = Mat4.multiply(transform, node.globalTransform);
                else
                    renderable.worldTransform = transform;
                renderables.insert(renderable);
            }
        }

        foreach(Node node; nodes)
        {
            checkNode(node);

            foreach(Node child; node.children)
            {
                checkNode(child);
            }
        }
    }
}