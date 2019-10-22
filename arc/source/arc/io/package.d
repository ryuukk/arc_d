module arc.io;

public import arc.io.reader;
public import arc.io.writer;

import std.stdio;
import std.bitmanip;
import std.file;

public ubyte[] readFile(string path)
{
    auto data = cast(ubyte[]) std.file.read(path);
    return data;
}

public bool isFileExist(string path)
{
    return exists(path);
}