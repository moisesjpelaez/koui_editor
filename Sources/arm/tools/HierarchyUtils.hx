package arm.tools;

import haxe.ds.Vector;

import koui.elements.Element;
import koui.elements.Panel;

import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.Expander;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout;
import koui.elements.layouts.RowLayout;
import koui.elements.layouts.ScrollPane;

/**
 * Which element contains which, and in what order. Containers are layouts
 * (AnchorPane, RowLayout, ColLayout, ScrollPane, Expander) and panels.
 *
 * Every change reads a container's children with `getChildren`, changes the
 * list, and writes it back with `setChildren`. Shared by the editor and the
 * game runtime.
 */
@:access(koui.elements.Element, koui.elements.layouts.Layout, koui.elements.layouts.AnchorPane, koui.elements.layouts.ScrollPane,
	koui.elements.layouts.Expander, koui.elements.layouts.GridLayout)
class HierarchyUtils {
	public static function canAcceptChild(target: Element): Bool {
		return target != null && (target is Layout || target is Panel);
	}

	public static function getParentElement(element: Element): Element {
		if (element == null) return null;
		if (element.layout != null) return cast(element.layout, Element);
		return element.parent;
	}

	/** The elements of `list` that aren't inside another element of `list`, in the same order. */
	public static function topMost(list: Array<Element>): Array<Element> {
		return list.filter(element -> {
			var parent: Element = getParentElement(element);
			while (parent != null) {
				if (list.indexOf(parent) >= 0) return false;
				parent = getParentElement(parent);
			}
			return true;
		});
	}

	public static function isDescendant(target: Element, ancestor: Element): Bool {
		var current: Element = getParentElement(target);
		while (current != null) {
			if (current == ancestor) return true;
			current = getParentElement(current);
		}
		return false;
	}

	/**
	 * The children of `parent` in order: drawing order, a RowLayout's from top
	 * to bottom, a ColLayout's from left to right. A new array: change it and
	 * give it to `setChildren`. Elements that aren't containers return their
	 * own parts (a Button's label).
	 */
	public static function getChildren(parent: Element): Array<Element> {
		if (parent == null) return [];
		if (parent is GridLayout) {
			var grid: GridLayout = cast parent;
			return [for (row in grid.elements) for (element in row) if (element != null) element];
		}
		var list: Null<Array<Element>> = layoutList(parent);
		return list != null ? list.copy() : parent.children.copy();
	}

	/**
	 * Makes `children` the children of the container `parent`, in this order.
	 * Children it had before and aren't in the list are detached; new ones must
	 * not be in another container. A RowLayout or ColLayout gets one cell per
	 * child, so it has no gaps.
	 */
	public static function setChildren(parent: Element, children: Array<Element>): Void {
		if (parent is RowLayout || parent is ColLayout) {
			setCells(cast parent, children, parent is RowLayout);
			return;
		}

		var list: Null<Array<Element>> = layoutList(parent);
		if (list != null) {
			var layout: Layout = cast parent;
			for (element in list.copy()) {
				if (children.indexOf(element) < 0) layout.removeElement(element);
			}
			for (child in children) {
				if (child.layout == layout) continue;
				// Adding lays the element out; its anchor stays
				if (parent is AnchorPane) (cast parent: AnchorPane).add(child);
				else if (parent is ScrollPane) (cast parent: ScrollPane).add(child);
				else (cast parent: Expander).add(child);
			}
			replaceAll(list, children);
			layOut(layout);
			return;
		}

		// Panel
		for (element in parent.children.copy()) {
			if (children.indexOf(element) < 0) parent.removeChild(element);
		}
		for (child in children) {
			if (child.parent != parent) parent.addChild(child);
		}
		replaceAll(parent.children, children);
	}

	/** Takes `element` out of its container, if it's in one. */
	public static function detachFromCurrentParent(element: Element): Void {
		var parent: Element = getParentElement(element);
		if (parent == null) return;
		var siblings: Array<Element> = getChildren(parent);
		siblings.remove(element);
		setChildren(parent, siblings);
	}

	/** Moves `element` into the container `target`, after its children. */
	public static function moveAsChild(element: Element, target: Element): Void {
		detachFromCurrentParent(element);
		var children: Array<Element> = getChildren(target);
		children.push(element);
		setChildren(target, children);
	}

	/** Moves `element` next to `target`, in the same container: before it if `before`, otherwise after it. */
	public static function moveRelativeToTarget(element: Element, target: Element, before: Bool): Void {
		var parent: Element = getParentElement(target);
		if (parent == null || element == target) return;

		detachFromCurrentParent(element);
		var siblings: Array<Element> = getChildren(parent);
		var targetIndex: Int = siblings.indexOf(target);
		if (targetIndex < 0) return;
		siblings.insert(before ? targetIndex : targetIndex + 1, element);
		setChildren(parent, siblings);
	}

	/** The list of children of an AnchorPane, ScrollPane or Expander, or null for other elements. */
	static function layoutList(element: Element): Null<Array<Element>> {
		if (element is AnchorPane) return (cast element: AnchorPane).elements;
		if (element is ScrollPane) return (cast element: ScrollPane).elements;
		if (element is Expander) return (cast element: Expander).elements;
		return null;
	}

	/** One cell per child: a column of rows for a RowLayout, a row of columns for a ColLayout. */
	static function setCells(grid: GridLayout, children: Array<Element>, vertical: Bool): Void {
		for (element in getChildren(grid)) {
			if (children.indexOf(element) < 0) element.layout = null;
		}

		var count: Int = children.length;
		grid.amountRows = vertical ? count : 1;
		grid.amountCols = vertical ? 1 : count;
		grid.elements = new Vector(grid.amountRows);
		for (row in 0...grid.amountRows) {
			grid.elements[row] = new Vector(grid.amountCols);
			for (col in 0...grid.amountCols) {
				var child: Element = children[vertical ? row : col];
				grid.elements[row][col] = child;
				child.layout = grid;
			}
		}

		// Every cell's size and place changes
		layOut(grid);
		for (row in 0...grid.amountRows) {
			for (col in 0...grid.amountCols) grid.recalcElement(row, col);
		}
	}

	static function layOut(layout: Layout): Void {
		layout.resize(layout.layoutWidth, layout.layoutHeight);
		layout.invalidateElem();
		layout.onResize();
	}

	static function replaceAll(list: Array<Element>, items: Array<Element>): Void {
		list.resize(0);
		for (item in items) list.push(item);
	}
}
