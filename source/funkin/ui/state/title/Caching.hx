/*
 * GNU General Public License, Version 3.0
 *
 * Copyright (c) 2021 MasterEric
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Caching.hx
 * On platforms where pre-caching of assets is performed,
 * this state displays the initial loading screen.
 */
package funkin.ui.state.title;

import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.TransitionData;
import funkin.util.assets.AudioAssets;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.util.assets.Paths;
import funkin.behavior.Debug;
import funkin.util.assets.GraphicsAssets;
import funkin.behavior.options.PlayerSettings;
import funkin.behavior.SaveData;
import funkin.ui.component.Cursor;
import funkin.util.Util;
import funkin.util.assets.SongAssets;
import haxe.Exception;
import lime.app.Application;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;
#if FEATURE_DISCORD
import funkin.behavior.api.Discord.DiscordClient;
#end
#if FEATURE_FILESYSTEM
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Caching extends MusicBeatState
{
	var toBeDone = 0;
	var done = 0;

	var loaded = false;

	var text:FlxText;
	var gameLogo:FlxSprite;

	public static var bitmapData:Map<String, FlxGraphic>;

	var images = [];
	var music = [];
	var charts = [];

	override function create()
	{
		FlxG.save.bind('funkin', 'ninjamuffin99');

		PlayerSettings.init();

		SaveData.initSave();

		Cursor.showCursor(false);

		FlxG.worldBounds.set(0, 0);

		bitmapData = new Map<String, FlxGraphic>();

		text = new FlxText(FlxG.width / 2, FlxG.height / 2 + 300, 0, "Loading...");
		text.size = 34;
		text.alignment = FlxTextAlign.CENTER;
		text.alpha = 1;

		gameLogo = new FlxSprite(FlxG.width / 2, FlxG.height / 2).loadGraphic(GraphicsAssets.loadImage('logo'));
		gameLogo.x -= gameLogo.width / 2;
		gameLogo.y -= gameLogo.height / 2 + 100;
		text.y -= gameLogo.height / 2 - 125;
		text.x -= 170;
		gameLogo.setGraphicSize(Std.int(gameLogo.width * 0.6));
		if (FlxG.save.data.antialiasing != null)
			gameLogo.antialiasing = FlxG.save.data.antialiasing;
		else
			gameLogo.antialiasing = true;

		gameLogo.alpha = 0;

		FlxGraphic.defaultPersist = FlxG.save.data.cacheImages;

		#if FEATURE_FILESYSTEM
		if (FlxG.save.data.cacheImages)
		{
			trace("caching images...");

			// TODO: Refactor this to use OpenFlAssets.
			for (i in FileSystem.readDirectory(FileSystem.absolutePath("assets/shared/images/characters")))
			{
				if (!i.endsWith(".png"))
					continue;
				images.push(i);
			}
		}

		trace("caching music...");

		music = SongAssets.listMusicFilesToCache();
		#end

		toBeDone = Lambda.count(images) + Lambda.count(music);

		var bar = new FlxBar(10, FlxG.height - 50, FlxBarFillDirection.LEFT_TO_RIGHT, FlxG.width, 40, null, "done", 0, toBeDone);
		bar.color = FlxColor.PURPLE;

		add(bar);

		add(gameLogo);
		add(text);

		trace('starting caching..');

		#if FEATURE_MULTITHREADING
		// update thread

		sys.thread.Thread.create(() ->
		{
			do
			{
				Sys.sleep(1);
				trace('Update loading text...');

				var alpha = Util.truncateFloat(done / toBeDone * 100, 2) / 100;
				gameLogo.alpha = alpha;
				text.text = "Loading... (" + done + "/" + toBeDone + ")";
			}
			while (!loaded);
		});

		// cache thread
		sys.thread.Thread.create(() ->
		{
			cache();
		});
		#end

		trace('Done making cache thread...');
		super.create();
	}

	var calledDone = false;

	override function update(elapsed)
	{
		super.update(elapsed);
		trace('update');
	}

	function cache()
	{
		#if FEATURE_FILESYSTEM
		trace("LOADING: " + toBeDone + " OBJECTS.");

		for (i in images)
		{
			var replaced = i.replace(".png", "");

			// var data:BitmapData = BitmapData.fromFile("assets/shared/images/characters/" + i);
			var imagePath = Paths.image('characters/$i', 'shared');
			Debug.logTrace('Caching character graphic $i ($imagePath)...');
			var data = OpenFlAssets.getBitmapData(imagePath);
			var graph = FlxGraphic.fromBitmapData(data);
			graph.persist = true;
			graph.destroyOnNoUse = false;
			bitmapData.set(replaced, graph);
			done++;
		}

		for (i in music)
		{
			Debug.logTrace('Caching song "$i"...');
			var inst = Paths.inst(i);
			if (AudioAssets.doesSoundAssetExist(inst))
			{
				FlxG.sound.cache(inst);
				Debug.logTrace('  Cached inst for song "$i"');
			}

			var voices = Paths.voices(i);
			if (AudioAssets.doesSoundAssetExist(voices))
			{
				FlxG.sound.cache(voices);
				Debug.logTrace('  Cached voices for song "$i"');
			}

			done++;
		}

		trace("Finished caching...");

		loaded = true;

		trace(OpenFlAssets.cache.hasBitmapData('GF_assets'));
		#end
		FlxG.switchState(new TitleState());
	}
}
#end
