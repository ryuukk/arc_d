module arc.gfx.modelloader;

import std.json;
import std.stdio;
import std.container;

import arc.pool;
import arc.math;
import arc.color;
import arc.core;
import arc.collections.arraymap;
import arc.gfx.node;
import arc.gfx.material;
import arc.gfx.animation;
import arc.gfx.mesh;
import arc.gfx.buffers;
import arc.gfx.node;
import arc.gfx.renderable;


// data for serialization

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
    parseAnimations(model, j);

    return model;
}

private void parseAnimations(ModelData model, JSONValue json)
{
    if ("animations" in json)
    {
        JSONValue[] animations = json["animations"].array;
        model.animations.length = animations.length;
        foreach (i, JSONValue anim; animations)
        {
            JSONValue[] nodes = anim["bones"].array;

            ModelAnimation animation = new ModelAnimation;
            model.animations[i] = animation;
            animation.id = anim["id"].str;
            animation.nodeAnimations.length = nodes.length;
            foreach (j, JSONValue node; nodes)
            {
                ModelNodeAnimation nodeAnim = new ModelNodeAnimation;
                animation.nodeAnimations[j] = nodeAnim;
                nodeAnim.nodeId = node["boneId"].str;

                // For backwards compatibility (version 0.1):
                JSONValue[] keyframes = node["keyframes"].array;

                //nodeAnim.translation.length = keyframes.length;
                //nodeAnim.rotation.length = keyframes.length;
                //nodeAnim.scaling.length = keyframes.length;

                foreach (k, JSONValue keyframe; keyframes)
                {
                    float keytime = keyframe["keytime"].floating / 1000f;

                    if( "translation" in keyframe )
                    {
                        auto kf = new ModelNodeKeyframe!Vec3;
                        kf.keytime = keytime;
                        kf.value = readVec3(keyframe["translation"]);
                        nodeAnim.translation ~= kf;
                    }
                    else
                    {
                        //nodeAnim.translation[k] = new ModelNodeKeyframe!Vec3;
                        //nodeAnim.translation[k].keytime = keytime;
                        //nodeAnim.translation[k].value = Vec3(0,0,0);
                    }

                    if( "rotation" in keyframe )
                    {
                        auto kf = new ModelNodeKeyframe!Quat;
                        kf.keytime = keytime;
                        kf.value = readQuat(keyframe["rotation"]);
                        nodeAnim.rotation ~= kf;
                    }
                    else
                    {
                        //nodeAnim.rotation[k] = new ModelNodeKeyframe!Quat;
                        //nodeAnim.rotation[k].keytime = keytime;
                        //nodeAnim.rotation[k].value = Quat.identity();
                    }

                    if( "scale" in keyframe )
                    {
                        auto kf = new ModelNodeKeyframe!Vec3;
                        kf.keytime = keytime;
                        kf.value = readVec3(keyframe["scale"]);
                        nodeAnim.scaling ~= kf;
                    }
                    else
                    {
                        //nodeAnim.scaling[k] = new ModelNodeKeyframe!Vec3;
                        //nodeAnim.scaling[k].keytime = keytime;
                        //nodeAnim.scaling[k].value = Vec3(1,1,1);
                    }
                }
            }
        }
    }
}

private void parseMaterials(ModelData model, JSONValue json, string materialDir)
{

    JSONValue materials = json["materials"];
    model.materials.length = materials.array.length;

    Core.logger.infof("Model %s has %s materials !!", model.id, model.materials.length);
    foreach (i, material; materials.array)
    {
        ModelMaterial jsonMaterial = new ModelMaterial;
        jsonMaterial.id = material["id"].str;

        if ("textures" in material)
        {
            JSONValue textures = material["textures"];
            jsonMaterial.textures.length = textures.array.length;

            foreach (j, texture; textures.array)
            {
                ModelTexture jsonTexture = new ModelTexture;
                jsonTexture.id = texture["id"].str;
                jsonTexture.fileName = materialDir ~ "/" ~ texture["filename"].str;

                // todo: uv data
                jsonTexture.uvTranslation = Vec2(0, 0);
                jsonTexture.uvScaling = Vec2(1, 1);

                jsonTexture.usage = parseTextureUsage(texture["type"].str);

                jsonMaterial.textures[j] = jsonTexture;
            }
        }
        else
        {
            Core.logger.errorf("Model %s has no texture !!", model.id);
        }
        model.materials[i] = jsonMaterial;
    }
}

