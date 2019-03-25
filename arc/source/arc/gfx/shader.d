module arc.gfx.shader;

import std.conv : text;
import std.format;
import std.stdio;
import core.math;

import bindbc.opengl;

import arc.gfx.camera;
import arc.gfx.rendering;
import arc.gfx.material;
import arc.gfx.mesh;
import arc.gfx.buffers;
import arc.gfx.renderable;
import arc.math;

public interface IShader
{
    void init();
    int compareTo(IShader other);
    bool canRender(Renderable renderable);
    void begin(Camera camera, RenderContext context);
    void render(Renderable renderable);
    void end();
}

public class ShaderProgram
{
    public static immutable string POSITION_ATTRIBUTE = "a_position";
    public static immutable string NORMAL_ATTRIBUTE = "a_normal";
    public static immutable string COLOR_ATTRIBUTE = "a_color";
    public static immutable string TEXCOORD_ATTRIBUTE = "a_texCoord";
    public static immutable string TANGENT_ATTRIBUTE = "a_tangent";
    public static immutable string BINORMAL_ATTRIBUTE = "a_binormal";
    public static immutable string BONEWEIGHT_ATTRIBUTE = "a_boneWeight";
    public static string prependVertexCode = "";
    public static string prependFragmentCode = "";
    public static bool pedantic = true;

    private string _log = "";
    private bool _isCompiled;

    private int[string] _uniforms;
    private int[string] _uniformTypes;
    private int[string] _uniformSizes;
    private string[] _uniformNames;

    private int[string] _attributes;
    private int[string] _attributeTypes;
    private int[string] _attributeSizes;
    private string[] _attributeNames;

    private int _program;
    private int _vertexShaderHandle;
    private int _fragmentShaderHandle;
    private string _vertexShaderSource;
    private string _fragmentShaderSource;

    private bool _invalidated;
    private int _refCount = 0;

    public this(string vertexShader, string fragmentShader)
    {
        assert(vertexShader != null);
        assert(fragmentShader != null);

        if (prependVertexCode !is null && prependVertexCode.length > 0)
            vertexShader = prependVertexCode ~= vertexShader;
        if (prependFragmentCode !is null && prependFragmentCode.length > 0)
            fragmentShader = prependFragmentCode ~= fragmentShader;

        _vertexShaderSource = vertexShader;
        _fragmentShaderSource = fragmentShader;

        compileShaders(vertexShader, fragmentShader);

        if (isCompiled())
        {
            fetchAttributes();
            fetchUniforms();
        }
    }

    private void compileShaders(string vertexShader, string fragmentShader)
    {
        _vertexShaderHandle = loadShader(GL_VERTEX_SHADER, vertexShader);
        _fragmentShaderHandle = loadShader(GL_FRAGMENT_SHADER, fragmentShader);

        if (_vertexShaderHandle == -1 || _fragmentShaderHandle == -1)
        {
            _isCompiled = false;
            return;
        }

        _program = linkProgram(createProgram());
        if (_program == -1)
        {
            _isCompiled = false;
            return;
        }

        _isCompiled = true;
    }

    private int loadShader(GLenum type, string source)
    {
        int shader = glCreateShader(type);
        if (shader == 0)
            return -1;

        int compiled;
        auto ssp = source.ptr;
        int ssl = cast(int) source.length;
        glShaderSource(shader, 1, &ssp, &ssl);
        glCompileShader(shader);
        glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);

        if (compiled == 0)
        {
            GLint logLen;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLen);

