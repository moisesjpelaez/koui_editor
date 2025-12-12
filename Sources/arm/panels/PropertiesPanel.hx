package arm.panels;

import arm.types.Enums;
import arm.base.UIBase;
import zui.Zui.Handle;

class PropertiesPanel {
    var propertiesTabHandle: Handle;

    public function new() {
        propertiesTabHandle = new Handle();
    }

    public function draw(uiBase: UIBase, params: Dynamic): Void {
        if (uiBase.ui.window(uiBase.hwnds[PanelProperties], params.tabx, params.h0, params.w, params.h1)) {
			uiBase.ui.tab(propertiesTabHandle, "Properties");
		}
    }
}