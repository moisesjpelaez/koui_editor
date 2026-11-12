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

	// Indexed by PanelHandle
	public var hwnds: Array<Handle>;

	// Dragging a panel border
	var borderStarted: Int = 0;
	var borderHandle: Handle = null;
	var cursorSet: Bool = false;

	public static inline var MIN_PANEL_SIZE: Int = 64; // Fits a header and some content
	public static inline var MIN_SIDEBAR_W: Int = 200;

	public function new(font: kha.Font) {
		inst = this;

		hwnds = [new Handle(), new Handle(), new Handle()];

		ui = new Zui({
			font: font,
			theme: Base.theme,
			scaleFactor: EditorSettings.getEditorUIScale()
		});

		Zui.onBorderHover = onBorderHover;
	}

	public function update() {
		if (ui == null) return;

		// Minimized or too small
		if (App.w() < MIN_SIDEBAR_W || App.h() < MIN_PANEL_SIZE * 2) return;

		var mouse: Mouse = Input.getMouse();

		var maxW = Std.int(App.w() * 0.7);
		if (maxW < MIN_SIDEBAR_W) maxW = MIN_SIDEBAR_W;
		if (LayoutSettings.sizes[LayoutSidebarW] > maxW) {
			LayoutSettings.sizes[LayoutSidebarW] = maxW;
		}

		if (borderHandle != null) {
			// The sidebar's left border
			if (borderStarted == SideLeft) {
				LayoutSettings.sizes[LayoutSidebarW] -= Std.int(mouse.movementX);
				if (LayoutSettings.sizes[LayoutSidebarW] < MIN_SIDEBAR_W) {
					LayoutSettings.sizes[LayoutSidebarW] = MIN_SIDEBAR_W;
				} else if (LayoutSettings.sizes[LayoutSidebarW] > maxW) {
					LayoutSettings.sizes[LayoutSidebarW] = maxW;
				}
			}

			// The border between two panels
			if (borderStarted == SideBottom || borderStarted == SideTop) {
				var my: Int = Std.int(mouse.movementY);
				if (borderHandle == hwnds[PanelBottom]) {
					// The bottom panel's top border
					LayoutSettings.sizes[LayoutBottomH] -= my;
					var maxBottomH: Int = Std.int(App.h() * 0.7);
					if (LayoutSettings.sizes[LayoutBottomH] < MIN_PANEL_SIZE) {
						LayoutSettings.sizes[LayoutBottomH] = MIN_PANEL_SIZE;
					} else if (LayoutSettings.sizes[LayoutBottomH] > maxBottomH) {
						LayoutSettings.sizes[LayoutBottomH] = maxBottomH;
					}
				} else {
					// Between the sidebar's panels
					if (LayoutSettings.sizes[LayoutSidebarH0] + my > MIN_PANEL_SIZE &&
						LayoutSettings.sizes[LayoutSidebarH1] - my > MIN_PANEL_SIZE) {
						LayoutSettings.sizes[LayoutSidebarH0] += my;
						LayoutSettings.sizes[LayoutSidebarH1] -= my;
					}
				}
			}
		}

		if (!mouse.down()) {
			if (borderHandle != null) {
				borderHandle = null;
				Base.isResizing = false;
				Krom.setMouseCursor(Cursor.Default);
				// Remembered for the next time the editor opens
				LayoutSettings.save();
			}
		}

		// Reset only when the mouse moves, so the OS can show its own cursors at the window edges
		if (mouse.movementX != 0 || mouse.movementY != 0) {
			if (cursorSet) {
				cursorSet = false;
			} else if (borderHandle == null) {
				Krom.setMouseCursor(Cursor.Default);
			}
		}
	}

	// Shows `cursor` until the mouse moves without anything setting it again
	public function setCursor(cursor: Cursor): Void {
		Krom.setMouseCursor(cursor);
		cursorSet = true;
	}

	// After the canvas or the selection changed
	public function redrawPanels(): Void {
		hwnds[PanelHierarchy].redraws = 2;
		hwnds[PanelProperties].redraws = 2;
	}

	function onBorderHover(handle: Handle, side: Int) {
		if (handle != hwnds[PanelHierarchy] && handle != hwnds[PanelProperties] && handle != hwnds[PanelBottom]) return;

		// Each panel's resizable borders
		if (handle == hwnds[PanelHierarchy] && side != SideLeft && side != SideBottom) return;

		if (handle == hwnds[PanelProperties] && side != SideLeft && side != SideTop) return;

		if (handle == hwnds[PanelBottom] && side != SideTop) return;

		setCursor(side == SideLeft || side == SideRight ? ResizeHorizontal : ResizeVertical);

		if (ui.inputStarted) {
			borderStarted = side;
			borderHandle = handle;
			Base.isResizing = true;
		}
	}

	public function getTabX(): Int {
		var w: Int = App.w();
		if (w < MIN_SIDEBAR_W) return 0;
		var sidebarW: Int = LayoutSettings.sizes[LayoutSidebarW];
		if (sidebarW > w - MIN_PANEL_SIZE) sidebarW = w - MIN_PANEL_SIZE;
		return w - sidebarW;
	}

	public function getSidebarW(): Int {
		var w: Int = App.w();
		if (w < MIN_SIDEBAR_W) return MIN_SIDEBAR_W;
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

		if (totalH < MIN_PANEL_SIZE * 2) return;

		var currentTotal = LayoutSettings.sizes[LayoutSidebarH0] + LayoutSettings.sizes[LayoutSidebarH1];

		// Heights too small to keep: split the window in half
		if (currentTotal < MIN_PANEL_SIZE * 2) {
			LayoutSettings.sizes[LayoutSidebarH0] = Std.int(totalH / 2);
			LayoutSettings.sizes[LayoutSidebarH1] = totalH - LayoutSettings.sizes[LayoutSidebarH0];
		} else if (currentTotal != totalH) {
			var ratio = LayoutSettings.sizes[LayoutSidebarH0] / currentTotal;
			LayoutSettings.sizes[LayoutSidebarH0] = Std.int(totalH * ratio);
			LayoutSettings.sizes[LayoutSidebarH1] = totalH - LayoutSettings.sizes[LayoutSidebarH0];
		}

		if (LayoutSettings.sizes[LayoutSidebarH0] < MIN_PANEL_SIZE) {
			LayoutSettings.sizes[LayoutSidebarH0] = MIN_PANEL_SIZE;
			LayoutSettings.sizes[LayoutSidebarH1] = totalH - MIN_PANEL_SIZE;
		}
		if (LayoutSettings.sizes[LayoutSidebarH1] < MIN_PANEL_SIZE) {
			LayoutSettings.sizes[LayoutSidebarH1] = MIN_PANEL_SIZE;
			LayoutSettings.sizes[LayoutSidebarH0] = totalH - MIN_PANEL_SIZE;
		}

		var maxBottomH = Std.int(App.h() * 0.7);
		if (LayoutSettings.sizes[LayoutBottomH] > maxBottomH) {
			LayoutSettings.sizes[LayoutBottomH] = maxBottomH;
		}
		if (LayoutSettings.sizes[LayoutBottomH] < MIN_PANEL_SIZE) {
			LayoutSettings.sizes[LayoutBottomH] = MIN_PANEL_SIZE;
		}
	}
}
