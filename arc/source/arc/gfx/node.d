module arc.gfx.node;

import arc.math;
import arc.gfx.node;
import arc.gfx.mesh;
import arc.gfx.material;

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
    public Node[Mat4] invBoneBindTransforms;
    public Mat4[] bones;
    public bool enabled = true;
}
