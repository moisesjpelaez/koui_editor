package arm.base;

import zui.Zui;
import zui.Zui.Handle;
import iron.App;
import iron.system.Input;
import arm.data.EditorSettings;
import arm.data.LayoutSettings;
import arm.types.Enums;

class UIBase {
	public static var inst: UIBase;
	public var ui: Zui;

	// Window handles for panels
	public var hwnds: Array<Handle>;

	// Border resize state
	var borderStarted: Int = 0;
	var borderHandle: Handle = null;
	var cursorSet: Bool = false;

	// Minimum sizes
	public static inline var MIN_PANEL_SIZE: Int = 64;  // Increased to fit header + content
	public static inline var MIN_SIDEBAR_W: Int = 200;

	public function new(font: kha.Font) {
		inst = this;

		// Initialize handles (top, bottom, center)
		hwnds = [new Handle(), new Handle(), new Handle()];

		// Create Zui instance
		ui = new Zui({
			font: font,
			theme: Base.theme,
			scaleFactor: EditorSettings.getEditorUIScale()
		});

		// Set Zui callbacks
		Zui.onBorderHover = onBorderHover;
	}

	public function update() {
		if (ui == null) return;

		// Skip updates when window is minimized or too small
		if (App.w() < MIN_SIDEBAR_W || App.h() < MIN_PANEL_SIZE * 2) return;

		var mouse: Mouse = Input.getMouse();

		// Clamp sidebar width when window is resized
		var maxW = Std.int(App.w() * 0.7);
		if (maxW < MIN_SIDEBAR_W) maxW = MIN_SIDEBAR_W;
		if (LayoutSettings.sizes[LayoutSidebarW] > maxW) {
			LayoutSettings.sizes[LayoutSidebarW] = maxW;
		}

		// Handle resize dragging
		if (borderHandle != null) {
			// Horizontal resize (left border of sidebar)
			if (borderStarted == SideLeft) {
				LayoutSettings.sizes[LayoutSidebarW] -= Std.int(mouse.movementX);
				// Clamp
				if (LayoutSettings.sizes[LayoutSidebarW] < MIN_SIDEBAR_W) {
					LayoutSettings.sizes[LayoutSidebarW] = MIN_SIDEBAR_W;
				} else if (LayoutSettings.sizes[LayoutSidebarW] > maxW) {
					LayoutSettings.sizes[LayoutSidebarW] = maxW;
				}
			}

			// Vertical resize (between top and bottom panels)
			if (borderStarted == SideBottom || borderStarted == SideTop) {
				var my: Int = Std.int(mouse.movementY);
				// Check if resizing sidebar panels or bottom center panel
				if (borderHandle == hwnds[PanelBottom]) {
					// Bottom center panel - resize by top border
					LayoutSettings.sizes[LayoutBottomH] -= my;
					// Clamp
					var maxBottomH: Int = Std.int(App.h() * 0.7);
					if (LayoutSettings.sizes[LayoutBottomH] < MIN_PANEL_SIZE) {
						LayoutSettings.sizes[LayoutBottomH] = MIN_PANEL_SIZE;
					} else if (LayoutSettings.sizes[LayoutBottomH] > maxBottomH) {
						LayoutSettings.sizes[LayoutBottomH] = maxBottomH;
					}
				} else {
					// Sidebar panels
					if (LayoutSettings.sizes[LayoutSidebarH0] + my > MIN_PANEL_SIZE &&
						LayoutSettings.sizes[LayoutSidebarH1] - my > MIN_PANEL_SIZE) {
						LayoutSettings.sizes[LayoutSidebarH0] += my;
						LayoutSettings.sizes[LayoutSidebarH1] -= my;
					}
				}
			}
		}

		// Stop resizing when mouse released
		if (!mouse.down()) {
			if (borderHandle != null) {
				borderHandle = null;
				Base.isResizing = false;
				Krom.setMouseCursor(Cursor.Default);
				// Remembered for the next time the editor opens
				LayoutSettings.save();
			}
		}

		// Reset cursor only when mouse moves and not hovering any border
		// This allows the OS to show its own resize cursors when near window edges
		if (mouse.movementX != 0 || mouse.movementY != 0) {
			if (cursorSet) {
				cursorSet = false;
			} else if (borderHandle == null) {
				Krom.setMouseCursor(Cursor.Default);
			}
		}
	}

	/** Shows `cursor` until the mouse moves without anything setting it again. */
	public function setCursor(cursor: Cursor): Void {
		Krom.setMouseCursor(cursor);
		cursorSet = true;
	}

	/** Redraws the Hierarchy and Properties panels, after the canvas or the selection changed. */
	public function redrawPanels(): Void {
		hwnds[PanelHierarchy].redraws = 2;
		hwnds[PanelProperties].redraws = 2;
	}

