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
	public var saveRequested: Signal = new Signal();
	public var loadRequested: Signal = new Signal();
	public var snappingToggled: Signal = new Signal(); // args: (enabled: Bool, snapValue: Float)

    public var snappingEnabled: Bool = false;
	public var snapValue: Float = 1.0;

	static inline var TOOLBAR_WIDTH: Int = 185;
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
	function iconButton(ui: Zui, tileX: Int, tileY: Int, highlight: Bool = false): Bool {
		if (icons == null) return ui.button("?");

		var col = ui.t.WINDOW_BG_COL;
		if (col < 0) col += untyped 4294967296;
		var light = col > 0xff666666 + 4294967296;
		var iconAccent = light ? 0xff666666 : 0xffaaaaaa;

		if (highlight) {
			iconAccent = ui.t.HIGHLIGHT_COL;
		}

		var rect = ImageUtils.tile50(tileX, tileY);
		return ImageUtils.image(ui, icons, iconAccent, null, rect.x, rect.y, rect.w, rect.h) == State.Released;
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
			// Row layout: [- | value | + | snap toggle | save | load]
			ui.row([BUTTON_SIZE / TOOLBAR_WIDTH, 0.25, BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH]);

			// Decrease snap value
			if (ui.button("-", Left)) {
				snapValue = Math.max(0.5, snapValue - 0.5);
				snapHandle.value = snapValue;
			}
			if (ui.isHovered) ui.tooltip("Decrease Snap Value");

			// Snap value display
			snapHandle.text = Std.string(snapValue);
			var newText: String = ui.textInput(snapHandle, "", Center);
			if (snapHandle.changed) {
				var parsed: Float = Std.parseFloat(newText);
				if (!Math.isNaN(parsed) && parsed >= 0.5) {
					snapValue = parsed;
				}
			}

			// Increase snap value
			if (ui.button("+", Left)) {
				snapValue += 0.5;
				snapHandle.value = snapValue;
			}
			if (ui.isHovered) ui.tooltip("Increase Snap Value");

            // Snap toggle button (using grid icon at position 0,3)
			if (iconButton(ui, 0, 3, snappingEnabled)) {
				snappingEnabled = !snappingEnabled;
                snappingToggled.emit(snappingEnabled, snapValue);
			}
			if (ui.isHovered) ui.tooltip("Toggle Snapping");

			// Load button (using import/open icon at position 2,2)
			if (iconButton(ui, 2, 2, false)) {
				loadRequested.emit();
			}
			if (ui.isHovered) ui.tooltip("Load Canvas");

			// Save button (using save/export icon at position 3,2)
			if (iconButton(ui, 3, 2, false)) {
				saveRequested.emit();
			}
			if (ui.isHovered) ui.tooltip("Save Canvas");
		}

		ui.t.FILL_WINDOW_BG = savedFillBg;
	}

    public function setIcons(iconsImage: Image): Void {
        icons = iconsImage;
    }
}