private int parseTextureUsage(string type)
{
    switch (type)
    {
    case "AMBIENT":
        return ModelTexture.USAGE_AMBIENT;
    case "BUMP":
        return ModelTexture.USAGE_BUMP;
    case "DIFFUSE":
        return ModelTexture.USAGE_DIFFUSE;
    case "EMISSIVE":
        return ModelTexture.USAGE_EMISSIVE;
    case "NONE":
        return ModelTexture.USAGE_NONE;
    case "NORMAL":
        return ModelTexture.USAGE_NORMAL;
    case "REFLECTION":
        return ModelTexture.USAGE_REFLECTION;
    case "SHININESS":
        return ModelTexture.USAGE_SHININESS;
    case "SPECULAR":
        return ModelTexture.USAGE_SPECULAR;
    case "TRANSPARENCY":
        return ModelTexture.USAGE_TRANSPARENCY;

    default:
        return ModelTexture.USAGE_UNKNOWN;
    }
}

private void parseNodes(ModelData model, JSONValue json)
{
    if ("nodes" in json)
    {
        JSONValue[] nodes = json["nodes"].array;

        model.nodes.length = nodes.length;
        foreach (i, JSONValue node; nodes)
        {
            model.nodes[i] = parseNodesRecursively(node);
        }
    }
}

private ModelNode parseNodesRecursively(JSONValue json)
{
    ModelNode jsonNode = new ModelNode;
    jsonNode.id = json["id"].str;

    if ("translation" in json)
        jsonNode.translation = readVec3(json["translation"]);
    else
        jsonNode.translation = Vec3();

    if ("scale" in json)
        jsonNode.scale = readVec3(json["scale"]);
    else
        jsonNode.scale = Vec3(1, 1, 1);

    if ("rotation" in json)
        jsonNode.rotation = readQuat(json["rotation"]);
    else
        jsonNode.rotation = Quat.identity;

    jsonNode.meshId = ("mesh" in json) ? json["mesh"].str : "";

    if ("parts" in json)
    {
        JSONValue[] materials = json["parts"].array;
        jsonNode.parts.length = materials.length;

        foreach (i, material; materials)
        {
            ModelNodePart nodePart = new ModelNodePart();

            nodePart.meshPartId = material["meshpartid"].str;
            nodePart.materialId = material["materialid"].str;

            if ("bones" in material)
            {
                JSONValue[] bones = material["bones"].array;
                nodePart.bones = new ArrayMap!(string, Mat4);
                nodePart.bones.resize(cast(int) bones.length);
                foreach (j, JSONValue bone; bones)
                {
                    string nodeId = bone["node"].str;

                    Mat4 transform = Mat4.identity;

                    JSONValue[] translation = bone["translation"].array;
                    JSONValue[] rotation = bone["rotation"].array;
                    JSONValue[] scale = bone["scale"].array;

                    transform.set(translation[0].floating, translation[1].floating,
                            translation[2].floating, rotation[0].floating, rotation[1].floating,
                            rotation[2].floating, rotation[3].floating,
                            scale[0].floating, scale[1].floating, scale[2].floating);

                    nodePart.bones.put(nodeId, transform);
                }
            }

            jsonNode.parts[i] = nodePart;
        }
    }

    if ("children" in json)
    {
        JSONValue[] children = json["children"].array;
        jsonNode.children.length = children.length;

        foreach (i, JSONValue child; children)
        {
            jsonNode.children[i] = parseNodesRecursively(child);
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
    return Quat(value.array[0].floating, value.array[1].floating,
            value.array[2].floating, value.array[3].floating);
}

private void parseMeshes(ModelData model, JSONValue json)
{
    if ("meshes" in json)
    {
        JSONValue meshes = json["meshes"];
        model.meshes.length = meshes.array.length;
        foreach (i, mesh; meshes.array)
        {
            ModelMesh jsonMesh = new ModelMesh;

            jsonMesh.id = ("id" in mesh) ? mesh["id"].str : "";

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

    for (int i = 0; i < array.length; i++)
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

    switch (type)
    {
    case "TRIANGLES":
        return GL_TRIANGLES;
    case "LINES":
        return GL_LINES;
    case "POINTS":
        return GL_POINTS;
    case "TRIANGLE_STRIP":
        return GL_TRIANGLE_STRIP;
    case "LINE_STRIP":
        return GL_LINE_STRIP;

    default:
        throw new Exception("Not supported type");
    }
}

private void parseIndices(ModelMeshPart modelMesh, JSONValue indices)
{
    auto array = indices.array;
    modelMesh.indices.length = array.length;
    for (int i = 0; i < array.length; i++)
    {
        modelMesh.indices[i] = cast(short) array[i].integer;
    }
}

private void parseVertices(ModelMesh modelMesh, JSONValue vertices)
{
    auto array = vertices.array;
    modelMesh.vertices.length = array.length;
    for (int i = 0; i < array.length; i++)
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
    public Vec3 scale = Vec3(1, 1, 1);
    public string meshId;
    public ModelNodePart[] parts;
    public ModelNode[] children;
}

public class ModelNodePart
{
    public string materialId;
    public string meshPartId;
    public ArrayMap!(string, Mat4) bones;
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
