package arm.data;

import arm.events.ElementEvents;
import arm.tools.HierarchyUtils;
import koui.elements.Element;

/**
 * The selected elements, in the order they were selected. The last one is the
 * primary element. Every change emits `ElementEvents.selectionChanged`.
 */
class Selection {
	public static var elements(default, null): Array<Element> = [];

	// Where a Shift range in the Hierarchy panel starts
	public static var rangeAnchor: Null<Element> = null;

	public static var primary(get, never): Null<Element>;
	static function get_primary(): Null<Element> {
		return elements.length > 0 ? elements[elements.length - 1] : null;
	}

	public static inline function contains(element: Element): Bool {
		return elements.indexOf(element) >= 0;
	}

	public static inline function isEmpty(): Bool {
		return elements.length == 0;
	}

	public static function select(element: Null<Element>): Void {
		rangeAnchor = element;
		setAll(element != null ? [element] : []);
	}

	// `primary` becomes the primary element if given, otherwise the last one
	public static function setAll(list: Array<Element>, ?primary: Element): Void {
		var result: Array<Element> = [];
		for (element in list) {
			if (element != null && element != primary && result.indexOf(element) < 0) result.push(element);
		}
		if (primary != null) result.push(primary);
		elements = result;
		changed();
	}

	// Makes an already selected element the primary one
	public static function add(element: Element): Void {
		elements.remove(element);
		elements.push(element);
		changed();
	}

	public static function toggle(element: Element): Void {
		if (!elements.remove(element)) elements.push(element);
		changed();
	}

	public static function clear(): Void {
		rangeAnchor = null;
		if (elements.length == 0) return;
		elements = [];
		changed();
	}

	// Drops elements no longer in the current scene, and notifies so panels show current values
	public static function refresh(): Void {
		var sceneData: SceneData = SceneData.data;
		elements = elements.filter(element -> sceneData.isInCurrentScene(element));
		if (rangeAnchor != null && !sceneData.isInCurrentScene(rangeAnchor)) rangeAnchor = null;
		changed();
	}

	// The selected elements not inside another selected one, in hierarchy order
	public static function getTopLevel(): Array<Element> {
		return HierarchyUtils.topMost([for (element in SceneData.data.getElements()) if (contains(element)) element]);
	}

	static inline function changed(): Void {
		ElementEvents.selectionChanged.emit();
	}
}
