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

		if (uiBase.ui.window(Id.handle(), 10, 10, 100, App.h() - uiBase.getBottomH() - 20, false)) {
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