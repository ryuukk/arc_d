module arc.gfx.texture;

import std.stdio;
import std.format;

import bindbc.opengl;
import bindbc.opengl.gl;
import stb.image;

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

        writeln(format("Loaded Image: %s, Size: %s:%s", path, image.w(), image.h()));

        return tex;
    }

}


public class TextureDescriptor(T) if (T is GLTexture) 
{
    public T texture;
	public TextureFilter minFilter;
	public TextureFilter magFilter;
	public TextureWrap uWrap;
	public TextureWrap vWrap;
}

public class TextureBinder
{
    public immutable static int ROUNDROBIN = 0;
    public immutable static int WEIGHTED = 1;

	public immutable static int MAX_UNITS = 32;

    private int offset;
	private int count;
	private int reuseWeight;
	private GLTexture[] textures;
	private int[] weights;
	private int method;
	private bool reused;

	private int reuseCount = 0;
	private int bindCount = 0;

    
	private static int getMaxTextureUnits () {
		int max;
        glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &max);
		return max;
	}

    public void begin()
    {
		for (int i = 0; i < count; i++) {
			textures[i] = null;
			if (weights !is null) weights[i] = 0;
		}
    }

    public void end()
    {
        glActiveTexture(GL_TEXTURE0);
    }


}