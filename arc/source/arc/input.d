module arc.input;

import std.stdio;
import std.conv;
import std.string;
import std.container;
import std.math;

import bindbc.opengl;
import bindbc.glfw;

import arc.core;
import arc.graphics;
import arc.time;

extern (C) void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) nothrow
{
    try
    {
        //writeln(format("EVENT: keyCallback(%s, %s, %s, %s)", key, scancode, action, mods));
        Core.input.onKeyCallback(key, scancode, action, mods);
    }
    catch (Exception e)
    {
    }
}

extern (C) void charCallback(GLFWwindow* window, uint codepoint) nothrow
{
    if ((codepoint & 0xff00) == 0xf700)
        return;

    try
    {
        //writeln(format("EVENT: charCallback(%s)", codepoint));
        Core.input.onCharCallback(codepoint);
    }
    catch (Exception e)
    {
    }
}

extern (C) void scrollCallback(GLFWwindow* window, double scrollX, double scrollY) nothrow
{
    try
    {
        //writeln(format("EVENT: scrollCallback(%s, %s)", scrollX, scrollY));
        Core.input.onScrollCallback(scrollX, scrollY);
    }
    catch (Exception e)
    {
    }
}

extern (C) void cursorPosCallback(GLFWwindow* window, double x, double y) nothrow
{
    try
    {
        //writeln(format("EVENT: cursorPosCallback(%s, %s)", x, y));
        Core.input.onCursorPosCallback(x, y);
    }
    catch (Exception e)
    {
    }
}

extern (C) void mouseButtonCallback(GLFWwindow* window, int button, int action, int mods) nothrow
{
    try
    {
        //writeln(format("EVENT: mouseButtonCallback(%s, %s, %s)", button, action, mods));
        Core.input.onMouseButtonCallback(button, action, mods);
    }
    catch (Exception e)
    {
    }
}

public class Input
{
    private GLFWwindow* _window;

    private IInputProcessor inputProcessor;
    private InputEventQueue eventQueue = new InputEventQueue();

    private int mouseX, mouseY;
    private int mousePressed;
    private int deltaX, deltaY;
    private bool justTouched;
    private int pressedKeys;
    private bool keyJustPressed;
    private bool[] justPressedKeys = new bool[256];
    private char lastCharacter;

    // scroll stuff
    private long pauseTime = 250000000L; //250ms
    private float scrollYRemainder;
    private long lastScrollEventTime;

    // cursor pos stuff
    private int logicalMouseY;
    private int logicalMouseX;

    void resetPollingStates()
    {
        justTouched = false;
        keyJustPressed = false;
        for (int i = 0; i < justPressedKeys.length; i++)
        {
            justPressedKeys[i] = false;
        }
        eventQueue.setProcessor(null);
        eventQueue.drain();
    }

    public void windowHandleChanged(GLFWwindow* window)
    {
        _window = window;
        resetPollingStates();
        glfwSetKeyCallback(_window, &keyCallback);
        glfwSetCharCallback(_window, &charCallback);
        glfwSetScrollCallback(_window, &scrollCallback);
        glfwSetCursorPosCallback(_window, &cursorPosCallback);
        glfwSetMouseButtonCallback(_window, &mouseButtonCallback);
    }

    void update()
    {
        eventQueue.setProcessor(inputProcessor);
        eventQueue.drain();
    }

    void prepareNext()
    {
        justTouched = false;

        if (keyJustPressed)
        {
            keyJustPressed = false;
            for (int i = 0; i < justPressedKeys.length; i++)
            {
                justPressedKeys[i] = false;
            }
        }
        deltaX = 0;
        deltaY = 0;
    }

