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

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class DragDropHandler {
	var uiBase: UIBase;
	var viewport: CanvasViewport;
	var topToolbar: TopToolbar;

	// Drag state: the element's position and the mouse position when the drag started
	var draggedElement: Element = null;
	var wasMouseDown: Bool = false;
	var dragStartX: Int = 0;
	var dragStartY: Int = 0;
	var dragMouseX: Float = 0;
	var dragMouseY: Float = 0;

	// Selection box: pressing on empty space and dragging past BOX_THRESHOLD pixels
	static inline var BOX_THRESHOLD: Float = 4;
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
					draggedElement = null;
					wasMouseDown = mouseDown;
					return;
				}

				Selection.select(clickedElement);
				if (isDynamicSized(clickedElement)) {
					draggedElement = null;
					return;
				}
				draggedElement = clickedElement;
				dragStartX = draggedElement.posX;
				dragStartY = draggedElement.posY;
				dragMouseX = mouse.x;
				dragMouseY = mouse.y;
			} else {
				// Clicking empty space clears the selection, unless adding to it
				if (!toggle && !additive) Selection.clear();
				draggedElement = null;

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
			draggedElement = null;
		} else if (mouseDown && boxPending) {
			boxEndX = mouse.x;
			boxEndY = mouse.y;
			if (Math.abs(boxEndX - boxStartX) > BOX_THRESHOLD || Math.abs(boxEndY - boxStartY) > BOX_THRESHOLD) boxActive = true;
		} else if (mouseDown && draggedElement != null) {
			// Positions are in canvas units: the mouse movement divided by the zoom.
			// The anchor stays as it is; Koui lays the element out before drawing.
			var newX: Float = dragStartX + (mouse.x - dragMouseX) / Koui.uiScale * dragDirection(draggedElement, true);
			var newY: Float = dragStartY + (mouse.y - dragMouseY) / Koui.uiScale * dragDirection(draggedElement, false);

			// Apply position snapping if enabled
			if (topToolbar.snappingEnabled) {
				var snapValue: Float = topToolbar.snapValue;
				newX = Math.round(newX / snapValue) * snapValue;
				newY = Math.round(newY / snapValue) * snapValue;
			}

			// Koui resets the laid-out position when a position is set to its current value
			// (without laying it out again), so only set what changed
			if (Math.round(newX) != draggedElement.posX) draggedElement.posX = Math.round(newX);
			if (Math.round(newY) != draggedElement.posY) draggedElement.posY = Math.round(newY);
		} else {
			if (boxActive) selectInBox();
			boxPending = boxActive = false;

			if (draggedElement != null) {
				if (draggedElement.posX != dragStartX || draggedElement.posY != dragStartY) {
					History.edited("Move");
				}
				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;
			}
			draggedElement = null;
		}

		wasMouseDown = mouseDown;
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
