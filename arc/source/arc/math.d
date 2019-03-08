module arc.math;

import std.math;
import std.range;
import std.format;
import std.conv;
import std.string;

public const float FLOAT_ROUNDING_ERROR = 0.000001f;
public const float PI = 3.1415927f;
public const float PI2 = PI * 2;
public const float DEG2RAD = PI / 180.0f;
public const float RAD2DEG = 180.0f / PI;

public struct Vec2
{
    public float x;
    public float y;

    public this(float x, float y)
    {
        this.x = x;
        this.y = y;
    }
}

public struct Vec3
{
    public float x = 0f;
    public float y = 0f;
    public float z = 0f;

    
    public static @property Vec3 X() { return Vec3(1, 0, 0); }
    public static @property Vec3 Y() { return Vec3(0, 1, 0); }
    public static @property Vec3 Z() { return Vec3(0, 0, 1); }
    public static @property Vec3 ZERO() { return Vec3(0, 0, 0); }

    public this(float x, float y, float z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public float len2()
    {
        return x * x + y * y + z * z;
    }

    public Vec3 nor()
    {
        float len2 = len2();
        if (len2 == 0f || len2 == 1f)
            return Vec3(x, y, z);

        float scalar = 1f / sqrt(len2);

        return Vec3(x * scalar, y * scalar, z * scalar);
    }

    public float dot(Vec3 vector)
    {
        return x * vector.x + y * vector.y + z * vector.z;
    }

    public Vec3 crs(Vec3 vector)
    {
        return Vec3(y * vector.z - z * vector.y, z * vector.x - x * vector.z, x * vector.y - y * vector.x);
    }

    public Vec3 rotate(in Vec3 axis, float degrees)
    {
        // todo: finish
        return Vec3();
    }

    public Vec3 mul(in Mat4 m)
    {
        return Vec3(x * m.val[Mat4.M00] + y * m.val[Mat4.M01] + z * m.val[Mat4.M02] + m.val[Mat4.M03], x
			* m.val[Mat4.M10] + y * m.val[Mat4.M11] + z * m.val[Mat4.M12] + m.val[Mat4.M13], x * m.val[Mat4.M20] + y
			* m.val[Mat4.M21] + z * m.val[Mat4.M22] + m.val[Mat4.M23]);
    }

    public bool isZero()
    {
        return x == 0 && y == 0 && z == 0;
    }

    Vec3 opUnary(string s)() if (s == "-")
    {
        return Vec3(-x, -y, -z);
    }

    Vec3 opBinary(string op)(Vec3 other)
    {
        static if (op == "+")
            return Vec3(x + other.x, y + other.y, z + other.z);
        else static if (op == "-")
            return Vec3(x - other.x, y - other.y, z - other.z);
        else static if (op == "*")
            return Vec3(x * other.x, y * other.y, z * other.z);
        else static if (op == "/")
            return Vec3(x / other.x, y / other.y, z / other.z);
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    Vec3 opBinary(string op)(float other)
    {
        static if (op == "+")
            return Vec3(x + other, y + other, z + other);
        else static if (op == "-")
            return Vec3(x - other, y - other, z - other);
        else static if (op == "*")
            return Vec3(x * other, y * other, z * other);
        else static if (op == "/")
            return Vec3(x / other, y / other, z / other);
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    public static float len(float x, float y, float z)
    {
        return sqrt(x * x + y * y + z * z);
    }
}

public struct Vec4
{
    private float[4] data;
    public @property float x() {return data[0];}
    public @property float y() {return data[1];}
    public @property float z() {return data[2];}
    public @property float w() {return data[3];}
    
    public @property float x(float value) {return data[0] = value;}
    public @property float y(float value) {return data[1] = value;}
    public @property float z(float value) {return data[2] = value;}
    public @property float w(float value) {return data[3] = value;}
    alias data this;

    public this(float x, float y, float z, float w)
    {
        data[0] = x;
        data[1] = y;
        data[2] = z;
        data[3] = w;
    }
}

/*
OPENGL is COLUMN MAJOR !!!!
| 0 2 |    | 0 3 6 |    |  0  4  8 12 |
| 1 3 |    | 1 4 7 |    |  1  5  9 13 |
           | 2 5 8 |    |  2  6 10 14 |
                        |  3  7 11 15 |

*/

public struct Mat4
{
    public static immutable int M00 = 0;
    public static immutable int M01 = 4;
    public static immutable int M02 = 8;
    public static immutable int M03 = 12;
    public static immutable int M10 = 1;
    public static immutable int M11 = 5;
    public static immutable int M12 = 9;
    public static immutable int M13 = 13;
    public static immutable int M20 = 2;
    public static immutable int M21 = 6;
    public static immutable int M22 = 10;
    public static immutable int M23 = 14;
    public static immutable int M30 = 3;
    public static immutable int M31 = 7;
    public static immutable int M32 = 11;
    public static immutable int M33 = 15;
    public float[16] val;

    public this(float m00, float m01, float m02, float m03, float m04, float m05, float m06, float m07, float m08, float m09,
            float m10, float m11, float m12, float m13, float m14, float m15)
    {
       val[0] = m00; val[1] = m01;  val[2] = m02;  val[3] = m03;
       val[4] = m04; val[5] = m05;  val[6] = m06;  val[7] = m07;
       val[8] = m08; val[9] = m09;  val[10]= m10;  val[11]= m11;
       val[12]= m12; val[13]= m13;  val[14]= m14;  val[15]= m15;
    }

    public static Mat4 identity()
    {
        auto ret = Mat4();
        ret.val[M00] = 1f;
        ret.val[M01] = 0f;
        ret.val[M02] = 0f;
        ret.val[M03] = 0f;
        ret.val[M10] = 0f;
        ret.val[M11] = 1f;
        ret.val[M12] = 0f;
        ret.val[M13] = 0f;
        ret.val[M20] = 0f;
        ret.val[M21] = 0f;
        ret.val[M22] = 1f;
        ret.val[M23] = 0f;
        ret.val[M30] = 0f;
        ret.val[M31] = 0f;
        ret.val[M32] = 0f;
        ret.val[M33] = 1f;
        return ret;
    }

    public Mat4 idt()
    {
        val[M00] = 1f;
        val[M01] = 0f;
        val[M02] = 0f;
        val[M03] = 0f;
        val[M10] = 0f;
        val[M11] = 1f;
        val[M12] = 0f;
        val[M13] = 0f;
        val[M20] = 0f;
        val[M21] = 0f;
        val[M22] = 1f;
        val[M23] = 0f;
        val[M30] = 0f;
        val[M31] = 0f;
        val[M32] = 0f;
        val[M33] = 1f;
        return this;
    }

    public float det3x3() 
    {
		return val[M00] * val[M11] * val[M22] + val[M01] * val[M12] * val[M20] + val[M02] * val[M10] * val[M21] - val[M00]
			* val[M12] * val[M21] - val[M01] * val[M10] * val[M22] - val[M02] * val[M11] * val[M20];
	}

    public void rotate(float angle, float x, float y, float z)
    {
        import  std.algorithm.comparison: clamp;
        
        float c = cos(angle * DEG2RAD); // cosine
        float s = sin(angle * DEG2RAD); // sine
        float c1 = 1.0f - c; // 1 - c
        float m0 = val[0], m4 = val[4], m8 = val[8], m12 = val[12], m1 = val[1], m5 = val[5], m9 = val[9], m13 = val[13], m2 = val[
        2], m6 = val[6], m10 = val[10], m14 = val[14];

        // build rotation matrix
        float r0 =  clamp( x * x * c1 + c    , -1, 1);
        float r1 =  clamp( x * y * c1 + z * s, -1, 1);
        float r2 =  clamp( x * z * c1 - y * s, -1, 1);
        float r4 =  clamp( x * y * c1 - z * s, -1, 1);
        float r5 =  clamp( y * y * c1 + c    , -1, 1);
        float r6 =  clamp( y * z * c1 + x * s, -1, 1);
        float r8 =  clamp( x * z * c1 + y * s, -1, 1);
        float r9 =  clamp( y * z * c1 - x * s, -1, 1);
        float r10 = clamp( z * z * c1 + c    , -1, 1);

        // multiply rotation matrix

        val[0] =   (r0 * m0 + r4 * m1 + r8 *  m2   );
        val[1] =   (r1 * m0 + r5 * m1 + r9 *  m2   );
        val[2] =   (r2 * m0 + r6 * m1 + r10 * m2   );
        val[4] =   (r0 * m4 + r4 * m5 + r8 *  m6   );
        val[5] =   (r1 * m4 + r5 * m5 + r9 *  m6   );
        val[6] =   (r2 * m4 + r6 * m5 + r10 * m6   );
        val[8] =   (r0 * m8 + r4 * m9 + r8 *  m10  );
        val[9] =   (r1 * m8 + r5 * m9 + r9 *  m10  );
        val[10] =  (r2 * m8 + r6 * m9 + r10 * m10  );
        val[12] =  (r0 * m12 + r4 * m13 + r8 * m14 );
        val[13] =  (r1 * m12 + r5 * m13 + r9 * m14 );
        val[14] =  (r2 * m12 + r6 * m13 + r10 * m14);

    }

    public void set(float translationX, float translationY, float translationZ, float quaternionX, float quaternionY, float quaternionZ,
            float quaternionW)
    {
        float xs = quaternionX * 2f, ys = quaternionY * 2f, zs = quaternionZ * 2f;
        float wx = quaternionW * xs, wy = quaternionW * ys, wz = quaternionW * zs;
        float xx = quaternionX * xs, xy = quaternionX * ys, xz = quaternionX * zs;
        float yy = quaternionY * ys, yz = quaternionY * zs, zz = quaternionZ * zs;

        val[M00] = (1.0f - (yy + zz));
        val[M01] = (xy - wz);
        val[M02] = (xz + wy);
        val[M03] = translationX;

        val[M10] = (xy + wz);
        val[M11] = (1.0f - (xx + zz));
        val[M12] = (yz - wx);
        val[M13] = translationY;

        val[M20] = (xz - wy);
        val[M21] = (yz + wx);
        val[M22] = (1.0f - (xx + yy));
        val[M23] = translationZ;

        val[M30] = 0.0f;
        val[M31] = 0.0f;
        val[M32] = 0.0f;
        val[M33] = 1.0f;
    }

    public void set(Vec3 translation, Quat quat)
    {
        float xs = quat.x * 2f, ys = quat.y * 2f, zs = quat.z * 2f;
        float wx = quat.w * xs, wy = quat.w * ys, wz = quat.w * zs;
        float xx = quat.x * xs, xy = quat.x * ys, xz = quat.x * zs;
        float yy = quat.y * ys, yz = quat.y * zs, zz = quat.z * zs;

        val[M00] = (1.0f - (yy + zz));
        val[M01] = (xy - wz);
        val[M02] = (xz + wy);
        val[M03] = translation.x;

        val[M10] = (xy + wz);
        val[M11] = (1.0f - (xx + zz));
        val[M12] = (yz - wx);
        val[M13] = translation.y;

        val[M20] = (xz - wy);
        val[M21] = (yz + wx);
        val[M22] = (1.0f - (xx + yy));
        val[M23] = translation.z;

        val[M30] = 0.0f;
        val[M31] = 0.0f;
        val[M32] = 0.0f;
        val[M33] = 1.0f;
    }

    public void set(float translationX, float translationY, float translationZ, float quaternionX, float quaternionY, float quaternionZ,
            float quaternionW, float scaleX, float scaleY, float scaleZ)
    {
        float xs = quaternionX * 2f, ys = quaternionY * 2f, zs = quaternionZ * 2f;
        float wx = quaternionW * xs, wy = quaternionW * ys, wz = quaternionW * zs;
        float xx = quaternionX * xs, xy = quaternionX * ys, xz = quaternionX * zs;
        float yy = quaternionY * ys, yz = quaternionY * zs, zz = quaternionZ * zs;

        val[M00] = scaleX * (1.0f - (yy + zz));
        val[M01] = scaleY * (xy - wz);
        val[M02] = scaleZ * (xz + wy);
        val[M03] = translationX;

        val[M10] = scaleX * (xy + wz);
        val[M11] = scaleY * (1.0f - (xx + zz));
        val[M12] = scaleZ * (yz - wx);
        val[M13] = translationY;

        val[M20] = scaleX * (xz - wy);
        val[M21] = scaleY * (yz + wx);
        val[M22] = scaleZ * (1.0f - (xx + yy));
        val[M23] = translationZ;

        val[M30] = 0.0f;
        val[M31] = 0.0f;
        val[M32] = 0.0f;
        val[M33] = 1.0f;
    }

    public static Mat4 createOrthographicOffCenter(float x, float y, float width, float height)
    {
        return createOrthographic(x, x + width, y, y + height, 0, 1);
    }

    public static Mat4 createOrthographic(float left, float right, float bottom, float top, float near = 0f, float far = 1f)
    {
        auto ret = Mat4.identity();

        float x_orth = 2 / (right - left);
        float y_orth = 2 / (top - bottom);
        float z_orth = -2 / (far - near);

        float tx = -(right + left) / (right - left);
        float ty = -(top + bottom) / (top - bottom);
        float tz = -(far + near) / (far - near);

        ret.val[M00] = x_orth;
        ret.val[M10] = 0;
        ret.val[M20] = 0;
        ret.val[M30] = 0;
        ret.val[M01] = 0;
        ret.val[M11] = y_orth;
        ret.val[M21] = 0;
        ret.val[M31] = 0;
        ret.val[M02] = 0;
        ret.val[M12] = 0;
        ret.val[M22] = z_orth;
        ret.val[M32] = 0;
        ret.val[M03] = tx;
        ret.val[M13] = ty;
        ret.val[M23] = tz;
        ret.val[M33] = 1;

        return ret;
    }

    public static Mat4 createLookAt(Vec3 position, Vec3 target, Vec3 up)
    {

        auto tmp = target - position;

        auto ret = createLookAt(tmp, up) * createTranslation(-position.x, -position.y, -position.z);


        return ret;
    }

    public static Mat4 createTranslation(float x, float y, float z)
    {
        auto ret = Mat4.identity();
		ret.val[M03] = x;
		ret.val[M13] = y;
		ret.val[M23] = z;
        return ret;
    }

    public static Mat4 createRotation(Vec3 axis, float degrees)
    {
        if(degrees == 0)
            return Mat4.identity();

        // todo: finish
        return Mat4();
    }

    
    public static Mat4 createScale(float x, float y, float z)
    {
        auto ret = Mat4.identity;
		ret.val[M00] = x;
		ret.val[M11] = y;
		ret.val[M22] = z;
        return ret;
    }

    

    public static Mat4 createProjection(float near, float far, float fovy, float aspectRatio)
    {
        auto ret = Mat4.identity();
		float l_fd = cast(float)(1.0 / tan((fovy * (PI / 180)) / 2.0));
		float l_a1 = (far + near) / (near - far);
		float l_a2 = (2 * far * near) / (near - far);
		ret.val[M00] = l_fd / aspectRatio;
		ret.val[M10] = 0;
		ret.val[M20] = 0;
		ret.val[M30] = 0;
		ret.val[M01] = 0;
		ret.val[M11] = l_fd;
		ret.val[M21] = 0;
		ret.val[M31] = 0;
		ret.val[M02] = 0;
		ret.val[M12] = 0;
		ret.val[M22] = l_a1;
		ret.val[M32] = -1;
		ret.val[M03] = 0;
		ret.val[M13] = 0;
		ret.val[M23] = l_a2;
		ret.val[M33] = 0;
        return ret;
    }

    public static Mat4 createLookAt(Vec3 direction, Vec3 up)
    {
        auto l_vez = direction.nor();
        auto l_vex = direction.nor();

        l_vex = l_vex.crs(up).nor();
        auto l_vey = l_vex.crs(l_vez).nor();

        auto ret = Mat4.identity();
        ret.val[M00] = l_vex.x;
        ret.val[M01] = l_vex.y;
        ret.val[M02] = l_vex.z;
        ret.val[M10] = l_vey.x;
        ret.val[M11] = l_vey.y;
        ret.val[M12] = l_vey.z;
        ret.val[M20] = -l_vez.x;
        ret.val[M21] = -l_vez.y;
        ret.val[M22] = -l_vez.z;

        return ret;
    }

    Mat4 opBinary(string op)(Mat4 n)
    {
        static if (op == "+")
            return Mat4();
        else static if (op == "-")
            return Mat4();
        else static if (op == "*")
            return Mat4(val[0]*n.val[0]  + val[4]*n.val[1]  + val[8]*n.val[2]  + val[12]*n.val[3],   val[1]*n.val[0]  + val[5]*n.val[1]  + val[9]*n.val[2]  + val[13]*n.val[3],   val[2]*n.val[0]  + val[6]*n.val[1]  + val[10]*n.val[2]  + val[14]*n.val[3],   val[3]*n.val[0]  + val[7]*n.val[1]  + val[11]*n.val[2]  + val[15]*n.val[3],
                           val[0]*n.val[4]  + val[4]*n.val[5]  + val[8]*n.val[6]  + val[12]*n.val[7],   val[1]*n.val[4]  + val[5]*n.val[5]  + val[9]*n.val[6]  + val[13]*n.val[7],   val[2]*n.val[4]  + val[6]*n.val[5]  + val[10]*n.val[6]  + val[14]*n.val[7],   val[3]*n.val[4]  + val[7]*n.val[5]  + val[11]*n.val[6]  + val[15]*n.val[7],
                           val[0]*n.val[8]  + val[4]*n.val[9]  + val[8]*n.val[10] + val[12]*n.val[11],  val[1]*n.val[8]  + val[5]*n.val[9]  + val[9]*n.val[10] + val[13]*n.val[11],  val[2]*n.val[8]  + val[6]*n.val[9]  + val[10]*n.val[10] + val[14]*n.val[11],  val[3]*n.val[8]  + val[7]*n.val[9]  + val[11]*n.val[10] + val[15]*n.val[11],
                           val[0]*n.val[12] + val[4]*n.val[13] + val[8]*n.val[14] + val[12]*n.val[15],  val[1]*n.val[12] + val[5]*n.val[13] + val[9]*n.val[14] + val[13]*n.val[15],  val[2]*n.val[12] + val[6]*n.val[13] + val[10]*n.val[14] + val[14]*n.val[15],  val[3]*n.val[12] + val[7]*n.val[13] + val[11]*n.val[14] + val[15]*n.val[15]);

        else static if (op == "/")
            return Mat4();
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }
}

public struct Quat
{
    public float x;
    public float y;
    public float z;
    public float w;

    public this(float x, float y, float z, float w)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

	public float len2 () 
    {
		return x * x + y * y + z * z + w * w;
	}

    public ref Quat nor()
    {
		float len = len2();
		if (len != 0.0f && !isEqual(len, 1f))
        {
			len = sqrt(len);
			w /= len;
			x /= len;
			y /= len;
			z /= len;
		}
        return this;
    }
    
    public static @property Quat identity() { return Quat(0,0,0,1); }

    public static Quat fromAxis(float x, float y, float z, float rad)
    {
		float d = Vec3.len(x, y, z);
		if (d == 0f) return Quat.identity;
		d = 1f / d;
		float l_ang = rad < 0 ? PI2 - (-rad % PI2) : rad % PI2;
		float l_sin = sin(l_ang / 2);
		float l_cos = cos(l_ang / 2);

        return Quat(d * x * l_sin, d * y * l_sin, d * z * l_sin, l_cos).nor();
    }

    public static Quat fromAxis(in Vec3 axis, float rad)
    {
        return fromAxis(axis.x, axis.y, axis.z, rad);
    }
}


public struct BoundingBox
{
    public Vec3 min;
    public Vec3 max;
    public Vec3 cnt;
    public Vec3 dim;
}

bool isEqual(float a, float b)
{
    return abs(a - b) <= FLOAT_ROUNDING_ERROR;
}