package arm;

import zui.Zui;
import zui.Zui.Handle;
import iron.App;
import iron.system.Input;
import arm.Enums;

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
			scaleFactor: Config.raw.window_scale
		});

		// Set Zui callbacks
		Zui.onBorderHover = onBorderHover;
	}

	public function update() {
		if (ui == null) return;

		// Skip updates when window is minimized or too small
		if (App.w() < MIN_SIDEBAR_W || App.h() < MIN_PANEL_SIZE * 2) return;

		var mouse = Input.getMouse();

		// Clamp sidebar width when window is resized
		var maxW = Std.int(App.w() * 0.7);
		if (maxW < MIN_SIDEBAR_W) maxW = MIN_SIDEBAR_W;
		if (Config.raw.layout[LayoutSidebarW] > maxW) {
			Config.raw.layout[LayoutSidebarW] = maxW;
		}

		// Handle resize dragging
		if (borderHandle != null) {
			// Horizontal resize (left border of sidebar)
			if (borderStarted == SideLeft) {
				Config.raw.layout[LayoutSidebarW] -= Std.int(mouse.movementX);
				// Clamp
				if (Config.raw.layout[LayoutSidebarW] < MIN_SIDEBAR_W) {
					Config.raw.layout[LayoutSidebarW] = MIN_SIDEBAR_W;
				} else if (Config.raw.layout[LayoutSidebarW] > maxW) {
					Config.raw.layout[LayoutSidebarW] = maxW;
				}
			}

			// Vertical resize (between top and bottom panels)
			if (borderStarted == SideBottom || borderStarted == SideTop) {
				var my = Std.int(mouse.movementY);
				// Check if resizing sidebar panels or bottom center panel
				if (borderHandle == hwnds[PanelBottom]) {
					// Bottom center panel - resize by top border
					Config.raw.layout[LayoutBottomH] -= my;
					// Clamp
					var maxBottomH = Std.int(App.h() * 0.7);
					if (Config.raw.layout[LayoutBottomH] < MIN_PANEL_SIZE) {
						Config.raw.layout[LayoutBottomH] = MIN_PANEL_SIZE;
					} else if (Config.raw.layout[LayoutBottomH] > maxBottomH) {
						Config.raw.layout[LayoutBottomH] = maxBottomH;
					}
				} else {
					// Sidebar panels
					if (Config.raw.layout[LayoutSidebarH0] + my > MIN_PANEL_SIZE &&
					    Config.raw.layout[LayoutSidebarH1] - my > MIN_PANEL_SIZE) {
						Config.raw.layout[LayoutSidebarH0] += my;
						Config.raw.layout[LayoutSidebarH1] -= my;
					}
				}
			}
		}

		// Stop resizing when mouse released
		if (!mouse.down()) {
			if (borderHandle != null) {
				borderHandle = null;
				Base.isResizing = false;
				Krom.setMouseCursor(0); // Reset cursor
			}
		}

		// Reset cursor only when mouse moves and not hovering any border
		// This allows the OS to show its own resize cursors when near window edges
		if (mouse.movementX != 0 || mouse.movementY != 0) {
			if (cursorSet) {
				cursorSet = false;
			} else if (borderHandle == null) {
				Krom.setMouseCursor(0); // Default cursor
			}
		}
	}

	function onBorderHover(handle: Handle, side: Int) {
		if (!Base.uiEnabled) return;

		// Only handle our panels
		if (handle != hwnds[PanelHierarchy] && handle != hwnds[PanelProperties] && handle != hwnds[PanelBottom]) return;

		// Top panel: respond to left and bottom borders
		if (handle == hwnds[PanelHierarchy] && side != SideLeft && side != SideBottom) return;

		// Bottom panel: respond to left and top borders
		if (handle == hwnds[PanelProperties] && side != SideLeft && side != SideTop) return;

		// Center panel: respond to top border only
		if (handle == hwnds[PanelBottom] && side != SideTop) return;

		// Set cursor based on resize direction
		if (side == SideLeft || side == SideRight) {
			Krom.setMouseCursor(3); // Horizontal resize cursor
		} else {
			Krom.setMouseCursor(4); // Vertical resize cursor
		}
		cursorSet = true;

		// Start resizing on mouse down
		if (ui.inputStarted) {
			borderStarted = side;
			borderHandle = handle;
			Base.isResizing = true;
		}
	}

	public function getTabX(): Int {
		var w = App.w();
		if (w < MIN_SIDEBAR_W) return 0; // Window minimized or too small
		var sidebarW = Config.raw.layout[LayoutSidebarW];
		if (sidebarW > w - MIN_PANEL_SIZE) sidebarW = w - MIN_PANEL_SIZE;
		return w - sidebarW;
	}

	public function getSidebarW(): Int {
		var w = App.w();
		if (w < MIN_SIDEBAR_W) return MIN_SIDEBAR_W; // Return minimum when window too small
		var sidebarW = Config.raw.layout[LayoutSidebarW];
		if (sidebarW > w - MIN_PANEL_SIZE) return w - MIN_PANEL_SIZE;
		if (sidebarW < MIN_SIDEBAR_W) return MIN_SIDEBAR_W;
		return sidebarW;
	}

	public function getSidebarH0(): Int {
		var h = Config.raw.layout[LayoutSidebarH0];
		if (h < MIN_PANEL_SIZE) return MIN_PANEL_SIZE;
		return h;
	}

	public function getSidebarH1(): Int {
		var h = Config.raw.layout[LayoutSidebarH1];
		if (h < MIN_PANEL_SIZE) return MIN_PANEL_SIZE;
		return h;
	}

	public function getBottomH(): Int {
		var h = Config.raw.layout[LayoutBottomH];
		if (h < MIN_PANEL_SIZE) return MIN_PANEL_SIZE;
		return h;
	}

	public function adjustHeightsToWindow() {
		var totalH = App.h();

		// Skip adjustment if window is minimized or too small
		if (totalH < MIN_PANEL_SIZE * 2) return;

		var currentTotal = Config.raw.layout[LayoutSidebarH0] + Config.raw.layout[LayoutSidebarH1];

		// If heights are corrupted (zero or too small), reset to defaults
		if (currentTotal < MIN_PANEL_SIZE * 2) {
			Config.raw.layout[LayoutSidebarH0] = Std.int(totalH / 2);
			Config.raw.layout[LayoutSidebarH1] = totalH - Config.raw.layout[LayoutSidebarH0];
		} else if (currentTotal != totalH) {
			var ratio = Config.raw.layout[LayoutSidebarH0] / currentTotal;
			Config.raw.layout[LayoutSidebarH0] = Std.int(totalH * ratio);
			Config.raw.layout[LayoutSidebarH1] = totalH - Config.raw.layout[LayoutSidebarH0];
		}

		// Ensure minimum sizes
		if (Config.raw.layout[LayoutSidebarH0] < MIN_PANEL_SIZE) {
			Config.raw.layout[LayoutSidebarH0] = MIN_PANEL_SIZE;
			Config.raw.layout[LayoutSidebarH1] = totalH - MIN_PANEL_SIZE;
		}
		if (Config.raw.layout[LayoutSidebarH1] < MIN_PANEL_SIZE) {
			Config.raw.layout[LayoutSidebarH1] = MIN_PANEL_SIZE;
			Config.raw.layout[LayoutSidebarH0] = totalH - MIN_PANEL_SIZE;
		}

		// Clamp bottom panel height
		var maxBottomH = Std.int(App.h() * 0.7);
		if (Config.raw.layout[LayoutBottomH] > maxBottomH) {
			Config.raw.layout[LayoutBottomH] = maxBottomH;
		}
		if (Config.raw.layout[LayoutBottomH] < MIN_PANEL_SIZE) {
			Config.raw.layout[LayoutBottomH] = MIN_PANEL_SIZE;
		}
	}
}