            char[] msgBuffer = new char[logLen];
            glGetShaderInfoLog(shader, logLen, null, &msgBuffer[0]);
            _log ~= type == GL_VERTEX_SHADER ? "Vertex shader\n" : "Fragment shader:\n";
            _log ~= text(msgBuffer);
            return -1;
        }
        return shader;
    }

    private int createProgram()
    {
        auto program = glCreateProgram();
        return program != 0 ? program : -1;
    }

    private int linkProgram(int program)
    {
        if (program == -1)
            return -1;

        glAttachShader(program, _vertexShaderHandle);
        glAttachShader(program, _fragmentShaderHandle);
        glLinkProgram(program);

        int linked;
        glGetProgramiv(program, GL_LINK_STATUS, &linked);
        if (linked == 0)
        {
            GLint logLen;
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);

            char[] msgBuffer = new char[logLen];
            glGetProgramInfoLog(program, logLen, null, &msgBuffer[0]);

            _log = text(msgBuffer);
            return -1;
        }

        return program;
    }

    private void fetchAttributes()
    {
        int numAttributes;
        glGetProgramiv(_program, GL_ACTIVE_ATTRIBUTES, &numAttributes);

        _attributeNames.length = numAttributes;
        for (int i = 0; i < numAttributes; i++)
        {
            char[64] buffer;
            GLenum type;
            int size;
            int length;
            glGetActiveAttrib(_program, i, buffer.length, &length, &size, &type, buffer.ptr);

            string name = buffer[0 .. length].idup;
            int location = glGetAttribLocation(_program, buffer.ptr);

            _attributes[name] = location;
            _attributeTypes[name] = type;
            _attributeSizes[name] = size;
            _attributeNames[i] = name;
            
            //version(DEBUG_SHADER)
            {
                writefln("ATTRIBUTE: %s loc: %s type: %s size: %s", name, location, type, size);
            }
        }
    }

    private void fetchUniforms()
    {
        int numUniforms;
        glGetProgramiv(_program, GL_ACTIVE_UNIFORMS, &numUniforms);

        _uniformNames.length = numUniforms;
        for (int i = 0; i < numUniforms; i++)
        {
            char[64] buffer;
            GLenum type;
            int size;
            int length;
            glGetActiveUniform(_program, i, buffer.length, &length, &size, &type, buffer.ptr);

            string name = buffer[0 .. length].idup;
            int location = glGetUniformLocation(_program, buffer.ptr);

            _uniforms[name] = location;
            _uniformTypes[name] = type;
            _uniformSizes[name] = size;
            _uniformNames[i] = name;

            //version(DEBUG_SHADER)
            {
                writeln("UNIFORM: ", name);
            }
        }
    }

    private int fetchAttributeLocation(string name)
    {
        // -2 == not yet cached
        // -1 == cached but not found
        int location;
        if ((location = _attributes.get(name, -2)) == -2)
        {
            location = glGetAttribLocation(_program, name.ptr);
            _attributes[name] = location;
        }
        return location;
    }

    private void checkManaged()
    {
        if (_invalidated)
        {
            //version(DEBUG_SHADER)
            {
                writeln("Recompile shader");
            }
            compileShaders(_vertexShaderSource, _fragmentShaderSource);
            _invalidated = false;
        }
    }

    public void setVertexAttribute(int location, int size, int type,
            bool normalize, int stride, int offset)
    {
        checkManaged();
        glVertexAttribPointer(location, size, type, normalize ? GL_TRUE
                : GL_FALSE, stride, cast(const(void)*) offset);
    }

    public void enableVertexAttribute(int location)
    {
        checkManaged();
        glEnableVertexAttribArray(location);
    }

    public void disableVertexAttribute(string name)
    {
        checkManaged();
        int location = fetchAttributeLocation(name);
        if (location == -1)
            return;
        glDisableVertexAttribArray(location);
    }

    public void disableVertexAttribute(int location)
    {
        checkManaged();
        glDisableVertexAttribArray(location);
    }

    public int getAttributeLocation(string name)
    {
        return _attributes.get(name, -1);
    }

    public void begin()
    {
        checkManaged();

        glUseProgram(_program);
    }

    public void end()
    {
        glUseProgram(0);
    }

    private int fetchUniformLocation(string name)
    {
        return fetchUniformLocation(name, pedantic);
    }

    public int fetchUniformLocation(string name, bool pedantic)
    {
        // -2 == not yet cached
        // -1 == cached but not found
        int location = _uniforms.get(name, -2);
        if (location == -2)
        {
            version(DEBUG_SHADER)
            {
                writeln(format("Uniform not cached yet: %s", name));
            }
            
            location = glGetUniformLocation(_program, name.ptr);
            if (location == -1 && pedantic)
                throw new Exception(format("no uniform with name '%s' in shader", name));
            _uniforms[name] = location;
        }
        return location;
    }

    public void setUniformi(string name, int value)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniform1i(location, value);
    }

    public void setUniformi(int location, int value)
    {
        checkManaged();
        glUniform1i(location, value);
    }

    public void setUniformMat4(string name, Mat4 value, bool transpose = false)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniformMatrix4fv(location, 1, transpose, value.val.ptr);
    }

    public void setUniformMat4Array(string name, ref Mat4[] value, bool transpose = false)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniformMatrix4fv(location, cast(int) value.length, transpose, cast(const(float)*) value.ptr);
    }

    public void setUniformVec4(string name, Vec4 value)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniform4f(location, value.x, value.y, value.z, value.w);
    }

    public void setUniform4f(string name, float a, float b, float c, float d)
    {
        checkManaged();
        int location = fetchUniformLocation(name);
        glUniform4f(location, a, b, c, d);
    }

    public bool isCompiled()
    {
        return _isCompiled;
    }

    public string getLog()
    {
        return _log;
    }
}


