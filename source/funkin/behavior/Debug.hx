/*
 * Apache License, Version 2.0
 *
 * Copyright (c) 2021 MasterEric
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Debug.hx
 * This class contains lots of utility functions for logging and debugging.
 * The goal is to integrate development more heavily with the HaxeFlixel debugger.
 * Use these methods to the fullest to produce mods efficiently!
 * 
 * @see https://haxeflixel.com/documentation/debugger/
 */
package funkin.behavior;

import funkin.util.concurrency.TaskWorker;
import funkin.util.SystemSpecUtil;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.debug.log.LogStyle;
import flixel.system.debug.watch.Tracker.TrackerProfile;
import flixel.util.FlxStringUtil;
import funkin.behavior.play.Song;
import funkin.behavior.data.SongData;
import funkin.const.Enigma;
import funkin.ui.component.play.character.OldCharacter;
import funkin.ui.component.play.HealthIcon;
import funkin.ui.component.play.Note;
import funkin.ui.state.menu.FreeplayState;
import funkin.ui.state.play.PlayState;
import funkin.util.Util;
import haxe.CallStack;
import haxe.Log;
import haxe.PosInfos;
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import polymod.Polymod.PolymodError;

using hx.strings.Strings;

class Debug
{
	static final LOG_STYLE_ERROR:LogStyle = new LogStyle('[ERROR] ', 'FF8888', 12, true, false, false, 'flixel/sounds/beep', true);
	static final LOG_STYLE_WARN:LogStyle = new LogStyle('[WARN ] ', 'D9F85C', 12, true, false, false, 'flixel/sounds/beep', true);
	static final LOG_STYLE_INFO:LogStyle = new LogStyle('[INFO ] ', '5CF878', 12, false);
	static final LOG_STYLE_TRACE:LogStyle = new LogStyle('[TRACE] ', '5CF878', 12, false);

	static var logFileWriter:DebugLogWriter = null;

	/**
	 * Log an error message to the game's console.
	 * Plays a beep to the user and forces the console open if this is a debug build.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logError(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		if (input == null)
			return;
		var output = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_ERROR);
		writeToLogFile(output, 'ERROR');
	}

	/**
	 * Log an warning message to the game's console.
	 * Plays a beep to the user and forces the console open if this is a debug build.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logWarn(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		if (input == null)
			return;
		var output = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_WARN);
		writeToLogFile(output, 'WARN');
	}

	/**
	 * Log an info message to the game's console. Only visible in debug builds.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logInfo(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		if (input == null)
			return;
		var output = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_INFO);
		writeToLogFile(output, 'INFO');
	}

	/**
	 * Log a debug message to the game's console. Only visible in debug builds.
	 * NOTE: We redirect all Haxe `trace()` calls to this function.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 * @see Does NOTHING in release builds. https://twitter.com/KadeDeveloper/status/1454900040212770824
	 */
	public static function logTrace(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		#if debug
		if (input == null)
			return;
		var output = formatOutput(input, pos);
		// Don't display trace()
		// writeToFlxGLog(output, LOG_STYLE_TRACE);
		writeToLogFile(output, 'TRACE');
		#end
	}

	/**
	 * Displays a popup with the provided text.
	 * This interrupts the game, so make sure it's REALLY important.
	 * @param title The title of the popup.
	 * @param description The description of the popup.
	 */
	public static function displayAlert(title:String, description:String):Void
	{
		Application.current.window.alert(description, title);
	}

	/**
	 * Display the value of a particular field of a given object
	 * in the Debug watch window, labelled with the specified name.
	 		* Updates continuously.
	 * @param object The object to watch.
	 * @param field The string name of a field of the above object.
	 * @param name
	 */
	public static inline function watchVariable(object:Dynamic, field:String, name:String):Void
	{
		#if debug
		if (object == null)
		{
			Debug.logError("Tried to watch a variable on a null object!");
			return;
		}
		FlxG.watch.add(object, field, name == null ? field : name);
		#end
		// Else, do nothing outside of debug mode.
	}

