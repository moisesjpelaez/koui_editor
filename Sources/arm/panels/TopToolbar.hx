package arm.panels;

import arm.base.UIBase;
import armory.system.Signal;
import iron.App;
import kha.graphics2.Graphics;
import zui.Id;
import zui.Zui;

class TopToolbar {
	public var saveRequested: Signal = new Signal();
	public var loadRequested: Signal = new Signal();
	public var snappingToggled: Signal = new Signal(); // args: (enabled: Bool, snapValue: Float)

    public var snappingEnabled: Bool = false;
	public var snapValue: Float = 1.0;

	static inline var TOOLBAR_WIDTH: Int = 185;
	static inline var TOOLBAR_HEIGHT: Int = 36;
	static inline var BUTTON_SIZE: Int = 28;
	static inline var ICON_SIZE: Int = 16;

	var snapHandle: zui.Zui.Handle;

	public function new() {
		snapHandle = new zui.Zui.Handle();
		snapHandle.value = snapValue;
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
			// Row layout: [snap toggle | - | value | + | save | load]
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

            // Snap toggle button
			var savedCol = ui.t.BUTTON_COL;
			if (snappingEnabled) {
				ui.t.BUTTON_COL = ui.t.HIGHLIGHT_COL;
			}
			if (ui.button("", Left)) {
				snappingEnabled = !snappingEnabled;
                snappingToggled.emit(snappingEnabled, snapValue);
			}
			if (ui.isHovered) ui.tooltip("Toggle Snapping");
			ui.t.BUTTON_COL = savedCol;

			// Save button - using icon_folder_save or similar
			if (ui.button("💾", Left)) {
				saveRequested.emit();
			}
			if (ui.isHovered) ui.tooltip("Save Canvas");

			// Load button - using icon_folder_open or similar
			if (ui.button("📁", Left)) {
				loadRequested.emit();
			}
			if (ui.isHovered) ui.tooltip("Load Canvas");
		}

		ui.t.FILL_WINDOW_BG = savedFillBg;
	}
}