module arc.gfx.model;

import std.container;
import std.stdio;
import std.format;

import arc.pool;
import arc.math;
import arc.color;
import arc.core;
import arc.collections.arraymap;
import arc.gfx.node;
import arc.gfx.material;
import arc.gfx.animation;
import arc.gfx.mesh;
import arc.gfx.mesh_part;
import arc.gfx.buffers;
import arc.gfx.node;
import arc.gfx.renderable;
import arc.gfx.modelloader;

public class ModelInstance : IRenderableProvider
{
    public static bool defaultShareKeyframes = true;

    public Material[] materials;
    public Node[] nodes;
    public Animation[] animations;
    public Model model;

    public Mat4 transform = Mat4.identity;

    public this(Model model)
    {
        this.model = model;
        copyNodes(this.model);
        copyAnimations(this.model);
        calculateTransforms();
    }

    private void copyNodes(Model model)
    {
        nodes.length = model.nodes.length;

        for (int i = 0; i < model.nodes.length; i++)
        {
            Node node = model.nodes[i];

            Node copy = new Node;
            copy.set(node);
            
            nodes[i] = copy;
        }

        invalidate();
    }

    private void copyAnimations(Model model)
    {
        foreach(sourceAnim; model.animations)
        {
            copyAnimation(sourceAnim, defaultShareKeyframes);
        }
    }

