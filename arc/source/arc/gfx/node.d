module arc.gfx.node;

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
    {}

    public void detach()
    {}

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
		
        foreach (i, NodePart nodePart; other.parts) {
			parts[i] = nodePart.copy();
		}
		foreach (i, Node child; other.children) {
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
    public Node[Mat4] invBoneBindTransforms;
    public Mat4[] bones;
    public bool enabled = true;

    public this()
    {}

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
        
        // todo: finish

		//if (other.invBoneBindTransforms.length == 0) {
		//	invBoneBindTransforms.length = 0;
		//	bones.length = 0;
		//} else {
           //invBoneBindTransforms.length = other.invBoneBindTransforms.length;
			//invBoneBindTransforms.putAll(other.invBoneBindTransforms);
			//if (bones == null || bones.length != invBoneBindTransforms.size)
			//	bones = new Matrix4[invBoneBindTransforms.size];
			//for (int i = 0; i < bones.length; i++) {
			//	if (bones[i] == null)
			//		bones[i] = new Matrix4();
			//}
		//}
		return this;
    }
}
