module arc.gfx.model;

import std.container;
import std.experimental.logger;

import arc.pool;
import arc.math;
import arc.color;
import arc.core;
import arc.gfx.node;
import arc.gfx.material;
import arc.gfx.animation;
import arc.gfx.mesh;
import arc.gfx.buffers;
import arc.gfx.node;
import arc.gfx.renderable;

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
        copyAnimations();
        calculateTransforms();
    }

    private void copyNodes(Model model)
    {
        nodes.length = model.nodes.length;

        for (int i = 0; i < model.nodes.length; i++)
        {
            Node node = model.nodes[i];
            nodes[i] = node.copy();
        }

        invalidate();
    }
    private void copyAnimations(){}
    private void calculateTransforms(){}

    public void invalidate(){}

    public void getRenderables(ref Array!Renderable renderables, Pool!Renderable pool)
    {
        for(int i = 0; i < nodes.length; i++)
        {
            Node node = nodes[i];
            getRenderables(node, renderables, pool);
        }
    }

    private void getRenderables(Node node, ref Array!Renderable renderables, Pool!Renderable pool)
    {
        if (node.parts.length > 0)
        {
            for (int i = 0; i < node.parts.length; i++)
            {
                NodePart nodePart = node.parts[i];


                if (nodePart.enabled)
                    renderables.insert(getRenderable(pool.obtain(), node, nodePart));

                    
            }
        }

        for (int i = 0; i < node.children.length; i++)
        {
            Node child = node.children[i];
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
    public Material[] materials;
    public Node[] nodes;
    public Animation[] animations;
    public Mesh[] meshes;
    public MeshPart[] meshParts;

    public void load(ModelData data)
    {
        loadMeshes(data.meshes);
        loadMaterials(data.materials /*, contentManager */ );
        loadNodes(data.nodes);
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

        int offset = 0;
        meshParts.length = modelMesh.parts.length;
        foreach(i, part; modelMesh.parts)
        {
            MeshPart meshPart = new MeshPart;
            meshPart.id = part.id;
            meshPart.primitiveType = part.primitiveType;
            meshPart.offset = offset;
            meshPart.size = hasIndices ? cast(int) part.indices.length : numVertices;
            meshPart.mesh = mesh;
            if(hasIndices)
            {
                mesh.setIndices(part.indices);
            }
            offset += meshPart.size;
            meshParts[i] = meshPart;
        }

        foreach(part; meshParts)
            part.update();
    }

    private void loadMaterials(ModelMaterial[] modelMaterials)
    {
        foreach(mtl; modelMaterials)
            convertMaterial(mtl);
    }

    private void convertMaterial(ModelMaterial mtl)
    {
        import arc.gfx.texture;
        
        Material result = new Material(mtl.id);
        Texture2D texture = Texture2D.fromFile(mtl.textures[0].fileName);

        result.set(TextureAttribute.createDiffuse(texture));

        materials ~= result;
    }

    
    Mat4[string][NodePart] nodePartBones;
    private void loadNodes(ModelNode[] modelNodes)
    {
        nodePartBones.clear();
        nodes.length = modelNodes.length;
        foreach(i, node; modelNodes)
            nodes[i] = loadNode(node);
            
    }

    private Node loadNode(ModelNode modelNode)
    {
        Node node = new Node;
        node.id = modelNode.id;
        
        node.translation = modelNode.translation;
        node.rotation = modelNode.rotation;
        node.scale = modelNode.scale;

        if(modelNode.parts.length > 0)
        {
            node.parts.length = modelNode.parts.length;
            
            foreach(i,ModelNodePart modelNodePart; modelNode.parts)
            {
                MeshPart meshPart = null;
                Material meshMaterial = null;

                if(modelNodePart.meshPartId.length > 0)
                {
                    foreach(part; meshParts)
                    {
                        meshPart = part;
                        break;
                    }
                }

                if(modelNodePart.materialId.length > 0)
                {
                    foreach(material; materials)
                    {
                        meshMaterial = material;
                        break;
                    }
                }
                
                if(meshPart is null || meshMaterial is null) throw new Exception("invalid node");

                if(meshPart !is null && meshMaterial !is null)
                {
                    NodePart nodePart = new NodePart();
                    nodePart.meshPart = meshPart;
                    nodePart.material = meshMaterial;
                    node.parts[i] = nodePart;
                    if(modelNodePart.bones.length > 0)
                    {
                        nodePartBones[nodePart] = modelNodePart.bones;
                    }
                }
            }
        }

        if(modelNode.children.length > 0)
        {
            node.children.length = modelNode.children.length;
            foreach(i,ModelNode child; modelNode.children)
            {
                node.children[i] = loadNode(child);
            }
        }

        return node;
    }

    private void loadAnimations(ModelAnimation[] modelAnimations)
    {
        for(int i = 0; i < modelAnimations.length; i++)
        {
            auto anim = modelAnimations[i];
            auto animation = new Animation;
            animation.id = anim.id;

            for(int j = 0; j < anim.nodeAnimations.length; j++)
            {
                auto nanim = anim.nodeAnimations[j];
                auto node = getNode(nodes, nanim.nodeId);
                if(node is null) continue;

                NodeAnimation nodeAnim = new NodeAnimation;
                nodeAnim.node = node;

                if(nanim.translation.length > 0)
                {
                    nodeAnim.translation.length = nanim.translation.length;
                    foreach(kf; nanim.translation)
                    {
                        if(kf.keytime > animation.duration) animation.duration = kf.keytime;
                        // todo: some might not have value, so we might was take node translation instead
                        nodeAnim.translation ~= new NodeKeyframe!Vec3(kf.keytime, kf.value);
                    }
                }

                if(nanim.rotation.length > 0)
                {
                    nodeAnim.rotation.length = nanim.rotation.length;
                    foreach(kf; nanim.rotation)
                    {
                        if(kf.keytime > animation.duration) animation.duration = kf.keytime;
                        // todo: some might not have value, so we might was take node translation instead
                        nodeAnim.rotation ~= new NodeKeyframe!Quat(kf.keytime, kf.value);
                    }
                }

                if(nanim.scaling.length > 0)
                {
                    nodeAnim.scaling.length = nanim.scaling.length;
                    foreach(kf; nanim.scaling)
                    {
                        if(kf.keytime > animation.duration) animation.duration = kf.keytime;
                        // todo: some might not have value, so we might was take node translation instead
                        nodeAnim.scaling ~= new NodeKeyframe!Vec3(kf.keytime, kf.value);
                    }
                }

                if(nodeAnim.translation.length > 0 || nodeAnim.rotation.length > 0 && nodeAnim.scaling.length > 0)
                    animation.nodeAnimations ~= nodeAnim;
            }
            if(animation.nodeAnimations.length > 0)
                animations ~= animation;
        }
    }

    public void calculateTransforms()
    {        
    }
}

// data for serialization
import std.json;
import std.stdio;

ModelData loadModelData(string path)
{
    import std.path;
    import std.file : readText;

    string json = path.readText;

    JSONValue j = parseJSON(json);

    ModelData model = new ModelData;

    int lo = cast(int) j["version"].array[0].integer;
    int hi = cast(int) j["version"].array[1].integer;
    model.id = ("id" in j) ? j["id"].str : path;

    parseMeshes(model, j);
    parseNodes(model, j);
    parseMaterials(model, j, dirName(path));

    return model;
}

private void parseMaterials(ModelData model, JSONValue json, string materialDir)
{

    JSONValue materials = json["materials"];
    model.materials.length = materials.array.length;

    infof("Model %s has %s materials !!", model.id, model.materials.length);
    foreach(i, material; materials.array)
    {
        ModelMaterial jsonMaterial = new ModelMaterial;
        jsonMaterial.id = material["id"].str;

        if("textures" in material)
        {
            JSONValue textures = material["textures"];
            jsonMaterial.textures.length = textures.array.length;

            foreach(j, texture; textures.array)
            {
                ModelTexture jsonTexture = new ModelTexture;
                jsonTexture.id = texture["id"].str;
                jsonTexture.fileName = materialDir ~ "/" ~ texture["filename"].str;
                
                // todo: uv data
                jsonTexture.uvTranslation = Vec2(0,0);
                jsonTexture.uvScaling = Vec2(1,1);

                jsonTexture.usage = parseTextureUsage(texture["type"].str);

                jsonMaterial.textures[j] = jsonTexture;
            }
        }
        else
        {
            error("Model %s has no material !!", model.id);
        }
        model.materials[i] = jsonMaterial;
    }
}

private int parseTextureUsage(string type)
{
    switch (type)
    {
        case "AMBIENT": return ModelTexture.USAGE_AMBIENT;
        case "BUMP": return ModelTexture.USAGE_BUMP;
        case "DIFFUSE": return ModelTexture.USAGE_DIFFUSE;
        case "EMISSIVE": return ModelTexture.USAGE_EMISSIVE;
        case "NONE": return ModelTexture.USAGE_NONE;
        case "NORMAL": return ModelTexture.USAGE_NORMAL;
        case "REFLECTION": return ModelTexture.USAGE_REFLECTION;
        case "SHININESS": return ModelTexture.USAGE_SHININESS;
        case "SPECULAR": return ModelTexture.USAGE_SPECULAR;
        case "TRANSPARENCY": return ModelTexture.USAGE_TRANSPARENCY;

        default: return ModelTexture.USAGE_UNKNOWN;
    }
}

private void parseNodes(ModelData model, JSONValue json)
{
    if( "nodes" in json)
    {
        JSONValue[] nodes = json["nodes"].array;
        
        model.nodes.length = nodes.length;
        foreach(i, JSONValue node; nodes)
        {
            model.nodes[i] = parseNodesRecursively(node);
        }
    }
}

private ModelNode parseNodesRecursively(JSONValue json)
{
    ModelNode jsonNode = new ModelNode;
    jsonNode.id = json["id"].str;


    if( "translation" in json ) jsonNode.translation = readVec3(json["translation"]);
    else jsonNode.translation = Vec3();

    if( "scale" in json ) jsonNode.scale = readVec3(json["scale"]);
    else jsonNode.scale = Vec3(1, 1, 1);

    if( "rotation" in json ) jsonNode.rotation = readQuat(json["rotation"]);
    else jsonNode.rotation = Quat.identity;

    jsonNode.meshId = ( "mesh" in json ) ? json["mesh"].str : "";


    if( "parts" in json )
    {
        JSONValue[] materials = json["parts"].array;
        jsonNode.parts.length = materials.length;

        foreach(i, material; materials)
        {
            ModelNodePart nodePart = new ModelNodePart();

            nodePart.meshPartId = material["meshpartid"].str;
            nodePart.materialId = material["materialid"].str;

            jsonNode.parts[i] = nodePart;
        }
    }


    return jsonNode;
}

private Vec3 readVec3(JSONValue value)
{
    return Vec3(value.array[0].floating, value.array[1].floating, value.array[2].floating);
}

private Vec2 readVec2(JSONValue value)
{
    return Vec2(value.array[0].floating, value.array[1].floating);
}

private Quat readQuat(JSONValue value)
{
    return Quat(value.array[0].floating, value.array[1].floating, value.array[2].floating, value.array[3].floating);
}

private void parseMeshes(ModelData model, JSONValue json)
{
    if("meshes" in json)
    {
        JSONValue meshes = json["meshes"];
        model.meshes.length = meshes.array.length;
        foreach(i, mesh; meshes.array)
        {
            ModelMesh jsonMesh = new ModelMesh;

            jsonMesh.id = ("id" in mesh) ? mesh["id"].str:"";
            
            JSONValue attributes = mesh["attributes"];
            JSONValue vertices = mesh["vertices"];
            JSONValue parts = mesh["parts"];

            parseAttributes(jsonMesh, attributes);
            parseVertices(jsonMesh, vertices);
            parseMeshParts(jsonMesh, parts);
            
            model.meshes[i] = jsonMesh;
        }
    }
    else
    {

    }
}

private void parseMeshParts(ModelMesh modelMesh, JSONValue parts)
{
    auto array = parts.array;
    modelMesh.parts.length = array.length;
    
    for(int i = 0; i < array.length; i++)
    {
        JSONValue meshPart = array[i];
        ModelMeshPart jsonPart = new ModelMeshPart;
        jsonPart.id = meshPart["id"].str;
        string type = meshPart["type"].str;
        jsonPart.primitiveType = parseType(type);

        JSONValue indices = meshPart["indices"];
        parseIndices(jsonPart, indices);
        modelMesh.parts[i] = jsonPart;
    }
}

private int parseType(string type)
{
    import bindbc.opengl;
    switch(type)
    {
        case "TRIANGLES": return GL_TRIANGLES;
        case "LINES": return GL_LINES;
        case "POINTS": return GL_POINTS;
        case "TRIANGLE_STRIP": return GL_TRIANGLE_STRIP;
        case "LINE_STRIP": return GL_LINE_STRIP;

        default: throw new Exception("Not supported type");
    }
}

private void parseIndices(ModelMeshPart modelMesh, JSONValue indices)
{
    auto array = indices.array;
    modelMesh.indices.length = array.length;
    for(int i = 0; i < array.length; i++)
    {
        modelMesh.indices[i] = cast(short) array[i].integer;
    }
}

private void parseVertices(ModelMesh modelMesh, JSONValue vertices)
{
    auto array = vertices.array;
    modelMesh.vertices.length = array.length;
    for(int i = 0; i < array.length; i++)
    {
        modelMesh.vertices[i] = array[i].floating;
    }
}

private void parseAttributes(ModelMesh modelMesh, JSONValue attributes)
{
    import std.algorithm.searching : startsWith;

    int unit = 0;
    int blendWeightCount = 0;
    foreach (value; attributes.array)
    {
        string attribute = value.str;

        if (attribute.startsWith("TEXCOORD"))
            modelMesh.attributes ~= VertexAttribute.texCoords(unit++);
        else if (attribute.startsWith("BLENDWEIGHT"))
            modelMesh.attributes ~= VertexAttribute.boneWeight(blendWeightCount++);
        else if (attribute == "POSITION")
            modelMesh.attributes ~= VertexAttribute.position();
        else if (attribute == "NORMAL")
            modelMesh.attributes ~= VertexAttribute.normal();
        else if (attribute == "COLOR")
            modelMesh.attributes ~= VertexAttribute.colorUnpacked();
        else if (attribute == "COLORPACKED")
            modelMesh.attributes ~= VertexAttribute.colorPacked();
        else if (attribute == "TANGENT")
            modelMesh.attributes ~= VertexAttribute.tangent();
        else if (attribute == "BINORMAL")
            modelMesh.attributes ~= VertexAttribute.binormal();
        else
            Core.logger.errorf("Unsupported attribute: %s", attribute);
    }
}

public class ModelData
{
    public string id;
    public ModelMesh[] meshes;
    public ModelMaterial[] materials;
    public ModelNode[] nodes;
    public ModelAnimation[] animations;
}

public class ModelMesh
{
    public string id;
    public VertexAttribute[] attributes;
    public float[] vertices;
    public ModelMeshPart[] parts;
}

public class ModelMeshPart
{
    public string id;
    public short[] indices;
    public int primitiveType;
}

public class ModelMaterial
{
    public enum MaterialType
    {
        Lambert,
        Phong
    }

    public string id;

    public MaterialType type;

    public Color ambient;
    public Color diffuse;
    public Color specular;
    public Color emissive;
    public Color reflection;

    public float shininess;
    public float opacity = 1.0f;

    public ModelTexture[] textures;
}

public class ModelTexture
{
    public immutable static int USAGE_UNKNOWN = 0;
    public immutable static int USAGE_NONE = 1;
    public immutable static int USAGE_DIFFUSE = 2;
    public immutable static int USAGE_EMISSIVE = 3;
    public immutable static int USAGE_AMBIENT = 4;
    public immutable static int USAGE_SPECULAR = 5;
    public immutable static int USAGE_SHININESS = 6;
    public immutable static int USAGE_NORMAL = 7;
    public immutable static int USAGE_BUMP = 8;
    public immutable static int USAGE_TRANSPARENCY = 9;
    public immutable static int USAGE_REFLECTION = 10;

    public string id;
    public string fileName;
    public Vec2 uvTranslation;
    public Vec2 uvScaling;
    public int usage;
}

public class ModelNode
{
    public string id;
    public Vec3 translation = Vec3();
    public Quat rotation = Quat.identity;
    public Vec3 scale = Vec3(1,1,1);
    public string meshId;
    public ModelNodePart[] parts;
    public ModelNode[] children;
}

public class ModelNodePart
{
    public string materialId;
    public string meshPartId;
    public Mat4[string] bones;
    public int[][] uvMapping;
}

public class ModelAnimation
{
    public string id;
    public ModelNodeAnimation[] nodeAnimations;
}

public class ModelNodeAnimation
{
    public string nodeId;
    public ModelNodeKeyframe!Vec3[] translation;
    public ModelNodeKeyframe!Quat[] rotation;
    public ModelNodeKeyframe!Vec3[] scaling;
}

public class ModelNodeKeyframe(T)
{
    public float keytime;
    public T value;
}
