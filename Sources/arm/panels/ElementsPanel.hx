package arm.panels;

import arm.data.SceneData;
import arm.editors.ElementRegistry;
import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import arm.base.UIBase;
import iron.App;
import zui.Id;

class ElementsPanel {
    public function new() {

    }

    public function draw(uiBase: UIBase): Void {
		uiBase.ui.t.FILL_WINDOW_BG = false;
		var uiScale: Float = uiBase.ui.SCALE();
		var panelX: Int = Std.int(10 * uiScale);
		var panelY: Int = Std.int(10 * uiScale);
		var panelW: Int = Std.int(100 * uiScale);
		var panelH: Int = App.h() - uiBase.getBottomH() - Std.int(20 * uiScale);

		if (uiBase.ui.window(Id.handle(), panelX, panelY, panelW, panelH, false)) {
			for (category in ElementRegistry.categories()) {
				if (uiBase.ui.panel(Id.handle({selected: true}), category)) {
					uiBase.ui.indent();
					for (editor in ElementRegistry.byCategory(category)) {
						if (uiBase.ui.button(editor.displayName)) {
							var element = editor.createDefault(SceneData.data.radioGroups);
							ElementEvents.elementAdded.emit({ key: editor.typeName, element: element });
						}
					}
					uiBase.ui.unindent();
				}
			}
		}

		uiBase.ui.t.FILL_WINDOW_BG = true;
	}
}