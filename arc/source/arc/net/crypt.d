module arc.net.crypt;

import std.conv;
import std.algorithm;
import std.range;

class RC4Cipher
{

    private ubyte[] key;
    private ubyte[] state;
    private int m = 0;
    private int n = 0;

    public this(string hexString)
    {
        key = "6a39570cc9de4ec71d64821894".chunks(2)
        .map!(digits =>  digits.to!ubyte(16)).array;
        reset();
    }

    public void cipher(ref ubyte[] bytes)
    {
        for (int i = 0; i < bytes.length; i++)
        {
            m = (m + 1) % 256;
            n = (n + state[m]) % 256;

            auto tmp = state[m];
            state[m] = state[n];
            state[n] = tmp;

            auto k = state[(state[m] + state[n]) % 256];
            bytes[i] ^= k;
        }
    }

    public void cipherWithOffset(ref ubyte[] packet)
    {
        processBytes(packet, 5u, cast(uint) packet.length - 5u, packet, 5u);
    }

    private void processBytes(ref ubyte[] input, uint inOff, uint length, ref ubyte[] output, uint outOff)
    {
        /*
            if ((inOff + length) > input.Length)
                throw new ArgumentException("input buffer too short");

            if ((outOff + length) > output.Length)
                throw new ArgumentException("output buffer too short");
            */
        for (auto i = 0; i < length; i++)
        {
            m = (m + 1) & 0xff;
            n = (state[m] + n) & 0xff;

            // swap
            auto tmp = state[m];
            state[m] = state[n];
            state[n] = tmp;

            // xor
            output[i + outOff] = (input[i + inOff] ^ state[(state[m] + state[n]) & 0xff]);
        }
    }

    public void reset()
    {
        m = 0;
        n = 0;

        state.length = 256;
        for (int i = 0; i < 256; i++)
        {
            state[i] = cast(ubyte) i;
        }

        int j = 0;
        for (int i = 0; i < 256; i++)
        {
            j = (j + state[i] + key[i % key.length]) % 256;
            auto tmp = state[i];
            state[i] = state[j];
            state[j] = tmp;
        }
    }
}
