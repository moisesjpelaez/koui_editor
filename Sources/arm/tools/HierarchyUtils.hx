package arm.tools;

import koui.elements.Element;
import koui.elements.Panel;
import koui.elements.layouts.Layout;
import koui.elements.layouts.Layout.Anchor;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ScrollPane;
import koui.elements.layouts.Expander;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.RowLayout;
import koui.elements.layouts.ColLayout;

class HierarchyUtils {
	public static function canAcceptChild(target: Element): Bool {
		if (target == null) return false;

		// Valid containers that can accept children
		if (Std.isOfType(target, AnchorPane)) return true;
		if (Std.isOfType(target, Panel)) return true;
		if (Std.isOfType(target, ColLayout)) return true;
		if (Std.isOfType(target, RowLayout)) return true;
		if (Std.isOfType(target, Expander)) return true;
		if (Std.isOfType(target, GridLayout)) return true;
		// if (Std.isOfType(target, ScrollPane)) return true;

		return false;
	}

	public static function isUserContainer(element: Element): Bool {
		if (element == null) return false;

		// Only show elements that are valid containers
		return canAcceptChild(element);
	}

	public static function getParentElement(element: Element): Element {
		if (element == null) return null;
		if (element.layout != null) {
			return cast(element.layout, Element);
		}
		return element.parent;
	}

	public static function isDescendant(target: Element, ancestor: Element): Bool {
		var current: Element = getParentElement(target);
		while (current != null) {
			if (current == ancestor) return true;
			current = getParentElement(current);
		}
		return false;
	}

	public static function getChildren(parent: Element): Array<Element> {
		if (parent == null) return [];

		if (Std.isOfType(parent, AnchorPane)) {
			return @:privateAccess cast(parent, AnchorPane).elements;
		}
		if (Std.isOfType(parent, ScrollPane)) {
			return @:privateAccess cast(parent, ScrollPane).elements;
		}
		if (Std.isOfType(parent, Expander)) {
			return @:privateAccess cast(parent, Expander).elements;
		}

		return @:privateAccess parent.children;
	}

	public static function detachFromCurrentParent(element: Element): Void {
		if (element == null) return;

		if (element.layout != null) {
			var lyt: Layout = element.layout;
			if (Std.isOfType(lyt, AnchorPane)) {
				cast(lyt, AnchorPane).remove(element);
			} else if (Std.isOfType(lyt, ScrollPane)) {
				cast(lyt, ScrollPane).remove(element);
			} else if (Std.isOfType(lyt, Expander)) {
				cast(lyt, Expander).remove(element);
			} else if (Std.isOfType(lyt, GridLayout)) {
				cast(lyt, GridLayout).remove(element);
			} else {
				element.layout = null;
			}
			return;
		}

		if (element.parent != null) {
			@:privateAccess element.parent.removeChild(element);
		}
	}

	public static function moveAsChild(element: Element, target: Element, ?fallbackParent: AnchorPane): Void {
		detachFromCurrentParent(element);

		if (Std.isOfType(target, AnchorPane)) {
			cast(target, AnchorPane).add(element, Anchor.TopLeft);
			return;
		}
		if (Std.isOfType(target, ScrollPane)) {
			cast(target, ScrollPane).add(element);
			return;
		}
		if (Std.isOfType(target, Expander)) {
			cast(target, Expander).add(element);
			return;
		}
		if (Std.isOfType(target, GridLayout)) {
			// Grid placement needs row/col; use fallback if provided.
			if (fallbackParent != null) {
				fallbackParent.add(element, Anchor.TopLeft);
			}
			return;
		}

		// Plain Element parenting.
		target.addChild(element);
	}

	public static function moveRelativeToTarget(element: Element, target: Element, before: Bool): Void {
		var parent: Element = getParentElement(target);
		if (parent == null) return;

		detachFromCurrentParent(element);

		if (Std.isOfType(parent, AnchorPane)) {
			cast(parent, AnchorPane).add(element, Anchor.TopLeft);
			var arr: Array<Element> = @:privateAccess cast(parent, AnchorPane).elements;
			arr.remove(element);
			var targetIdx: Int = arr.indexOf(target);
			if (targetIdx < 0) return;
			var insertIdx: Int = before ? targetIdx : targetIdx + 1;
			arr.insert(insertIdx, element);
			return;
		}

		// if (Std.isOfType(parent, ScrollPane)) {
		// 	cast(parent, ScrollPane).add(element);
		// 	var arr: Array<Element> = @:privateAccess cast(parent, ScrollPane).elements;
		// 	arr.remove(element);
		// 	var targetIdx: Int = arr.indexOf(target);
		// 	if (targetIdx < 0) return;
		// 	var insertIdx: Int = before ? targetIdx : targetIdx + 1;
		// 	arr.insert(insertIdx, element);
		// 	return;
		// }

		if (Std.isOfType(parent, Expander)) {
			var exp: Expander = cast parent;
			var arr: Array<Element> = @:privateAccess exp.elements;
			var targetIdx: Int = arr.indexOf(target);
			if (targetIdx < 0) return;
			var insertIdx: Int = before ? targetIdx : targetIdx + 1;
			exp.add(element, insertIdx);
			return;
		}

		// Plain Element sibling ordering via children array.
		var children: Array<Element> = @:privateAccess parent.children;
		children.remove(element);
		var tIdx: Int = children.indexOf(target);
		if (tIdx < 0) return;
		var iIdx: Int = before ? tIdx : tIdx + 1;
		@:privateAccess element.parent = parent;
		children.insert(iIdx, element);
	}
}