public interface IValidator
{
    bool validate(BaseShader shader, int inputId, Renderable renderable);
}

public interface ISetter
{
    bool isGlobal(BaseShader shader, int inputId);

    void set(BaseShader shader, int inputId, Renderable renderable, Attributes combinedAttributes);
}

public abstract class GlobalSetter : ISetter
{
    public bool isGlobal(BaseShader shader, int inputId)
    {
        return true;
    }
}

public abstract class LocalSetter : ISetter
{
    public bool isGlobal(BaseShader shader, int inputId)
    {
        return false;
    }
}

public class Uniform : IValidator
{
    public string aliass;
    public ulong materialMask;
    public ulong environmentMask;
    public ulong overallMask;

    public this(string aliass, ulong materialMask = 0, ulong environmentMask = 0,
            ulong overallMask = 0)
    {
        this.aliass = aliass;
        this.materialMask = materialMask;
        this.environmentMask = environmentMask;
        this.overallMask = overallMask;
    }

    public bool validate(BaseShader shader, int inputId, Renderable renderable)
    {
        bool hasMaterial = (renderable !is null && renderable.material !is null);
        bool hasEnvironment = (renderable !is null && renderable.environment !is null);
        ulong matFlags = hasMaterial ? renderable.material.getMask() : 0UL;
        ulong envFlags = hasEnvironment ? renderable.environment.getMask() : 0UL;
        return ((matFlags & materialMask) == materialMask) && ((envFlags & environmentMask) == environmentMask)
            && (((matFlags | envFlags) & overallMask) == overallMask);
    }
}

public abstract class BaseShader : IShader
{
    public ShaderProgram program;
    public RenderContext context;
    public Camera camera;
    private Mesh currentMesh;

    public string[] uniforms;
    public IValidator[] validators;
    public ISetter[] setters;
    public int[] locations;
    public int[] globalUniforms;
    public int[] localUniforms;
    public int[int] attributes;

    public int register(string aliass, IValidator validator = null, ISetter setter = null)
    {
        int existing = getUniformId(aliass);
        if (existing >= 0)
        {
            validators[existing] = validator;
            setters[existing] = setter;
            return existing;
        }
        uniforms ~= aliass;
        validators ~= validator;
        setters ~= setter;
        return cast(int) uniforms.length - 1;
    }

    public int getUniformId(string aliass)
    {
        for (int i = 0; i < uniforms.length; i++)
            if (uniforms[i] == aliass)
                return i;
        return -1;
    }

    public bool has(int inputId)
    {
        return inputId >= 0 && inputId < locations.length && locations[inputId] >= 0;
    }

    public int loc(int inputId)
    {
        return (inputId >= 0 && inputId < locations.length) ? locations[inputId] : -1;
    }

    public void init(ShaderProgram program, Renderable renderable)
    {
        if (program.isCompiled() == false)
            throw new Exception("Shader needs to be compiled");
        this.program = program;

        int n = cast(int) uniforms.length;
        locations.length = n;

        for (int i = 0; i < n; i++)
        {
            string input = uniforms[i];
            IValidator validator = validators[i];
            ISetter setter = setters[i];

            if (validator !is null && !validator.validate(this, i, renderable))
                locations[i] = -1;
            else
            {
                locations[i] = program.fetchUniformLocation(input, false);
                if (locations[i] >= 0 && setter !is null)
                {
                    if (setter.isGlobal(this, i))
                        globalUniforms ~= i;
                    else
                        localUniforms ~= i;
                }
            }
            if (locations[i] < 0)
            {
                validators[i] = null;
                setters[i] = null;
            }
        }

        if (renderable !is null)
        {
            VertexAttributes attrs = renderable.meshPart.mesh.getVertexAttributes();
            int c = attrs.size();
            for (int i = 0; i < c; i++)
            {
                VertexAttribute attr = attrs.get(i);
                int location = program.getAttributeLocation(attr.aliass);
                if (location >= 0)
                    attributes[attr.getKey()] = location;
            }
        }
    }

