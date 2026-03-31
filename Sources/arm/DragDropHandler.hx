package arm;

import arm.base.UIBase;
import arm.editors.ElementRegistry;
import arm.events.ElementEvents;
import arm.panels.TopToolbar;
import arm.types.Enums.PanelHandle;

import iron.math.Vec2;
import iron.system.Input;
import iron.system.Input.Mouse;

import koui.Koui;
import koui.elements.Element;
import koui.elements.Panel;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout;
import koui.elements.layouts.Layout.Anchor;
import koui.elements.layouts.RowLayout;

import iron.App;

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class DragDropHandler {
	// Shared references (set by KouiEditor)
	public var rootPane: AnchorPane;
	public var selectedElement: Element = null;

	var uiBase: UIBase;
	var viewport: CanvasViewport;
	var topToolbar: TopToolbar;

	// Drag state
	var draggedElement: Element = null;
	var dragAnchor: Anchor = TopLeft;
	var wasMouseDown: Bool = false;
	var dragOffsetX: Int = 0;
	var dragOffsetY: Int = 0;
	var anchorOffsetX: Int = 0;
	var anchorOffsetY: Int = 0;
	var dragStartX: Float = 0;
	var dragStartY: Float = 0;

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

	function isDynamicSized(element: Element): Bool {
		var isDynamicWidth: Bool = element.style != null && element.style.size.minWidth != 0;
		var isDynamicHeight: Bool = element.style != null && element.style.size.minHeight != 0;
		return isDynamicWidth || isDynamicHeight;
	}

	public function update() {
		if (viewport.isPanning) return;

		// FIXME: elements flicker on mouse start and release
		var mouse: Mouse = Input.getMouse();
		var mouseDown: Bool = mouse.down();
		var mouseJustPressed: Bool = mouseDown && !wasMouseDown;

		if (mouseJustPressed && isInCanvas()) {
			var element: Element = getElementAtPositionUnclipped(Std.int(mouse.x), Std.int(mouse.y));

			if (element != null && element != rootPane) {
				// Select parent element instead of internal children of composite types
				var parentEditor = ElementRegistry.getForElement(element.parent);
				if ((parentEditor != null && parentEditor.isComposite) || (element is Panel && element.parent != rootPane)) {
					selectedElement = element.parent;
				}
				// Select parent AnchorPane instead of child AnchorPane (but not if parent is rootPane)
				else if (element is AnchorPane && element.layout is AnchorPane && element.layout != rootPane) {
					selectedElement = cast(element.layout, Element);
				}
				else {
					selectedElement = element;
				}
				ElementEvents.elementSelected.emit(selectedElement);
				if (isDynamicSized(selectedElement)) {
					draggedElement = null;
					return;
				}
				draggedElement = selectedElement;

				// Store original anchor and switch to TopLeft BEFORE calculating offset
				dragAnchor = draggedElement.getAnchorResolved();
				draggedElement.anchor = TopLeft;
				draggedElement.invalidateElem();

				// Now calculate offset using the element's screen position (drawX/drawY)
				dragOffsetX = Std.int(mouse.x - draggedElement.posX * Koui.uiScale);
				dragOffsetY = Std.int(mouse.y - draggedElement.posY * Koui.uiScale);

				dragStartX = draggedElement.posX;
				dragStartY = draggedElement.posY;
			} else {
				selectedElement = null;
				draggedElement = null;
				ElementEvents.elementSelected.emit(null);
			}
		} else if (mouseJustPressed && isInHierarchyPanel()) {
			// Clicked in hierarchy panel — clear canvas drag state only.
			// The hierarchy panel emits its own elementSelected event.
			draggedElement = null;
		} else if (mouseDown && draggedElement != null) {
			// Calculate new position in TopLeft space
			var elemX = Std.int(mouse.x - dragOffsetX);
			var elemY = Std.int(mouse.y - dragOffsetY);

			// Apply position snapping if enabled
			if (topToolbar.snappingEnabled && rootPane != null) {
				var snapValue = topToolbar.snapValue;
				elemX -= Std.int(elemX % (snapValue * Koui.uiScale));
				elemY -= Std.int(elemY % (snapValue * Koui.uiScale));
			}

			anchorOffsetX = elemX;
			anchorOffsetY = elemY;

			// Get parent dimensions for anchor calculations
			var parentWidth: Int = draggedElement.parent != null ? draggedElement.parent.drawWidth : rootPane.drawWidth;
			var parentHeight: Int = draggedElement.parent != null ? draggedElement.parent.drawHeight : rootPane.drawHeight;

			// Adjust position to simulate dragging from the original anchor point
			switch (dragAnchor) {
				case TopCenter:
					elemX += Std.int(parentWidth * 0.5 - draggedElement.drawWidth * 0.5);
				case TopRight:
					elemX += parentWidth - draggedElement.drawWidth;
				case MiddleLeft:
					elemY += Std.int(parentHeight * 0.5 - draggedElement.drawHeight * 0.5);
				case MiddleCenter:
					elemX += Std.int(parentWidth * 0.5 - draggedElement.drawWidth * 0.5);
					elemY += Std.int(parentHeight * 0.5 - draggedElement.drawHeight * 0.5);
				case MiddleRight:
					elemX += parentWidth - draggedElement.drawWidth;
					elemY += Std.int(parentHeight * 0.5 - draggedElement.drawHeight * 0.5);
				case BottomLeft:
					elemY += parentHeight - draggedElement.drawHeight;
				case BottomCenter:
					elemX += Std.int(parentWidth * 0.5 - draggedElement.drawWidth * 0.5);
					elemY += parentHeight - draggedElement.drawHeight;
				case BottomRight:
					elemX += parentWidth - draggedElement.drawWidth;
					elemY += parentHeight - draggedElement.drawHeight;
				default: // TopLeft - no adjustment
			}

			if (draggedElement is Layout) {
				draggedElement.setPosition(Std.int(elemX / Koui.uiScale), Std.int(elemY / Koui.uiScale));
				draggedElement.drawX = Std.int(draggedElement.posX * Koui.uiScale);
				draggedElement.drawY = Std.int(draggedElement.posY * Koui.uiScale);
				draggedElement.layout.elemUpdated(draggedElement);
			} else {
				draggedElement.setPosition(Std.int(elemX), Std.int(elemY));
				draggedElement.invalidateElem();
			}
		} else {
			if (draggedElement != null) {
				draggedElement.anchor = dragAnchor; // Restore original anchor
				draggedElement.setPosition(Std.int(anchorOffsetX / Koui.uiScale), Std.int(anchorOffsetY / Koui.uiScale));
				if (draggedElement is Layout) draggedElement.layout.elemUpdated(draggedElement);
				draggedElement.invalidateElem();

				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;

				ElementEvents.propertyChanged.emit(draggedElement, ["posX", "posY"], [dragStartX, dragStartY], [draggedElement.posX, draggedElement.posY]);
			}
			draggedElement = null;
		}

		wasMouseDown = mouseDown;
	}

	/**
	 * Custom method to get elements at a position without clipping to rootPane bounds.
	 * This allows selecting elements that are positioned outside the rootPane's visible area.
	 */
	function getElementAtPositionUnclipped(x: Int, y: Int): Null<Element> {
		// Transform screen coordinates to rootPane space (accounting for pan and scale)
		// rootPane.layoutX/layoutY already include the pan offset and are in screen coordinates
		var relX: Int = x - rootPane.layoutX;
		var relY: Int = y - rootPane.layoutY;

		// Reverse to ensure that the topmost element is selected
		var sortedElements: Array<Element> = rootPane.elements.copy();
		sortedElements.reverse();

		for (element in sortedElements) {
			if (!element.visible) {
				continue;
			}

			// For GridLayout/RowLayout/ColLayout, check bounds manually since they may be empty
			if (Std.isOfType(element, GridLayout) || Std.isOfType(element, RowLayout) || Std.isOfType(element, ColLayout)) {
				// Check if mouse is within the layout's bounds (relative to rootPane)
				if (relX >= element.layoutX && relX <= element.layoutX + element.drawWidth &&
					relY >= element.layoutY && relY <= element.layoutY + element.drawHeight) {
					return element;
				}
				continue;
			}

			// Check if element has children (recursively check them with relative coords)
			var hit: Null<Element> = element.getElementAtPosition(relX, relY);
			if (hit != null) return hit;

			// Check the element itself - element.layoutX/Y are relative to rootPane
			// So we need to check against relX/relY (mouse position relative to rootPane)
			if (relX >= element.layoutX && relX <= element.layoutX + element.drawWidth &&
				relY >= element.layoutY && relY <= element.layoutY + element.drawHeight) {
				return element;
			}
		}

		return null;
	}

	public function drawSelectedElement(g2: kha.graphics2.Graphics) {
		viewport.drawSelectedElement(g2, selectedElement, draggedElement);
	}
}
