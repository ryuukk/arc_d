module arc.log;

import std.stdio;
import std.conv;
import std.string;

immutable int NONE = 1 << 0;
immutable int DEBUG = 1 << 1;
immutable int INFO = 1 << 2;
immutable int WARN = 1 << 3;
immutable int ERROR = 1 << 4;

immutable int MINIMUM = INFO | WARN;
immutable int ALL = DEBUG | INFO | WARN | ERROR;

int flag = MINIMUM;

void info(string tag, string msg)
{
    if((flag & INFO) != 0)
        writeln(format("[INFO] (%s) %s", tag, msg));
}
void warn(string tag, string msg)
{
    if((flag & WARN) != 0)
        writeln(format("[WARN] (%s) %s", tag, msg));
}
void error(string tag, string msg)
{
    if((flag & ERROR) != 0)
        writeln(format("[ERROR] (%s) %s", tag, msg));
}