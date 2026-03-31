package arm.editors;

import arm.editors.IElementEditor;
import koui.elements.Element;

/**
 * Central registry for element type editors.
 * All element types register here at startup; panels and utilities
 * query the registry instead of using switch/if-else chains.
 */
class ElementRegistry {
	static var editors: Array<IElementEditor> = [];
	static var byTypeName: Map<String, IElementEditor> = new Map();

	/** Register an element editor. Initializes its handles immediately. */
	public static function register(editor: IElementEditor): Void {
		editor.initHandles();
		editors.push(editor);
		byTypeName.set(editor.typeName, editor);
	}

	/** Look up an editor by JSON type name. */
	public static function getByTypeName(typeName: String): IElementEditor {
		return byTypeName.get(typeName);
	}

	/** Find the editor that handles a given element instance. */
	public static function getForElement(element: Element): IElementEditor {
		for (editor in editors) {
			if (editor.matches(element)) {
				return editor;
			}
		}
		return null;
	}

	/** Get the type name string for an element instance. */
	public static function getElementType(element: Element): String {
		var editor = getForElement(element);
		return editor != null ? editor.typeName : "Unknown";
	}

	/** All registered editors, in registration order. */
	public static function all(): Array<IElementEditor> {
		return editors;
	}

	/** All editors in a given category, in registration order. */
	public static function byCategory(category: String): Array<IElementEditor> {
		return editors.filter(function(e: IElementEditor): Bool {
			return e.category == category;
		});
	}

	/** Ordered list of categories for the ElementsPanel. */
	public static function categories(): Array<String> {
		var seen = new Map<String, Bool>();
		var result: Array<String> = [];
		for (editor in editors) {
			if (!seen.exists(editor.category)) {
				seen.set(editor.category, true);
				result.push(editor.category);
			}
		}
		return result;
	}
}
