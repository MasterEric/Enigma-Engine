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
 * PolymodHandler.hx
 * The central handler for the system which handles retrieving and loading mods.
 */
package funkin.behavior.mods;

import flixel.FlxG;
import polymod.Polymod;
#if FEATURE_POLYMOD
import polymod.backends.OpenFLBackend;
import polymod.backends.PolymodAssets.PolymodAssetType;
import polymod.format.ParseRules.LinesParseFormat;
import polymod.format.ParseRules.TextFileFormat;
#end

class PolymodHandler
{
	/**
	 * The current API version.
	 * Must be formatted in Semantic Versioning v2; <MAJOR>.<MINOR>.<PATCH>.
	 * 
	 * Remember to increment the major version if you make breaking changes to mods!
	 */
	static final API_VERSION = "0.1.0";

	static final API_MATCH_VERSION = "0.1.*";

	static final MOD_DIRECTORY = "mods";

	public static function loadAllMods()
	{
		#if FEATURE_POLYMOD
		Debug.logInfo("Initializing Polymod (using all mods)...");
		loadModsById(getAllModIds());
		#else
		Debug.logInfo("Polymod not initialized; not supported on this platform.");
		#end
	}

	public static function loadConfiguredMods()
	{
		#if FEATURE_POLYMOD
		Debug.logInfo("Initializing Polymod (using user config)...");
		Debug.logTrace('  User mod config: ${FlxG.save.data.modConfig}');
		var userModConfig = getConfiguredMods();
		loadModsById(userModConfig);
		#else
		Debug.logInfo("Polymod not initialized; not supported on this platform.");
		#end
	}

	public static function loadNoMods()
	{
		// We still need to configure the debug print calls etc.
		#if FEATURE_POLYMOD
		Debug.logInfo("Initializing Polymod (using no mods)...");
		loadModsById([]);
		#else
		Debug.logInfo("Polymod not initialized; not supported on this platform.");
		#end
	}

	/**
	 * If the user has configured an order of mods to load, returns the list of mod IDs in order.
	 * Otherwise, returns a list of ALL installed mods in alphabetical order.
	 * @return The mod order to load.
	 */
	public static function getConfiguredMods():Array<String>
	{
		var rawSaveData = FlxG.save.data.modConfig;

		if (rawSaveData != null)
		{
			var modEntries = rawSaveData.split('~');
			return modEntries;
		}
		else
		{
			// Mod list not in save!
			return null;
		}
	}

	public static function saveModList(loadedMods:Array<String>)
	{
		Debug.logInfo('Saving mod configuration...');
		var rawSaveData = loadedMods.join('~');
		Debug.logTrace(rawSaveData);
		FlxG.save.data.modConfig = rawSaveData;
		var result = FlxG.save.flush();
		if (result)
			Debug.logInfo('Mod configuration saved successfully.');
		else
			Debug.logWarn('Failed to save mod configuration.');
	}

	public static function loadModsById(ids:Array<String>)
	{
		#if FEATURE_POLYMOD
		if (ids.length == 0)
		{
			Debug.logWarn('You attempted to load zero mods.');
		}
		else
		{
			Debug.logInfo('Attempting to load ${ids.length} mods...');
		}
		var loadedModList = polymod.Polymod.init({
			// Root directory for all mods.
			modRoot: MOD_DIRECTORY,
			// The directories for one or more mods to load.
			dirs: ids,
			// Framework being used to load assets. We're using a CUSTOM one which extends the OpenFL one.
			framework: CUSTOM,
			// The current version of our API.
			apiVersion: API_VERSION,
			// Call this function any time an error occurs.
			errorCallback: onPolymodError,
			// Enforce semantic version patterns for each mod.
			// modVersions: null,
			// A map telling Polymod what the asset type is for unfamiliar file extensions.
			// extensionMap: [],

			frameworkParams: buildFrameworkParams(),

			// Use a custom backend so we can get a picture of what's going on,
			// or even override behavior ourselves.
			customBackend: EnigmaBackend,

			// List of filenames to ignore in mods. Use the default list to ignore the metadata file, etc.
			ignoredFiles: Polymod.getDefaultIgnoreList(),

			// Parsing rules for various data formats.
			parseRules: buildParseRules(),
		});

		if (loadedModList == null)
		{
			Debug.logError('Mod loading failed, check above for a message from Polymod explaining why.');
		}
		else
		{
			if (loadedModList.length == 0)
			{
				Debug.logInfo('Mod loading complete. We loaded no mods / ${ids.length} mods.');
			}
			else
			{
				Debug.logInfo('Mod loading complete. We loaded ${loadedModList.length} / ${ids.length} mods.');
			}
		}

		for (mod in loadedModList)
			Debug.logTrace('  * ${mod.title} v${mod.modVersion} [${mod.id}]');

		var fileList = Polymod.listModFiles("IMAGE");
		Debug.logInfo('Installed mods have replaced ${fileList.length} images.');
		for (item in fileList)
			Debug.logTrace('  * $item');

		fileList = Polymod.listModFiles("TEXT");
		Debug.logInfo('Installed mods have replaced ${fileList.length} text files.');
		for (item in fileList)
			Debug.logTrace('  * $item');

		fileList = Polymod.listModFiles("MUSIC");
		Debug.logInfo('Installed mods have replaced ${fileList.length} music files.');
		for (item in fileList)
			Debug.logTrace('  * $item');

		fileList = Polymod.listModFiles("SOUND");
		Debug.logInfo('Installed mods have replaced ${fileList.length} sound files.');
		for (item in fileList)
			Debug.logTrace('  * $item');
		#else
		Debug.logWarn("Attempted to load mods when Polymod was not supported!");
		#end
	}

