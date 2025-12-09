package;

import kha.Window;
import kha.System;
import iron.App;
import iron.Scene;
import iron.RenderPath;
import iron.data.Data;

/**
 * Standalone entry point for Koui Editor when launched from Blender.
 * Receives scene path as command-line argument and renders it with UI overlay.
 */
class Main {

	public static var scenePath: String = "";
	public static var uiScale: Float = 1.0;

	public static function main() {
		// Parse command-line arguments
		#if kha_krom
		var argCount = Krom.getArgCount();
		// ./krom . . scene_path [ui_scale]
		if (argCount > 3) {
			scenePath = Krom.getArg(3);
			// Convert backslashes to forward slashes
			scenePath = StringTools.replace(scenePath, "\\", "/");
		}
		if (argCount > 4) {
			uiScale = Std.parseFloat(Krom.getArg(4));
			if (Math.isNaN(uiScale)) uiScale = 1.0;
		}
		#end

		trace("Koui Editor Standalone");
		trace("Scene path: " + scenePath);
		trace("UI scale: " + uiScale);

		// Window size
		var w = 1280;
		var h = 720;
		if (kha.Display.primary != null) {
			if (w > kha.Display.primary.width) w = kha.Display.primary.width;
			if (h > kha.Display.primary.height - 30) h = kha.Display.primary.height - 30;
		}

		System.start(
			{
				title: "Koui Editor",
				width: w,
				height: h,
				framebuffer: { samplesPerPixel: 4 }
			},
			initialized
		);
	}

	static function initialized(window: Window) {
		// Register uniforms
		armory.object.Uniforms.register();

		// Initialize Iron
		App.init(function() {
			// Load the scene from the path
			if (scenePath != "") {
				loadSceneFromPath(scenePath);
			} else {
				// No scene provided - create empty scene with default camera
				createEmptyScene();
			}
		});
	}

	static function loadSceneFromPath(path: String) {
		trace("Loading scene from: " + path);

		// Extract scene name from path (e.g., "/path/to/Scene.arm" -> "Scene")
		var parts = path.split("/");
		var filename = parts[parts.length - 1];
		var sceneName = StringTools.replace(filename, ".arm", "");

		// Load scene data from path
		Data.getSceneRaw(sceneName, function(format) {
			if (format == null) {
				trace("Failed to load scene: " + sceneName);
				createEmptyScene();
				return;
			}

			Scene.create(format, function(root) {
				trace("Scene loaded successfully");
				setupRenderPath();
				initEditor();
			});
		});
	}

	static function createEmptyScene() {
		trace("Creating empty scene...");

		// Create a minimal scene with just a camera
		var emptyFormat: iron.data.SceneFormat.TSceneFormat = {
			name: "Empty",
			objects: [],
			camera_datas: [{
				name: "Camera",
				near_plane: 0.1,
				far_plane: 100.0,
				fov: 0.85
			}],
			camera_ref: "Camera",
			material_datas: [],
			shader_datas: [],
			light_datas: [],
			mesh_datas: []
		};

		Scene.create(emptyFormat, function(root) {
			trace("Empty scene created");
			setupRenderPath();
			initEditor();
		});
	}

	static function setupRenderPath() {
		// Set up a basic render path
		RenderPath.setActive(armory.renderpath.RenderPathCreator.get());
	}

	static function initEditor() {
		// Add the Koui Editor trait to the scene
		if (Scene.active != null && Scene.active.root != null) {
			Scene.active.root.addTrait(new arm.KouiEditor());
		}
	}
}
