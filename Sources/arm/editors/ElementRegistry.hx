package arm.editors;

import arm.canvas.CanvasElements;

import koui.elements.Element;
import koui.elements.Panel;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;

// The editor of every element type
class ElementRegistry {
	static var editors: Array<ElementEditor> = [];
	static var byTypeName: Map<String, ElementEditor> = new Map();

	// In palette order. A type without fields of its own needs no editor class
	public static function registerAll(): Void {
		register(new LabelEditor());
		register(new ElementEditor("Panel", "Panel", "Basic", groups -> new Panel()));
		register(new ImagePanelEditor());
		register(new ButtonEditor());
		register(new CheckboxEditor());
		register(new RadioButtonEditor());
		register(new ElementEditor("AnchorPane", "AnchorPane", "Layout", groups -> {
			var pane: AnchorPane = new AnchorPane(0, 0, 200, 200);
			pane.setTID("_fixed_anchorpane");
			pane;
		}));
		register(new ElementEditor("ColLayout", "ColLayout", "Layout", groups -> new ColLayout(0, 0, 200, 100, 0)));
		register(new ElementEditor("RowLayout", "RowLayout", "Layout", groups -> new RowLayout(0, 0, 200, 100, 0)));
		register(new ProgressbarEditor());
		register(new SliderEditor());
	}

	public static function register(editor: ElementEditor): Void {
		editors.push(editor);
		byTypeName.set(editor.typeName, editor);
	}

	public static function getByTypeName(typeName: String): ElementEditor {
		return byTypeName.get(typeName);
	}

	public static function getForElement(element: Element): ElementEditor {
		var typeName: Null<String> = CanvasElements.getType(element);
		return typeName != null ? byTypeName.get(typeName) : null;
	}

	public static function all(): Array<ElementEditor> {
		return editors;
	}

	public static function byCategory(category: String): Array<ElementEditor> {
		return editors.filter(e -> e.category == category);
	}

	// In palette order
	public static function categories(): Array<String> {
		var result: Array<String> = [];
		for (editor in editors) {
			if (result.indexOf(editor.category) < 0) result.push(editor.category);
		}
		return result;
	}
}
