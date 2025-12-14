package arm.panels;

import arm.base.UIBase;
import arm.tools.ImageUtils;
import armory.system.Signal;
import iron.App;
import kha.Image;
import zui.Id;
import zui.Zui;
import zui.Zui.Handle;
import zui.Zui.State;

class TopToolbar {
	public var themeReloadRequested: Signal = new Signal();
	public var saveRequested: Signal = new Signal();
	public var loadRequested: Signal = new Signal();
	public var snappingToggled: Signal = new Signal(); // args: (enabled: Bool, snapValue: Float)
	public var snapValueChanged: Signal = new Signal(); // args: (snapValue: Float)

    public var snappingEnabled: Bool = false;
	public var snapValue: Float = 1.0;

	static inline var TOOLBAR_WIDTH: Int = 224;
	static inline var TOOLBAR_HEIGHT: Int = 36;
	static inline var BUTTON_SIZE: Int = 28;
	static inline var ICON_SIZE: Int = 50; // Icon tile size in atlas

	var snapHandle: Handle;
	var icons: Image;

	public function new() {
		snapHandle = new Handle();
		snapHandle.value = snapValue;
	}

	// Draw an icon button and return true if clicked
	function iconButton(ui: Zui, tileX: Int, tileY: Int, tooltip: String, highlight: Bool = false): Bool {
		if (icons == null) return ui.button("?");

		var col = ui.t.WINDOW_BG_COL;
		if (col < 0) col += untyped 4294967296;
		var light = col > 0xff666666 + 4294967296;

		// Base color
		var iconAccent = light ? 0xff666666 : 0xffaaaaaa;

		if (highlight) {
			iconAccent = ui.t.HIGHLIGHT_COL;
		}

		// Store position before drawing
		@:privateAccess var startX = ui._x;
		@:privateAccess var startY = ui._y;

		var rect = ImageUtils.tile50(tileX, tileY);
		ui.g.pipeline = ImageUtils.getPipeline();
		var state = ui.image(icons, iconAccent, null, rect.x, rect.y, rect.w, rect.h);
		ui.g.pipeline = null;

		// Apply hover and pressed visual feedback on top of the icon
		@:privateAccess {
			if (state == State.Down || state == State.Started) {
				// Pressed - draw darker overlay
				ui.g.color = 0x55000000;
				ui.g.fillRect(startX, startY, ui._w, ui.ELEMENT_H());
			}
			else if (state == State.Hovered) {
				// Hovered - draw light overlay
				ui.g.color = 0x33ffffff;
				ui.g.fillRect(startX, startY, ui._w, ui.ELEMENT_H());
			}
		}

		if (ui.isHovered) ui.tooltip(tooltip);
		return state == State.Released;
	}

	public function draw(uiBase: UIBase): Void {
		var ui = uiBase.ui;

		// Calculate center position
		var centerX: Int = Std.int((App.w() - uiBase.getSidebarW()) / 2 - TOOLBAR_WIDTH / 2);
		var topY: Int = 5;

		// Don't fill background, make it floating
		var savedFillBg = ui.t.FILL_WINDOW_BG;
		ui.t.FILL_WINDOW_BG = false;

		if (ui.window(Id.handle(), centerX, topY, TOOLBAR_WIDTH, TOOLBAR_HEIGHT, false)) {
			ui.row([0.5, BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH]);

			// Snap value slider (0.5 to 10, step by 0.5)
			snapValue = ui.slider(snapHandle, "Snap", 0.5, 10.0, false, 2, true, Align.Right, false);
			if (ui.isHovered) ui.tooltip("Grid Snap Value");
			if (snapHandle.changed && snappingEnabled) {
				snapValueChanged.emit(snapValue);
			}

            // Snap toggle button (using grid icon at position 0,3)
			if (iconButton(ui, 0, 3, "Toggle Snapping", snappingEnabled)) {
				snappingEnabled = !snappingEnabled;
                snappingToggled.emit(snappingEnabled, snapValue);
			}

			if (iconButton(ui, 5, 0, "Reload Theme")) {
				// Load ui_override.ksn from Assets directory
				var basePath = Krom.getFilesLocation();
				var assetsPaths = [
					basePath + "/../../../../Assets/ui_override.ksn",
					basePath + "/../../../Assets/ui_override.ksn",
				];
				var assetsPath: String = "";

				var blob: js.lib.ArrayBuffer = null;
				for (path in assetsPaths) {
					var _blob = Krom.loadBlob(path);
					if (_blob != null) {
						assetsPath = path;
						blob = _blob;
						break;
					}
				}

				if (blob != null) {
					var themeContent = haxe.io.Bytes.ofData(blob).toString();
					var error = koui.theme.RuntimeThemeLoader.parseAndApply(themeContent);

					if (error != null) {
						trace('Theme reload ERROR: ${error}');
					} else {
						var buildPath = basePath + "/ui_override.ksn";
						try {
						var bytes = haxe.io.Bytes.ofString(themeContent);
						Krom.fileSaveBytes(buildPath, bytes.getData());
							trace('Theme reloaded successfully from: ${assetsPath}');
							trace('Theme copied to build directory: ${buildPath}');
						} catch (e: Dynamic) {
							trace('Theme reloaded but failed to copy to build directory: ${e}');
						}
					}
				} else {
					trace('Theme file not found: ${assetsPath}');
				}
			}

			// Load button (using import/open icon at position 2,2)
			if (iconButton(ui, 2, 2, "Load Canvas")) {
				loadRequested.emit();
			}

			// Save button (using save/export icon at position 3,2)
			if (iconButton(ui, 3, 2, "Save Canvas")) {
				saveRequested.emit();
			}
		}

		ui.t.FILL_WINDOW_BG = savedFillBg;
	}

    public function setIcons(iconsImage: Image): Void {
        icons = iconsImage;
    }
}