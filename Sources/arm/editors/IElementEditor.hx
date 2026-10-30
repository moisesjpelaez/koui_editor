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

	/** Whether this element type has internal children that shouldn't be individually selectable (e.g. Button, Checkbox). */
	var isComposite(get, never): Bool;

	/** Create a default instance for the ElementsPanel palette. */
	function createDefault(?radioGroups: Array<RadioGroup>): Element;

	/** Initialize Zui handles for the property panel. Called once at registration. */
	function initHandles(): Void;

	/** Sync handle state to the currently selected element. Called when selection changes. */
	function syncHandles(element: Element): Void;

	/** Draw type-specific property fields in the PropertiesPanel. */
	function drawProperties(ui: Zui, element: Element): Void;
}
