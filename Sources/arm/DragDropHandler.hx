package arm;

import arm.base.UIBase;
import arm.data.History;
import arm.data.SceneData;
import arm.data.Selection;
import arm.CanvasViewport.TScreenRect;
import arm.panels.TopToolbar;
import arm.tools.HierarchyUtils;
import arm.types.Enums.PanelHandle;

import iron.math.Vec2;
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

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class DragDropHandler {
	var uiBase: UIBase;
	var viewport: CanvasViewport;
	var topToolbar: TopToolbar;

	/** How far (in pixels) the mouse must move while pressed before it drags instead of clicking. */
	static inline var MOVE_THRESHOLD: Float = 4;

	// Drag state: the dragged elements with their positions, and the mouse position, when the press started.
	// The first one is the element under the mouse (or its selected container); it snaps to the grid.
	var draggedElements: Array<TDraggedElement> = [];
	var dragStarted: Bool = false;
	var dragMouseX: Float = 0;
	var dragMouseY: Float = 0;
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

	public function new(uiBase: UIBase, viewport: CanvasViewport, topToolbar: TopToolbar) {
		this.uiBase = uiBase;
		this.viewport = viewport;
		this.topToolbar = topToolbar;
	}

	public function isInCanvas(): Bool {
		var mouse: Mouse = Input.getMouse();
		var canvasMargin1: Vec2 = new Vec2(App.w() - uiBase.getSidebarW() - borderSize * 0.5, App.h() - uiBase.getBottomH() - borderSize * 0.5);
		var canvasMargin2: Vec2 = new Vec2(canvasMargin1.x - borderSize * 0.5, App.h() - uiBase.getSidebarH1() - borderSize * 0.5);
		return mouse.x < canvasMargin1.x && mouse.y < canvasMargin1.y || mouse.x < canvasMargin2.x && mouse.y < canvasMargin2.y;
	}

	public function isInHierarchyPanel(): Bool {
		var mouse: Mouse = Input.getMouse();
		var tabx: Int = uiBase.getTabX() + Std.int(borderSize * 0.5);
		var w: Int = uiBase.getSidebarW();
		var h0: Int = uiBase.getSidebarH0() - Std.int(borderSize * 0.5);
		return mouse.x > tabx && mouse.x < tabx + w && mouse.y > 0 && mouse.y < h0;
	}

	public function isInElementsPanel(): Bool {
		var mouse: Mouse = Input.getMouse();
		var uiScale: Float = uiBase.ui.SCALE();
		var panelX: Int = Std.int(10 * uiScale);
		var panelY: Int = Std.int(10 * uiScale);
		var panelW: Int = Std.int(100 * uiScale);
		var panelH: Int = App.h() - uiBase.getBottomH() - Std.int(20 * uiScale);
		return mouse.x > panelX && mouse.x < panelX + panelW && mouse.y > panelY && mouse.y < panelY + panelH;
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

		if (mouseJustPressed && isInCanvas()) {
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
		} else if (mouseJustPressed && isInHierarchyPanel()) {
			// Clicked in hierarchy panel — clear canvas drag state only.
			// The hierarchy panel updates the selection itself.
			draggedElements = [];
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
				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;
			}
			// A click without dragging on a selected element selects only that one
			if (clickedInSelection != null && !dragStarted) Selection.select(clickedInSelection);
			clickedInSelection = null;
			draggedElements = [];
			dragStarted = false;
			topToolbar.snapInverted = false;
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
	}

	/**
	 * Positions are in canvas units: the mouse movement divided by the zoom. The
	 * anchors stay as they are; Koui lays the elements out before drawing. With
	 * snapping, the first element snaps to the grid and the others move by the
	 * same amount, so their spacing stays the same.
	 */
	function moveDraggedElements(mouse: Mouse): Void {
		var lead: TDraggedElement = draggedElements[0];
		var leadDirX: Int = dragDirection(lead.element, true);
		var leadDirY: Int = dragDirection(lead.element, false);
		var leadX: Float = lead.startX + (mouse.x - dragMouseX) / Koui.uiScale * leadDirX;
		var leadY: Float = lead.startY + (mouse.y - dragMouseY) / Koui.uiScale * leadDirY;
		// Holding Ctrl while dragging inverts snapping (pressing with Ctrl toggles the selection instead)
		topToolbar.snapInverted = Input.getKeyboard().down("control");
		if (topToolbar.isSnapping()) {
			var snapValue: Float = topToolbar.snapValue;
			leadX = Math.round(leadX / snapValue) * snapValue;
			leadY = Math.round(leadY / snapValue) * snapValue;
		}
		// The movement on screen, in canvas units
		var moveX: Float = (leadX - lead.startX) * leadDirX;
		var moveY: Float = (leadY - lead.startY) * leadDirY;

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

		var topMost: Array<Element> = inside.filter(element -> {
			var parent: Element = HierarchyUtils.getParentElement(element);
			while (parent != null) {
				if (inside.indexOf(parent) >= 0) return false;
				parent = HierarchyUtils.getParentElement(parent);
			}
			return true;
		});

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