    public void onKeyCallback(int key, int scancode, int action, int mods)
    {
        switch (action)
        {
        case GLFW_PRESS:
            int code = convertKeyCode(key);
            eventQueue.keyDown(code);
            pressedKeys++;
            keyJustPressed = true;
            justPressedKeys[code] = true;
            lastCharacter = 0;
            char character = characterForKeyCode(key);

            if (character != 0)
                onCharCallback(character);
            break;

        case GLFW_RELEASE:
            pressedKeys--;
            eventQueue.keyUp(convertKeyCode(key));
            break;

        case GLFW_REPEAT:
            if (lastCharacter != 0)
            {
                eventQueue.keyTyped(lastCharacter);
            }
            break;

        default:
            writeln(format("ERROR: Unhandled action: %s", action));
            break;
        }
    }

    public void onCharCallback(int codepoint)
    {
        lastCharacter = cast(char) codepoint;
        eventQueue.keyTyped(cast(char) codepoint);
    }

    public void onScrollCallback(double scrollX, double scrollY)
    {
        if (scrollYRemainder > 0 && scrollY < 0 || scrollYRemainder < 0
                && scrollY > 0 || nanoTime() - lastScrollEventTime > pauseTime)
        {
            // fire a scroll event immediately:
            //  - if the scroll direction changes; 
            //  - if the user did not move the wheel for more than 250ms
            scrollYRemainder = 0;
            int scrollAmount = cast(int)-sgn(scrollY);
            eventQueue.scrolled(scrollAmount);
            lastScrollEventTime = nanoTime();
        }
        else
        {
            scrollYRemainder += scrollY;
            while (abs(scrollYRemainder) >= 1)
            {
                int scrollAmount = cast(int)-sgn(scrollY);
                eventQueue.scrolled(scrollAmount);
                lastScrollEventTime = nanoTime();
                scrollYRemainder += scrollAmount;
            }
        }
    }

    public void onCursorPosCallback(double x, double y)
    {
        deltaX = cast(int) x - logicalMouseX;
        deltaY = cast(int) y - logicalMouseY;
        mouseX = logicalMouseX = cast(int) x;
        mouseY = logicalMouseY = cast(int) y;

        auto gfx = Core.graphics;

        if (gfx.getHdpiMode() == HdpiMode.Pixels)
        {
            float xScale = gfx.getBackBufferWidth() / cast(float) gfx.getLogicalWidth();
            float yScale = gfx.getBackBufferHeight() / cast(float) gfx.getLogicalHeight();
            deltaX = cast(int)(deltaX * xScale);
            deltaY = cast(int)(deltaY * yScale);
            mouseX = cast(int)(mouseX * xScale);
            mouseY = cast(int)(mouseY * yScale);
        }

        if (mousePressed > 0)
        {
            eventQueue.touchDragged(mouseX, mouseY, 0);
        }
        else
        {
            eventQueue.mouseMoved(mouseX, mouseY);
        }
    }

    public void onMouseButtonCallback(int button, int action, int mods)
    {
        int convertedBtn = convertButton(button);
        if (button != -1 && convertedBtn == -1)
            return;

        if (action == GLFW_PRESS)
        {
            mousePressed++;
            justTouched = true;
            eventQueue.touchDown(mouseX, mouseY, 0, convertedBtn);
        }
        else
        {
            mousePressed = cast(int) fmax(0, mousePressed - 1);
            eventQueue.touchUp(mouseX, mouseY, 0, convertedBtn);
        }
    }

    public float getX()
    {
        return mouseX;
    }

    public float getY()
    {
        return mouseY;
    }

    public float getDeltaX()
    {
        return deltaX;
    }

    public float getDeltaY()
    {
        return deltaY;
    }

    public void setInputProcessor(IInputProcessor processor)
    {
        this.inputProcessor = processor;
    }
}

public class Buttons
{
    public static immutable int LEFT = 0;
    public static immutable int RIGHT = 1;
    public static immutable int MIDDLE = 2;
    public static immutable int BACK = 3;
    public static immutable int FORWARD = 4;
}

