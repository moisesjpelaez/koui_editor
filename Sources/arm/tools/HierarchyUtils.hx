package arm.tools;

import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Panel;

import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Expander;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout;
import koui.elements.layouts.Layout.Anchor;
import koui.elements.layouts.ScrollPane;

@:access(koui.elements.Element, koui.elements.layouts.Layout, koui.elements.layouts.AnchorPane, koui.elements.layouts.ScrollPane, koui.elements.layouts.Expander, koui.elements.layouts.GridLayout)
class HierarchyUtils {
	public static function canAcceptChild(target: Element): Bool {
		return target != null && (target is Layout || target is Panel);
	}

	public static function isUserContainer(element: Element): Bool {
		if (element == null) return false;
		return canAcceptChild(element);
	}

	public static function getParentElement(element: Element): Element {
		if (element == null) return null;
		if (element.layout != null) return cast(element.layout, Element);
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
		if (parent is AnchorPane || parent is ScrollPane || parent is Expander || parent is GridLayout) return untyped parent.elements;
		return parent.children;
	}

	public static function detachFromCurrentParent(element: Element): Void {
		if (element == null) return;
		if (element.layout != null) {
			var layout: Layout = element.layout;
			if (layout is AnchorPane || layout is ScrollPane || layout is Expander || layout is GridLayout) {
				untyped layout.remove(element);
				return;
			}
		}
		if (element.parent != null) element.parent.removeChild(element);
	}

	public static function moveAsChild(element: Element, target: Element, ?fallbackParent: AnchorPane): Void { // TODO: remove third arg?
		detachFromCurrentParent(element);

		if (target is Layout && (target is AnchorPane || target is ScrollPane || target is Expander)) {
			untyped cast(target, Layout).add(element);
		} else if (target is Panel) {
			target.addChild(element);
		}

		// TODO: test GridLayout case
		// if (Std.isOfType(target, GridLayout)) {
		// 	// Grid placement needs row/col; use fallback if provided.
		// 	if (fallbackParent != null) {
		// 		fallbackParent.add(element, Anchor.TopLeft);
		// 	}
		// 	return;
		// }
	}

	public static function moveRelativeToTarget(element: Element, target: Element, before: Bool): Void {
		var parent: Element = getParentElement(target);
		if (parent == null) return;

		detachFromCurrentParent(element);

		var elements: Array<Element>;
		if (parent is AnchorPane || parent is ScrollPane || parent is Expander || parent is GridLayout) {
			untyped cast(parent, Layout).add(element);
			elements = untyped cast(parent, Layout).elements;
		} else {
			elements = parent.children;

		}
		elements.remove(element);
		var targetIdx: Int = elements.indexOf(target);
		if (targetIdx < 0) return;
		var insertIdx: Int = before ? targetIdx : targetIdx + 1;
		elements.insert(insertIdx, element);
	}

	public static function shouldSkipInternalChild(parent: Element, child: Element): Bool {
        // Skip Button's internal label
        if (parent is Button) {
            return true;
        }
		// TODO: Add more cases as needed. Return single line once ready.

        return false;
    }
}