    private void copyAnimation(Animation sourceAnim, bool shareKeyFrames)
    {
        Animation animation = new Animation;
        animation.id = sourceAnim.id;
        animation.duration = sourceAnim.duration;
        foreach (i, NodeAnimation nanim; sourceAnim.nodeAnimations)
        {
            Node node = getNode(nodes, nanim.node.id);
            if (node is null)
                continue;

            NodeAnimation nodeAnim = new NodeAnimation;
            nodeAnim.node = node;
            if (shareKeyFrames)
            {
                nodeAnim.translation = nanim.translation;
                nodeAnim.rotation = nanim.rotation;
                nodeAnim.scaling = nanim.scaling;
            }
            else
            {
                nodeAnim.translation.length = nanim.translation.length;
                nodeAnim.rotation.length = nanim.rotation.length;
                nodeAnim.scaling.length = nanim.scaling.length;
                foreach (j, kf; nanim.translation)
                    {
                        nodeAnim.translation[j] = new NodeKeyframe!Vec3;
                        nodeAnim.translation[j].keytime = kf.keytime;
                        nodeAnim.translation[j].value = kf.value;
                    }
                foreach (j, kf; nanim.rotation)
                    {
                        nodeAnim.rotation[j] = new NodeKeyframe!Quat;
                        nodeAnim.rotation[j].keytime = kf.keytime;
                        nodeAnim.rotation[j].value =kf.value;
                    }
                foreach (j, kf; nanim.scaling)
                    {
                        nodeAnim.scaling[j] = new NodeKeyframe!Vec3;
                        nodeAnim.scaling[j].keytime = kf.keytime;
                        nodeAnim.scaling[j].value = kf.value;
                    }
            }
            if (nodeAnim.translation.length > 0 || nodeAnim.rotation.length > 0
                    || nodeAnim.scaling.length > 0)
                animation.nodeAnimations ~= nodeAnim;
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

        for (int i = 0, n = cast(int)node.parts.length; i < n; ++i)
        {
	        NodePart part = node.parts[i];
			auto bindPose = part.invBoneBindTransforms;
			if (bindPose !is null) {
				for (int j = 0; j < bindPose.size; ++j) 
                {
					bindPose.keys[j] = getNode(nodes, bindPose.keys[j].id);
				}
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
        foreach(Node node; nodes)
        {
            getRenderables(node, renderables, pool);
        }
    }

    private void getRenderables(Node node, ref Array!Renderable renderables, Pool!Renderable pool)
    {
        if (node.parts.length > 0)
        {
            foreach(NodePart nodePart; node.parts)
            {
                if (nodePart.enabled)
                {
                    auto renderable = pool.obtain();
                    renderables.insert(getRenderable(renderable, node, nodePart));
                }
            }
        }

        foreach(Node child; node.children)
        {
            getRenderables(child, renderables, pool);
        }
    }

    private Renderable getRenderable(Renderable renderable, Node node, NodePart nodePart)
    {
        nodePart.setRenderable(renderable);

        if (nodePart.bones.length == 0)
            renderable.worldTransform = transform * node.globalTransform;
        else
            renderable.worldTransform = transform;
        return renderable;
    }
}

public class Model
{
    public string id;
    public Material[] materials;
    public Node[] nodes;
    public Animation[] animations;
    public Mesh[] meshes;
    public MeshPart[] meshParts;

    ArrayMap!(string, Mat4)[NodePart] nodePartBones;

    public void load(ModelData data)
    {
        id = data.id;
        loadMeshes(data.meshes);
        loadMaterials(data.materials /*, contentManager */ );
        loadNodes(data);
        loadAnimations(data.animations);
        calculateTransforms();
    }

    private void loadMeshes(ModelMesh[] meshes)
    {
        for (int i = 0; i < meshes.length; i++)
        {
            convertMesh(meshes[i]);
        }
    }

    private void convertMesh(ModelMesh modelMesh)
    {
        int numIndices = 0;
        for (int i = 0; i < modelMesh.parts.length; i++)
        {
            numIndices += modelMesh.parts[i].indices.length;
        }

        bool hasIndices = numIndices > 0;

        VertexAttributes attributes = new VertexAttributes(modelMesh.attributes);
        int numVertices = cast(int) modelMesh.vertices.length / (attributes.vertexSize / 4);

        Mesh mesh = new Mesh(true, numVertices, numIndices, attributes);
        meshes ~= mesh;

        mesh.setVertices(modelMesh.vertices);
        short[] indices;
        
        int offset = 0;
        meshParts.length = modelMesh.parts.length;
        foreach (i, part; modelMesh.parts)
        {
            MeshPart meshPart = new MeshPart;
            meshPart.id = part.id;
            meshPart.primitiveType = part.primitiveType;
            meshPart.offset = offset;
            meshPart.size = hasIndices ? cast(int) part.indices.length : numVertices;
            meshPart.mesh = mesh;
            if (hasIndices)
            {
               indices ~= part.indices;
            }
            offset += meshPart.size;
            meshParts[i] = meshPart;
        }
        mesh.setIndices(indices);
        foreach (part; meshParts)
            part.update();
    }

    private void loadMaterials(ModelMaterial[] modelMaterials)
    {
        foreach (mtl; modelMaterials)
            convertMaterial(mtl);
    }

    private void convertMaterial(ModelMaterial mtl)
    {
        import arc.gfx.texture;

        Material result = new Material(mtl.id);

        if (mtl.textures.length > 0)
        {
            Texture2D texture = Texture2D.fromFile(mtl.textures[0].fileName);
            result.set(TextureAttribute.createDiffuse(texture));
        }

        materials ~= result;
    }


    private void loadNodes(ModelData data)
    {
        nodePartBones.clear();
        nodes.length = data.nodes.length;
        foreach (i, node; data.nodes)
        {
            nodes[i] = loadNode(node);
        }

        foreach(e; nodePartBones.byKeyValue())
        {
            if(e.key.invBoneBindTransforms is null)
                e.key.invBoneBindTransforms = new ArrayMap!(Node, Mat4);

            e.key.invBoneBindTransforms.clear();
            e.key.invBoneBindTransforms.resize(e.value.size);

            for(int i = 0; i < e.value.size; i++)
            {
                string k = e.value.keys[i];
                Mat4 v = e.value.values[i];
                Node node = getNode(nodes, k);

                if(node is null) throw new Exception(format("can't find node with id: %s", k));
                
                e.key.invBoneBindTransforms.put(node, Mat4.inv(v));
            }
        }
    }

    private Node loadNode(ModelNode modelNode)
    {
        Node node = new Node;
        node.id = modelNode.id;


        node.translation = modelNode.translation;
        node.rotation = modelNode.rotation;
        node.scale = modelNode.scale;

        if (modelNode.parts.length > 0)
        {
            node.parts.length = modelNode.parts.length;

            foreach (i, ModelNodePart modelNodePart; modelNode.parts)
            {
                MeshPart meshPart = null;
                Material meshMaterial = null;

                if (modelNodePart.meshPartId.length > 0)
                {
                    foreach (part; meshParts)
                    {
                        if(modelNodePart.meshPartId == part.id)
                        {
                            meshPart = part;
                            break;
                        }
                    }
                }

                if (modelNodePart.materialId.length > 0)
                {
                    foreach (material; materials)
                    {
                        if(modelNodePart.materialId == material.id)
                        {
                            meshMaterial = material;
                            break;
                        }
                    }
                }

                if (meshPart is null || meshMaterial is null)
                    throw new Exception("invalid node");

                if (meshPart !is null && meshMaterial !is null)
                {
                    NodePart nodePart = new NodePart();
                    nodePart.meshPart = meshPart;
                    nodePart.material = meshMaterial;
                    node.parts[i] = nodePart;

                    if (modelNodePart.bones !is null)
                    {
                        nodePartBones[nodePart] = modelNodePart.bones;
                    }
                }
            }
        }

        if (modelNode.children.length > 0)
        {
            node.children.length = modelNode.children.length;
            foreach (i, ModelNode child; modelNode.children)
            {
                node.children[i] = loadNode(child);
                node.children[i].parent = node;
            }
        }

        return node;
    }

    private void loadAnimations(ModelAnimation[] modelAnimations)
    {
        for (int i = 0; i < modelAnimations.length; i++)
        {
            auto anim = modelAnimations[i];
            auto animation = new Animation;
            animation.id = anim.id;

            for (int j = 0; j < anim.nodeAnimations.length; j++)
            {
                auto nanim = anim.nodeAnimations[j];
                auto node = getNode(nodes, nanim.nodeId);
                if (node is null)
                    continue;

                NodeAnimation nodeAnim = new NodeAnimation;
                nodeAnim.node = node;

                if (nanim.translation.length > 0)
                {
                    nodeAnim.translation.length = nanim.translation.length;
                    foreach (k, kf; nanim.translation)
                    {
                        if (kf.keytime > animation.duration)
                            animation.duration = kf.keytime;

                        // todo: some might not have value, so we might was take node translation instead
                        nodeAnim.translation[k] = new NodeKeyframe!Vec3;
                        nodeAnim.translation[k].keytime = kf.keytime;
                        nodeAnim.translation[k].value = kf.value;
                    }
                }

                if (nanim.rotation.length > 0)
                {
                    nodeAnim.rotation.length = nanim.rotation.length;
                    foreach (k, kf; nanim.rotation)
                    {
                        if (kf.keytime > animation.duration)
                            animation.duration = kf.keytime;
                        // todo: some might not have value, so we might was take node translation instead
                        nodeAnim.rotation[k] = new NodeKeyframe!Quat;
                        nodeAnim.rotation[k].keytime = kf.keytime;
                        nodeAnim.rotation[k].value = kf.value;
                    }
                }

                if (nanim.scaling.length > 0)
                {
                    nodeAnim.scaling.length = nanim.scaling.length;
                    foreach (k, kf; nanim.scaling)
                    {
                        if (kf.keytime > animation.duration)
                            animation.duration = kf.keytime;
                        // todo: some might not have value, so we might was take node translation instead
                        nodeAnim.scaling[k] = new NodeKeyframe!Vec3;
                        nodeAnim.scaling[k].keytime = kf.keytime;
                        nodeAnim.scaling[k].value = kf.value;
                    }
                }

                if (nodeAnim.translation.length > 0
                        || nodeAnim.rotation.length > 0 && nodeAnim.scaling.length > 0)
                    animation.nodeAnimations ~= nodeAnim;
            }
            if (animation.nodeAnimations.length > 0)
                animations ~= animation;
        }
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
}

