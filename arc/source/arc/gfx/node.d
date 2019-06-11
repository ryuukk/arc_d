module arc.gfx.node;

import std.stdio;
import std.algorithm;
import std.typecons;

import arc.math;
import arc.collections.arraymap;
import arc.gfx.node;
import arc.gfx.mesh;
import arc.gfx.mesh_part;
import arc.gfx.material;
import arc.gfx.renderable;

public class Node
{
    public string id;
    public bool inheritTransform = true;
    public bool isAnimated;

    public Vec3 translation = Vec3(0, 0, 0);
    public Quat rotation = Quat.identity;
    public Vec3 scale = Vec3(1, 1, 1);

    public Mat4 localTransform = Mat4.identity;
    public Mat4 globalTransform = Mat4.identity;

    public NodePart[] parts;

    public Node parent;
    public Node[] children;

    public void calculateLocalTransform()
    {
        if (!isAnimated)
            localTransform.idt().set(translation.x, translation.y,
                    translation.z, rotation.x, rotation.y, rotation.z,
                    rotation.w, scale.x, scale.y, scale.z);
    }

    public void calculateWorldTransform()
    {
        if (inheritTransform && parent !is null)
            globalTransform = parent.globalTransform * localTransform;
        else
            globalTransform = localTransform;
    }

    public void calculateTransforms(bool recursive)
    {
        calculateLocalTransform();
        calculateWorldTransform();

        if (recursive)
        {
            foreach (Node child; children)
                child.calculateTransforms(true);
        }
    }

    public void calculateBoneTransforms(bool recursive)
    {
        import std.stdio;

        foreach (NodePart part; parts)
        {
            if (part.invBoneBindTransforms is null || part.bones.length == 0
                    || part.invBoneBindTransforms.length != part.bones.length)
            {
                continue;
            }
            auto n = part.invBoneBindTransforms.length;
            for (int i = 0; i < n; i++)
            {
                Mat4 globalTransform = part.invBoneBindTransforms[i].node.globalTransform;
                Mat4 invTransform = part.invBoneBindTransforms[i].transform;
                part.bones[i] = globalTransform * invTransform;
            }
        }

        if (recursive)
        {
            foreach (Node child; children)
                child.calculateBoneTransforms(true);
        }
    }

    public void detach()
    {
        if (parent !is null)
        {
            parent.removeChild(this);
            parent = null;
        }
    }

    public Node copy()
    {
        Node node = new Node();
        node.set(this);
        return node;
    }

    public Node set(Node other)
    {
        detach();

        id = other.id;
        isAnimated = other.isAnimated;
        inheritTransform = other.inheritTransform;
        translation = other.translation;
        rotation = other.rotation;
        scale = other.scale;
        localTransform = other.localTransform;
        globalTransform = other.globalTransform;

        parts.length = other.parts.length;
        foreach (i, NodePart nodePart; other.parts)
        {
            parts[i] = nodePart.copy();
        }
        children.length = 0;
        foreach (i, Node child; other.children)
        {
            addChild(child.copy());
        }
        return this;
    }

    public int addChild(Node child)
    {
        for (Node p = this; p !is null; p = p.parent)
        {
            if (p == child)
                throw new Exception("Cannot add a parent as a child");
        }
        Node p = child.parent;
        if (p !is null && !p.removeChild(child))
            throw new Exception("Could not remove child from its current parent");

        children ~= child;
        child.parent = this;
        return cast(int) children.length;
    }

    public int indexOf(Node child)
    {
        for (int i = 0; i < children.length; i++)
        {
            if (children[i] == child)
                return i;
        }
        return -1;
    }

    public bool removeChild(Node child)
    {
        int index = indexOf(child);
        if (index == -1)
            return false;

        children = children.remove(index, index + 1);
        child.parent = null;
        return true;
    }
}

Node getNode(ref Node[] nodes, string id, bool recursive = true, bool ignoreCase = false)
{
    int n = cast(int) nodes.length;
    if (ignoreCase)
    {
        throw new Exception("not supported yet");
    }
    else
    {
        for (int i = 0; i < n; i++)
        {
            Node node = nodes[i];
            if (node.id == id)
                return node;
        }
    }

    if (recursive)
    {
        for (int i = 0; i < n; i++)
        {
            Node node = getNode(nodes[i].children, id, true, ignoreCase);
            if (node !is null)
                return node;
        }
    }
    return null;
}

public struct InvBoneTransform
{
    public Node node;
    public Mat4 transform;
}

public class NodePart
{
    public MeshPart meshPart;
    public Material material;
    public InvBoneTransform[] invBoneBindTransforms;
    public Mat4[] bones;
    public bool enabled = true;

    public this()
    {
    }

    public Renderable setRenderable(Renderable renderable)
    {
        renderable.material = material;
        renderable.meshPart.set(meshPart);
        renderable.bones = bones;
        return renderable;
    }

    public NodePart copy()
    {
        auto ret = new NodePart();
        ret.set(this);
        return ret;
    }

    public NodePart set(NodePart other)
    {
        meshPart = new MeshPart(other.meshPart);
        material = other.material;
        enabled = other.enabled;

        if(other.invBoneBindTransforms.length > 0)
        {
            invBoneBindTransforms.length = other.invBoneBindTransforms.length;
            bones.length = other.invBoneBindTransforms.length;
            for(int i = 0; i < other.invBoneBindTransforms.length; ++i)
            {
                auto entry = other.invBoneBindTransforms[i];
                if(entry.node is null)
                    writeln("wtf bro");

                invBoneBindTransforms[i] = InvBoneTransform();
                invBoneBindTransforms[i].node = entry.node;
                invBoneBindTransforms[i].transform = entry.transform;
            }

            for (auto j = 0; j < bones.length; ++j) {
                bones[j] = Mat4.identity;
            }
        }

        return this;
    }
}
