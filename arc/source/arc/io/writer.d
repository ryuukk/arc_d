module arc.io.writer;

import std.stdio;
import std.bitmanip;
import std.file;

struct BinaryWriter
{
	ubyte[] _data;
	uint _index;

    void reset()
    {
        _data.length = 0;
        _index = 0;
    }

	void writeByte(ubyte data)
	 {
		_data ~= data;
	}

	void writeBytes(in ubyte[] data)
	{
		_data ~= data;
	}

	void writeInt(int data)
	 {
		ubyte[4] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeUInt(uint data)
	 {
		ubyte[4] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeShort(short data)
	 {
		ubyte[2] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeUShort(ushort data)
	 {
		ubyte[2] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeDouble(double data)
	{
		ubyte[8] value = nativeToBigEndian(data);
		writeBytes(value);
	}

	void writeUTF(in char[] data)
	{
		ushort size = cast(ushort)data.length;
		ubyte[] string = cast(ubyte[])data;
		writeUShort(size);
		writeBytes(string);
	}

	void writeUTFBytes(in char[] data)
	 {
		ubyte[] str = cast(ubyte[])data;
		writeBytes(str);
	}

	void writeBool(bool data)
	{
		if(data) writeByte(1);
		if(!data) writeByte(0);
	}

	ubyte[] getData()
	{
		return _data;
	}
}