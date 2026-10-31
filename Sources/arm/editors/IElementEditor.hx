package arm.editors;

import koui.elements.Element;
import koui.utils.RadioGroup;
import zui.Zui;

/**
 * Contract for element type editors in the Koui Editor.
 *
 * Each element type (Button, Label, Slider, etc.) implements this interface
 * to provide its palette default and property panel UI. Creating elements
 * from canvas data and saving them is shared with the game runtime, see
 * `arm.canvas.CanvasElements`.
 * Common properties (posX, posY, width, height, anchor, visible, disabled, tID, focus)
 * are handled by the framework — implementations only deal with type-specific concerns.
 */
interface IElementEditor {
	/** Type identifier matching the JSON "type" field (e.g. "Button", "Label"). */
	var typeName(get, never): String;

	/** Display name shown in the ElementsPanel button (e.g. "Radio Button", "Image Panel"). */
	var displayName(get, never): String;

	/** Category grouping in ElementsPanel (e.g. "Basic", "Buttons", "Layout", "Misc."). */
	var category(get, never): String;

	/** Create a default instance for the ElementsPanel palette. */
	function createDefault(?radioGroups: Array<RadioGroup>): Element;

	/**
	 * Draw type-specific property fields in the PropertiesPanel for the selected
	 * elements, all of this type. Fields edit every one of them (see `PropertyFields`).
	 */
	function drawProperties(ui: Zui, elements: Array<Element>): Void;
}
