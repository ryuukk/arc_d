module arc.gfx.rendering;

import bindbc.opengl;

import arc.gfx.texture;

public class RenderContext
{
    public TextureBinder textureBinder;

    private bool blending;
    private int blendSFactor;
    private int blendDFactor;
    private int depthFunc;
    private float depthRangeNear;
    private float depthRangeFar;
    private bool depthMask;
    private int cullFace;

    public this(TextureBinder binder)
    {
        this.textureBinder = binder;
    }

    public void begin()
    {
        glDisable(GL_DEPTH_TEST);
        depthFunc = 0;
        glDepthMask(true);
        depthMask = true;
        glDisable(GL_BLEND);
        blending = false;
        glDisable(GL_CULL_FACE);
        cullFace = blendSFactor = blendDFactor = 0;
        textureBinder.begin();
    }

    public void end()
    {
        if (depthFunc != 0)
            glDisable(GL_DEPTH_TEST);
        if (!depthMask)
            glDepthMask(true);
        if (blending)
            glDisable(GL_BLEND);
        if (cullFace > 0)
            glDisable(GL_CULL_FACE);
        textureBinder.end();
    }

    public void setDepthMask(bool value)
    {
        if (depthMask != value)
        {
            depthMask = value;
            glDepthMask(depthMask);
        }
    }

    public void setDepthTest(int depthFunction, float depthRangeNear = 0f, float depthRangeFar = 1f)
    {
        bool wasEnabled = depthFunc != 0;
        bool enabled = depthFunction != 0;
        if (depthFunc != depthFunction)
        {
            depthFunc = depthFunction;
            if (enabled)
            {
                glEnable(GL_DEPTH_TEST);
                glDepthFunc(depthFunction);
            }
            else
                glDisable(GL_DEPTH_TEST);
        }
        if (enabled)
        {
            if (!wasEnabled || depthFunc != depthFunction)
                glDepthFunc(depthFunc = depthFunction);
            if (!wasEnabled || this.depthRangeNear != depthRangeNear || this.depthRangeFar != depthRangeFar)
            {
                this.depthRangeNear = depthRangeNear;
                this.depthRangeFar = depthRangeFar;
                glDepthRange(this.depthRangeNear, this.depthRangeFar);
            }
        }
    }

    public void setBlending(bool enabled, int sFactor, int dFactor)
    {
        if (enabled != blending)
        {
            blending = enabled;
            if (enabled)
                glEnable(GL_BLEND);
            else
                glDisable(GL_BLEND);
        }
        if (enabled && (blendSFactor != sFactor || blendDFactor != dFactor))
        {
            glBlendFunc(sFactor, dFactor);
            blendSFactor = sFactor;
            blendDFactor = dFactor;
        }
    }

    public void setCullFace(int face)
    {
        if (face != cullFace)
        {
            cullFace = face;
            if ((face == GL_FRONT) || (face == GL_BACK) || (face == GL_FRONT_AND_BACK))
            {
                glEnable(GL_CULL_FACE);
                glCullFace(face);
            }
            else
                glDisable(GL_CULL_FACE);
        }
    }
}
