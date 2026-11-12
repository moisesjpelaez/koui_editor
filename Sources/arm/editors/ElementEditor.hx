package arm.editors;

import koui.elements.Element;
import koui.utils.RadioGroup;
import zui.Zui;

/**
 * One element type's palette button and its own fields in the Properties
 * panel. Types with fields of their own extend it and override `drawProperties`.
 */
class ElementEditor {
	// As in `CanvasElements.types`
	public final typeName: String;
	// The palette button's text
	public final displayName: String;
	// The palette group
	public final category: String;

	final makeDefault: Array<RadioGroup>->Element;

	public function new(typeName: String, displayName: String, category: String, makeDefault: Array<RadioGroup>->Element) {
		this.typeName = typeName;
		this.displayName = displayName;
		this.category = category;
		this.makeDefault = makeDefault;
	}

	// A radio button joins the first of `radioGroups`
	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return makeDefault(radioGroups != null ? radioGroups : []);
	}

	// Measured on a new palette element
	public function defaultSize(): { width: Int, height: Int } {
		var element: Element = makeDefault([]);
		var size = { width: element.width, height: element.height };
		element.destroy();
		return size;
	}

	// For Reset Size
	public function resetSize(element: Element): { width: Int, height: Int } {
		return defaultSize();
	}

	// `elements` are all of this type
	public function drawProperties(ui: Zui, elements: Array<Element>): Void {}
}
