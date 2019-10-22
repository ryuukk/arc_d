module arc.collections.array;

import arc.math;
import std.algorithm.mutation : copy;

public class Array(T)
{
    private T[] _items;
    private int _count = 0;
    private int _version = 0;

    public T get(int index)
    {
        if ((index < 0) || (index >= _count))
            throw new Exception("out of bound");
        return _items[index];
    }

    public void set(int index, in T value)
    {
        if (index >= _count)
            throw new Exception();
        _items[index] = value;
        ++_version;
    }

    public ref T[] ensureCapacity(int newSize)
    {
        T[] newItems = new T[newSize];
        T[] items = this._items;

        int diff = newSize - items.length;

        //Array.Copy(items, 0, newItems, 0, Math.Min(_count, newItems.Length));

        copy(items[0 .. newItems], newItems[0 .. min(_count, newItems.length)]);

        if(diff > 0)
        {
            // todo: fill stuff with default values
        }

        this._items = newItems;
        return _items;
    }

    public void clear()
    {
        for (int i = 0; i < _items.length; i++)
        {
            _items[i] = null;
        }

        _count = 0;
        _version++;
    }

    public void add(T item)
    {
        auto length = _items.length;
        if (_count + 1 > length)
        {
            auto expand = (length < 1000) ? (length + 1) * 4 : 1000;
            ensureCapacity(length + expand);
        }

        _items[_count++] = item;
        _version++;
    }
}
