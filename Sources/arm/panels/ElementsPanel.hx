package arm.panels;

import arm.events.ElementEvents;
import arm.base.UIBase;
import iron.App;
import koui.elements.Button;
import koui.elements.Checkbox;
import koui.elements.Label;
import koui.elements.Progressbar;
import koui.elements.layouts.AnchorPane;
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
					var key: String = "ImagePanel";
					var imagePanel = new koui.elements.ImagePanel(null);
					ElementEvents.elementAdded.emit({ key: key, element: imagePanel });
				}

				// if (uiBase.ui.button("Panel")) {
				// 	trace("Panel");
				// }

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
					var key: String = "Checkbox";
					var checkbox: Checkbox = new Checkbox("New Checkbox");
					ElementEvents.elementAdded.emit({ key: key, element: checkbox });
				}

				// if (uiBase.ui.button("Radio")) {
				// 	trace("Radio");
				// }

				uiBase.ui.unindent();
			}

			if (uiBase.ui.panel(Id.handle({selected: true}), "Layout")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("AnchorPane")) {
					var key: String = "AnchorPane";
					var anchorPane: AnchorPane = new AnchorPane(0, 0, 200, 200);
					anchorPane.setTID("_fixed_anchorpane");
					ElementEvents.elementAdded.emit({ key: key, element: anchorPane });
				}

				if (uiBase.ui.button("ColLayout")) {
					var key: String = "ColLayout";
					var colLayout: ColLayout = new ColLayout(0, 0, 200, 100, 0);
					ElementEvents.elementAdded.emit({ key: key, element: colLayout });
				}

				if (uiBase.ui.button("RowLayout")) {
					var key: String = "RowLayout";
					var rowLayout: RowLayout = new RowLayout(0, 0, 200, 100, 0);
					ElementEvents.elementAdded.emit({ key: key, element: rowLayout });
				}

				uiBase.ui.unindent();
			}

			if (uiBase.ui.panel(Id.handle({selected: true}), "Misc.")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("Progressbar")) {
					var key: String = "Progressbar";
					var progressbar: Progressbar = new Progressbar(0, 100);
					ElementEvents.elementAdded.emit({ key: key, element: progressbar });
				}
			}
		}

		uiBase.ui.t.FILL_WINDOW_BG = true;
	}
}