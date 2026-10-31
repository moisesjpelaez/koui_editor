package arm.data;

import haxe.Json;

typedef TEditorSettings = {
	?editorUIScale: Float,
	?snapEnabled: Bool,
	?snapValue: Float,
	/** The panel sizes, see `LayoutSettings`. */
	?layout: Array<Int>,
}

class EditorSettings {
	public static var data: TEditorSettings = {
		editorUIScale: 1.0,
		snapEnabled: false,
		snapValue: 8.0,
		layout: null,
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
				if (Std.isOfType(loaded.snapEnabled, Bool)) data.snapEnabled = loaded.snapEnabled;
				// The toolbar keeps the value within its range
				if (Std.isOfType(loaded.snapValue, Float) && Math.isFinite(loaded.snapValue)) data.snapValue = loaded.snapValue;
				// LayoutSettings checks the sizes
				if (Std.isOfType(loaded.layout, Array)) data.layout = loaded.layout;
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
	 * The settings file, in the editor's own folder: the game's Bundled/ folder is packed into every build
	 */
	private static function getSettingsPath(): String {
		return arm.tools.CanvasUtils.editorDataDir() + "/koui_editor_settings.json";
	}

	/**
	 * Get the editor UI scale setting
	 */
	public static function getEditorUIScale(): Float {
		if (!initialized) init();
		var scale = data.editorUIScale;
		return sanitizeScale(scale != null ? scale : 1.0);
	}

	/** Remembers the grid snapping toggle and size, and saves them to file. */
	public static function setSnap(enabled: Bool, value: Float): Void {
		if (!initialized) init();
		if (data.snapEnabled == enabled && data.snapValue == value) return;
		data.snapEnabled = enabled;
		data.snapValue = value;
		save();
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
