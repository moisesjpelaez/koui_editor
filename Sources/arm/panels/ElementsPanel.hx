package arm.panels;

import arm.base.UIBase;
import armory.system.Signal;
import iron.App;
import koui.elements.Button;
import koui.elements.Label;
import zui.Id;

class ElementsPanel {
    public var elementAdded: Signal = new Signal(); // args: (key: String, element: Element)

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
                    elementAdded.emit({ key: key, element: label });
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
					elementAdded.emit({ key: key, element: button });
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
					trace("ColLayout");
				}

				if (uiBase.ui.button("RowLayout")) {
					trace("RowLayout");
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