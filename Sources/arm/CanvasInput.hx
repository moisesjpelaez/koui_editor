package arm;

import arm.base.UIBase;
import arm.data.History;
import arm.data.SceneData;
import arm.data.Selection;
import arm.CanvasViewport.TScreenRect;
import arm.panels.ElementsPanel;
import arm.panels.TopToolbar;
import arm.tools.HierarchyUtils;
import arm.types.Enums;

import iron.system.Input;
import iron.system.Input.Keyboard;
import iron.system.Input.Mouse;

import koui.Koui;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout.Anchor;

import iron.App;

typedef TDraggedElement = {
	var element: Element;
	var startX: Int;
	var startY: Int;
}

typedef TResizedElement = {
	var element: Element;
	var startX: Int;
	var startY: Int;
	var startW: Int;
	var startH: Int;
}

// A resize handle by the edges it moves: -1 left/top, 1 right/bottom, 0 neither
typedef THandle = {
	var x: Int;
	var y: Int;
}

// Mouse input on the canvas: selecting, the selection box, moving and resizing
@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class CanvasInput {
	var uiBase: UIBase;
	var viewport: CanvasViewport;
	var topToolbar: TopToolbar;
	var elementsPanel: ElementsPanel;

	// Pixels the mouse moves while pressed before a click becomes a drag
	static inline var MOVE_THRESHOLD: Float = 4;

	// Pixels at UI scale 1
	static inline var HANDLE_SIZE: Float = 7;
	// Corners first, so they win where handles overlap
	static final HANDLES: Array<THandle> = [
		{ x: -1, y: -1 }, { x: 1, y: -1 }, { x: -1, y: 1 }, { x: 1, y: 1 },
		{ x: 0, y: -1 }, { x: 0, y: 1 }, { x: -1, y: 0 }, { x: 1, y: 0 }
	];

	// Resizing: the first element is the primary one, the others change by the same amount
	var resizeHandle: Null<THandle> = null;
	var resizedElements: Array<TResizedElement> = [];
	// The primary element's top-left corner at the start, in canvas units
	var resizeLeadX: Float = 0;
	var resizeLeadY: Float = 0;

	// Dragging: the first element is the one under the mouse (or its selected container) and snaps to the grid
	var draggedElements: Array<TDraggedElement> = [];
	var dragStarted: Bool = false;
	var dragMouseX: Float = 0;
	var dragMouseY: Float = 0;
	// The first element's top-left corner at the start, in canvas units
	var dragLeadX: Float = 0;
	var dragLeadY: Float = 0;
	// A selected element that was pressed: a click without dragging selects only it
	var clickedInSelection: Null<Element> = null;

	// Selection box, from a press on empty space
	var boxPending: Bool = false;
	var boxActive: Bool = false;
	var boxStartX: Float = 0;
	var boxStartY: Float = 0;
	var boxEndX: Float = 0;
	var boxEndY: Float = 0;
	var boxToggles: Bool = false;
	var boxAdds: Bool = false;

	var borderSize: Int = 8;

	public function new(uiBase: UIBase, viewport: CanvasViewport, topToolbar: TopToolbar, elementsPanel: ElementsPanel) {
		this.uiBase = uiBase;
		this.viewport = viewport;
		this.topToolbar = topToolbar;
		this.elementsPanel = elementsPanel;
	}

	// Whether the mouse is over the canvas and not over a panel or the toolbar
	public function isInCanvas(): Bool {
		var mouse: Mouse = Input.getMouse();
		if (mouse.x >= App.w() - uiBase.getSidebarW() - borderSize * 0.5) return false;
		if (mouse.y >= App.h() - uiBase.getBottomH() - borderSize * 0.5) return false;
		return !contains(topToolbar.getRect(uiBase), mouse.x, mouse.y) && !contains(elementsPanel.getRect(uiBase), mouse.x, mouse.y);
	}

	static function contains(rect: TScreenRect, x: Float, y: Float): Bool {
		return x >= rect.x && x < rect.x + rect.w && y >= rect.y && y < rect.y + rect.h;
	}

	function isDynamicSized(element: Element): Bool {
		var isDynamicWidth: Bool = element.style != null && element.style.size.minWidth != 0;
		var isDynamicHeight: Bool = element.style != null && element.style.size.minHeight != 0;
		return isDynamicWidth || isDynamicHeight;
	}

	// Called from the editor's update: Iron's started/released states are only valid there
	public function update() {
		if (SceneData.data.getRoot() == null) return;

		var mouse: Mouse = Input.getMouse();
		// A press and release in the same frame both run. Panning, or a button up
		// without a release (Iron's Mouse.reset()), still ends what the press started
		if (!viewport.isPanning) {
			if (mouse.started() && isInCanvas()) onPress(mouse);
			else if (mouse.down()) onDrag(mouse);
		}
		if (mouse.released() || (!mouse.down() && isActive())) onRelease();
		if (viewport.isPanning) return;

		var hovered: Null<THandle> = resizeHandle != null ? resizeHandle : (!mouse.down() && isInCanvas() ? getHandleAt(mouse.x, mouse.y) : null);
		if (hovered != null) uiBase.setCursor(hovered.x == 0 ? ResizeVertical : hovered.y == 0 ? ResizeHorizontal : hovered.x == hovered.y ? ResizeDiagonalDown : ResizeDiagonalUp);
	}

	function onPress(mouse: Mouse): Void {
		// Handles win over the elements under them
		if (startResize(mouse)) return;

		var clickedElement: Element = viewport.getElementAt(Std.int(mouse.x), Std.int(mouse.y));
		var keyboard: Keyboard = Input.getKeyboard();
		var toggle: Bool = keyboard.down("control");
		var additive: Bool = keyboard.down("shift");

		if (clickedElement != null) {
			// Ctrl toggles and Shift adds to the selection; neither starts a drag
			if (toggle || additive) {
				toggle ? Selection.toggle(clickedElement) : Selection.add(clickedElement);
				return;
			}

			// Pressing a selected element keeps the selection, so all of it can be dragged
			clickedInSelection = Selection.contains(clickedElement) && Selection.elements.length > 1 ? clickedElement : null;
			if (clickedInSelection == null) Selection.select(clickedElement);
			startDrag(clickedElement, mouse);
		} else {
			if (!toggle && !additive) Selection.clear();

			boxPending = true;
			boxStartX = boxEndX = mouse.x;
			boxStartY = boxEndY = mouse.y;
			boxToggles = toggle;
			boxAdds = additive;
		}
	}

	function onDrag(mouse: Mouse): Void {
		if (resizeHandle != null) {
			if (!dragStarted) dragStarted = movedPastThreshold(mouse);
			if (dragStarted) resizeElements(mouse);
		} else if (boxPending) {
			boxEndX = mouse.x;
			boxEndY = mouse.y;
			if (Math.abs(boxEndX - boxStartX) > MOVE_THRESHOLD || Math.abs(boxEndY - boxStartY) > MOVE_THRESHOLD) boxActive = true;
		} else if (draggedElements.length > 0) {
			if (!dragStarted) dragStarted = movedPastThreshold(mouse);
			if (dragStarted) moveDraggedElements(mouse);
		}
	}

	function onRelease(): Void {
		if (boxActive) selectInBox();
		boxPending = boxActive = false;

		if (draggedElements.length > 0) {
			var moved: Bool = false;
			for (dragged in draggedElements) {
				if (dragged.element.posX != dragged.startX || dragged.element.posY != dragged.startY) moved = true;
			}
			if (moved) History.edited("Move");
			uiBase.redrawPanels();
		}
		if (resizeHandle != null) {
			var resized: Bool = false;
			for (r in resizedElements) {
				var e: Element = r.element;
				if (e.posX != r.startX || e.posY != r.startY || e.width != r.startW || e.height != r.startH) resized = true;
			}
			if (resized) History.edited("Resize");
			uiBase.hwnds[PanelProperties].redraws = 2;
			resizeHandle = null;
			resizedElements = [];
		}
		if (clickedInSelection != null && !dragStarted) Selection.select(clickedInSelection);
		clickedInSelection = null;
		draggedElements = [];
		dragStarted = false;
		topToolbar.snapInverted = false;
	}

	// Whether a press started something that a release has to end
	function isActive(): Bool {
		return resizeHandle != null || boxPending || draggedElements.length > 0 || clickedInSelection != null;
	}

	function movedPastThreshold(mouse: Mouse): Bool {
		return Math.abs(mouse.x - dragMouseX) > MOVE_THRESHOLD || Math.abs(mouse.y - dragMouseY) > MOVE_THRESHOLD;
	}

	// Prepares dragging the top-level selected elements; theme-sized ones stay where the theme puts them
	function startDrag(clickedElement: Element, mouse: Mouse): Void {
		draggedElements = [];
		dragStarted = false;
		dragMouseX = mouse.x;
		dragMouseY = mouse.y;
		if (isDynamicSized(clickedElement)) return;

		for (element in Selection.getTopLevel()) {
			if (isDynamicSized(element)) continue;
			var dragged: TDraggedElement = { element: element, startX: element.posX, startY: element.posY };
			if (element == clickedElement || HierarchyUtils.isDescendant(clickedElement, element)) draggedElements.unshift(dragged);
			else draggedElements.push(dragged);
		}
		if (draggedElements.length > 0) {
			dragLeadX = canvasCorner(draggedElements[0].element, true);
			dragLeadY = canvasCorner(draggedElements[0].element, false);
		}
	}

	/**
	 * Moves in canvas units, keeping the anchors. With snapping, the first
	 * element's top-left corner lands on the grid and the others keep their
	 * spacing to it.
	 */
	function moveDraggedElements(mouse: Mouse): Void {
		var mouseMoveX: Float = mouse.x - dragMouseX;
		var mouseMoveY: Float = mouse.y - dragMouseY;
		// Shift locks the movement to the axis moved along most
		var lockX: Bool = false;
		var lockY: Bool = false;
		if (Input.getKeyboard().down("shift")) {
			if (Math.abs(mouseMoveX) >= Math.abs(mouseMoveY)) lockY = true;
			else lockX = true;
		}
		var moveX: Float = lockX ? 0 : mouseMoveX / Koui.uiScale;
		var moveY: Float = lockY ? 0 : mouseMoveY / Koui.uiScale;
		// Ctrl inverts snapping
		topToolbar.snapInverted = Input.getKeyboard().down("control");
		if (topToolbar.isSnapping()) {
			var snapValue: Float = topToolbar.snapValue;
			if (!lockX) moveX = Math.round((dragLeadX + moveX) / snapValue) * snapValue - dragLeadX;
			if (!lockY) moveY = Math.round((dragLeadY + moveY) / snapValue) * snapValue - dragLeadY;
		}

		for (dragged in draggedElements) {
			var element: Element = dragged.element;
			var newX: Int = Math.round(dragged.startX + moveX * dragDirection(element, true));
			var newY: Int = Math.round(dragged.startY + moveY * dragDirection(element, false));
			// Setting a position to its current value resets Koui's laid-out position, so only set what changed
			if (newX != element.posX) element.posX = newX;
			if (newY != element.posY) element.posY = newY;
		}
	}

	// Visible, not theme-sized elements of the scene can be resized
	function canResize(element: Null<Element>): Bool {
		return element != null && element != SceneData.data.getRoot() && SceneData.data.isRegistered(element)
			&& !isDynamicSized(element) && element.isEffectivelyVisible();
	}

	// The handle's square on `rect`, or null for an edge handle on a side too short for it
	function getHandleRect(rect: TScreenRect, handle: THandle): Null<TScreenRect> {
		var size: Int = Std.int(HANDLE_SIZE * uiBase.ui.SCALE());
		if (handle.x == 0 && rect.w < size * 4) return null;
		if (handle.y == 0 && rect.h < size * 4) return null;
		var cx: Int = rect.x + Std.int(rect.w * (handle.x + 1) / 2);
		var cy: Int = rect.y + Std.int(rect.h * (handle.y + 1) / 2);
		return { x: cx - Std.int(size / 2), y: cy - Std.int(size / 2), w: size, h: size };
	}

	/**
	 * The primary element's handle at the screen point, or null. A handle reaches
	 * a little past its square but at most a quarter into the element, so a
	 * small element can still be moved.
	 */
	function getHandleAt(x: Float, y: Float): Null<THandle> {
		var element: Null<Element> = Selection.primary;
		if (!canResize(element)) return null;
		var rect: TScreenRect = viewport.getScreenRect(element);
		var margin: Float = 3 * uiBase.ui.SCALE();
		for (handle in HANDLES) {
			var square: Null<TScreenRect> = getHandleRect(rect, handle);
			if (square == null) continue;
			var left: Float = square.x - margin;
			var right: Float = square.x + square.w + margin;
			var top: Float = square.y - margin;
			var bottom: Float = square.y + square.h + margin;
			if (handle.x < 0) right = Math.min(right, rect.x + rect.w / 4);
			if (handle.x > 0) left = Math.max(left, rect.x + rect.w * 3 / 4);
			if (handle.y < 0) bottom = Math.min(bottom, rect.y + rect.h / 4);
			if (handle.y > 0) top = Math.max(top, rect.y + rect.h * 3 / 4);
			if (x >= left && x <= right && y >= top && y <= bottom) return handle;
		}
		return null;
	}

	// Starts resizing the selection if the mouse is on a handle of the primary element
	function startResize(mouse: Mouse): Bool {
		var handle: Null<THandle> = getHandleAt(mouse.x, mouse.y);
		if (handle == null) return false;

		resizeHandle = handle;
		resizedElements = [];
		for (element in Selection.elements) {
			if (!canResize(element)) continue;
			var resized: TResizedElement = { element: element, startX: element.posX, startY: element.posY, startW: element.width, startH: element.height };
			if (element == Selection.primary) resizedElements.unshift(resized);
			else resizedElements.push(resized);
		}
		resizeLeadX = canvasCorner(Selection.primary, true);
		resizeLeadY = canvasCorner(Selection.primary, false);
		draggedElements = [];
		clickedInSelection = null;
		dragStarted = false;
		dragMouseX = mouse.x;
		dragMouseY = mouse.y;
		return true;
	}

	/**
	 * Moves the grabbed edges with the mouse, on every resized element by the
	 * same amount; the opposite edges stay put. With snapping, the primary
	 * element's edges land on the grid. Shift on a corner keeps its proportions.
	 */
	function resizeElements(mouse: Mouse): Void {
		var handle: THandle = resizeHandle;
		var lead: TResizedElement = resizedElements[0];
		topToolbar.snapInverted = Input.getKeyboard().down("control");
		var snapping: Bool = topToolbar.isSnapping();
		var snapValue: Float = topToolbar.snapValue;

		// How far each grabbed edge moves, in canvas units
		var moveX: Float = 0;
		var moveY: Float = 0;
		if (handle.x != 0) {
			// From the scene's left side, like the grid
			var edge: Float = resizeLeadX + (handle.x > 0 ? lead.startW : 0);
			var target: Float = edge + (mouse.x - dragMouseX) / Koui.uiScale;
			if (snapping) target = Math.round(target / snapValue) * snapValue;
			moveX = target - edge;
		}
		if (handle.y != 0) {
			var edge: Float = resizeLeadY + (handle.y > 0 ? lead.startH : 0);
			var target: Float = edge + (mouse.y - dragMouseY) / Koui.uiScale;
			if (snapping) target = Math.round(target / snapValue) * snapValue;
			moveY = target - edge;
		}

		// Shift on a corner: the side that changed most, relatively, decides the size
		if (handle.x != 0 && handle.y != 0 && Input.getKeyboard().down("shift") && lead.startW > 0 && lead.startH > 0) {
			var w: Float = lead.startW + moveX * handle.x;
			var h: Float = lead.startH + moveY * handle.y;
			if (Math.abs(w / lead.startW - 1) >= Math.abs(h / lead.startH - 1)) h = w * lead.startH / lead.startW;
			else w = h * lead.startW / lead.startH;
			moveX = (w - lead.startW) * handle.x;
			moveY = (h - lead.startH) * handle.y;
		}

		for (resized in resizedElements) {
			var horizontal: Array<Int> = resizeAxis(resized.element, true, handle.x, Math.round(moveX), resized.startX, resized.startW);
			var vertical: Array<Int> = resizeAxis(resized.element, false, handle.y, Math.round(moveY), resized.startY, resized.startH);
			var element: Element = resized.element;
			// Only set what changed, see moveDraggedElements
			if (horizontal[0] != element.posX) element.posX = horizontal[0];
			if (vertical[0] != element.posY) element.posY = vertical[0];
			if (horizontal[1] != element.width || vertical[1] != element.height) {
				element.width = horizontal[1];
				element.height = vertical[1];
				Koui.updateElementSize(element);
			}
		}
	}

	/**
	 * [position, size] along one axis when the edge `side` (as in THandle) moves
	 * by `move` canvas units. Koui places elements from their anchor, so the
	 * position changes to keep the opposite edge in place.
	 */
	static function resizeAxis(element: Element, horizontal: Bool, side: Int, move: Int, start: Int, size: Int): Array<Int> {
		if (side == 0) return [start, size];
		// The size stays at least 1
		if (side < 0) move = Std.int(Math.min(move, size - 1));
		else move = Std.int(Math.max(move, 1 - size));

		var anchor: Int = anchorSide(element, horizontal);
		// Centered elements grow on both sides: an even amount keeps the opposite edge exact
		if (anchor == 0 && move % 2 != 0) move -= move > 0 ? 1 : -1;

		var newSize: Int = size + move * side;
		var newPos: Int = start;
		if (anchor == side) newPos = start + move * dragDirection(element, horizontal);
		else if (anchor == 0) newPos = start + Std.int(move / 2);
		return [newPos, newSize];
	}

	/**
	 * The element's left (top) edge in canvas units from the scene's corner,
	 * where the grid starts. In AnchorPanes it's computed unrounded, so snapping
	 * is exact at any zoom; in Row/Col layouts, whose cells are rounded to
	 * pixels, it's measured as drawn.
	 */
	function canvasCorner(element: Element, horizontal: Bool): Float {
		var root: AnchorPane = SceneData.data.getRoot();
		if (element == root) return 0;

		if (Std.isOfType(element.layout, AnchorPane)) {
			var pane: AnchorPane = cast element.layout;
			var pos: Float = horizontal ? element.posX : element.posY;
			var size: Float = horizontal ? element.layoutWidth : element.layoutHeight;
			var paneSize: Float = horizontal ? pane.layoutWidth : pane.layoutHeight;
			var offset: Float = switch (anchorSide(element, horizontal)) {
				case -1: pos + (horizontal ? pane.paddingLeft : pane.paddingTop);
				case 0: paneSize / 2 - size / 2 + pos;
				default: paneSize - size + pos - (horizontal ? pane.paddingRight : pane.paddingBottom);
			}
			return canvasCorner(pane, horizontal) + offset;
		}

		var rect: TScreenRect = viewport.getScreenRect(element);
		var rootRect: TScreenRect = viewport.getScreenRect(root);
		return horizontal ? (rect.x - rootRect.x) / Koui.uiScale : (rect.y - rootRect.y) / Koui.uiScale;
	}

	// -1 if the element is placed from its left (top) edge, 0 from its center, 1 from its right (bottom) edge
	static function anchorSide(element: Element, horizontal: Bool): Int {
		return switch (element.getAnchorResolved()) {
			case TopLeft | MiddleLeft | BottomLeft if (horizontal): -1;
			case TopCenter | MiddleCenter | BottomCenter if (horizontal): 0;
			case TopRight | MiddleRight | BottomRight if (horizontal): 1;
			case TopLeft | TopCenter | TopRight: -1;
			case MiddleLeft | MiddleCenter | MiddleRight: 0;
			case BottomLeft | BottomCenter | BottomRight: 1;
			default: -1;
		}
	}

	/**
	 * 1 if a larger position moves the element right (down), -1 if left (up):
	 * in a GridLayout cell, right- and bottom-anchored elements are placed from
	 * the cell's far edge.
	 */
	static function dragDirection(element: Element, horizontal: Bool): Int {
		if (!Std.isOfType(element.layout, GridLayout)) return 1;
		return switch (element.getAnchorResolved()) {
			case TopRight | MiddleRight | BottomRight if (horizontal): -1;
			case BottomLeft | BottomCenter | BottomRight if (!horizontal): -1;
			default: 1;
		}
	}

	public function drawSelectedElements(g2: kha.graphics2.Graphics) {
		viewport.drawSelection(g2);
		if (boxActive) viewport.drawSelectionBox(g2, getBoxRect());
		else drawHandles(g2);
	}

	function drawHandles(g2: kha.graphics2.Graphics): Void {
		var element: Null<Element> = Selection.primary;
		if (!canResize(element)) return;
		var rect: TScreenRect = viewport.getScreenRect(element);
		for (handle in HANDLES) {
			var square: Null<TScreenRect> = getHandleRect(rect, handle);
			if (square == null) continue;
			g2.color = 0xff469cff;
			g2.fillRect(square.x, square.y, square.w, square.h);
			g2.color = 0xffffffff;
			g2.fillRect(square.x + 1, square.y + 1, square.w - 2, square.h - 2);
		}
	}

	function getBoxRect(): TScreenRect {
		var x: Int = Std.int(Math.min(boxStartX, boxEndX));
		var y: Int = Std.int(Math.min(boxStartY, boxEndY));
		return { x: x, y: y, w: Std.int(Math.max(boxStartX, boxEndX)) - x, h: Std.int(Math.max(boxStartY, boxEndY)) - y };
	}

	/**
	 * Selects the top-most visible elements fully inside the box. Shift adds
	 * them to the selection, Ctrl toggles them, otherwise they replace it.
	 */
	function selectInBox(): Void {
		var box: TScreenRect = getBoxRect();
		var inside: Array<Element> = [];
		for (element in SceneData.data.getElements()) {
			if (!element.isEffectivelyVisible()) continue;
			var rect: TScreenRect = viewport.getScreenRect(element);
			if (rect.x >= box.x && rect.y >= box.y && rect.x + rect.w <= box.x + box.w && rect.y + rect.h <= box.y + box.h) {
				inside.push(element);
			}
		}

		var topMost: Array<Element> = HierarchyUtils.topMost(inside);

		if (boxToggles) {
			var result: Array<Element> = Selection.elements.copy();
			for (element in topMost) {
				if (!result.remove(element)) result.push(element);
			}
			Selection.setAll(result);
		} else if (boxAdds) {
			Selection.setAll(Selection.elements.concat(topMost));
		} else {
			Selection.setAll(topMost);
		}
	}
}