public class Keys
{
    public static immutable int ANY_KEY = -1;
    public static immutable int NUM_0 = 7;
    public static immutable int NUM_1 = 8;
    public static immutable int NUM_2 = 9;
    public static immutable int NUM_3 = 10;
    public static immutable int NUM_4 = 11;
    public static immutable int NUM_5 = 12;
    public static immutable int NUM_6 = 13;
    public static immutable int NUM_7 = 14;
    public static immutable int NUM_8 = 15;
    public static immutable int NUM_9 = 16;
    public static immutable int A = 29;
    public static immutable int ALT_LEFT = 57;
    public static immutable int ALT_RIGHT = 58;
    public static immutable int APOSTROPHE = 75;
    public static immutable int AT = 77;
    public static immutable int B = 30;
    public static immutable int BACK = 4;
    public static immutable int BACKSLASH = 73;
    public static immutable int C = 31;
    public static immutable int CALL = 5;
    public static immutable int CAMERA = 27;
    public static immutable int CLEAR = 28;
    public static immutable int COMMA = 55;
    public static immutable int D = 32;
    public static immutable int DEL = 67;
    public static immutable int BACKSPACE = 67;
    public static immutable int FORWARD_DEL = 112;
    public static immutable int DPAD_CENTER = 23;
    public static immutable int DPAD_DOWN = 20;
    public static immutable int DPAD_LEFT = 21;
    public static immutable int DPAD_RIGHT = 22;
    public static immutable int DPAD_UP = 19;
    public static immutable int CENTER = 23;
    public static immutable int DOWN = 20;
    public static immutable int LEFT = 21;
    public static immutable int RIGHT = 22;
    public static immutable int UP = 19;
    public static immutable int E = 33;
    public static immutable int ENDCALL = 6;
    public static immutable int ENTER = 66;
    public static immutable int ENVELOPE = 65;
    public static immutable int EQUALS = 70;
    public static immutable int EXPLORER = 64;
    public static immutable int F = 34;
    public static immutable int FOCUS = 80;
    public static immutable int G = 35;
    public static immutable int GRAVE = 68;
    public static immutable int H = 36;
    public static immutable int HEADSETHOOK = 79;
    public static immutable int HOME = 3;
    public static immutable int I = 37;
    public static immutable int J = 38;
    public static immutable int K = 39;
    public static immutable int L = 40;
    public static immutable int LEFT_BRACKET = 71;
    public static immutable int M = 41;
    public static immutable int MEDIA_FAST_FORWARD = 90;
    public static immutable int MEDIA_NEXT = 87;
    public static immutable int MEDIA_PLAY_PAUSE = 85;
    public static immutable int MEDIA_PREVIOUS = 88;
    public static immutable int MEDIA_REWIND = 89;
    public static immutable int MEDIA_STOP = 86;
    public static immutable int MENU = 82;
    public static immutable int MINUS = 69;
    public static immutable int MUTE = 91;
    public static immutable int N = 42;
    public static immutable int NOTIFICATION = 83;
    public static immutable int NUM = 78;
    public static immutable int O = 43;
    public static immutable int P = 44;
    public static immutable int PERIOD = 56;
    public static immutable int PLUS = 81;
    public static immutable int POUND = 18;
    public static immutable int POWER = 26;
    public static immutable int Q = 45;
    public static immutable int R = 46;
    public static immutable int RIGHT_BRACKET = 72;
    public static immutable int S = 47;
    public static immutable int SEARCH = 84;
    public static immutable int SEMICOLON = 74;
    public static immutable int SHIFT_LEFT = 59;
    public static immutable int SHIFT_RIGHT = 60;
    public static immutable int SLASH = 76;
    public static immutable int SOFT_LEFT = 1;
    public static immutable int SOFT_RIGHT = 2;
    public static immutable int SPACE = 62;
    public static immutable int STAR = 17;
    public static immutable int SYM = 63;
    public static immutable int T = 48;
    public static immutable int TAB = 61;
    public static immutable int U = 49;
    public static immutable int UNKNOWN = 0;
    public static immutable int V = 50;
    public static immutable int VOLUME_DOWN = 25;
    public static immutable int VOLUME_UP = 24;
    public static immutable int W = 51;
    public static immutable int X = 52;
    public static immutable int Y = 53;
    public static immutable int Z = 54;
    public static immutable int META_ALT_LEFT_ON = 16;
    public static immutable int META_ALT_ON = 2;
    public static immutable int META_ALT_RIGHT_ON = 32;
    public static immutable int META_SHIFT_LEFT_ON = 64;
    public static immutable int META_SHIFT_ON = 1;
    public static immutable int META_SHIFT_RIGHT_ON = 128;
    public static immutable int META_SYM_ON = 4;
    public static immutable int CONTROL_LEFT = 129;
    public static immutable int CONTROL_RIGHT = 130;
    public static immutable int ESCAPE = 131;
    public static immutable int END = 132;
    public static immutable int INSERT = 133;
    public static immutable int PAGE_UP = 92;
    public static immutable int PAGE_DOWN = 93;
    public static immutable int PICTSYMBOLS = 94;
    public static immutable int SWITCH_CHARSET = 95;
    public static immutable int BUTTON_CIRCLE = 255;
    public static immutable int BUTTON_A = 96;
    public static immutable int BUTTON_B = 97;
    public static immutable int BUTTON_C = 98;
    public static immutable int BUTTON_X = 99;
    public static immutable int BUTTON_Y = 100;
    public static immutable int BUTTON_Z = 101;
    public static immutable int BUTTON_L1 = 102;
    public static immutable int BUTTON_R1 = 103;
    public static immutable int BUTTON_L2 = 104;
    public static immutable int BUTTON_R2 = 105;
    public static immutable int BUTTON_THUMBL = 106;
    public static immutable int BUTTON_THUMBR = 107;
    public static immutable int BUTTON_START = 108;
    public static immutable int BUTTON_SELECT = 109;
    public static immutable int BUTTON_MODE = 110;

