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
 * HitGraph.hx
 * The note hit graph used in the Results screen.
 * @see https://github.com/HaxeFlixel/flixel/blob/master/flixel/system/debug/stats/StatsGraph.hx
 */
package funkin.ui.component.play;

import funkin.behavior.options.Options;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormatAlign;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.system.FlxAssets;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import funkin.behavior.play.Scoring;
import funkin.ui.state.play.PlayState;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

class HitGraph extends Sprite
{
	static inline var AXIS_COLOR:FlxColor = 0xffffff;
	static inline var AXIS_ALPHA:Float = 0.5;
	static inline var HISTORY_MAX:Int = 30;

	public var minLabel:TextField;
	public var curLabel:TextField;
	public var maxLabel:TextField;
	public var avgLabel:TextField;

	public var minValue:Float = -(Math.floor((PlayState.currentReplay.replay.safeFrames / 60) * 1000) + 95);
	public var maxValue:Float = Math.floor((PlayState.currentReplay.replay.safeFrames / 60) * 1000) + 95;

	public var showInput:Bool = ExtendedScoreInfoOption.get();

	public var graphColor:FlxColor;

	public var history:Array<Dynamic> = [];

	public var bitmap:Bitmap;

	public var ts:Float;

	var _axis:Shape;
	var _width:Int;
	var _height:Int;
	var _unit:String;
	var _labelWidth:Int;
	var _label:String;

	public function new(X:Int, Y:Int, Width:Int, Height:Int)
	{
		super();
		x = X;
		y = Y;
		_width = Width;
		_height = Height;

		var bm = new BitmapData(Width, Height);
		bm.draw(this);
		bitmap = new Bitmap(bm);

		_axis = new Shape();
		_axis.x = _labelWidth + 10;

		ts = Math.floor((PlayState.currentReplay.replay.safeFrames / 60) * 1000) / Scoring.TIMING_WINDOWS[0];

		var early = createTextField(10, 10, FlxColor.WHITE, 12);
		var late = createTextField(10, _height - 20, FlxColor.WHITE, 12);

		early.text = "Early (" + -Scoring.TIMING_WINDOWS[0] * ts + "ms)";
		late.text = "Late (" + Scoring.TIMING_WINDOWS[0] * ts + "ms)";

		addChild(early);
		addChild(late);

		addChild(_axis);

		drawAxes();
	}

	/**
	 * Redraws the axes of the graph.
	 */
	function drawAxes():Void
	{
		var gfx = _axis.graphics;
		gfx.clear();
		gfx.lineStyle(1, AXIS_COLOR, AXIS_ALPHA);

		// y-Axis
		gfx.moveTo(0, 0);
		gfx.lineTo(0, _height);

		// x-Axis
		gfx.moveTo(0, _height);
		gfx.lineTo(_width, _height);

		gfx.moveTo(0, _height / 2);
		gfx.lineTo(_width, _height / 2);
	}

	public static function createTextField(X:Float = 0, Y:Float = 0, Color:FlxColor = FlxColor.WHITE, Size:Int = 12):TextField
	{
		return initTextField(new TextField(), X, Y, Color, Size);
	}

	public static function initTextField<T:TextField>(tf:T, X:Float = 0, Y:Float = 0, Color:FlxColor = FlxColor.WHITE, Size:Int = 12):T
	{
		tf.x = X;
		tf.y = Y;
		tf.multiline = false;
		tf.wordWrap = false;
		tf.embedFonts = true;
		tf.selectable = false;
		#if flash
		tf.antiAliasType = AntiAliasType.NORMAL;
		tf.gridFitType = GridFitType.PIXEL;
		#end
		tf.defaultTextFormat = new TextFormat("assets/fonts/vcr.ttf", Size, Color.to24Bit());
		tf.alpha = Color.alphaFloat;
		tf.autoSize = TextFieldAutoSize.LEFT;
		return tf;
	}

