package arm.panels;

import arm.events.ElementEvents;
import arm.base.UIBase;
import iron.App;
import koui.elements.Button;
import koui.elements.Label;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;
import zui.Id;

class ElementsPanel {
    public function new() {

    }

    public function draw(uiBase: UIBase): Void {
		uiBase.ui.t.FILL_WINDOW_BG = false;

		if (uiBase.ui.window(Id.handle(), 10, 10, 100, App.h() - uiBase.getBottomH() - 20, false)) {
			if (uiBase.ui.panel(Id.handle({selected: true}), "Basic")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("Label")) {
					var key: String = "Label";
					var label: Label = new Label("New Label");
                    ElementEvents.elementAdded.emit({ key: key, element: label });
				}

				if (uiBase.ui.button("Image Panel")) {
					trace("Image Panel");
				}

				if (uiBase.ui.button("Panel")) {
					trace("Panel");
				}

				uiBase.ui.unindent();
			}

			if (uiBase.ui.panel(Id.handle({selected: true}), "Buttons")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("Button")) {
					var key: String = "Button";
					var button: Button = new Button("New Button");
					ElementEvents.elementAdded.emit({ key: key, element: button });
				}

				if (uiBase.ui.button("Checkbox")) {
					trace("Checkbox");
				}

				if (uiBase.ui.button("Radio")) {
					trace("Radio");
				}

				uiBase.ui.unindent();
			}

			if (uiBase.ui.panel(Id.handle({selected: true}), "Layout")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("GridLayout")) {
					trace("GridLayout");
				}

				if (uiBase.ui.button("ColLayout")) {
					var key: String = "ColLayout";
					var colLayout: ColLayout = new ColLayout(0, 0, 200, 150, 4);
					ElementEvents.elementAdded.emit({ key: key, element: colLayout });
				}

				if (uiBase.ui.button("RowLayout")) {
					var key: String = "RowLayout";
					var rowLayout: RowLayout = new RowLayout(0, 0, 200, 150, 4);
					ElementEvents.elementAdded.emit({ key: key, element: rowLayout });
				}

				if (uiBase.ui.button("Expander")) {
					trace("Expander");
				}

				uiBase.ui.unindent();
			}
		}

		uiBase.ui.t.FILL_WINDOW_BG = true;
	}
}