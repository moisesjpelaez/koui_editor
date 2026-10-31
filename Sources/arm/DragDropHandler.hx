package arm;

import arm.base.UIBase;
import arm.data.History;
import arm.data.SceneData;
import arm.data.Selection;
import arm.CanvasViewport.TScreenRect;
import arm.panels.ElementsPanel;
import arm.panels.TopToolbar;
import arm.tools.HierarchyUtils;
import arm.types.Enums.PanelHandle;

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

/** A resize handle: the edges it moves, -1 for left/top, 1 for right/bottom, 0 for neither. */
typedef THandle = {
	var x: Int;
	var y: Int;
}

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane, arm.base.UIBase)
class DragDropHandler {
	var uiBase: UIBase;
	var viewport: CanvasViewport;
	var topToolbar: TopToolbar;
	var elementsPanel: ElementsPanel;

	/** How far (in pixels) the mouse must move while pressed before it drags instead of clicking. */
	static inline var MOVE_THRESHOLD: Float = 4;

	/** A resize handle's square, in pixels at UI scale 1. */
	static inline var HANDLE_SIZE: Float = 7;
	/** Corners first, so they win where handles overlap. */
	static final HANDLES: Array<THandle> = [
		{ x: -1, y: -1 }, { x: 1, y: -1 }, { x: -1, y: 1 }, { x: 1, y: 1 },
		{ x: 0, y: -1 }, { x: 0, y: 1 }, { x: -1, y: 0 }, { x: 1, y: 0 }
	];

	// Resize state: the grabbed handle of the primary element, and the selected elements with their positions and sizes.
	// The first one is the primary element; the others change by the same amount.
	var resizeHandle: Null<THandle> = null;
	var resizedElements: Array<TResizedElement> = [];
	var resizeLeadRect: TScreenRect;
	var resizeRootRect: TScreenRect;

	// Drag state: the dragged elements with their positions, and the mouse position, when the press started.
	// The first one is the element under the mouse (or its selected container); it snaps to the grid.
	var draggedElements: Array<TDraggedElement> = [];
	var dragStarted: Bool = false;
	var dragMouseX: Float = 0;
	var dragMouseY: Float = 0;
	/** The lead element's and the scene's screen rectangles when the drag started, for snapping to the grid. */
	var dragLeadRect: TScreenRect;
	var dragRootRect: TScreenRect;
	/** Pressed on an already selected element: if the mouse doesn't move, only this one gets selected on release. */
	var clickedInSelection: Null<Element> = null;
	var wasMouseDown: Bool = false;

	// Selection box: pressing on empty space and dragging past MOVE_THRESHOLD pixels
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

	/** Whether the mouse is over the canvas: left of the sidebar, above the bottom panel, and not on the toolbar or the Elements panel floating over it. */
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

	public function update() {
		if (viewport.isPanning) return;

		var rootPane: AnchorPane = SceneData.data.getRoot();
		if (rootPane == null) return;

		var mouse: Mouse = Input.getMouse();
		var mouseDown: Bool = mouse.down();
		var mouseJustPressed: Bool = mouseDown && !wasMouseDown;

		if (mouseJustPressed && isInCanvas() && startResize(mouse)) {
			// Grabbed a handle of the primary element: resize, even over another element
		} else if (mouseJustPressed && isInCanvas()) {
			var clickedElement: Element = viewport.getElementAt(Std.int(mouse.x), Std.int(mouse.y));
			var keyboard: Keyboard = Input.getKeyboard();
			var toggle: Bool = keyboard.down("control");
			var additive: Bool = keyboard.down("shift");

			if (clickedElement != null) {
				// Ctrl toggles and Shift adds to the selection; neither starts a drag
				if (toggle || additive) {
					toggle ? Selection.toggle(clickedElement) : Selection.add(clickedElement);
					draggedElements = [];
					wasMouseDown = mouseDown;
					return;
				}

				// Pressing a selected element keeps the selection, so all of it can be dragged;
				// pressing another element selects only that one
				clickedInSelection = Selection.contains(clickedElement) && Selection.elements.length > 1 ? clickedElement : null;
				if (clickedInSelection == null) Selection.select(clickedElement);
				startDrag(clickedElement, mouse);
			} else {
				// Clicking empty space clears the selection, unless adding to it
				if (!toggle && !additive) Selection.clear();
				draggedElements = [];

				// Dragging from here draws a selection box
				boxPending = true;
				boxActive = false;
				boxStartX = boxEndX = mouse.x;
				boxStartY = boxEndY = mouse.y;
				boxToggles = toggle;
				boxAdds = additive;
			}
		} else if (mouseDown && resizeHandle != null) {
			if (!dragStarted && (Math.abs(mouse.x - dragMouseX) > MOVE_THRESHOLD || Math.abs(mouse.y - dragMouseY) > MOVE_THRESHOLD)) {
				dragStarted = true;
			}
			if (dragStarted) resizeElements(mouse);
		} else if (mouseDown && boxPending) {
			boxEndX = mouse.x;
			boxEndY = mouse.y;
			if (Math.abs(boxEndX - boxStartX) > MOVE_THRESHOLD || Math.abs(boxEndY - boxStartY) > MOVE_THRESHOLD) boxActive = true;
		} else if (mouseDown && draggedElements.length > 0) {
			if (!dragStarted && (Math.abs(mouse.x - dragMouseX) > MOVE_THRESHOLD || Math.abs(mouse.y - dragMouseY) > MOVE_THRESHOLD)) {
				dragStarted = true;
			}
			if (dragStarted) moveDraggedElements(mouse);
		} else {
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
			// A click without dragging on a selected element selects only that one
			if (clickedInSelection != null && !dragStarted) Selection.select(clickedInSelection);
			clickedInSelection = null;
			draggedElements = [];
			dragStarted = false;
			topToolbar.snapInverted = false;
		}

		// A resize cursor over a handle and while resizing
		var hovered: Null<THandle> = resizeHandle != null ? resizeHandle : (!mouseDown && isInCanvas() ? getHandleAt(mouse.x, mouse.y) : null);
		if (hovered != null) {
			Krom.setMouseCursor(hovered.x == 0 ? 4 : hovered.y == 0 ? 3 : hovered.x == hovered.y ? 6 : 5);
			uiBase.cursorSet = true;
		}

		wasMouseDown = mouseDown;
	}