	function drawJudgementLine(ms:Float):Void
	{
		var gfx:Graphics = graphics;

		gfx.lineStyle(1, graphColor, 0.3);

		var ts = Math.floor((PlayState.currentReplay.replay.safeFrames / 60) * 1000) / Scoring.TIMING_WINDOWS[0];
		var range:Float = Math.max(maxValue - minValue, maxValue * 0.1);

		var value = ((ms * ts) - minValue) / range;

		var pointY = _axis.y + ((-value * _height - 1) + _height);

		var graphX = _axis.x + 1;

		if (ms == 45)
			gfx.moveTo(graphX, _axis.y + pointY);

		var graphX = _axis.x + 1;

		gfx.drawRect(graphX, pointY, _width, 1);

		gfx.lineStyle(1, graphColor, 1);
	}

	/**
	 * Redraws the graph based on the values stored in the history.
	 */
	function drawGraph():Void
	{
		var gfx:Graphics = graphics;
		gfx.clear();
		gfx.lineStyle(1, graphColor, 1);

		gfx.beginFill(0x00FF00);
		drawJudgementLine(Scoring.TIMING_WINDOWS[3]);
		gfx.endFill();

		gfx.beginFill(0xFF0000);
		drawJudgementLine(Scoring.TIMING_WINDOWS[2]);
		gfx.endFill();

		gfx.beginFill(0x8b0000);
		drawJudgementLine(Scoring.TIMING_WINDOWS[1]);
		gfx.endFill();

		gfx.beginFill(0x580000);
		drawJudgementLine(Scoring.TIMING_WINDOWS[0]);
		gfx.endFill();

		gfx.beginFill(0x00FF00);
		drawJudgementLine(-Scoring.TIMING_WINDOWS[3]);
		gfx.endFill();

		gfx.beginFill(0xFF0000);
		drawJudgementLine(-Scoring.TIMING_WINDOWS[2]);
		gfx.endFill();

		gfx.beginFill(0x8b0000);
		drawJudgementLine(-Scoring.TIMING_WINDOWS[1]);
		gfx.endFill();

		gfx.beginFill(0x580000);
		drawJudgementLine(-Scoring.TIMING_WINDOWS[0]);
		gfx.endFill();

		var range:Float = Math.max(maxValue - minValue, maxValue * 0.1);
		var graphX = _axis.x + 1;

		if (showInput)
		{
			for (i in 0...PlayState.currentReplay.replay.replayInputs.length)
			{
				var ana = PlayState.currentReplay.replay.replayInputs[i];

				var value = (ana.key * 25 - minValue) / range;

				if (ana.hit)
					gfx.beginFill(0xFFFF00);
				else
					gfx.beginFill(0xC2B280);

				if (ana.hitTime < 0)
					continue;

				var pointY = (-value * _height - 1) + _height;
				gfx.drawRect(graphX + fitX(ana.hitTime), pointY, 2, 2);
				gfx.endFill();
			}
		}

		for (i in 0...history.length)
		{
			var value = (history[i][0] - minValue) / range;
			var judge = history[i][1];

			switch (judge)
			{
				case "sick":
					gfx.beginFill(0x00FFFF);
				case "good":
					gfx.beginFill(0x00FF00);
				case "bad":
					gfx.beginFill(0xFF0000);
				case "shit":
					gfx.beginFill(0x8b0000);
				case "miss":
					gfx.beginFill(0x580000);
				default:
					gfx.beginFill(0xFFFFFF);
			}
			var pointY = ((-value * _height - 1) + _height);

			gfx.drawRect(fitX(history[i][2]), pointY, 4, 4);

			gfx.endFill();
		}

		var bm = new BitmapData(_width, _height);
		bm.draw(this);
		bitmap = new Bitmap(bm);
	}

	public function fitX(x:Float)
	{
		return (x / FlxG.sound.music.length) * width;
	}

	public function addToHistory(diff:Float, judge:String, time:Float)
	{
		history.push([diff, judge, time]);
	}

	public function update():Void
	{
		drawGraph();
	}

	public function average():Float
	{
		var sum:Float = 0;
		for (value in history)
			sum += value;
		return sum / history.length;
	}

	public function destroy():Void
	{
		_axis = FlxDestroyUtil.removeChild(this, _axis);
		history = null;
	}
}
