module arc.gfx.texture;

import std.stdio;
import std.format;
import std.math;

import bindbc.opengl;
import bindbc.opengl.gl;
import stb.image;
import arc.math;

public enum TextureFilter
{
    Nearest, // GL20.GL_NEAREST
    Linear, // GL20.GL_LINEAR
    MipMap, // GL20.GL_LINEAR_MIPMAP_LINEAR
    MipMapNearestNearest, // GL20.GL_NEAREST_MIPMAP_NEAREST
    MipMapLinearNearest, // GL20.GL_LINEAR_MIPMAP_NEAREST
    MipMapNearestLinear, // GL20.GL_NEAREST_MIPMAP_LINEAR
    MipMapLinearLinear, // GL20.GL_LINEAR_MIPMAP_LINEAR
}

public enum TextureWrap
{
    MirroredRepeat, // GL20.GL_MIRRORED_REPEAT
    ClampToEdge, // GL20.GL_CLAMP_TO_EDGE
    Repeat, // GL20.GL_REPEAT
}

bool isMipMap(TextureFilter filter)
{
    return filter != TextureFilter.Nearest && filter != TextureFilter.Linear;
}

int getGLEnumFromTextureFilter(TextureFilter filter)
{
    switch (filter)
    {
    case TextureFilter.Nearest:
        return cast(int) GL_NEAREST;
    case TextureFilter.Linear:
        return cast(int) GL_LINEAR;
    case TextureFilter.MipMap:
        return cast(int) GL_LINEAR_MIPMAP_LINEAR;
    case TextureFilter.MipMapNearestNearest:
        return cast(int) GL_NEAREST_MIPMAP_NEAREST;
    case TextureFilter.MipMapLinearNearest:
        return cast(int) GL_LINEAR_MIPMAP_NEAREST;
    case TextureFilter.MipMapNearestLinear:
        return cast(int) GL_NEAREST_MIPMAP_LINEAR;
    case TextureFilter.MipMapLinearLinear:
        return cast(int) GL_LINEAR_MIPMAP_LINEAR;
    default:
        throw new Exception("wut");
    }
}

int getGLEnumFromTextureWrap(TextureWrap wrap)
{
    switch (wrap)
    {
    case TextureWrap.MirroredRepeat:
        return cast(int) GL_MIRRORED_REPEAT;
    case TextureWrap.ClampToEdge:
        return cast(int) GL_CLAMP_TO_EDGE;
    case TextureWrap.Repeat:
        return cast(int) GL_CLAMP_TO_EDGE;
    default:
        throw new Exception("wut");
    }
}

public abstract class GLTexture
{
    private GLenum glTarget;
    private GLuint glHandle;
    private TextureFilter minFilter = TextureFilter.Nearest;
    private TextureFilter magFilter = TextureFilter.Nearest;
    private TextureWrap uWrap = TextureWrap.ClampToEdge;
    private TextureWrap vWrap = TextureWrap.ClampToEdge;

    public this(GLenum glTarget)
    {
        GLuint handle;
        glGenTextures(1, &handle);
        this(glTarget, handle);
    }
    public this(GLenum glTarget, GLuint glHandle)
    {
        this.glTarget = glTarget;
        this.glHandle = glHandle;
    }

    public abstract int getWidth();

    public abstract int getHeight();

    public abstract int getDepth();

    public abstract bool isManaged();

    public abstract void reload();

    public void bind()
    {
        glBindTexture(glTarget, glHandle);
    }

    public void bind(int unit)
    {
        glActiveTexture(GL_TEXTURE0 + unit);
        glBindTexture(glTarget, glHandle);
    }

    public TextureFilter getMinFilter()
    {
        return minFilter;
    }

    public TextureFilter getMagFilter()
    {
        return magFilter;
    }

    public TextureWrap getUWrap()
    {
        return uWrap;
    }

    public TextureWrap getVWrap()
    {
        return vWrap;
    }

    public int getTextureObjectHandle()
    {
        return glHandle;
    }

    public void unsafeSetWrap(TextureWrap u, TextureWrap v, bool force = false)
    {
        if ((force || uWrap != u))
        {
            glTexParameteri(glTarget, GL_TEXTURE_WRAP_S, getGLEnumFromTextureWrap(u));
            uWrap = u;
        }

        if ((force || vWrap != v))
        {
            glTexParameteri(glTarget, GL_TEXTURE_WRAP_T, getGLEnumFromTextureWrap(v));
            vWrap = v;
        }
    }

    public void setWrap(TextureWrap u, TextureWrap v)
    {
        this.uWrap = u;
        this.vWrap = v;
        bind();
        glTexParameteri(glTarget, GL_TEXTURE_WRAP_S, getGLEnumFromTextureWrap(u));
        glTexParameteri(glTarget, GL_TEXTURE_WRAP_T, getGLEnumFromTextureWrap(v));
    }

    public void unsafeSetFilter(TextureFilter minFilter, TextureFilter magFilter, bool force = false)
    {
        if ((force || this.minFilter != minFilter))
        {
            glTexParameteri(glTarget, GL_TEXTURE_MIN_FILTER, getGLEnumFromTextureFilter(minFilter));
            this.minFilter = minFilter;
        }

        if ((force || this.magFilter != magFilter))
        {
            glTexParameteri(glTarget, GL_TEXTURE_MAG_FILTER, getGLEnumFromTextureFilter(magFilter));
            this.magFilter = magFilter;
        }
    }