    public void begin(Camera camera, RenderContext context)
    {
        this.camera = camera;
        this.context = context;
        program.begin();

        currentMesh = null;

        //for (int u, i = 0; i < globalUniforms.length; ++i)
        //    if (setters[u = globalUniforms[i]]!is null)
        //        setters[u].set(this, u, null, null);
    }

    public void render(Renderable renderable)
    {
        //if (renderable.worldTransform.det3x3() == 0)
        //   return;
        render(renderable, renderable.material);
    }

    private int[] tmp;
    private ref int[] getAttributeLocations(VertexAttributes attrs)
    {
        int n = attrs.size();
        tmp.length = n;
        for (int i = 0; i < n; i++)
        {
            tmp[i] = attributes.get(attrs.get(i).getKey(), -1);
        }
        return tmp;
    }

    public void render(Renderable renderable, Attributes combinedAttributes)
    {
        for (int u, i = 0; i < localUniforms.length; i++)
            if (setters[u = localUniforms[i]]!is null)
                setters[u].set(this, u, renderable, combinedAttributes);

        if (currentMesh != renderable.meshPart.mesh)
        {
            if (currentMesh !is null)
                currentMesh.unbind(program, null);

            currentMesh = renderable.meshPart.mesh;

            currentMesh.bind(program, null);
        }

        renderable.meshPart.render(program, false);
    }

    public void end()
    {
        if (currentMesh !is null)
        {
            currentMesh.unbind(program, null);
            currentMesh = null;
        }

        program.end();
    }

    public bool set(int uniform, int value)
    {
        if (locations[uniform] < 0)
            return false;
        program.setUniformi(locations[uniform], value);
        return true;
    }
}

public class DefaultShader : BaseShader
{
    public struct Config
    {
        public string vertexShader;
        public string fragmentShader;
        public int numDirectionalLights = 2;
        public int numPointLights = 5;
        public int numSpotLights = 0;
        public int numBones = 20;
        public bool ignoreUnimplemented = true;
        public int defaultCullFace = -1;
        public int defaultDepthFunc = -1;

        public this(string vs, string fs)
        {
            vertexShader = vs;
            fragmentShader = fs;
        }
    }

    // Global uniforms
    public immutable int u_projTrans;
    public immutable int u_viewTrans;
    public immutable int u_projViewTrans;
    public immutable int u_cameraPosition;
    public immutable int u_cameraDirection;
    public immutable int u_cameraUp;
    public immutable int u_cameraNearFar;
    public immutable int u_time;
    // Object uniforms
    public immutable int u_worldTrans;
    public immutable int u_viewWorldTrans;
    public immutable int u_projViewWorldTrans;
    public immutable int u_normalMatrix;
    public immutable int u_bones;
    // Material uniforms
    public immutable int u_shininess;
    public immutable int u_opacity;
    public immutable int u_diffuseColor;
    public immutable int u_diffuseTexture;
    public immutable int u_diffuseUVTransform;
    public immutable int u_specularColor;
    public immutable int u_specularTexture;
    public immutable int u_specularUVTransform;
    public immutable int u_emissiveColor;
    public immutable int u_emissiveTexture;
    public immutable int u_emissiveUVTransform;
    public immutable int u_reflectionColor;
    public immutable int u_reflectionTexture;
    public immutable int u_reflectionUVTransform;
    public immutable int u_normalTexture;
    public immutable int u_normalUVTransform;
    public immutable int u_ambientTexture;
    public immutable int u_ambientUVTransform;
    public immutable int u_alphaTest;

    private Renderable renderable;
    protected immutable ulong attributesMask;
    private immutable ulong vertexMask;
    protected immutable Config config;

    private immutable static ulong optionalAttributes;

    /** @deprecated Replaced by {@link Config#defaultCullFace} Set to 0 to disable culling */
    public static int defaultCullFace = GL_BACK;
    /** @deprecated Replaced by {@link Config#defaultDepthFunc} Set to 0 to disable depth test */
    public static int defaultDepthFunc = GL_LEQUAL;

    static this()
    {
        optionalAttributes = IntAttribute.cullFace | DepthTestAttribute.type;
    }

