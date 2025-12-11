package arm.panels;

import arm.Enums;
import arm.UIBase;
import zui.Zui.Handle;

class HierarchyPanel {
    var sceneTabHandle: Handle;
    var sceneTabs: Array<String> = ["Scene"];
	var sceneCounter: Int = 1;

    public function new() {
        sceneTabHandle = new Handle();
    }

    public function draw(uiBase: UIBase, params: Dynamic): Void {
        if (uiBase.ui.window(uiBase.hwnds[PanelTop], params.tabx, 0, params.w, params.h0)) {
			// Scene selector row: [Dropdown] [+] [x]
			uiBase.ui.row([0.7, 0.15, 0.15]);

			// Scene dropdown
			sceneTabHandle.position = uiBase.ui.combo(sceneTabHandle, sceneTabs, "", true);

			// Add scene button
			if (uiBase.ui.button("+")) {
				sceneCounter++;
				var newName = "Scene " + sceneCounter;
				sceneTabs.push(newName);
				sceneTabHandle.position = sceneTabs.length - 1;
			}

			// Delete scene button
			if (uiBase.ui.button("-")) {
				if (sceneTabs.length > 1) {
					var currentIndex = sceneTabHandle.position;
					if (currentIndex > 0) sceneTabHandle.position = currentIndex - 1;
					sceneTabs.splice(currentIndex, 1);
					if (sceneTabHandle.position >= sceneTabs.length) {
						sceneTabHandle.position = sceneTabs.length - 1;
					}
				}
			}
		}
    }
}