	/**
	 * Returns true if there are mods to load in the mod folder,
	 * and false if there aren't (or mods aren't supported).
	 * @return A boolean value.
	 */
	public static function hasMods():Bool
	{
		#if FEATURE_POLYMOD
		return getAllMods().length > 0;
		#else
		return false;
		#end
	}

	public static function getAllMods():Array<ModMetadata>
	{
		Debug.logInfo('Scanning the mods folder...');
		var modMetadata = Polymod.scan(MOD_DIRECTORY);
		Debug.logInfo('Found ${modMetadata.length} mods when scanning.');
		return modMetadata;
	}

	public static function getAllModIds():Array<String>
	{
		var modIds = [for (i in getAllMods()) i.id];
		return modIds;
	}

	#if FEATURE_POLYMOD
	static function buildParseRules():polymod.format.ParseRules
	{
		var output = polymod.format.ParseRules.getDefault();
		// Ensure TXT files have merge support.
		output.addType("txt", TextFileFormat.LINES);
		// Ensure script files have merge support.
		output.addType("hscript", TextFileFormat.PLAINTEXT);

		// You can specify the format of a specific file, with file extension.
		// output.addFile("data/introText.txt", TextFileFormat.LINES)
		return output;
	}

	static inline function buildFrameworkParams():polymod.FrameworkParams
	{
		return {
			assetLibraryPaths: [
				"default" => "./preload", // ./preload
				"sm" => "./sm",
				"songs" => "./songs",
				"shared" => "./",
				"tutorial" => "./tutorial",
				"scripts" => "./scripts",
				"week3" => "./week3",
				"week4" => "./week4",
				"week5" => "./week5",
				"week6" => "./week6",
				'core' => './_core' // Don't override these files.
			]
		}
	}

	static function onPolymodError(error:PolymodError):Void
	{
		// Perform an action based on the error code.
		switch (error.code)
		{
			case MOD_LOAD_PREPARE:
				Debug.logInfo('[POLYMOD] ${error.message}', null);
			case MOD_LOAD_DONE:
				Debug.logInfo('[POLYMOD] ${error.message}', null);
			// case MOD_LOAD_FAILED:
			case MISSING_ICON:
				Debug.logWarn('[POLYMOD] A mod is missing an icon, will just skip it but please add one: ${error.message}', null);
			// case "parse_mod_version":
			// case "parse_api_version":
			// case "parse_mod_api_version":
			// case "missing_mod":
			// case "missing_meta":
			// case "version_conflict_mod":
			// case "version_conflict_api":
			// case "version_prerelease_api":
			// case "param_mod_version":
			// case "framework_autodetect":
			// case "framework_init":
			// case "undefined_custom_backend":
			// case "failed_create_backend":
			// case "merge_error":
			// case "append_error":
			default:
				// Log the message based on its severity.
				switch (error.severity)
				{
					case NOTICE:
						Debug.logInfo('[POLYMOD] ${error.message}', null);
					case WARNING:
						Debug.logWarn('[POLYMOD] ${error.message}', null);
					case ERROR:
						Debug.logError('[POLYMOD] ${error.message}', null);
				}
		}
	}
	#end
}

#if FEATURE_POLYMOD
class EnigmaBackend extends OpenFLBackend
{
	public function new()
	{
		super();
	}

	public override function clearCache()
	{
		super.clearCache();
	}

	public override function exists(id:String):Bool
	{
		return super.exists(id);
	}

	public override function getBytes(id:String):lime.utils.Bytes
	{
		return super.getBytes(id);
	}

	public override function getText(id:String):String
	{
		return super.getText(id);
	}

	public override function list(type:PolymodAssetType = null):Array<String>
	{
		return super.list(type);
	}
}
#end