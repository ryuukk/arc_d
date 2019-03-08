module arc.pool;

import std.container;
import std.math;
import std.algorithm.comparison;

public interface IPoolable
{
    void reset();
}

public abstract class Pool(T)
{
    public int maxCapacity;
    public int peak;
    public Array!T freeObjects;

    public this(int initialSize = 16, int maxCapacity = 1024)
    {
        this.maxCapacity = maxCapacity;
        freeObjects.reserve(initialSize);
    }

    protected abstract T newObject();

    public T obtain()
    {
        if (freeObjects.length == 0)
            return newObject();

        return freeObjects.removeAny();
    }

    public void free(T object)
    {
        assert(object !is null, "object shouldn't be null");
        if (freeObjects.length < maxCapacity)
        {
            freeObjects.insert(object);
            peak = max(peak, cast(int) freeObjects.length);
        }
        reset(object);
    }

    protected void reset(T object)
    {
        if( is(T == IPoolable) )
            (cast(IPoolable) object).reset();
    }
}