	function onBorderHover(handle: Handle, side: Int) {
		// Only handle our panels
		if (handle != hwnds[PanelHierarchy] && handle != hwnds[PanelProperties] && handle != hwnds[PanelBottom]) return;

		// Top panel: respond to left and bottom borders
		if (handle == hwnds[PanelHierarchy] && side != SideLeft && side != SideBottom) return;

		// Bottom panel: respond to left and top borders
		if (handle == hwnds[PanelProperties] && side != SideLeft && side != SideTop) return;

		// Center panel: respond to top border only
		if (handle == hwnds[PanelBottom] && side != SideTop) return;

		setCursor(side == SideLeft || side == SideRight ? ResizeHorizontal : ResizeVertical);

		// Start resizing on mouse down
		if (ui.inputStarted) {
			borderStarted = side;
			borderHandle = handle;
			Base.isResizing = true;
		}
	}

	public function getTabX(): Int {
		var w: Int = App.w();
		if (w < MIN_SIDEBAR_W) return 0; // Window minimized or too small
		var sidebarW: Int = LayoutSettings.sizes[LayoutSidebarW];
		if (sidebarW > w - MIN_PANEL_SIZE) sidebarW = w - MIN_PANEL_SIZE;
		return w - sidebarW;
	}

	public function getSidebarW(): Int {
		var w: Int = App.w();
		if (w < MIN_SIDEBAR_W) return MIN_SIDEBAR_W; // Return minimum when window too small
		var sidebarW: Int = LayoutSettings.sizes[LayoutSidebarW];
		if (sidebarW > w - MIN_PANEL_SIZE) return w - MIN_PANEL_SIZE;
		if (sidebarW < MIN_SIDEBAR_W) return MIN_SIDEBAR_W;
		return sidebarW;
	}

	public function getSidebarH0(): Int {
		var h: Int = LayoutSettings.sizes[LayoutSidebarH0];
		if (h < MIN_PANEL_SIZE) return MIN_PANEL_SIZE;
		return h;
	}

	public function getSidebarH1(): Int {
		var h: Int = LayoutSettings.sizes[LayoutSidebarH1];
		if (h < MIN_PANEL_SIZE) return MIN_PANEL_SIZE;
		return h;
	}

	public function getBottomH(): Int {
		var h: Int = LayoutSettings.sizes[LayoutBottomH];
		if (h < MIN_PANEL_SIZE) return MIN_PANEL_SIZE;
		return h;
	}

	public function adjustHeightsToWindow() {
		var totalH: Int = App.h();

		// Skip adjustment if window is minimized or too small
		if (totalH < MIN_PANEL_SIZE * 2) return;

		var currentTotal = LayoutSettings.sizes[LayoutSidebarH0] + LayoutSettings.sizes[LayoutSidebarH1];

		// If heights are corrupted (zero or too small), reset to defaults
		if (currentTotal < MIN_PANEL_SIZE * 2) {
			LayoutSettings.sizes[LayoutSidebarH0] = Std.int(totalH / 2);
			LayoutSettings.sizes[LayoutSidebarH1] = totalH - LayoutSettings.sizes[LayoutSidebarH0];
		} else if (currentTotal != totalH) {
			var ratio = LayoutSettings.sizes[LayoutSidebarH0] / currentTotal;
			LayoutSettings.sizes[LayoutSidebarH0] = Std.int(totalH * ratio);
			LayoutSettings.sizes[LayoutSidebarH1] = totalH - LayoutSettings.sizes[LayoutSidebarH0];
		}

		// Ensure minimum sizes
		if (LayoutSettings.sizes[LayoutSidebarH0] < MIN_PANEL_SIZE) {
			LayoutSettings.sizes[LayoutSidebarH0] = MIN_PANEL_SIZE;
			LayoutSettings.sizes[LayoutSidebarH1] = totalH - MIN_PANEL_SIZE;
		}
		if (LayoutSettings.sizes[LayoutSidebarH1] < MIN_PANEL_SIZE) {
			LayoutSettings.sizes[LayoutSidebarH1] = MIN_PANEL_SIZE;
			LayoutSettings.sizes[LayoutSidebarH0] = totalH - MIN_PANEL_SIZE;
		}

		// Clamp bottom panel height
		var maxBottomH = Std.int(App.h() * 0.7);
		if (LayoutSettings.sizes[LayoutBottomH] > maxBottomH) {
			LayoutSettings.sizes[LayoutBottomH] = maxBottomH;
		}
		if (LayoutSettings.sizes[LayoutBottomH] < MIN_PANEL_SIZE) {
			LayoutSettings.sizes[LayoutBottomH] = MIN_PANEL_SIZE;
		}
	}
}
