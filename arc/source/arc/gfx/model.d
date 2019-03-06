module arc.gfx.model;

import arc.math;
import arc.color;
import arc.gfx.node;
import arc.gfx.material;
import arc.gfx.animation;
import arc.gfx.mesh;
import arc.gfx.buffers;

public class Model
{
    public Material[] materials;
    public Node[] nodes;
    public Node[] animations;
    public Node[] meshes;
    public Node[] meshParts;

    private void load(ModelData data)
    {
        loadMeshes(data.meshes);
        loadMaterials(data.materials /*, contentManager */ );
        loadNodes(data.nodes);
        loadAnimations(data.animations);
        calculateTransforms();
    }

    private void loadMeshes(ModelMesh[] meshes)
    {
    }

    private void loadMaterials(ModelMaterial[] meshes)
    {
    }

    private void loadNodes(ModelNode[] meshes)
    {
    }

    private void loadAnimations(ModelAnimation[] meshes)
    {
    }

    public void calculateTransforms()
    {        
    }
}

// data for serialization

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
    public Vec3 translation;
    public Quat rotation;
    public Vec3 scale;
    public string meshId;
    public ModelNodePart[] parts;
    public ModelNode[] children;
}

public class ModelNodePart
{
    public string materialId;
    public string meshPartId;
    public string[Mat4] bones;
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
