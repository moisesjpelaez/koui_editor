package arm.tools;

import haxe.ds.Vector;

import koui.Koui;
import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Panel;

import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.Expander;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout;
import koui.elements.layouts.Layout.Anchor;
import koui.elements.layouts.RowLayout;
import koui.elements.layouts.ScrollPane;

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.Layout, koui.elements.layouts.AnchorPane, koui.elements.layouts.ScrollPane, koui.elements.layouts.Expander, koui.elements.layouts.GridLayout, koui.elements.layouts.RowLayout, koui.elements.layouts.ColLayout)
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
		if (parent is AnchorPane || parent is ScrollPane || parent is Expander) return untyped parent.elements;
		// GridLayout/RowLayout/ColLayout use 2D Vector<Vector<Element>>, need to flatten
		if (parent is GridLayout || parent is RowLayout || parent is ColLayout) {
			var grid: GridLayout = cast parent;
			var flattened = new Array<Element>();
			for (row in grid.elements) {
				for (element in row) {
					if (element != null) flattened.push(element);
				}
			}
			return flattened;
		}
		return parent.children;
	}

	public static function detachFromCurrentParent(element: Element): Void {
		if (element == null) return;
		if (element.layout != null) {
			var layout: Layout = element.layout;
			if (layout is AnchorPane || layout is ScrollPane || layout is Expander || layout is GridLayout || layout is RowLayout || layout is ColLayout) {
				untyped layout.remove(element);
				// Compact and shrink RowLayout/ColLayout
				if (layout is RowLayout) {
					var grid: GridLayout = cast layout;
					compactRows(grid);
					while (removeLastRowIfEmpty(grid)) {}
					grid.resize(grid.layoutWidth, grid.layoutHeight);
					grid.invalidateElem();
					grid.onResize();
				} else if (layout is ColLayout) {
					var grid: GridLayout = cast layout;
					compactColumns(grid);
					while (removeLastColumnIfEmpty(grid)) {}
					grid.resize(grid.layoutWidth, grid.layoutHeight);
					grid.invalidateElem();
					grid.onResize();
				}
				return;
			}
		}
		if (element.parent != null) element.parent.removeChild(element);
	}

	public static function moveAsChild(element: Element, target: Element, ?fallbackParent: AnchorPane): Void { // TODO: remove third arg?
		detachFromCurrentParent(element);

		if (target is RowLayout) {
			var row: RowLayout = cast target;
			var grid: GridLayout = cast row;
			var slot: Int = findFirstEmptyRowSlot(row);
			if (slot < 0) {
				// No empty slot, add a new row
				addRowToGrid(grid);
				slot = grid.amountRows - 1;
			}
			row.addToRow(element, slot);
			grid.resize(grid.layoutWidth, grid.layoutHeight);
			grid.invalidateElem();
			grid.onResize();
		} else if (target is ColLayout) {
			var col: ColLayout = cast target;
			var grid: GridLayout = cast col;
			var slot: Int = findFirstEmptyColSlot(col);
			if (slot < 0) {
				// No empty slot, add a new column
				addColumnToGrid(grid);
				slot = grid.amountCols - 1;
			}
			col.addToColumn(element, slot);
			grid.resize(grid.layoutWidth, grid.layoutHeight);
			grid.invalidateElem();
			grid.onResize();
		} else if (target is Layout && (target is AnchorPane || target is ScrollPane || target is Expander)) {
			untyped cast(target, Layout).add(element);
		} else if (target is Panel) {
			target.addChild(element);
		}

	}

	static function findFirstEmptyRowSlot(row: RowLayout): Int {
		var grid: GridLayout = cast row;
		if (grid.amountRows == 0) return -1;
		for (i in 0...grid.elements.length) {
			if (grid.elements[i][0] == null) return i;
		}
		return -1; // No empty slot
	}

	static function findFirstEmptyColSlot(col: ColLayout): Int {
		var grid: GridLayout = cast col;
		if (grid.amountCols == 0 || grid.elements.length == 0) return -1;
		for (i in 0...grid.elements[0].length) {
			if (grid.elements[0][i] == null) return i;
		}
		return -1; // No empty slot
	}

	static function findRowIndex(grid: GridLayout, element: Element): Int {
		for (i in 0...grid.amountRows) {
			if (grid.elements[i][0] == element) return i;
		}
		return -1;
	}

	static function findColIndex(grid: GridLayout, element: Element): Int {
		if (grid.amountRows == 0) return -1;
		for (i in 0...grid.amountCols) {
			if (grid.elements[0][i] == element) return i;
		}
		return -1;
	}

	public static function moveRelativeToTarget(element: Element, target: Element, before: Bool): Void {
		var parent: Element = getParentElement(target);
		if (parent == null) return;

		// Handle RowLayout reordering
		if (parent is RowLayout) {
			var grid: GridLayout = cast parent;
			var targetIdx: Int = findRowIndex(grid, target);
			if (targetIdx < 0) return;

			var elementIdx: Int = findRowIndex(grid, element);
			var sameParent: Bool = elementIdx >= 0;

			if (sameParent) {
				// Reorder within same parent - shift elements
				var insertIdx: Int = before ? targetIdx : targetIdx + 1;
				if (elementIdx < insertIdx) insertIdx--; // Adjust for removal

				// Remove from current position
				grid.elements[elementIdx][0] = null;

				// Shift elements to fill gap and make room
				if (elementIdx < insertIdx) {
					// Moving down - shift elements up
					for (i in elementIdx...insertIdx) {
						grid.elements[i][0] = grid.elements[i + 1][0];
						if (grid.elements[i][0] != null) grid.recalcElement(i, 0);
					}
				} else {
					// Moving up - shift elements down
					var i = elementIdx;
					while (i > insertIdx) {
						grid.elements[i][0] = grid.elements[i - 1][0];
						if (grid.elements[i][0] != null) grid.recalcElement(i, 0);
						i--;
					}
				}

				// Insert at new position
				grid.elements[insertIdx][0] = element;
				element.layout = cast grid;
				grid.recalcElement(insertIdx, 0);
			} else {
				// Moving from different parent
				detachFromCurrentParent(element);
				var insertIdx: Int = before ? targetIdx : targetIdx + 1;

				// Need to add a row and shift elements down from insertIdx
				addRowToGrid(grid);
				var i = grid.amountRows - 1;
				while (i > insertIdx) {
					grid.elements[i][0] = grid.elements[i - 1][0];
					if (grid.elements[i][0] != null) grid.recalcElement(i, 0);
					i--;
				}
				grid.elements[insertIdx][0] = element;
				element.layout = cast grid;
				grid.recalcElement(insertIdx, 0);
			}
			grid.resize(grid.layoutWidth, grid.layoutHeight);
			grid.invalidateElem();
			grid.onResize();
			return;
		}

		// Handle ColLayout reordering
		if (parent is ColLayout) {
			var grid: GridLayout = cast parent;
			var targetIdx: Int = findColIndex(grid, target);
			if (targetIdx < 0) return;

			var elementIdx: Int = findColIndex(grid, element);
			var sameParent: Bool = elementIdx >= 0;

			if (sameParent) {
				// Reorder within same parent - shift elements
				var insertIdx: Int = before ? targetIdx : targetIdx + 1;
				if (elementIdx < insertIdx) insertIdx--; // Adjust for removal

				// Remove from current position
				grid.elements[0][elementIdx] = null;

				// Shift elements to fill gap and make room
				if (elementIdx < insertIdx) {
					// Moving right - shift elements left
					for (i in elementIdx...insertIdx) {
						grid.elements[0][i] = grid.elements[0][i + 1];
						if (grid.elements[0][i] != null) grid.recalcElement(0, i);
					}
				} else {
					// Moving left - shift elements right
					var i = elementIdx;
					while (i > insertIdx) {
						grid.elements[0][i] = grid.elements[0][i - 1];
						if (grid.elements[0][i] != null) grid.recalcElement(0, i);
						i--;
					}
				}

				// Insert at new position
				grid.elements[0][insertIdx] = element;
				element.layout = cast grid;
				grid.recalcElement(0, insertIdx);
			} else {
				// Moving from different parent
				detachFromCurrentParent(element);
				var insertIdx: Int = before ? targetIdx : targetIdx + 1;

				// Need to add a column and shift elements right from insertIdx
				addColumnToGrid(grid);
				var i = grid.amountCols - 1;
				while (i > insertIdx) {
					grid.elements[0][i] = grid.elements[0][i - 1];
					if (grid.elements[0][i] != null) grid.recalcElement(0, i);
					i--;
				}
				grid.elements[0][insertIdx] = element;
				element.layout = cast grid;
				grid.recalcElement(0, insertIdx);
			}
			grid.resize(grid.layoutWidth, grid.layoutHeight);
			grid.invalidateElem();
			grid.onResize();
			return;
		}

		detachFromCurrentParent(element);

		var elements: Array<Element>;
		if (parent is AnchorPane || parent is ScrollPane || parent is Expander) {
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

	/**
	 * Adds a new row to the grid layout.
	 * The layout's height remains the same, cells become smaller.
	 */
	public static function addRowToGrid(grid: GridLayout): Void {
		grid.amountRows++;

		// Create new elements vector with additional row
		var newElements = new Vector<Vector<Element>>(grid.amountRows);
		for (row in 0...grid.amountRows - 1) {
			newElements[row] = grid.elements[row];
		}
		newElements[grid.amountRows - 1] = new Vector<Element>(grid.amountCols);
		grid.elements = newElements;

		// Recalculate cell sizes
		if (grid.amountRows > 0) {
			grid.cellHeight = Std.int(grid.layoutHeight * Koui.uiScale / grid.amountRows);
		}

		// Recalculate all elements
		for (row in 0...grid.elements.length) {
			for (col in 0...grid.amountCols) {
				grid.recalcElement(row, col);
			}
		}
	}

	/**
	 * Adds a new column to the grid layout.
	 * The layout's width remains the same, cells become smaller.
	 */
	public static function addColumnToGrid(grid: GridLayout): Void {
		grid.amountCols++;

		// Resize each row's vector to have one more column
		for (row in 0...grid.amountRows) {
			var oldRow = grid.elements[row];
			var newRow = new Vector<Element>(grid.amountCols);
			for (col in 0...grid.amountCols - 1) {
				newRow[col] = oldRow[col];
			}
			grid.elements[row] = newRow;
		}

		// Recalculate cell sizes
		if (grid.amountCols > 0) {
			grid.cellWidth = Std.int(grid.layoutWidth * Koui.uiScale / grid.amountCols);
		}

		// Recalculate all elements
		for (row in 0...grid.amountRows) {
			for (col in 0...grid.elements[row].length) {
				grid.recalcElement(row, col);
			}
		}
	}

	/**
	 * Removes the last row from the grid layout if it's empty.
	 * Returns true if a row was removed.
	 */
	public static function removeLastRowIfEmpty(grid: GridLayout): Bool {
		if (grid.amountRows == 0) return false;

		// Check if last row is empty
		var lastRow = grid.amountRows - 1;
		for (col in 0...grid.amountCols) {
			if (grid.elements[lastRow][col] != null) return false;
		}

		// Remove the last row
		grid.amountRows--;
		var newElements = new Vector<Vector<Element>>(grid.amountRows);
		for (row in 0...grid.amountRows) {
			newElements[row] = grid.elements[row];
		}
		grid.elements = newElements;

		// Recalculate cell sizes
		if (grid.amountRows > 0) {
			grid.cellHeight = Std.int(grid.layoutHeight * Koui.uiScale / grid.amountRows);
		}

		// Recalculate all elements
		for (row in 0...grid.amountRows) {
			for (col in 0...grid.amountCols) {
				grid.recalcElement(row, col);
			}
		}
		return true;
	}

	/**
	 * Removes the last column from the grid layout if it's empty.
	 * Returns true if a column was removed.
	 */
	public static function removeLastColumnIfEmpty(grid: GridLayout): Bool {
		if (grid.amountCols == 0) return false;

		// Check if last column is empty
		var lastCol = grid.amountCols - 1;
		for (row in 0...grid.amountRows) {
			if (grid.elements[row][lastCol] != null) return false;
		}

		// Remove the last column
		grid.amountCols--;
		for (row in 0...grid.amountRows) {
			var oldRow = grid.elements[row];
			var newRow = new Vector<Element>(grid.amountCols);
			for (col in 0...grid.amountCols) {
				newRow[col] = oldRow[col];
			}
			grid.elements[row] = newRow;
		}

		// Recalculate cell sizes
		if (grid.amountCols > 0) {
			grid.cellWidth = Std.int(grid.layoutWidth * Koui.uiScale / grid.amountCols);
		}

		// Recalculate all elements
		for (row in 0...grid.amountRows) {
			for (col in 0...grid.amountCols) {
				grid.recalcElement(row, col);
			}
		}
		return true;
	}

	/**
	 * Compacts rows by shifting elements up to fill gaps.
	 * Used for RowLayout (single column).
	 */
	static function compactRows(grid: GridLayout): Void {
		if (grid.amountRows == 0) return;

		var writeIdx: Int = 0;
		for (readIdx in 0...grid.amountRows) {
			if (grid.elements[readIdx][0] != null) {
				if (writeIdx != readIdx) {
					grid.elements[writeIdx][0] = grid.elements[readIdx][0];
					grid.elements[readIdx][0] = null;
				}
				writeIdx++;
			}
		}
	}

	/**
	 * Compacts columns by shifting elements left to fill gaps.
	 * Used for ColLayout (single row).
	 */
	static function compactColumns(grid: GridLayout): Void {
		if (grid.amountCols == 0 || grid.amountRows == 0) return;

		var writeIdx: Int = 0;
		for (readIdx in 0...grid.amountCols) {
			if (grid.elements[0][readIdx] != null) {
				if (writeIdx != readIdx) {
					grid.elements[0][writeIdx] = grid.elements[0][readIdx];
					grid.elements[0][readIdx] = null;
				}
				writeIdx++;
			}
		}
	}
}