	/**
	 * Prepares dragging the selection by `clickedElement`: the top-level selected
	 * elements move together (a selected child moves with its selected
	 * container). Theme-sized elements are placed by the theme and stay.
	 */
	function startDrag(clickedElement: Element, mouse: Mouse): Void {
		draggedElements = [];
		dragStarted = false;
		dragMouseX = mouse.x;
		dragMouseY = mouse.y;
		if (isDynamicSized(clickedElement)) return;

		for (element in Selection.getTopLevel()) {
			if (isDynamicSized(element)) continue;
			var dragged: TDraggedElement = { element: element, startX: element.posX, startY: element.posY };
			// The element under the mouse (or the selected container it's in) goes first: it snaps
			if (element == clickedElement || HierarchyUtils.isDescendant(clickedElement, element)) draggedElements.unshift(dragged);
			else draggedElements.push(dragged);
		}
		if (draggedElements.length > 0) {
			dragLeadRect = viewport.getScreenRect(draggedElements[0].element);
			dragRootRect = viewport.getScreenRect(SceneData.data.getRoot());
		}
	}

	/**
	 * Positions are in canvas units: the mouse movement divided by the zoom. The
	 * anchors stay as they are; Koui lays the elements out before drawing. With
	 * snapping, the first element's top-left corner lands on the grid (drawn
	 * from the scene's corner, whatever the element's anchor or container) and
	 * the others move by the same amount, so their spacing stays the same.
	 */
	function moveDraggedElements(mouse: Mouse): Void {
		var mouseMoveX: Float = mouse.x - dragMouseX;
		var mouseMoveY: Float = mouse.y - dragMouseY;
		// Holding Shift while dragging locks the movement to the axis moved along most
		// (pressing with Shift adds to the selection instead)
		var lockX: Bool = false;
		var lockY: Bool = false;
		if (Input.getKeyboard().down("shift")) {
			if (Math.abs(mouseMoveX) >= Math.abs(mouseMoveY)) lockY = true;
			else lockX = true;
		}
		// The movement on screen, in canvas units
		var moveX: Float = lockX ? 0 : mouseMoveX / Koui.uiScale;
		var moveY: Float = lockY ? 0 : mouseMoveY / Koui.uiScale;
		// Holding Ctrl while dragging inverts snapping (pressing with Ctrl toggles the selection instead)
		topToolbar.snapInverted = Input.getKeyboard().down("control");
		if (topToolbar.isSnapping()) {
			var snapValue: Float = topToolbar.snapValue;
			var lead: TDraggedElement = draggedElements[0];
			// Directly in the scene, a left/top-anchored position is the corner in exact canvas units;
			// otherwise the corner is measured as drawn (in whole pixels), like resizing does
			var inScene: Bool = HierarchyUtils.getParentElement(lead.element) == SceneData.data.getRoot();
			if (!lockX) {
				var left: Float = inScene && anchorSide(lead.element, true) == -1 ? lead.startX : (dragLeadRect.x - dragRootRect.x) / Koui.uiScale;
				moveX = Math.round((left + moveX) / snapValue) * snapValue - left;
			}
			if (!lockY) {
				var top: Float = inScene && anchorSide(lead.element, false) == -1 ? lead.startY : (dragLeadRect.y - dragRootRect.y) / Koui.uiScale;
				moveY = Math.round((top + moveY) / snapValue) * snapValue - top;
			}
		}

		for (dragged in draggedElements) {
			var element: Element = dragged.element;
			var newX: Int = Math.round(dragged.startX + moveX * dragDirection(element, true));
			var newY: Int = Math.round(dragged.startY + moveY * dragDirection(element, false));
			// Koui resets the laid-out position when a position is set to its current value
			// (without laying it out again), so only set what changed
			if (newX != element.posX) element.posX = newX;
			if (newY != element.posY) element.posY = newY;
		}
	}