	/**
	 * Adds the specified value to the Debug Watch window under the current name.
	 * A lightweight alternative to watchVariable, since it doesn't update until you call it again.
	 * 
	 * @param value 
	 * @param name 
	 */
	public static inline function quickWatch(value:Dynamic, name:String)
	{
		#if debug
		FlxG.watch.addQuick(name == null ? "QuickWatch" : name, value);
		#end
		// Else, do nothing outside of debug mode.
	}

	/**
	 * The Console window already supports most hScript, meaning you can do most things you could already do in Haxe.
	 		* However, you can also add custom commands using this function.
	 */
	public static inline function addConsoleCommand(name:String, callbackFn:Dynamic)
	{
		FlxG.console.registerFunction(name, callbackFn);
	}

	/**
	 * Add an object with a custom alias so that it can be accessed via the console.
	 */
	public static inline function addObject(name:String, object:Dynamic)
	{
		FlxG.console.registerObject(name, object);
	}

	/**
	 * Create a tracker window for an object.
	 * This will display the properties of that object in
	 * a fancy little Debug window you can minimize and drag around.
	 * 
	 * @param obj The object to display.
	 */
	public static inline function trackObject(obj:Dynamic)
	{
		if (obj == null)
		{
			Debug.logError("Tried to track a null object!");
			return;
		}
		FlxG.debugger.track(obj);
	}

	/**
	 * The game runs this function immediately when it starts.
	 		* Use onGameStart() if it can wait until a little later.
	 */
	public static function onInitProgram()
	{
		// Initialize logging tools.
		trace('Initializing Debug tools...');

		// Override Haxe's vanilla trace() calls to use the Flixel console.
		Log.trace = function(data:Dynamic, ?info:PosInfos)
		{
			var paramArray:Array<Dynamic> = [data];

			if (info != null && info.customParams != null)
			{
				for (i in info.customParams)
				{
					paramArray.push(i);
				}
			}

			logTrace(paramArray, info);
		};

		// Start the log file writer.
		// We have to set it to TRACE for now.
		logFileWriter = new DebugLogWriter("TRACE");

		logInfo("Debug logging initialized. Hello, developer.");

		#if debug
		logInfo("This is a DEBUG build.");
		#else
		logInfo("This is a RELEASE build.");
		#end
		logInfo('Enigma Engine version: ${Enigma.ENGINE_VERSION}');
		logInfo('  HaxeFlixel version: ${Std.string(FlxG.VERSION)}');
		logInfo('  Friday Night Funkin\' version: ${Enigma.GAME_VERSION}');
		logInfo('  Git commit: ${Enigma.COMMIT_HASH}');
		logInfo('System telemetry:');
		logInfo('  OS: ${SystemSpecUtil.getOS()}');
		logInfo('  CPU: ${SystemSpecUtil.getCPU()}');
		logInfo('  GPU: ${SystemSpecUtil.getGPU()}');
		logInfo('  Manufacturer: ${SystemSpecUtil.getManufacturer()}');
		logInfo('  Language: ${SystemSpecUtil.getLanguage()}');
		logInfo('  Screen resolution: ${SystemSpecUtil.getScreenResolution()}');

		// Add a crash handler.
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
	}

	static function onUncaughtError(error:UncaughtErrorEvent)
	{
		logError('FATAL ERROR: An uncaught error was thrown by OpenFL.');

		var errorCallStack:Array<StackItem> = CallStack.exceptionStack(true);

		for (line in errorCallStack)
		{
			switch (line)
			{
				case CFunction:
					logError('  function:');
				case Module(m):
					logError('  module:${m}');
				case FilePos(s, file, line, column):
					logError('  (${file}#${line},${column})');
				case Method(className, method):
					logError('  method:(${className}/${method}');
				case LocalFunction(v):
					logError('  localFunction:${v}');
			}
		}

		logError('ADDITIONAL INFO:');
		logError('Type of instigator: ${Util.getTypeName(error.error)}');
		displayAlert('Fatal Crash Error',
			'A fatal error has occurred. ' +
			'Please retrieve your log file from the "logs" folder and report it to the GitHub page: https://github.com/EnigmaEngine/EnigmaEngine');
	}