    public static immutable int NUMPAD_0 = 144;
    public static immutable int NUMPAD_1 = 145;
    public static immutable int NUMPAD_2 = 146;
    public static immutable int NUMPAD_3 = 147;
    public static immutable int NUMPAD_4 = 148;
    public static immutable int NUMPAD_5 = 149;
    public static immutable int NUMPAD_6 = 150;
    public static immutable int NUMPAD_7 = 151;
    public static immutable int NUMPAD_8 = 152;
    public static immutable int NUMPAD_9 = 153;

    // public static int BACKTICK = 0;
    // public static int TILDE = 0;
    // public static int UNDERSCORE = 0;
    // public static int DOT = 0;
    // public static int BREAK = 0;
    // public static int PIPE = 0;
    // public static int EXCLAMATION = 0;
    // public static int QUESTIONMARK = 0;

    // ` | VK_BACKTICK
    // ~ | VK_TILDE
    // : | VK_COLON
    // _ | VK_UNDERSCORE
    // . | VK_DOT
    // (break) | VK_BREAK
    // | | VK_PIPE
    // ! | VK_EXCLAMATION
    // ? | VK_QUESTION
    public static immutable int COLON = 243;
    public static immutable int F1 = 244;
    public static immutable int F2 = 245;
    public static immutable int F3 = 246;
    public static immutable int F4 = 247;
    public static immutable int F5 = 248;
    public static immutable int F6 = 249;
    public static immutable int F7 = 250;
    public static immutable int F8 = 251;
    public static immutable int F9 = 252;
    public static immutable int F10 = 253;
    public static immutable int F11 = 254;
    public static immutable int F12 = 255;
}

char characterForKeyCode(int key)
{
    // Map certain key codes to character codes.
    switch (key)
    {
    case Keys.BACKSPACE:
        return 8;
    case Keys.TAB:
        return '\t';
    case Keys.FORWARD_DEL:
        return 127;
    case Keys.ENTER:
        return '\n';
    default:
        return 0;
    }
}

