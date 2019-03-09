module arc.engine;

import std.experimental.logger;

import bindbc.opengl;
import bindbc.glfw;

import arc.core;
import arc.graphics;
import arc.audio;
import arc.input;

public class Configuration
{
	public int glMinVersion = 3;
	public int glMajVersion = 3;

	public int windowWidth = 1280;
	public int windowHeight = 720;

	public int windowX = -1;
	public int windowY = -1;

	public string windowTitle = "";

	public bool vsync = true;
}

public class Engine
{
	private Graphics _graphics;
	private Audio _audio;
	private Input _input;
	private IApp _app;
	private Logger _logger;
	private Configuration _config;
	private bool _running = true;
	
	public this(IApp app, Configuration config)
	{
		_app = app;
		_config = config;
	}

	public void run()
	{
		_graphics = new Graphics(_app, _config);
		_audio = new Audio;
		_input = new Input;
		_logger = new FileLogger("log.txt");
        
		Core.graphics = _graphics;
		Core.audio = _audio;
		Core.input = _input;
		Core.logger = _logger;


		_graphics.createContext();
        _input.windowHandleChanged(_graphics.windowHandle());

		while(_running)
		{
			// runables

			if(!_graphics.isIconified())
				_input.update();

			_graphics.update();


			if(!_graphics.isIconified())
				_input.prepareNext();

			_running = !_graphics.shouldClose();
			
			glfwPollEvents();
		}

		glfwTerminate();
		
		_app.dispose();
	}

	public void exit()
	{
		_running = false;
	}
}
