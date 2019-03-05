module arc.gfx.shader;

import std.conv : text;
import std.format;
import std.stdio;
import core.math;

import bindbc.opengl;

import arc.gfx.camera;
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
        }
    }

	private int fetchAttributeLocation (string name) {
		// -2 == not yet cached
		// -1 == cached but not found
		int location;
		if ((location = _attributes.get(name, -2)) == -2) {
			location = glGetAttribLocation(_program, name.ptr);
			_attributes[name] = location;
		}
		return location;
	}

	private void checkManaged () {
		if (_invalidated) {
            writeln("Recompile shader");
			compileShaders(_vertexShaderSource, _fragmentShaderSource);
			_invalidated = false;
		}
	}

	public void setVertexAttribute (int location, int size, int type, bool normalize, int stride, int offset) {
		checkManaged();
		glVertexAttribPointer(location, size, type, normalize ? GL_TRUE : GL_FALSE, stride, cast(const(void)*) offset);
	}

    public void enableVertexAttribute(int location)
    {
        checkManaged();
        glEnableVertexAttribArray(location);
    }
    public void disableVertexAttribute (string name) {
		checkManaged();
		int location = fetchAttributeLocation(name);
		if (location == -1) return;
		glDisableVertexAttribArray(location);
	}

	public void disableVertexAttribute (int location) {
		checkManaged();
		glDisableVertexAttribArray(location);
	}

	public int getAttributeLocation (string name) {
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

    	private int fetchUniformLocation (string name) {
		return fetchUniformLocation(name, pedantic);
	}

	public int fetchUniformLocation (string name, bool pedantic) {
		// -2 == not yet cached
		// -1 == cached but not found
		int location = _uniforms.get(name, -2);
		if (location == -2) {
            writeln(format("Uniform not cached yet: %s", name));
			location = glGetUniformLocation(_program, name.ptr);
			if (location == -1 && pedantic) throw new Exception(format("no uniform with name '%s' in shader", name));
			_uniforms[name] = location;
		}
		return location;
	}

    

    
	public void setUniformi (string name, int value) {
		checkManaged();
		int location = fetchUniformLocation(name);
		glUniform1i(location, value);
	}

    
	public void setUniformMat4 (string name, Mat4 value, bool transpose = false) {
		checkManaged();
		int location = fetchUniformLocation(name);
		glUniformMatrix4fv(location, 1, transpose, value.val.ptr);
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

public class Renderable
{
}

public class RenderContext
{

}