public int convertKeyCode(int lwjglKeyCode)
{
    switch (lwjglKeyCode)
    {
    case GLFW_KEY_SPACE:
        return Keys.SPACE;
    case GLFW_KEY_APOSTROPHE:
        return Keys.APOSTROPHE;
    case GLFW_KEY_COMMA:
        return Keys.COMMA;
    case GLFW_KEY_MINUS:
        return Keys.MINUS;
    case GLFW_KEY_PERIOD:
        return Keys.PERIOD;
    case GLFW_KEY_SLASH:
        return Keys.SLASH;
    case GLFW_KEY_0:
        return Keys.NUM_0;
    case GLFW_KEY_1:
        return Keys.NUM_1;
    case GLFW_KEY_2:
        return Keys.NUM_2;
    case GLFW_KEY_3:
        return Keys.NUM_3;
    case GLFW_KEY_4:
        return Keys.NUM_4;
    case GLFW_KEY_5:
        return Keys.NUM_5;
    case GLFW_KEY_6:
        return Keys.NUM_6;
    case GLFW_KEY_7:
        return Keys.NUM_7;
    case GLFW_KEY_8:
        return Keys.NUM_8;
    case GLFW_KEY_9:
        return Keys.NUM_9;
    case GLFW_KEY_SEMICOLON:
        return Keys.SEMICOLON;
    case GLFW_KEY_EQUAL:
        return Keys.EQUALS;
    case GLFW_KEY_A:
        return Keys.A;
    case GLFW_KEY_B:
        return Keys.B;
    case GLFW_KEY_C:
        return Keys.C;
    case GLFW_KEY_D:
        return Keys.D;
    case GLFW_KEY_E:
        return Keys.E;
    case GLFW_KEY_F:
        return Keys.F;
    case GLFW_KEY_G:
        return Keys.G;
    case GLFW_KEY_H:
        return Keys.H;
    case GLFW_KEY_I:
        return Keys.I;
    case GLFW_KEY_J:
        return Keys.J;
    case GLFW_KEY_K:
        return Keys.K;
    case GLFW_KEY_L:
        return Keys.L;
    case GLFW_KEY_M:
        return Keys.M;
    case GLFW_KEY_N:
        return Keys.N;
    case GLFW_KEY_O:
        return Keys.O;
    case GLFW_KEY_P:
        return Keys.P;
    case GLFW_KEY_Q:
        return Keys.Q;
    case GLFW_KEY_R:
        return Keys.R;
    case GLFW_KEY_S:
        return Keys.S;
    case GLFW_KEY_T:
        return Keys.T;
    case GLFW_KEY_U:
        return Keys.U;
    case GLFW_KEY_V:
        return Keys.V;
    case GLFW_KEY_W:
        return Keys.W;
    case GLFW_KEY_X:
        return Keys.X;
    case GLFW_KEY_Y:
        return Keys.Y;
    case GLFW_KEY_Z:
        return Keys.Z;
    case GLFW_KEY_LEFT_BRACKET:
        return Keys.LEFT_BRACKET;
    case GLFW_KEY_BACKSLASH:
        return Keys.BACKSLASH;
    case GLFW_KEY_RIGHT_BRACKET:
        return Keys.RIGHT_BRACKET;
    case GLFW_KEY_GRAVE_ACCENT:
        return Keys.GRAVE;
    case GLFW_KEY_WORLD_1:
    case GLFW_KEY_WORLD_2:
        return Keys.UNKNOWN;
    case GLFW_KEY_ESCAPE:
        return Keys.ESCAPE;
    case GLFW_KEY_ENTER:
        return Keys.ENTER;
    case GLFW_KEY_TAB:
        return Keys.TAB;
    case GLFW_KEY_BACKSPACE:
        return Keys.BACKSPACE;
    case GLFW_KEY_INSERT:
        return Keys.INSERT;
    case GLFW_KEY_DELETE:
        return Keys.FORWARD_DEL;
    case GLFW_KEY_RIGHT:
        return Keys.RIGHT;
    case GLFW_KEY_LEFT:
        return Keys.LEFT;
    case GLFW_KEY_DOWN:
        return Keys.DOWN;
    case GLFW_KEY_UP:
        return Keys.UP;
    case GLFW_KEY_PAGE_UP:
        return Keys.PAGE_UP;
    case GLFW_KEY_PAGE_DOWN:
        return Keys.PAGE_DOWN;
    case GLFW_KEY_HOME:
        return Keys.HOME;
    case GLFW_KEY_END:
        return Keys.END;
    case GLFW_KEY_CAPS_LOCK:
    case GLFW_KEY_SCROLL_LOCK:
    case GLFW_KEY_NUM_LOCK:
    case GLFW_KEY_PRINT_SCREEN:
    case GLFW_KEY_PAUSE:
        return Keys.UNKNOWN;
    case GLFW_KEY_F1:
        return Keys.F1;
    case GLFW_KEY_F2:
        return Keys.F2;
    case GLFW_KEY_F3:
        return Keys.F3;
    case GLFW_KEY_F4:
        return Keys.F4;
    case GLFW_KEY_F5:
        return Keys.F5;
    case GLFW_KEY_F6:
        return Keys.F6;
    case GLFW_KEY_F7:
        return Keys.F7;
    case GLFW_KEY_F8:
        return Keys.F8;
    case GLFW_KEY_F9:
        return Keys.F9;
    case GLFW_KEY_F10:
        return Keys.F10;
    case GLFW_KEY_F11:
        return Keys.F11;
    case GLFW_KEY_F12:
        return Keys.F12;
    case GLFW_KEY_F13:
    case GLFW_KEY_F14:
    case GLFW_KEY_F15:
    case GLFW_KEY_F16:
    case GLFW_KEY_F17:
    case GLFW_KEY_F18:
    case GLFW_KEY_F19:
    case GLFW_KEY_F20:
    case GLFW_KEY_F21:
    case GLFW_KEY_F22:
    case GLFW_KEY_F23:
    case GLFW_KEY_F24:
    case GLFW_KEY_F25:
        return Keys.UNKNOWN;
    case GLFW_KEY_KP_0:
        return Keys.NUMPAD_0;
    case GLFW_KEY_KP_1:
        return Keys.NUMPAD_1;
    case GLFW_KEY_KP_2:
        return Keys.NUMPAD_2;
    case GLFW_KEY_KP_3:
        return Keys.NUMPAD_3;
    case GLFW_KEY_KP_4:
        return Keys.NUMPAD_4;
    case GLFW_KEY_KP_5:
        return Keys.NUMPAD_5;
    case GLFW_KEY_KP_6:
        return Keys.NUMPAD_6;
    case GLFW_KEY_KP_7:
        return Keys.NUMPAD_7;
    case GLFW_KEY_KP_8:
        return Keys.NUMPAD_8;
    case GLFW_KEY_KP_9:
        return Keys.NUMPAD_9;
    case GLFW_KEY_KP_DECIMAL:
        return Keys.PERIOD;
    case GLFW_KEY_KP_DIVIDE:
        return Keys.SLASH;
    case GLFW_KEY_KP_MULTIPLY:
        return Keys.STAR;
    case GLFW_KEY_KP_SUBTRACT:
        return Keys.MINUS;
    case GLFW_KEY_KP_ADD:
        return Keys.PLUS;
    case GLFW_KEY_KP_ENTER:
        return Keys.ENTER;
    case GLFW_KEY_KP_EQUAL:
        return Keys.EQUALS;
    case GLFW_KEY_LEFT_SHIFT:
        return Keys.SHIFT_LEFT;
    case GLFW_KEY_LEFT_CONTROL:
        return Keys.CONTROL_LEFT;
    case GLFW_KEY_LEFT_ALT:
        return Keys.ALT_LEFT;
    case GLFW_KEY_LEFT_SUPER:
        return Keys.SYM;
    case GLFW_KEY_RIGHT_SHIFT:
        return Keys.SHIFT_RIGHT;
    case GLFW_KEY_RIGHT_CONTROL:
        return Keys.CONTROL_RIGHT;
    case GLFW_KEY_RIGHT_ALT:
        return Keys.ALT_RIGHT;
    case GLFW_KEY_RIGHT_SUPER:
        return Keys.SYM;
    case GLFW_KEY_MENU:
        return Keys.MENU;
    default:
        return Keys.UNKNOWN;
    }
}

