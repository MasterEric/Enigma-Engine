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
 * ModchartHandler.hx
 * Handles higher-level logic for Lua modcharts.
 * This will eventually be deprecated in favor of HScript.
 */
package funkin.behavior.modchart;

// this file is for modchart things, this is to declutter playstate.hx
// Lua
#if FEATURE_LUAMODCHART
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.behavior.modchart.LuaClass;
import funkin.behavior.modchart.LuaClass.LuaCamera;
import funkin.behavior.modchart.LuaClass.LuaGame;
import funkin.behavior.modchart.LuaClass.LuaReceptor;
import funkin.behavior.modchart.LuaClass.LuaSprite;
import funkin.behavior.modchart.LuaClass.LuaWindow;
import funkin.behavior.options.Options;
import funkin.behavior.play.Conductor;
import funkin.ui.component.play.Boyfriend;
import funkin.ui.component.play.Character;
import funkin.ui.effects.WiggleEffect;
import funkin.ui.state.menu.FreeplayState;
import funkin.ui.state.play.PlayState;
import funkin.util.assets.Paths;
import lime.app.Application;
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
import openfl.display.BitmapData;
import openfl.display3D.textures.VideoTexture;
import openfl.filters.ShaderFilter;
import openfl.geom.Matrix;

// Renamed to ModchartHandler because it's not a Flixel state.
class ModchartHandler
{
	public static var lua:State = null;

	function callLua(func_name:String, args:Array<Dynamic>, ?type:String):Dynamic
	{
		var result:Any = null;

		Lua.getglobal(lua, func_name);

		for (arg in args)
		{
			Convert.toLua(lua, arg);
		}

		result = Lua.pcall(lua, args.length, 1, 0);
		var p = Lua.tostring(lua, result);
		var e = getLuaErrorMessage(lua);

		Lua.tostring(lua, -1);

		if (e != null)
		{
			if (e != "attempt to call a nil value")
			{
				trace(StringTools.replace(e, "c++", "haxe function"));
			}
		}
		if (result == null)
		{
			return null;
		}
		else
		{
			return convert(result, type);
		}
	}

	static function toLua(l:State, val:Any):Bool
	{
		switch (Type.typeof(val))
		{
			case Type.ValueType.TNull:
				Lua.pushnil(l);
			case Type.ValueType.TBool:
				Lua.pushboolean(l, val);
			case Type.ValueType.TInt:
				Lua.pushinteger(l, cast(val, Int));
			case Type.ValueType.TFloat:
				Lua.pushnumber(l, val);
			case Type.ValueType.TClass(String):
				Lua.pushstring(l, cast(val, String));
			case Type.ValueType.TClass(Array):
				Convert.arrayToLua(l, val);
			case Type.ValueType.TObject:
				objectToLua(l, val);
			default:
				trace("haxe value not supported - " + val + " which is a type of " + Type.typeof(val));
				return false;
		}

		return true;
	}

	static function objectToLua(l:State, res:Any)
	{
		var FUCK = 0;
		for (n in Reflect.fields(res))
		{
			trace(Type.typeof(n).getName());
			FUCK++;
		}

		Lua.createtable(l, FUCK, 0); // TODONE: I did it

		for (n in Reflect.fields(res))
		{
			if (!Reflect.isObject(n))
				continue;
			Lua.pushstring(l, n);
			toLua(l, Reflect.field(res, n));
			Lua.settable(l, -3);
		}
	}

	function getType(l, type):Any
	{
		return switch Lua.type(l, type)
		{
			case t if (t == Lua.LUA_TNIL): null;
			case t if (t == Lua.LUA_TNUMBER): Lua.tonumber(l, type);
			case t if (t == Lua.LUA_TSTRING): (Lua.tostring(l, type) : String);
			case t if (t == Lua.LUA_TBOOLEAN): Lua.toboolean(l, type);
			case t: throw 'you don goofed up. lua type error ($t)';
		}
	}

