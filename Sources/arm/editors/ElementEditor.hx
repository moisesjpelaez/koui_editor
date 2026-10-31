package arm.editors;

import koui.elements.Element;
import koui.utils.RadioGroup;
import zui.Zui;

/**
 * The editor of one element type: its palette button and its section of the
 * Properties panel. Types without properties of their own use this class as
 * it is; the others extend it and override `drawProperties`.
 *
 * Creating elements from canvas data and saving them is shared with the game
 * runtime, see `arm.canvas.CanvasElements`. The common properties (position,
 * size, anchor, visibility, theme ID, focus) are drawn by the Properties panel.
 */
class ElementEditor {
	/** The type's saved name (e.g. "Button"), as in `CanvasElements.types`. */
	public final typeName: String;
	/** The palette button's text (e.g. "Radio Button"). */
	public final displayName: String;
	/** The palette group (e.g. "Basic", "Buttons", "Layout", "Misc."). */
	public final category: String;

	final makeDefault: Array<RadioGroup>->Element;

	public function new(typeName: String, displayName: String, category: String, makeDefault: Array<RadioGroup>->Element) {
		this.typeName = typeName;
		this.displayName = displayName;
		this.category = category;
		this.makeDefault = makeDefault;
	}

	/** A new element for the palette; a radio button joins the first of `radioGroups`. */
	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return makeDefault(radioGroups != null ? radioGroups : []);
	}

	/** The size of a new element from the palette, for "Reset Size": measured on one made and freed for it. */
	public function defaultSize(): { width: Int, height: Int } {
		var element: Element = makeDefault([]);
		var size = { width: element.width, height: element.height };
		element.destroy();
		return size;
	}

	/** Draws the type's fields for `elements`, all of this type; a field edits every one of them (see `PropertyFields`). */
	public function drawProperties(ui: Zui, elements: Array<Element>): Void {}
}
