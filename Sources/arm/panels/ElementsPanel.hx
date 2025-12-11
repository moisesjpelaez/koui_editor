package arm.panels;

import arm.Enums;
import arm.KouiEditor;
import arm.UIBase;
import iron.App;
import koui.elements.Button;
import koui.elements.Label;
import koui.elements.Panel;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;
import zui.Id;

class ElementsPanel {
    public function new() {

    }

    public function draw(uiBase: UIBase, anchorPane: AnchorPane): Void {
		uiBase.ui.t.FILL_WINDOW_BG = false;

		if (uiBase.ui.window(Id.handle(), 10, 10, 100, App.h() - uiBase.getBottomH() - 20, false)) {
			if (uiBase.ui.panel(Id.handle({selected: true}), "Basic")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("Label")) {
					var key: String = "label_" + Std.string(KouiEditor.labelsCount);
					var label: Label = new Label("New Label");
					KouiEditor.elements.push({name: key, element: label});
					anchorPane.add(label, Anchor.TopLeft);
					KouiEditor.labelsCount++;
					KouiEditor.selectedElement = label;
					uiBase.hwnds[PanelTop].redraws = 2;
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
					var key: String = "button_" + Std.string(KouiEditor.buttonsCount);
					var button: Button = new Button("New Button");
					KouiEditor.elements.push({name: key, element: button});
					anchorPane.add(button, Anchor.TopLeft);
					KouiEditor.buttonsCount++;
					KouiEditor.selectedElement = button;
					uiBase.hwnds[PanelTop].redraws = 2;
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

				if (uiBase.ui.button("AnchorPane")) {
					trace("AnchorPane");
				}

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