    public this(Renderable renderable, Config config, ShaderProgram program)
    {
        this.config = config;
        this.program = program;
        this.renderable = renderable;

        attributesMask = renderable.material.getMask() | optionalAttributes;
        vertexMask = renderable.meshPart.mesh.getVertexAttributes().getMaskWithSizePacked();

        // global
        u_projTrans = register("u_projTrans");
        u_viewTrans = register("u_viewTrans");
        u_projViewTrans = register("u_projViewTrans");
        u_cameraPosition = register("u_cameraPosition");
        u_cameraDirection = register("u_cameraDirection");
        u_cameraUp = register("u_cameraUp");
        u_cameraNearFar = register("u_cameraNearFar");
        u_time = register("u_time");

        // object
        u_worldTrans = register("u_worldTrans");
        u_viewWorldTrans = register("u_viewWorldTrans");
        u_projViewWorldTrans = register("u_projViewWorldTrans");
        u_normalMatrix = register("u_normalMatrix");
        u_bones = register("u_bones");

        // material
        u_shininess = register("u_shininess");
        u_opacity = register("u_opacity");
        u_diffuseColor = register("u_diffuseColor");
        u_diffuseTexture = register("u_diffuseTexture");
        u_diffuseUVTransform = register("u_diffuseUVTransform");
        u_specularColor = register("u_specularColor");
        u_specularTexture = register("u_specularTexture");
        u_specularUVTransform = register("u_specularUVTransform");
        u_emissiveColor = register("u_emissiveColor");
        u_emissiveTexture = register("u_emissiveTexture");
        u_emissiveUVTransform = register("u_emissiveUVTransform");
        u_reflectionColor = register("u_reflectionColor");
        u_reflectionTexture = register("u_reflectionTexture");
        u_reflectionUVTransform = register("u_reflectionUVTransform");
        u_normalTexture = register("u_normalTexture");
        u_normalUVTransform = register("u_normalUVTransform");
        u_ambientTexture = register("u_ambientTexture");
        u_ambientUVTransform = register("u_ambientUVTransform");
        u_alphaTest = register("u_alphaTest");

    }

    public void init()
    {
		ShaderProgram program = this.program;
        this.program = null;
        super.init(program, renderable);
        renderable = null;
    }

    public override void begin(Camera camera, RenderContext context)
    {
        super.begin(camera, context);
        //program.setUniformMat4("u_projTrans", camera.projection);
        //program.setUniformMat4("u_viewTrans", camera.view);
        program.setUniformMat4("u_projViewTrans", camera.combined);
        //program.setUniformMat4("u_viewWorldTrans", camera.view * renderable.worldTransform);
    }

    public override void render(Renderable renderable, Attributes attributes)
    {
        program.setUniformMat4("u_worldTrans", renderable.worldTransform);
        if(config.numBones > 0 && renderable.bones.length > 0)
        {
            program.setUniformMat4Array("u_bones", renderable.bones);
        }
        
        bindMaterial(attributes);

        super.render(renderable, attributes);
    }

    private void bindMaterial(Attributes attributes)
    {
        int cullFace = config.defaultCullFace == -1 ? defaultCullFace : config.defaultCullFace;
        int depthFunc = config.defaultDepthFunc == -1 ? defaultDepthFunc : config.defaultDepthFunc;
        float depthRangeNear = 0f;
        float depthRangeFar = 1f;
        bool depthMask = true;

        if (attributes.has(TextureAttribute.diffuse))
        {
            // todo: use binder from context
            TextureAttribute ta = attributes.get!TextureAttribute(TextureAttribute.diffuse);
            ta.textureDescriptor.texture.bind();
            //context.textureBinder.bind(ta.textureDescriptor);
            program.setUniformi("u_diffuseTexture", 0);
            program.setUniform4f("u_diffuseUVTransform", 0, 0, 1, 1);
        }

        context.setCullFace(cullFace);
        context.setDepthTest(depthFunc, depthRangeNear, depthRangeFar);
        context.setDepthMask(depthMask);
    }

    public int compareTo(IShader other)
    {
        if (other is null)
            return -1;
        if (other is this)
            return 0;
        return 0; // FIXME compare shaders on their impact on performance
    }

    public bool canRender(Renderable renderable)
    {
        ulong renderableMask = combineAttributeMasks(renderable);
        return (attributesMask == (renderableMask | optionalAttributes))
            && (vertexMask == renderable.meshPart.mesh.getVertexAttributes().getMaskWithSizePacked()) /*&& (renderable.environment != null) == lighting*/
            ;
    }

    private static ulong combineAttributeMasks(Renderable renderable)
    {
        ulong mask = 0;
        if (renderable.environment !is null)
            mask |= renderable.environment.getMask();
        if (renderable.material !is null)
            mask |= renderable.material.getMask();
        return mask;
    }

