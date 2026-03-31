package arm.editors;

import koui.elements.Element;
import koui.utils.RadioGroup;
import zui.Zui;

/**
 * Contract for element type editors in the Koui Editor.
 *
 * Each element type (Button, Label, Slider, etc.) implements this interface
 * to provide its factory, serialization, and property panel UI.
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

	/** Returns true if this editor handles the given element instance. */
	function matches(element: Element): Bool;

	/** Create a default instance for the ElementsPanel palette. */
	function createDefault(?radioGroups: Array<RadioGroup>): Element;

	/**
	 * Create an element from deserialized data.
	 * Position/size are provided because some types (layouts) need them at construction time.
	 * Common properties (anchor, visible, disabled, tID) are applied by the caller.
	 */
	function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element;

	/** Serialize type-specific properties to a Dynamic for JSON output. */
	function serializeProperties(element: Element): Dynamic;

	/** Initialize Zui handles for the property panel. Called once at registration. */
	function initHandles(): Void;

	/** Sync handle state to the currently selected element. Called when selection changes. */
	function syncHandles(element: Element): Void;

	/** Draw type-specific property fields in the PropertiesPanel. */
	function drawProperties(ui: Zui, element: Element): Void;
}