	/**
	 * The game runs this function when it starts, but after Flixel is initialized.
	 */
	public static function onGameStart()
	{
		// Add the mouse position to the debug Watch window.
		FlxG.watch.addMouse();

		defineTrackerProfiles();
		defineConsoleCommands();

		// Now we can remember the log level.
		if (FlxG.save.data.debugLogLevel == null)
			FlxG.save.data.debugLogLevel = "TRACE";

		logFileWriter.setLogLevel(FlxG.save.data.debugLogLevel);
	}

	static function writeToFlxGLog(data:Array<Dynamic>, logStyle:LogStyle)
	{
		if (FlxG != null && FlxG.game != null && FlxG.log != null)
		{
			FlxG.log.advanced(data, logStyle);
		}
	}

	static function writeToLogFile(data:Array<Dynamic>, logLevel:String = "TRACE")
	{
		if (logFileWriter != null && logFileWriter.isActive())
		{
			logFileWriter.write(data, logLevel);
		}
	}

	/**
	 * Defines what properties will be displayed in tracker windows for all these classes.
	 */
	static function defineTrackerProfiles()
	{
		// Example: This will display all the properties that FlxSprite does, along with curCharacter and barColor.
		FlxG.debugger.addTrackerProfile(new TrackerProfile(OldCharacter, ["curCharacter", "isPlayer", "barColor"], [FlxSprite]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(HealthIcon, ["char", "isPlayer", "isOldIcon"], [FlxSprite]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Note, ["x", "y", "strumTime", "mustPress", "rawNoteData", "sustainLength"], []));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Song, [
			"chartVersion",
			"song",
			"speed",
			"player1",
			"player2",
			"gfVersion",
			"noteStyle",
			"stage"
		], []));
	}

	/**
	 * Defines some commands you can run in the console for easy use of important debugging functions.
	 * Feel free to add your own!
	 */
	static inline function defineConsoleCommands()
	{
		// Example: This will display Boyfriend's sprite properties in a debug window.
		addConsoleCommand("trackBoyfriend", function()
		{
			Debug.logInfo("CONSOLE: Begin tracking Boyfriend...");
			trackObject(PlayState.playerChar);
		});
		addConsoleCommand("trackGirlfriend", function()
		{
			Debug.logInfo("CONSOLE: Begin tracking Girlfriend...");
			trackObject(PlayState.gfChar);
		});
		addConsoleCommand("trackDad", function()
		{
			Debug.logInfo("CONSOLE: Begin tracking Dad...");
			trackObject(PlayState.cpuChar);
		});

		addConsoleCommand("setLogLevel", function(logLevel:String)
		{
			if (!DebugLogWriter.LOG_LEVELS.contains(logLevel))
			{
				Debug.logWarn('CONSOLE: Invalid log level $logLevel!');
				Debug.logWarn('  Expected: ${DebugLogWriter.LOG_LEVELS.join(', ')}');
			}
			else
			{
				Debug.logInfo('CONSOLE: Setting log level to $logLevel...');
				logFileWriter.setLogLevel(logLevel);
			}
		});

		// Console commands let you do WHATEVER you want.
		addConsoleCommand("playSong", function(songName:String, ?difficulty:String = 'normal')
		{
			Debug.logInfo('CONSOLE: Opening song $songName ($difficulty) in Free Play...');
			FreeplayState.loadSongInFreePlay(songName, difficulty, false);
		});
		addConsoleCommand("chartSong", function(songName:String, ?difficulty:String = 'normal')
		{
			Debug.logInfo('CONSOLE: Opening song $songName ($difficulty) in Chart Editor...');
			FreeplayState.loadSongInFreePlay(songName, difficulty, true, true);
		});
	}

	static function formatOutput(input:Dynamic, pos:haxe.PosInfos):Array<Dynamic>
	{
		// This code is junk but I kept getting Null Function References.
		var inArray:Array<Dynamic> = null;
		if (input == null)
		{
			inArray = ['<NULL>'];
		}
		else if (!Std.isOfType(input, Array))
		{
			inArray = [input];
		}
		else
		{
			inArray = input;
		}

		if (pos == null)
			return inArray;

		var gameTickTime = (FlxG.game != null ? '${FlxG.game.ticks / 1000} ' : '');

		// Format the position ourselves.
		var output:Array<Dynamic> = ['${gameTickTime}(${pos.className}/${pos.methodName}#${pos.lineNumber}): '];

		return output.concat(inArray);
	}
}

