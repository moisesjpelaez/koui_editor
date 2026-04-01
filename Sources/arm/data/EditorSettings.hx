package arm.data;

import haxe.Json;

typedef TEditorSettings = {
	?editorUIScale: Float,
}

class EditorSettings {
	public static var data: TEditorSettings = {
		editorUIScale: 1.0,
	};

	private static var initialized: Bool = false;

	private static inline function sanitizeScale(scale: Float): Float {
		if (Math.isNaN(scale) || !Math.isFinite(scale)) return 1.0;
		return Math.max(0.5, Math.min(4.0, scale));
	}

	/**
	 * Initialize settings and load from file if it exists
	 */
	public static function init(): Void {
		if (initialized) return;
		initialized = true;

		var blob: js.lib.ArrayBuffer = Krom.loadBlob(getSettingsPath());
		if (blob != null) {
			try {
				var jsonString: String = haxe.io.Bytes.ofData(blob).toString();
				var loaded: TEditorSettings = Json.parse(jsonString);

				if (loaded.editorUIScale != null) {
					data.editorUIScale = sanitizeScale(loaded.editorUIScale);
				}
			} catch (e: Dynamic) {
				trace("Failed to load editor settings: " + Std.string(e));
			}
		}
	}

	/**
	 * Save current settings to file
	 */
	public static function save(): Void {
		try {
			var jsonString: String = Json.stringify(data, null, "\t");
			var bytes: haxe.io.Bytes = haxe.io.Bytes.ofString(jsonString);
			Krom.fileSaveBytes(getSettingsPath(), bytes.getData());
		} catch (e: Dynamic) {
			trace("Failed to save editor settings: " + Std.string(e));
		}
	}

	/**
	 * Get the full path to the settings file
	 */
	private static function getSettingsPath(): String {
		var projectDir = arm.tools.CanvasUtils.projectDir;
		if (projectDir != "") {
			return projectDir + "/Bundled/koui_editor_settings.json";
		}
		return "Bundled/koui_editor_settings.json";
	}

	/**
	 * Get the editor UI scale setting
	 */
	public static function getEditorUIScale(): Float {
		if (!initialized) init();
		var scale = data.editorUIScale;
		return sanitizeScale(scale != null ? scale : 1.0);
	}

	/**
	 * Set the editor UI scale and save to file
	 */
	public static function setEditorUIScale(scale: Float): Void {
		if (!initialized) init();
		data.editorUIScale = sanitizeScale(scale);
		save();
	}
}