    public static string createPrefix(Renderable renderable, Config config)
    {
        import std.array;

        Attributes attributes = renderable.material;
        ulong attributesMask = attributes.getMask();
        ulong vertexMask = renderable.meshPart.mesh.getVertexAttributes().getMask();

        auto strBuilder = appender!string;

        if (and(vertexMask, Usage.Position))
            strBuilder.put("#define positionFlag\n");
        if (or(vertexMask, Usage.ColorUnpacked | Usage.ColorPacked))
            strBuilder.put("#define colorFlag\n");
        if (and(vertexMask, Usage.BiNormal))
            strBuilder.put("#define binormalFlag\n");
        if (and(vertexMask, Usage.Tangent))
            strBuilder.put("#define tangentFlag\n");
        if (and(vertexMask, Usage.Normal))
            strBuilder.put("#define normalFlag\n");

        // env

        int n = renderable.meshPart.mesh.getVertexAttributes().size();
        for (int i = 0; i < n; i++)
        {
            VertexAttribute attr = renderable.meshPart.mesh.getVertexAttributes().get(i);
            if (attr.usage == Usage.BoneWeight)
                strBuilder.put(format("#define boneWeight%sFlag\n", attr.unit));
            else if (attr.usage == Usage.TextureCoordinates)
                strBuilder.put(format("#define texCoord%sFlag\n", attr.unit));
        }
        //if ((attributesMask & BlendingAttribute.Type) == BlendingAttribute.Type)
        //	strBuilder.put("#define " ~ BlendingAttribute.Alias ~ "Flag\n");
        if ((attributesMask & TextureAttribute.diffuse) == TextureAttribute.diffuse)
        {
            strBuilder.put("#define " ~ TextureAttribute.diffuseAlias ~ "Flag\n");
            strBuilder.put("#define " ~ TextureAttribute.diffuseAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        }
        //if ((attributesMask & TextureAttribute.Specular) == TextureAttribute.Specular) {
        //	strBuilder.put("#define " ~ TextureAttribute.SpecularAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.SpecularAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Normal) == TextureAttribute.Normal) {
        //	strBuilder.put("#define " ~ TextureAttribute.NormalAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.NormalAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Emissive) == TextureAttribute.Emissive) {
        //	strBuilder.put("#define " ~ TextureAttribute.EmissiveAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.EmissiveAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Reflection) == TextureAttribute.Reflection) {
        //	strBuilder.put("#define " ~ TextureAttribute.ReflectionAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.ReflectionAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & TextureAttribute.Ambient) == TextureAttribute.Ambient) {
        //	strBuilder.put("#define " ~ TextureAttribute.AmbientAlias ~ "Flag\n");
        //	strBuilder.put("#define " ~ TextureAttribute.AmbientAlias ~ "Coord texCoord0\n"); // FIXME implement UV mapping
        //}
        //if ((attributesMask & ColorAttribute.Diffuse) == ColorAttribute.Diffuse)
        //	strBuilder.put("#define " ~ ColorAttribute.DiffuseAlias ~ "Flag\n");
        //if ((attributesMask & ColorAttribute.Specular) == ColorAttribute.Specular)
        //	strBuilder.put("#define " ~ ColorAttribute.SpecularAlias ~ "Flag\n");
        //if ((attributesMask & ColorAttribute.Emissive) == ColorAttribute.Emissive)
        //	strBuilder.put("#define " ~ ColorAttribute.EmissiveAlias ~ "Flag\n");
        //if ((attributesMask & ColorAttribute.Reflection) == ColorAttribute.Reflection)
        //	strBuilder.put("#define " ~ ColorAttribute.ReflectionAlias ~ "Flag\n");
        //if ((attributesMask & FloatAttribute.Shininess) == FloatAttribute.Shininess)
        //	strBuilder.put("#define " ~ FloatAttribute.ShininessAlias ~ "Flag\n");
        //if ((attributesMask & FloatAttribute.AlphaTest) == FloatAttribute.AlphaTest)
        //	strBuilder.put("#define " ~ FloatAttribute.AlphaTestAlias ~ "Flag\n");


        if (renderable.bones.length > 0 && config.numBones > 0) strBuilder.put(format("#define numBones %s\n", config.numBones));

        return strBuilder.data;
    }

    private static bool and(ulong mask, ulong flag)
    {
        return (mask & flag) == flag;
    }

    private static bool or(ulong mask, ulong flag)
    {
        return (mask & flag) != 0;
    }
}
