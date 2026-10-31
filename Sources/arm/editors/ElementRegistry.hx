package arm.editors;

import arm.canvas.CanvasElements;

import koui.elements.Element;
import koui.elements.Panel;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;

/**
 * Central registry for element type editors.
 * All element types register here at startup; panels and utilities
 * query the registry instead of using switch/if-else chains.
 */
class ElementRegistry {
	static var editors: Array<ElementEditor> = [];
	static var byTypeName: Map<String, ElementEditor> = new Map();

	/**
	 * Registers the editor of every element type, in palette order. A type
	 * without properties of its own needs no editor class, only a line here.
	 */
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

	/** Register an element editor. */
	public static function register(editor: ElementEditor): Void {
		editors.push(editor);
		byTypeName.set(editor.typeName, editor);
	}

	/** Look up an editor by JSON type name. */
	public static function getByTypeName(typeName: String): ElementEditor {
		return byTypeName.get(typeName);
	}

	/** Find the editor that handles a given element instance. */
	public static function getForElement(element: Element): ElementEditor {
		var typeName: Null<String> = CanvasElements.getType(element);
		return typeName != null ? byTypeName.get(typeName) : null;
	}

	/** All registered editors, in registration order. */
	public static function all(): Array<ElementEditor> {
		return editors;
	}

	/** All editors in a given category, in registration order. */
	public static function byCategory(category: String): Array<ElementEditor> {
		return editors.filter(e -> e.category == category);
	}

	/** Ordered list of categories for the ElementsPanel. */
	public static function categories(): Array<String> {
		var result: Array<String> = [];
		for (editor in editors) {
			if (result.indexOf(editor.category) < 0) result.push(editor.category);
		}
		return result;
	}
}
