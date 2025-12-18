package arm.panels;

import arm.base.UIBase;
import arm.tools.CanvasUtils;
import arm.tools.ImageUtils;
import arm.tools.ZuiUtils;
import armory.system.Signal;
import iron.App;
import kha.Image;
import zui.Id;
import zui.Zui;
import zui.Zui.Handle;
using zui.Ext;

@:access(zui.Zui)
class TopToolbar {
	public var snappingToggled: Signal = new Signal(); // args: (enabled: Bool, snapValue: Float)
	public var snapValueChanged: Signal = new Signal(); // args: (snapValue: Float)

    public var snappingEnabled: Bool = false;
	public var snapValue: Float = 1.0;

	static inline var TOOLBAR_WIDTH: Int = 378;
	static inline var TOOLBAR_HEIGHT: Int = 32;
	static inline var BUTTON_SIZE: Int = 28;
	static inline var ICON_SIZE: Int = 50; // Icon tile size in atlas

	var snapHandle: Handle;
	var icons: Image;

	public function new() {
		snapHandle = new Handle();
		snapHandle.value = snapValue;
	}

	// Wrapper for ZuiUtils.iconButton with local icons
	function iconButton(ui: Zui, tileX: Int, tileY: Int, tooltip: String, highlight: Bool = false): Bool {
		return ZuiUtils.iconButton(ui, icons, tileX, tileY, tooltip, highlight);
	}

	function hSeparator(ui: Zui, w: Float = 1, spacing: Float = 8): Void {
		var sepH: Float = BUTTON_SIZE - 8;

		// Add spacing before the line
		ui._x += spacing;

		// Draw the vertical line
		var startX: Float = ui._x;
		var startY: Float = ui._y + (ui.ELEMENT_H() - sepH) / 2;
		ui.g.color = ui.t.SEPARATOR_COL;
		ui.g.fillRect(startX, startY, w, sepH);

		// Add spacing after the line
		ui._x += w + spacing;
	}

	public function draw(uiBase: UIBase): Void {
		var ui: Zui = uiBase.ui;

		// Calculate center position
		var centerX: Int = Std.int((App.w() - uiBase.getSidebarW()) / 2 - TOOLBAR_WIDTH / 2);
		var topY: Int = 5;

		// Don't fill background, make it floating
		var savedFillBg: Bool = ui.t.FILL_WINDOW_BG;
		ui.t.FILL_WINDOW_BG = false;

		if (ui.window(Id.handle(), centerX, topY, TOOLBAR_WIDTH, TOOLBAR_HEIGHT, false)) {
			// Center elements vertically within the toolbar
			var yOffset: Float = (TOOLBAR_HEIGHT - BUTTON_SIZE) / 2;
			ui._y += yOffset;

			ui.row([
				BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH,
				BUTTON_SIZE / TOOLBAR_WIDTH, BUTTON_SIZE / TOOLBAR_WIDTH,
				BUTTON_SIZE / TOOLBAR_WIDTH,
				BUTTON_SIZE / TOOLBAR_WIDTH, (BUTTON_SIZE * 4) / TOOLBAR_WIDTH]);

			ui._x += 8; // Small padding on the left
			if (iconButton(ui, 3, 1, "Clear Canvas")) {
				CanvasUtils.clearCanvas();
			}
			if (iconButton(ui, 2, 2, "Load Canvas")) {
				CanvasUtils.loadCanvas();
			}
			if (iconButton(ui, 3, 2, "Save Canvas")) {
				CanvasUtils.saveCanvas();
			}
			hSeparator(ui);

			if (iconButton(ui, 6, 2, "Undo")) {
				// CanvasUtils.undo();
			}
			if (iconButton(ui, 7, 2, "Redo")) {
				// CanvasUtils.redo();
			}
			hSeparator(ui);

			if (iconButton(ui, 5, 0, "Reload Theme")) {
				CanvasUtils.refreshTheme();
			}
			hSeparator(ui);

			if (iconButton(ui, 0, 3, "Toggle Snapping", snappingEnabled)) {
				snappingEnabled = !snappingEnabled;
                snappingToggled.emit(snappingEnabled, snapValue);
			}
			ui._x += 4; // Small padding on the left
			snapValue = ui.slider(snapHandle, "Snap", 0.5, 10.0, false, 2, true, Align.Right, false);
			if (ui.isHovered) ui.tooltip("Grid Snap Value");
			if (snapHandle.changed && snappingEnabled) {
				snapValueChanged.emit(snapValue);
			}

			ui._y -= yOffset;
		}

		ui.t.FILL_WINDOW_BG = savedFillBg;
	}

    public function setIcons(iconsImage: Image): Void {
        icons = iconsImage;
    }
}