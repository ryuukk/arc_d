module arc.gfx.node;

import std.stdio;

import arc.math;
import arc.gfx.node;
import arc.gfx.mesh;
import arc.gfx.material;
import arc.gfx.renderable;

public class Node
{
    public string id;
    public bool inheritTransform = true;
    public bool isAnimated;

    public Vec3 translation;
    public Quat rotation = Quat.identity;
    public Vec3 scale = Vec3(1, 1, 1);

    public Mat4 localTransform = Mat4.identity;
    public Mat4 globalTransform = Mat4.identity;

    public NodePart[] parts;

    public Node parent;
    public Node[] children;

    public this()
    {
    }

    public void calculateLocalTransform()
    {
        if (!isAnimated)
            localTransform.set(translation.x, translation.y, translation.z,
                    rotation.x, rotation.y, rotation.z, rotation.w, scale.x, scale.y, scale.z);
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
            if (part.invBoneBindTransforms.length == 0 || part.bones.length == 0
                    || part.invBoneBindTransforms.length != part.bones.length)
            {
                writeln("continue: ", part.meshPart.id, " Bones: ", part.bones.length, " INV: ", part.invBoneBindTransforms.length);
                continue;
            }

            // Map<Node, Matrix>
            // part.bones[i].set(part.invBoneBindTransforms.keys[i].globalTransform).mul(part.invBoneBindTransforms.values[i]);

            // todo: i need to verify this
            // problem: i need ordered map, i should port my C# impl maybe
            int n = cast(int) part.invBoneBindTransforms.length;
            int c = 0;
            foreach (item; part.invBoneBindTransforms.byKeyValue())
            {
                Mat4 invTransform = part.invBoneBindTransforms.values[c];
                Node node = part.invBoneBindTransforms.keys[c];
                part.bones[c] = node.globalTransform * invTransform;
                c++;
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
    }

    public Node copy()
    {
        return new Node().set(this);
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
        children.length = other.children.length;

        foreach (i, NodePart nodePart; other.parts)
        {
            parts[i] = nodePart.copy();
        }
        foreach (i, Node child; other.children)
        {
            children[i] = child.copy();
        }
        return this;
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

public class NodePart
{
    public MeshPart meshPart;
    public Material material;
    public Mat4[Node] invBoneBindTransforms;
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
        return new NodePart().set(this);
    }

    public NodePart set(NodePart other)
    {
        meshPart = new MeshPart(other.meshPart);
        material = other.material;
        enabled = other.enabled;

        if (other.invBoneBindTransforms.length == 0)
        {
            invBoneBindTransforms.clear();
            bones.length = 0;
        }
        else
        {
            foreach (item; other.invBoneBindTransforms.byKeyValue())
            {
                invBoneBindTransforms[item.key] = item.value;
            }
            bones.length = invBoneBindTransforms.length;
            for (int i = 0; i < bones.length; i++)
            {
                bones[i] = Mat4.identity;
            }
        }
        return this;
    }
}
