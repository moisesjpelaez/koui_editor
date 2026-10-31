package arm.panels;

import arm.data.EditorSettings;
import arm.base.UIBase;
import arm.CanvasViewport.TScreenRect;
import arm.data.History;
import arm.tools.CanvasUtils;
import arm.tools.ZuiUtils;
import arm.types.Enums.PanelHandle;
import iron.App;
import kha.Image;
import zui.Id;
import zui.Zui;
import zui.Zui.Handle;

@:access(zui.Zui)
class TopToolbar {

	public var snappingEnabled: Bool = false;
	public var snapValue: Float = 8.0;
	public var snapMaxValue: Float = 288.0;
	/** Set while a drag is going on with Ctrl held: snapping is inverted. */
	public var snapInverted: Bool = false;

	/** The snap size steps by this much (Ctrl+[ / Ctrl+]). */
	public static inline var SNAP_STEP: Float = 8;

	static inline var TOOLBAR_WIDTH: Int = 378;
	static inline var TOOLBAR_HEIGHT: Int = 32;
	static inline var BUTTON_SIZE: Int = 28;

	var snapHandle: Handle;
	var windowHandle: Handle;
	var icons: Image;

	public function new() {
		snapHandle = new Handle();
		snapHandle.value = snapValue;
		windowHandle = Id.handle();

	}

	/** Whether moving elements snaps to the grid right now: the toggle, inverted while Ctrl is held during a drag. */
	public function isSnapping(): Bool {
		return snappingEnabled != snapInverted;
	}

	public function toggleSnapping(): Void {
		snappingEnabled = !snappingEnabled;
		EditorSettings.setSnap(snappingEnabled, snapValue);
	}

	/** Takes the snapping toggle and size saved in the editor's settings; the size is kept within `snapMaxValue`. */
	public function applySavedSnap(): Void {
		snappingEnabled = EditorSettings.data.snapEnabled;
		setSnapValue(EditorSettings.data.snapValue);
	}

	/** Sets the snap size, rounded to a multiple of SNAP_STEP within the slider's range. */
	public function setSnapValue(value: Float): Void {
		value = Math.round(value / SNAP_STEP) * SNAP_STEP;
		value = Math.max(SNAP_STEP, Math.min(snapMaxValue, value));
		if (value == snapValue) return;
		snapValue = value;
		snapHandle.value = value;
		EditorSettings.setSnap(snappingEnabled, snapValue);
	}

	// Wrapper for ZuiUtils.iconButton with local icons
	function iconButton(ui: Zui, tileX: Int, tileY: Int, tooltip: String, highlight: Bool = false, disabled: Bool = false): Bool {
		return ZuiUtils.iconButton(ui, icons, tileX, tileY, tooltip, highlight, disabled);
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

	/** Where the toolbar floats over the canvas, centered at the top, in screen pixels. */
	public function getRect(uiBase: UIBase): TScreenRect {
		var uiScale: Float = uiBase.ui.SCALE();
		var w: Int = Std.int(TOOLBAR_WIDTH * uiScale);
		return {
			x: Std.int((App.w() - uiBase.getSidebarW()) / 2 - w / 2),
			y: Std.int(5 * uiScale),
			w: w,
			h: Std.int(TOOLBAR_HEIGHT * uiScale)
		};
	}

	public function draw(uiBase: UIBase): Void {
		var ui: Zui = uiBase.ui;
		var uiScale: Float = ui.SCALE();
		var rect: TScreenRect = getRect(uiBase);
		var toolbarWidth: Int = rect.w;
		var toolbarHeight: Int = rect.h;
		var buttonSize: Int = Std.int(BUTTON_SIZE * uiScale);
		var centerX: Int = rect.x;
		var topY: Int = rect.y;

		// Don't fill background, make it floating
		var savedFillBg: Bool = ui.t.FILL_WINDOW_BG;
		ui.t.FILL_WINDOW_BG = false;

		if (ui.window(windowHandle, centerX, topY, toolbarWidth, toolbarHeight, false)) {
			// Center elements vertically within the toolbar
			var yOffset: Float = (toolbarHeight - buttonSize) / 2;
			ui._y += yOffset;

			ui.row([
				buttonSize / toolbarWidth, buttonSize / toolbarWidth, buttonSize / toolbarWidth,
				buttonSize / toolbarWidth, buttonSize / toolbarWidth,
				buttonSize / toolbarWidth,
				buttonSize / toolbarWidth, (buttonSize * 4) / toolbarWidth]);

			ui._x += 8 * uiScale; // Small padding on the left
			if (iconButton(ui, 3, 1, "Clear Canvas (Ctrl+N)")) {
				CanvasUtils.clearToEmptyScene();
			}
			if (iconButton(ui, 2, 2, "Load Canvas (Ctrl+O)")) {
				CanvasUtils.loadCanvas();
			}
			if (iconButton(ui, 3, 2, "Save Canvas (Ctrl+S)")) {
				CanvasUtils.saveCanvas();
			}
			hSeparator(ui, 1 * uiScale, 8 * uiScale);

			if (iconButton(ui, 6, 2, "Undo (Ctrl+Z)", false, !History.canUndo())) {
				if (History.undo()) {
					uiBase.redrawPanels();
				}
			}
			if (iconButton(ui, 7, 2, "Redo (Ctrl+Shift+Z / Ctrl+Y)", false, !History.canRedo())) {
				if (History.redo()) {
					uiBase.redrawPanels();
				}
			}
			hSeparator(ui, 1 * uiScale, 8 * uiScale);

			if (iconButton(ui, 5, 0, "Reload Theme (Ctrl+R)")) {
				CanvasUtils.refreshTheme();
			}
			hSeparator(ui, 1 * uiScale, 8 * uiScale);

			if (iconButton(ui, 0, 3, "Toggle Snapping (Shift+S; hold Ctrl while dragging to invert, Shift to lock the axis or keep proportions)", isSnapping())) {
				toggleSnapping();
			}
			ui._x += 4 * uiScale; // Small padding on the left
			snapHandle.value = snapValue;
			var newSnapValue: Float = ui.slider(snapHandle, "Snap", SNAP_STEP, snapMaxValue, true, 1 / SNAP_STEP, true, Align.Right);
			if (snapHandle.changed) setSnapValue(newSnapValue);
			if (ui.isHovered) ui.tooltip("Grid Snap Value (Ctrl+[ / Ctrl+])");

			ui._y -= yOffset;
		}

		ui.t.FILL_WINDOW_BG = savedFillBg;
	}

	public function setIcons(iconsImage: Image): Void {
		icons = iconsImage;
	}

}