	function getReturnValues(l)
	{
		var lua_v:Int;
		var v:Any = null;
		while ((lua_v = Lua.gettop(l)) != 0)
		{
			var type:String = getType(l, lua_v);
			v = convert(lua_v, type);
			Lua.pop(l, 1);
		}
		return v;
	}

	private function convert(v:Any, type:String):Dynamic
	{ // I didn't write this lol
		if (Std.isOfType(v, String) && type != null)
		{
			var v:String = v;
			if (type.substr(0, 4) == 'array')
			{
				if (type.substr(4) == 'float')
				{
					var array:Array<String> = v.split(',');
					var array2:Array<Float> = new Array();

					for (vars in array)
					{
						array2.push(Std.parseFloat(vars));
					}

					return array2;
				}
				else if (type.substr(4) == 'int')
				{
					var array:Array<String> = v.split(',');
					var array2:Array<Int> = new Array();

					for (vars in array)
					{
						array2.push(Std.parseInt(vars));
					}

					return array2;
				}
				else
				{
					var array:Array<String> = v.split(',');
					return array;
				}
			}
			else if (type == 'float')
			{
				return Std.parseFloat(v);
			}
			else if (type == 'int')
			{
				return Std.parseInt(v);
			}
			else if (type == 'bool')
			{
				if (v == 'true')
				{
					return true;
				}
				else
				{
					return false;
				}
			}
			else
			{
				return v;
			}
		}
		else
		{
			return v;
		}
	}

	function getLuaErrorMessage(l)
	{
		var v:String = Lua.tostring(l, -1);
		Lua.pop(l, 1);
		return v;
	}

	public function setVar(var_name:String, object:Dynamic)
	{
		Lua.pushnumber(lua, object);
		Lua.setglobal(lua, var_name);
	}

	public function getVar(var_name:String, type:String):Dynamic
	{
		var result:Any = null;

		Lua.getglobal(lua, var_name);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if (result == null)
		{
			return null;
		}
		else
		{
			var result = convert(result, type);
			return result;
		}
	}

	function getActorByName(id:String):Dynamic
	{
		// pre defined names
		switch (id)
		{
			case 'boyfriend':
				@:privateAccess
				return PlayState.playerChar;
			case 'girlfriend':
				@:privateAccess
				return PlayState.gfChar;
			case 'dad':
				@:privateAccess
				return PlayState.cpuChar;
		}
		// lua objects or what ever
		if (luaSprites.get(id) == null)
		{
			if (Std.parseInt(id) == null)
				return Reflect.getProperty(PlayState.instance, id);
			return PlayState.strumLineNotes.members[Std.parseInt(id)];
		}
		return luaSprites.get(id);
	}

	function getPropertyByName(id:String)
	{
		return Reflect.field(PlayState.instance, id);
	}

	public static var luaSprites:Map<String, FlxSprite> = [];

	function changeDadCharacter(id:String)
	{
		var olddadx = PlayState.cpuChar.x;
		var olddady = PlayState.cpuChar.y;
		PlayState.instance.removeObject(PlayState.cpuChar);
		PlayState.cpuChar = new Character(olddadx, olddady, id);
		PlayState.instance.addObject(PlayState.cpuChar);
		PlayState.instance.healthIconCPU.changeIcon(id);
	}

	function changeBoyfriendCharacter(id:String)
	{
		var oldboyfriendx = PlayState.playerChar.x;
		var oldboyfriendy = PlayState.playerChar.y;
		PlayState.instance.removeObject(PlayState.playerChar);
		PlayState.playerChar = new Boyfriend(oldboyfriendx, oldboyfriendy, id);
		PlayState.instance.addObject(PlayState.playerChar);
		PlayState.instance.healthIconPlayer.changeIcon(id);
	}