	/** Whether `element` shows resize handles: a placed (not theme-sized) visible element of the scene. */
	function canResize(element: Null<Element>): Bool {
		return element != null && element != SceneData.data.getRoot() && SceneData.data.isRegistered(element)
			&& !isDynamicSized(element) && element.isEffectivelyVisible();
	}

	/**
	 * The square of handle `handle` on screen rectangle `rect`. Edge handles
	 * are left out when the side is too short to hold them besides the corners.
	 */
	function getHandleRect(rect: TScreenRect, handle: THandle): Null<TScreenRect> {
		var size: Int = Std.int(HANDLE_SIZE * uiBase.ui.SCALE());
		if (handle.x == 0 && rect.w < size * 4) return null;
		if (handle.y == 0 && rect.h < size * 4) return null;
		var cx: Int = rect.x + Std.int(rect.w * (handle.x + 1) / 2);
		var cy: Int = rect.y + Std.int(rect.h * (handle.y + 1) / 2);
		return { x: cx - Std.int(size / 2), y: cy - Std.int(size / 2), w: size, h: size };
	}

	/**
	 * The primary element's handle at the screen point, or null. A handle can
	 * be grabbed a little outside its square, but reaches at most a quarter
	 * into the element, so a small element can still be moved.
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

	/** Starts resizing the selection if the mouse is on a handle of the primary element. */
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
		resizeLeadRect = viewport.getScreenRect(Selection.primary);
		resizeRootRect = viewport.getScreenRect(SceneData.data.getRoot());
		draggedElements = [];
		clickedInSelection = null;
		dragStarted = false;
		dragMouseX = mouse.x;
		dragMouseY = mouse.y;
		return true;
	}

	/**
	 * Moves the grabbed edges of the primary element with the mouse, and the
	 * same edges of the other selected elements by the same amount. The
	 * opposite edges stay where they are, whatever the anchor. With snapping,
	 * the primary element's grabbed edges land on the grid; Shift on a corner
	 * keeps the primary element's proportions.
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
			// The grabbed edge, in canvas units from the scene's left side, like the grid
			var edge: Float = (resizeLeadRect.x + (handle.x > 0 ? resizeLeadRect.w : 0) - resizeRootRect.x) / Koui.uiScale;
			var target: Float = edge + (mouse.x - dragMouseX) / Koui.uiScale;
			if (snapping) target = Math.round(target / snapValue) * snapValue;
			moveX = target - edge;
		}
		if (handle.y != 0) {
			var edge: Float = (resizeLeadRect.y + (handle.y > 0 ? resizeLeadRect.h : 0) - resizeRootRect.y) / Koui.uiScale;
			var target: Float = edge + (mouse.y - dragMouseY) / Koui.uiScale;
			if (snapping) target = Math.round(target / snapValue) * snapValue;
			moveY = target - edge;
		}

		// Shift on a corner: the side that changed most (relatively) decides the size
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
			// Koui resets the laid-out position when a position is set to its current value, so only set what changed
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
	 * The new position and size along one axis when the grabbed edge (`side`:
	 * -1 left/top, 1 right/bottom, 0 none) moves by `move` canvas units. Koui
	 * places an element from its anchor, so the position changes so the other
	 * edge stays put. The size stays at least 1.
	 */
	static function resizeAxis(element: Element, horizontal: Bool, side: Int, move: Int, start: Int, size: Int): Array<Int> {
		if (side == 0) return [start, size];
		// The size can't go below 1: the edge stops before the opposite one
		if (side < 0) move = Std.int(Math.min(move, size - 1));
		else move = Std.int(Math.max(move, 1 - size));

		var anchor: Int = anchorSide(element, horizontal);
		// Centered elements grow on both sides, so they change by an even amount to keep the other edge exact
		if (anchor == 0 && move % 2 != 0) move -= move > 0 ? 1 : -1;

		var newSize: Int = size + move * side;
		var newPos: Int = start;
		if (anchor == side) newPos = start + move * dragDirection(element, horizontal);
		else if (anchor == 0) newPos = start + Std.int(move / 2);
		return [newPos, newSize];
	}

	/** -1 if the element is placed from its left (top) edge, 0 from its center, 1 from its right (bottom) edge. */
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
	 * +1 if increasing the element's position moves it right (or down), -1 if
	 * it moves it left (or up): in a GridLayout cell, right- and bottom-anchored
	 * elements are positioned from the cell's far edge.
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
	 * Selects the visible elements fully inside the box, top-most only: an
	 * element inside another one in the box is left out. Shift adds them to
	 * the selection, Ctrl toggles them, otherwise they replace it.
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