public int convertButton(int button)
{
    if (button == 0)
        return Buttons.LEFT;
    if (button == 1)
        return Buttons.RIGHT;
    if (button == 2)
        return Buttons.MIDDLE;
    if (button == 3)
        return Buttons.BACK;
    if (button == 4)
        return Buttons.FORWARD;
    return -1;
}

public interface IInputProcessor
{
    bool keyDown(int keycode);

    bool keyUp(int keycode);

    bool keyTyped(char character);

    bool touchDown(int screenX, int screenY, int pointer, int button);

    bool touchUp(int screenX, int screenY, int pointer, int button);

    bool touchDragged(int screenX, int screenY, int pointer);

    bool mouseMoved(int screenX, int screenY);

    bool scrolled(int amount);
}

public class InputEventQueue : IInputProcessor
{
    static private immutable int SKIP = -1;
    static private immutable int KEY_DOWN = 0;
    static private immutable int KEY_UP = 1;
    static private immutable int KEY_TYPED = 2;
    static private immutable int TOUCH_DOWN = 3;
    static private immutable int TOUCH_UP = 4;
    static private immutable int TOUCH_DRAGGED = 5;
    static private immutable int MOUSE_MOVED = 6;
    static private immutable int SCROLLED = 7;

    private IInputProcessor processor;
    private int[] queue;
    private int[] processingQueue;
    private long currentEventTime;

