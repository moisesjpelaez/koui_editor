package arm.panels;

import arm.Enums;
import arm.UIBase;
import iron.App;
import zui.Zui.Handle;

class BottomPanel {
    var themeTabHandle: Handle;
    var themeTextHandle: Handle;

    public function new() {
        themeTabHandle = new Handle();
        themeTextHandle = new Handle();
    }

    public function draw(uiBase: UIBase): Void {
        var bottomH: Int = uiBase.getBottomH();

		// Skip drawing if panel is too small
		if (bottomH < UIBase.MIN_PANEL_SIZE) return;

		var panelX: Int = 0;
		var panelY: Int = App.h() - bottomH;
		var panelW: Int = uiBase.getTabX();

		if (uiBase.ui.window(uiBase.hwnds[PanelBottom], panelX, panelY, panelW, bottomH)) {
			uiBase.ui.tab(themeTabHandle, "Theme");
			uiBase.ui.row([0.075, 0.075, 0.075, 0.075]);
			if (uiBase.ui.button("Load")) {
				trace("Load");
			}
			if (uiBase.ui.button("Save")) {
				trace("Save");
			}
			if (uiBase.ui.button("Save As")) {
				trace("Save As");
			}
			if (uiBase.ui.button("Clear")) {
				trace("Clear");
			}

			uiBase.ui.row([1]);
			if (themeTabHandle.position == 0) {
				zui.Ext.textAreaLineNumbers = true;
				zui.Ext.textAreaScrollPastEnd = true;
				zui.Ext.textArea(uiBase.ui, themeTextHandle);
				zui.Ext.textAreaLineNumbers = false;
				zui.Ext.textAreaScrollPastEnd = false;
			}
		}
    }
}