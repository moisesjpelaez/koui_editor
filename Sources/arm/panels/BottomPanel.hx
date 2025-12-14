package arm.panels;

import arm.types.Enums;
import arm.base.UIBase;
import iron.App;
import zui.Zui.Handle;

class BottomPanel {
    var themeTabHandle: Handle;

    public function new() {
        themeTabHandle = new Handle();
    }

    public function draw(uiBase: UIBase): Void {
        var bottomH: Int = uiBase.getBottomH();

		// Skip drawing if panel is too small
		if (bottomH < UIBase.MIN_PANEL_SIZE) return;

		var panelX: Int = 0;
		var panelY: Int = App.h() - bottomH;
		var panelW: Int = uiBase.getTabX();

		if (uiBase.ui.window(uiBase.hwnds[PanelBottom], panelX, panelY, panelW, bottomH)) {
			uiBase.ui.tab(themeTabHandle, "Assets"); // images for icons and image panels
		}
    }
}