    public this()
    {
    }

    public void setProcessor(IInputProcessor processor)
    {
        this.processor = processor;
    }

    public void drain()
    {
        if (processor is null)
        {
            queue = [];
            return;
        }

        processingQueue = queue;
        queue = [];

        for (int i = 0, n = cast(int) processingQueue.length; i < n;)
        {
            int type = processingQueue[i++];
            currentEventTime = cast(long) processingQueue[i++] << 32
                | processingQueue[i++] & 0xFFFFFFFFL;
            switch (type)
            {
            case SKIP:
                i += processingQueue[i];
                break;
            case KEY_DOWN:
                processor.keyDown(processingQueue[i++]);
                break;
            case KEY_UP:
                processor.keyUp(processingQueue[i++]);
                break;
            case KEY_TYPED:
                processor.keyTyped(cast(char) processingQueue[i++]);
                break;
            case TOUCH_DOWN:
                processor.touchDown(processingQueue[i++], processingQueue[i++],
                        processingQueue[i++], processingQueue[i++]);
                break;
            case TOUCH_UP:
                processor.touchUp(processingQueue[i++], processingQueue[i++],
                        processingQueue[i++], processingQueue[i++]);
                break;
            case TOUCH_DRAGGED:
                processor.touchDragged(processingQueue[i++],
                        processingQueue[i++], processingQueue[i++]);
                break;
            case MOUSE_MOVED:
                processor.mouseMoved(processingQueue[i++], processingQueue[i++]);
                break;
            case SCROLLED:
                processor.scrolled(processingQueue[i++]);
                break;
            default:
                throw new Exception("wut");
            }

        }
        processingQueue = [];
    }