	function makeAnimatedLuaSprite(spritePath:String, names:Array<String>, prefixes:Array<String>, startAnim:String, id:String)
	{
		#if FEATURE_FILESYSTEM
		// TODO: Make this use OpenFlAssets.
		var data:BitmapData = BitmapData.fromFile(Sys.getCwd() + "assets/data/songs/" + PlayState.SONG.songId + '/' + spritePath + ".png");

		var sprite:FlxSprite = new FlxSprite(0, 0);

		sprite.frames = FlxAtlasFrames.fromSparrow(FlxGraphic.fromBitmapData(data),
			Sys.getCwd() + "assets/data/songs/" + PlayState.SONG.songId + "/" + spritePath + ".xml");

		trace(sprite.frames.frames.length);

		for (p in 0...names.length)
		{
			var i = names[p];
			var ii = prefixes[p];
			sprite.animation.addByPrefix(i, ii, 24, false);
		}

		luaSprites.set(id, sprite);

		PlayState.instance.addObject(sprite);

		sprite.animation.play(startAnim);
		return id;
		#end
	}

	function makeLuaSprite(spritePath:String, toBeCalled:String, drawBehind:Bool)
	{
		#if FEATURE_FILESYSTEM
		// pre lowercasing the song name (makeLuaSprite)
		var songLowercase = StringTools.replace(PlayState.SONG.songId, " ", "-").toLowerCase();
		switch (songLowercase)
		{
			case 'dad-battle':
				songLowercase = 'dadbattle';
			case 'philly-nice':
				songLowercase = 'philly';
			case 'm.i.l.f':
				songLowercase = 'milf';
		}

		var path = Sys.getCwd() + "assets/data/songs/" + PlayState.SONG.songId + '/';

		var data:BitmapData = BitmapData.fromFile(path + spritePath + ".png");

		var sprite:FlxSprite = new FlxSprite(0, 0);
		var imgWidth:Float = FlxG.width / data.width;
		var imgHeight:Float = FlxG.height / data.height;
		var scale:Float = imgWidth <= imgHeight ? imgWidth : imgHeight;

		// Cap the scale at x1
		if (scale > 1)
			scale = 1;

		sprite.makeGraphic(Std.int(data.width * scale), Std.int(data.width * scale), FlxColor.TRANSPARENT);

		var data2:BitmapData = sprite.pixels.clone();
		var matrix:Matrix = new Matrix();
		matrix.identity();
		matrix.scale(scale, scale);
		data2.fillRect(data2.rect, FlxColor.TRANSPARENT);
		data2.draw(data, matrix, null, null, null, true);
		sprite.pixels = data2;

		luaSprites.set(toBeCalled, sprite);

		// TODO: Can we redo this code somehow? It's garbage. Is there a way to control z-level?
		@:privateAccess
		{
			if (drawBehind)
			{
				PlayState.instance.removeObject(PlayState.gfChar);
				PlayState.instance.removeObject(PlayState.playerChar);
				PlayState.instance.removeObject(PlayState.cpuChar);
			}
			PlayState.instance.addObject(sprite);
			if (drawBehind)
			{
				PlayState.instance.addObject(PlayState.gfChar);
				PlayState.instance.addObject(PlayState.playerChar);
				PlayState.instance.addObject(PlayState.cpuChar);
			}
		}
		#end

		new LuaSprite(sprite, toBeCalled).Register(lua);

		return toBeCalled;
	}

	public function die()
	{
		Lua.close(lua);
		lua = null;
	}

	public var luaWiggles:Map<String, WiggleEffect> = new Map<String, WiggleEffect>();

