package arm.panels;

import arm.data.History;

import koui.elements.Element;

import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

/**
 * Property fields that edit every selected element at once.
 *
 * A field shows the elements' value when they all agree. When they differ, a
 * text field is blank and checkboxes and combos say "(mixed)". A change sets
 * the new value on every element and is recorded as one undo step.
 */
@:access(zui.Zui)
class PropertyFields {
	static inline var MIXED: String = "(mixed)";

	/** The elements each text field's edit started on, while it's being edited. */
	static var editTargets: haxe.ds.ObjectMap<Handle, Array<Element>> = new haxe.ds.ObjectMap();

	/**
	 * The elements a text field edits. Zui commits a text edit a frame after
	 * the field loses focus, when the selection may already be another one:
	 * the edit still goes to the elements it was started on. Call right after
	 * `ui.textInput`.
	 */
	public static function textEditTargets(ui: Zui, handle: Handle, elements: Array<Element>): Array<Element> {
		if (ui.textSelectedHandle == handle) {
			editTargets.set(handle, elements.copy());
			return elements;
		}
		var started: Null<Array<Element>> = editTargets.get(handle);
		if (handle.changed) editTargets.remove(handle);
		return handle.changed && started != null ? started : elements;
	}

	/** The value all `elements` share, or null if they differ (or there are none). */
	public static function shared<T>(elements: Array<Element>, get: Element->T): Null<T> {
		if (elements.length == 0) return null;
		var value: T = get(elements[0]);
		for (i in 1...elements.length) {
			if (get(elements[i]) != value) return null;
		}
		return value;
	}

	/** Calls `set` on every element and records the change. */
	public static function apply<T>(label: String, elements: Array<Element>, set: (Element, T)->Void, value: T): Void {
		for (element in elements) set(element, value);
		History.edited(label);
	}

	/**
	 * A text field. `parse` turns the typed text into a value, or null to
	 * reject it (the field then shows the current value again).
	 */
	public static function value<T>(ui: Zui, handle: Handle, label: String, elements: Array<Element>,
			get: Element->T, set: (Element, T)->Void, format: T->String, parse: String->Null<T>, ?align: Align): Void {
		var current: Null<T> = shared(elements, get);
		handle.text = current != null ? format(current) : "";
		var typed: String = ui.textInput(handle, label, align != null ? align : Right);
		var targets: Array<Element> = textEditTargets(ui, handle, elements);
		if (!handle.changed) return;

		// Only elements whose value changes are set (Koui re-lays out an element even when a value is set to itself)
		var parsed: Null<T> = parse(typed);
		if (parsed == null) return;
		var changing: Array<Element> = targets.filter(e -> get(e) != parsed);
		if (changing.length > 0) apply('Change $label', changing, set, parsed);
	}

	/** A text field for text that must not be empty. */
	public static function text(ui: Zui, handle: Handle, label: String, elements: Array<Element>,
			get: Element->String, set: (Element, String)->Void, allowEmpty: Bool = false, ?align: Align): Void {
		value(ui, handle, label, elements, get, set, s -> s, s -> (s == null || (s == "" && !allowEmpty)) ? null : s, align);
	}

	public static function int(ui: Zui, handle: Handle, label: String, elements: Array<Element>,
			get: Element->Int, set: (Element, Int)->Void, ?align: Align): Void {
		value(ui, handle, label, elements, get, set, Std.string, s -> Std.parseInt(s), align);
	}

	public static function float(ui: Zui, handle: Handle, label: String, elements: Array<Element>,
			get: Element->Float, set: (Element, Float)->Void, ?align: Align): Void {
		value(ui, handle, label, elements, get, set, Std.string, s -> {
			var f: Float = Std.parseFloat(s);
			Math.isNaN(f) ? null : f;
		}, align);
	}

	/** A checkbox. Clicking a mixed one checks every element. */
	public static function check(ui: Zui, handle: Handle, label: String, elements: Array<Element>,
			get: Element->Bool, set: (Element, Bool)->Void): Void {
		var current: Null<Bool> = shared(elements, get);
		handle.selected = current == true;
		var checked: Bool = ui.check(handle, current != null ? label : '$label $MIXED');
		if (handle.changed) apply('Change $label', elements, set, checked);
	}

	/** A combo of `options`; `get` and `set` use option indices. A mixed combo starts with a "(mixed)" entry that changes nothing. */
	public static function combo(ui: Zui, handle: Handle, label: String, options: Array<String>, elements: Array<Element>,
			get: Element->Int, set: (Element, Int)->Void): Void {
		var current: Null<Int> = shared(elements, get);
		var shown: Array<String> = current != null ? options : [MIXED].concat(options);
		handle.position = current != null ? current : 0;
		var picked: Int = ui.combo(handle, shown, current != null ? label : '$label $MIXED', true, Right);
		if (!handle.changed) return;

		var index: Int = current != null ? picked : picked - 1;
		if (index >= 0 && index < options.length) apply('Change $label', elements, set, index);
	}

	/** A slider from `min` to `max` with `precision` decimals; a mixed one shows the first element's value. */
	public static function slider(ui: Zui, handle: Handle, label: String, min: Float, max: Float, precision: Int, elements: Array<Element>,
			get: Element->Float, set: (Element, Float)->Void): Void {
		var current: Null<Float> = shared(elements, get);
		handle.value = current != null ? current : get(elements[0]);
		var steps: Float = Math.pow(10, -precision);
		var picked: Float = ui.slider(handle, current != null ? label : '$label $MIXED', min, max, true, 1 / steps, true, Right);
		if (!handle.changed) return;

		picked = Math.round(picked / steps) * steps;
		handle.value = picked;
		apply('Change $label', elements, set, picked);
	}
}