class DebugLogWriter
{
	static final LOG_FOLDER = "logs";
	public static final LOG_LEVELS = ['ERROR', 'WARN', 'INFO', 'TRACE'];

	/**
	 * Set this to the current timestamp that the game started.
	 */
	var startTime:Float = 0;

	var logLevel:Int;

	var active = false;
	#if FEATURE_FILESYSTEM
	var file:sys.io.FileOutput;
	#end

	public function new(logLevelParam:String)
	{
		logLevel = LOG_LEVELS.indexOf(logLevelParam);

		#if FEATURE_FILESYSTEM
		printDebug("Initializing log file...");

		// The path of the log file.
		var logFilePath = '$LOG_FOLDER/${Sys.time()}.log';

		// Make sure that the log directory exists.
		if (logFilePath.indexOf("/") != -1)
		{
			var lastIndex:Int = logFilePath.lastIndexOf("/");
			var logFolderPath:String = logFilePath.substr(0, lastIndex);
			printDebug('Creating log folder $logFolderPath');
			sys.FileSystem.createDirectory(logFolderPath);
		}
		// Open the file
		printDebug('Creating log file $logFilePath');
		file = sys.io.File.write(logFilePath, false);
		active = true;
		#else
		printDebug("Won't create log file; no file system access.");
		active = false;
		#end

		// Get the absolute time in seconds. This lets us show relative time in log, which is more readable.
		startTime = getTime(true);
	}

	public function isActive()
	{
		return active;
	}

	/**
	 * Get the time in seconds.
	 * @param abs Whether the timestamp is absolute or relative to the start time.
	 */
	public inline function getTime(abs:Bool = false):Float
	{
		#if sys
		// Use this one on CPP and Neko since it's more accurate.
		return abs ? Sys.time() : (Sys.time() - startTime);
		#else
		// This one is more accurate on non-CPP platforms.
		return abs ? Date.now().getTime() : (Date.now().getTime() - startTime);
		#end
	}

	function shouldLog(input:String):Bool
	{
		var levelIndex = LOG_LEVELS.indexOf(input);
		// Could not find this log level.
		if (levelIndex == -1)
			return false;
		return levelIndex <= logLevel;
	}

	public function setLogLevel(input:String):Void
	{
		var levelIndex = LOG_LEVELS.indexOf(input);
		// Could not find this log level.
		if (levelIndex == -1)
			return;

		logLevel = levelIndex;
		FlxG.save.data.debugLogLevel = logLevel;
	}

	/**
	 * Output text to the log file. Delegates the task to an async thread pool.
	 */
	public function write(input:Array<Dynamic>, logLevel = 'TRACE'):Void
	{
		TaskWorker.performTask(function():Void
		{
			writeSync(input, logLevel);
		});
	}

	/**
	 * Output text to the log file.
	 */
	public function writeSync(input:Array<Dynamic>, logLevel = 'TRACE'):Void
	{
		var ts = FlxStringUtil.formatTime(getTime(), true);
		var msg = '$ts [${logLevel.rpad(5)}] ${input.join('')}';

		#if FEATURE_FILESYSTEM
		if (active && file != null)
		{
			if (shouldLog(logLevel))
			{
				file.writeString('$msg\n');
				file.flush();
				file.flush();
			}
		}
		#end

		// Output text to the debug console directly.
		if (shouldLog(logLevel))
		{
			printDebug(msg);
		}
	}

	function printDebug(msg:String)
	{
		#if sys
		Sys.println(msg);
		#else
		// Pass null to exclude the position.
		haxe.Log.trace(msg, null);
		#end
	}
}