    // todo: should be synchronized
    int next(int nextType, int i)
    {
        for (int n = cast(int) queue.length; i < n;)
        {
            int type = queue[i];
            if (type == nextType)
                return i;
            i += 3;
            switch (type)
            {
            case SKIP:
                i += queue[i];
                break;
            case KEY_DOWN:
                i++;
                break;
            case KEY_UP:
                i++;
                break;
            case KEY_TYPED:
                i++;
                break;
            case TOUCH_DOWN:
                i += 4;
                break;
            case TOUCH_UP:
                i += 4;
                break;
            case TOUCH_DRAGGED:
                i += 3;
                break;
            case MOUSE_MOVED:
                i += 2;
                break;
            case SCROLLED:
                i++;
                break;
            default:
                throw new Exception(format("Unknow input type: %s", type));
            }
        }
        return -1;
    }

    private void queueTime()
    {
        long time = nanoTime();

        queue ~= cast(int)(time >> 32);
        queue ~= cast(int) time;
    }

    public bool keyDown(int keycode)
    {
        queue ~= (KEY_DOWN);
        queueTime();
        queue ~= (keycode);
        return false;
    }

    public bool keyUp(int keycode)
    {
        queue ~= (KEY_UP);
        queueTime();
        queue ~= (keycode);
        return false;
    }

    public bool keyTyped(char character)
    {
        queue ~= (KEY_TYPED);
        queueTime();
        queue ~= (character);
        return false;
    }

    public bool touchDown(int screenX, int screenY, int pointer, int button)
    {
        queue ~= (TOUCH_DOWN);
        queueTime();
        queue ~= (screenX);
        queue ~= (screenY);
        queue ~= (pointer);
        queue ~= (button);
        return false;
    }

    public bool touchUp(int screenX, int screenY, int pointer, int button)
    {
        queue ~= (TOUCH_UP);
        queueTime();
        queue ~= (screenX);
        queue ~= (screenY);
        queue ~= (pointer);
        queue ~= (button);
        return false;
    }

    public bool touchDragged(int screenX, int screenY, int pointer)
    {
        // Skip any queued touch dragged events for the same pointer.
        for (int i = next(TOUCH_DRAGGED, 0); i >= 0; i = next(TOUCH_DRAGGED, i + 6))
        {
            if (queue[i + 5] == pointer)
            {
                queue[i] = SKIP;
                queue[i + 3] = 3;
            }
        }
        queue ~= (TOUCH_DRAGGED);
        queueTime();
        queue ~= (screenX);
        queue ~= (screenY);
        queue ~= (pointer);
        return false;
    }

    public bool mouseMoved(int screenX, int screenY)
    {
        // Skip any queued mouse moved events.
        for (int i = next(MOUSE_MOVED, 0); i >= 0; i = next(MOUSE_MOVED, i + 5))
        {
            queue[i] = SKIP;
            queue[i + 3] = 2;
        }
        queue ~= (MOUSE_MOVED);
        queueTime();
        queue ~= (screenX);
        queue ~= (screenY);
        return false;
    }

    public bool scrolled(int amount)
    {
        queue ~= (SCROLLED);
        queueTime();
        queue ~= (amount);
        return false;
    }

    public long getCurrentEventTime()
    {
        return currentEventTime;
    }
}

public class InputAdapter : IInputProcessor
{
    public bool keyDown(int keycode)
    {
        return false;
    }

    public bool keyUp(int keycode)
    {
        return false;
    }

    public bool keyTyped(char character)
    {
        return false;
    }

    public bool touchDown(int screenX, int screenY, int pointer, int button)
    {
        return false;
    }

    public bool touchUp(int screenX, int screenY, int pointer, int button)
    {
        return false;
    }

    public bool touchDragged(int screenX, int screenY, int pointer)
    {
        return false;
    }

    public bool mouseMoved(int screenX, int screenY)
    {
        return false;
    }

    public bool scrolled(int amount)
    {
        return false;
    }
}