    public void setFilter(TextureFilter minFilter, TextureFilter magFilter)
    {
        this.minFilter = minFilter;
        this.magFilter = magFilter;
        bind();
        glTexParameteri(glTarget, GL_TEXTURE_MIN_FILTER, getGLEnumFromTextureFilter(minFilter));
        glTexParameteri(glTarget, GL_TEXTURE_MAG_FILTER, getGLEnumFromTextureFilter(magFilter));
    }

    public void deletee()
    {
        if (glHandle != 0)
        {
            glDeleteTextures(1, &glHandle);
            glHandle = 0;
        }
    }
}

public class Texture2D : GLTexture
{
    private int _width;
    private int _height;
    private Image _data;

    public this(GLenum glTarget)
    {
        super(glTarget);
    }

    public override int getWidth()
    {
        return _width;
    }
    public override int getHeight()
    {
        return _height;
    }

    public override int getDepth()
    {
        return 0;
    }

    public override bool isManaged()
    {
        return true;
    }

    public override void reload()
    {
        
    }

    public void setData(Image data, int w, int h)
    {
        _data = data;
        _width = w;
        _height = h;

        bind();

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glTexImage2D(glTarget, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, data[].ptr);

		unsafeSetWrap(uWrap, vWrap, true);
		unsafeSetFilter(minFilter, magFilter, true);

        glBindTexture(glTarget, 0);
    }

    public static Texture2D fromFile(string path)
    {
        auto image = new Image(path);
        auto tex = new Texture2D(GL_TEXTURE_2D);
        tex.setData(image, image.w(), image.h());
        return tex;
    }

}


public class TextureDescriptor
{
    public GLTexture texture;
	public TextureFilter minFilter;
	public TextureFilter magFilter;
	public TextureWrap uWrap;
	public TextureWrap vWrap;
}

public class TextureBinder
{
    public const int ROUNDROBIN = 0;
    public const int WEIGHTED = 1;

	public const int MAX_UNITS = 32;

    private int _offset;
	private int _count;
	private int _reuseWeight;
	private GLTexture[] _textures;
	private int[] _weights;
	private int _method;
	private bool _reused;

	private int _reuseCount = 0;
	private int _bindCount = 0;

    private int _currentTexture = 0;

    this(int method = 0, int offset = 0, int count = -1, int reuseWeight = 10)
    {        
        int max = min(getMaxTextureUnits(), MAX_UNITS);
        if (count < 0) count = max - offset;
        if (_offset < 0 || _count < 0 || (offset + count) > max || reuseWeight < 1)
            throw new Exception("Illegal arguments");
        _method = method;
        _offset = offset;
        _count = count;
        _textures.length = count;
        _reuseWeight = reuseWeight;

        if(method == WEIGHTED)
            _weights.length = count;
    }
    
	private static int getMaxTextureUnits () {
		int max;
        glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &max);
		return max;
	}

    public void begin()
    {
		for (int i = 0; i < _count; i++) {
			_textures[i] = null;
			if (_weights.length > 0) _weights[i] = 0;
		}
    }

    public void end()
    {
        glActiveTexture(GL_TEXTURE0);
    }

    public int bind(TextureDescriptor textureDesc)
    {
        return bindTexture(textureDesc, true);
    }

    private int bindTexture(TextureDescriptor textureDesc, bool rebind)
    {
        int idx;
        int result;
        GLTexture texture = textureDesc.texture;
        _reused = false;

        switch (_method)
        {
        case 0:
            result = _offset + (idx = bindTextureRoundRobin(texture));
            break;
        case 1:
            result = _offset + (idx = bindTextureWeighted(texture));
            break;
        default:
            return -1;
        }

        if (_reused)
        {
            _reuseCount++;
            if (rebind)
                texture.bind(result);
            else
                glActiveTexture(GL_TEXTURE0  + result);
        }
        else
            _bindCount++;

        texture.unsafeSetWrap(textureDesc.uWrap, textureDesc.vWrap);
        texture.unsafeSetFilter(textureDesc.minFilter, textureDesc.magFilter);
        return result;
    }

    private int bindTextureRoundRobin(GLTexture texture)
    {
        for (int i = 0; i < _count; i++)
        {
            int idx = (_currentTexture + i) % _count;
            if (_textures[idx] == texture)
            {
                _reused = true;
                return idx;
            }
        }

        _currentTexture = (_currentTexture + 1) % _count;
        _textures[_currentTexture] = texture;
        texture.bind(_offset + _currentTexture);

        return _currentTexture;
    }

    private int bindTextureWeighted(GLTexture texture)
    {
        int result = -1;
        int weight = _weights[0];
        int windex = 0;
        for (int i = 0; i < _count; i++)
        {
            if (_textures[i] == texture)
            {
                result = i;
                _weights[i] += _reuseWeight;
            }
            else if (_weights[i] < 0 || --_weights[i] < weight)
            {
                weight = _weights[i];
                windex = i;
            }
        }

        if (result < 0)
        {
            _textures[windex] = texture;
            _weights[windex] = 100;
            texture.bind(_offset + (result = windex));
        }
        else
            _reused = true;

        return result;
    }
}