	function new(?isStoryMode = true)
	{
		trace('opening a lua state (because we are cool :))');
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		trace("Lua version: " + Lua.version());
		trace("LuaJIT version: " + Lua.versionJIT());
		Lua.init_callbacks(lua);

		// pre lowercasing the song name (new)
		var songLowercase = StringTools.replace(PlayState.SONG.songId, " ", "-").toLowerCase();
		switch (songLowercase)
		{
			case 'dad-battle':
				songLowercase = 'dadbattle';
			case 'philly-nice':
				songLowercase = 'philly';
			case 'm.i.l.f':
				songLowercase = 'milf';
		}

		var path = Paths.lua('songs/${PlayState.SONG.songId}/modchart');

		var result = LuaL.dofile(lua, path); // execute le file

		if (result != 0)
		{
			Application.current.window.alert("LUA COMPILE ERROR:\n" + Lua.tostring(lua, result), "Enigma Engine Modcharts");
			FlxG.switchState(new FreeplayState());
			return;
		}

		// get some fukin globals up in here bois

		setVar("difficulty", PlayState.songDifficulty);
		setVar("bpm", Conductor.bpm);
		setVar("scrollspeed", ScrollSpeedOption.get() != 1 ? ScrollSpeedOption.get() : PlayState.SONG.speed);
		setVar("fpsCap", FramerateCapOption.get());
		setVar("downscroll", DownscrollOption.get());
		setVar("flashing", FlashingLightsOption.get());
		setVar("distractions", DistractionsAndEffectsOption.get());
		setVar("colour", HPBarColorOption.get());

		setVar("curStep", 0);
		setVar("curBeat", 0);
		setVar("crochet", Conductor.stepCrochet);
		setVar("safeZoneOffset", Conductor.safeZoneOffset);

		setVar("hudZoom", PlayState.instance.camHUD.zoom);
		setVar("cameraZoom", FlxG.camera.zoom);

		setVar("cameraAngle", FlxG.camera.angle);
		setVar("camHudAngle", PlayState.instance.camHUD.angle);

		setVar("followXOffset", 0);
		setVar("followYOffset", 0);

		setVar("showOnlyStrums", false);
		setVar("strumLine1Visible", true);
		setVar("strumLine2Visible", true);

		setVar("screenWidth", FlxG.width);
		setVar("screenHeight", FlxG.height);
		setVar("windowWidth", FlxG.width);
		setVar("windowHeight", FlxG.height);
		setVar("hudWidth", PlayState.instance.camHUD.width);
		setVar("hudHeight", PlayState.instance.camHUD.height);

		setVar("mustHit", false);

		setVar("strumLineY", PlayState.instance.strumLine.y);

		// callbacks

		Lua_helper.add_callback(lua, "makeSprite", makeLuaSprite);

		// sprites

		Lua_helper.add_callback(lua, "setNoteWiggle", function(wiggleId)
		{
			PlayState.instance.camNotes.setFilters([new ShaderFilter(luaWiggles.get(wiggleId).shader)]);
		});

		Lua_helper.add_callback(lua, "setSustainWiggle", function(wiggleId)
		{
			PlayState.instance.camSustains.setFilters([new ShaderFilter(luaWiggles.get(wiggleId).shader)]);
		});

		Lua_helper.add_callback(lua, "createWiggle", function(freq:Float, amplitude:Float, speed:Float)
		{
			var wiggle = new WiggleEffect();
			wiggle.waveAmplitude = amplitude;
			wiggle.waveSpeed = speed;
			wiggle.waveFrequency = freq;

			var id = Lambda.count(luaWiggles) + 1 + "";

			luaWiggles.set(id, wiggle);
			return id;
		});

		Lua_helper.add_callback(lua, "setWiggleTime", function(wiggleId:String, time:Float)
		{
			var wiggle = luaWiggles.get(wiggleId);

			wiggle.shader.uTime.value = [time];
		});

		Lua_helper.add_callback(lua, "setWiggleAmplitude", function(wiggleId:String, amp:Float)
		{
			var wiggle = luaWiggles.get(wiggleId);

			wiggle.waveAmplitude = amp;
		});

		Lua_helper.add_callback(lua, "setStrumlineY", function(y:Float)
		{
			PlayState.instance.strumLine.y = y;
		});

		Lua_helper.add_callback(lua, "getNumberOfNotes", function(y:Float)
		{
			return PlayState.instance.songNotes.members.length;
		});

		for (i in 0...PlayState.strumLineNotes.length)
		{
			var member = PlayState.strumLineNotes.members[i];
			new LuaReceptor(member, "receptor_" + i).Register(lua);
		}

		new LuaGame().Register(lua);

		new LuaWindow().Register(lua);
	}

	public function executeState(name, args:Array<Dynamic>)
	{
		return Lua.tostring(lua, callLua(name, args));
	}

	public static function createModchartHandler(?isStoryMode = true):ModchartHandler
	{
		return new ModchartHandler(isStoryMode);
	}
}
#end
