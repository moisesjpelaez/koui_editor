package arm;

import arm.base.UIBase;
import arm.data.SceneData;
import arm.data.Selection;
import arm.panels.TopToolbar;

import iron.App;
import iron.Scene;
import iron.system.Input;

import kha.graphics2.Graphics;

import koui.Koui;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;

typedef TScreenRect = {
	var x: Int;
	var y: Int;
	var w: Int;
	var h: Int;
}

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class CanvasViewport {
	// Viewport state
	public var isPanning: Bool = false;
	public var viewReset: Bool = false;
	var panStartX: Float = 0;
	var panStartY: Float = 0;
	public var canvasPanX: Float = 0;
	public var canvasPanY: Float = 0;
	public var initialScale: Float = 0.8;
	public var currentScale: Float = 0.8;

	// Shared references (set by KouiEditor)
	public var uiBase: UIBase;
	public var topToolbar: TopToolbar;
	public var sceneData: SceneData;

	public function new() {}

	public function canvasControl(isInCanvas: Bool, isInElementsPanel: Bool): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (rootPane == null) return;

		var mouse: Mouse = Input.getMouse();
		var keyboard: Keyboard = Input.getKeyboard();

		// Handle middle mouse button panning
		if (mouse.started("middle") && isInCanvas) {
			isPanning = true;
			panStartX = mouse.x;
			panStartY = mouse.y;
		}
		else if (mouse.down("middle") && isPanning) {
			var deltaX: Float = mouse.x - panStartX;
			var deltaY: Float = mouse.y - panStartY;

			canvasPanX += deltaX;
			canvasPanY += deltaY;
			applyPan();

			panStartX = mouse.x;
			panStartY = mouse.y;

			Krom.setMouseCursor(9);
		}
		else if (!mouse.down("middle") && isPanning) {
			isPanning = false;
			Krom.setMouseCursor(0);
		}

		if (isInCanvas && !isPanning && !isInElementsPanel && mouse.wheelDelta != 0) {
			var newScale: Float = mouse.wheelDelta < 0 ? Math.min(3.0, currentScale + 0.1) : Math.max(0.25, currentScale - 0.1);
			if (newScale != currentScale) zoomAt(mouse.x, mouse.y, newScale);
		}

		if (keyboard.started("f") && isInCanvas) resetCanvasView();
	}

	public function resetCanvasView(): Void {
		canvasPanX = 0;
		canvasPanY = 0;
		applyPan();

		viewReset = true;
	}

	/** Zooms to `newScale`, keeping the canvas point under the screen point (`x`, `y`) where it is. */
	public function zoomAt(x: Float, y: Float, newScale: Float): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (rootPane == null) return;

		var ratio: Float = newScale / currentScale;
		var targetX: Float = x - (x - rootPane.drawX) * ratio;
		var targetY: Float = y - (y - rootPane.drawY) * ratio;

		currentScale = newScale;
		Koui.uiScale = newScale;

		// Lay the root out at the new scale, then pan by whatever is still off
		applyPan();
		canvasPanX += targetX - rootPane.drawX;
		canvasPanY += targetY - rootPane.drawY;
		applyPan();
	}

	/** Places the current scene's root at the view's pan offset, e.g. after switching scenes or an undo. */
	public function applyPan(): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (rootPane == null) return;

		rootPane.posX = Std.int(canvasPanX / Koui.uiScale);
		rootPane.posY = Std.int(canvasPanY / Koui.uiScale);
		rootPane.drawX = Std.int(rootPane.posX * Koui.uiScale);
		rootPane.drawY = Std.int(rootPane.posY * Koui.uiScale);
		Koui.anchorPane.elemUpdated(rootPane);
	}

	public function onResized(sizeInit: Bool, baseH: Int): Void {
		if (!sizeInit) {
			Koui.uiScale = ((App.h() - uiBase.getBottomH()) / baseH) * initialScale;
			currentScale = Koui.uiScale;
		}
		Koui.onResize(App.w() - uiBase.getSidebarW(), App.h() - uiBase.getBottomH());
		if (Scene.active != null && Scene.active.camera != null) {
			Scene.active.camera.buildProjection();
		}
	}

	public function drawGrid(g2: Graphics): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (!topToolbar.snappingEnabled || rootPane == null) return;

		var cellSize: Float = topToolbar.snapValue * currentScale;
		if (cellSize < 4) return;

		var viewWidth: Float = App.w() - uiBase.getSidebarW();
		var viewHeight: Float = App.h() - uiBase.getBottomH();

		var offsetX: Float = rootPane.drawX % cellSize;
		var offsetY: Float = rootPane.drawY % cellSize;

		// Minor grid lines
		var minorAlpha: Int = 0x30;
		g2.color = (minorAlpha << 24) | 0xffffff;

		var x: Float = offsetX;
		while (x < viewWidth) {
			g2.drawLine(x, 0, x, viewHeight, 1);
			x += cellSize;
		}

		var y: Float = offsetY;
		while (y < viewHeight) {
			g2.drawLine(0, y, viewWidth, y, 1);
			y += cellSize;
		}

		// Major grid lines (every 4 cells)
		var majorCellSize: Float = cellSize * 4;
		var majorOffsetX: Float = rootPane.drawX % majorCellSize;
		var majorOffsetY: Float = rootPane.drawY % majorCellSize;

		var majorAlpha: Int = 0x50;
		g2.color = (majorAlpha << 24) | 0xffffff;

		x = majorOffsetX;
		while (x < viewWidth) {
			g2.drawLine(x, 0, x, viewHeight, 1);
			x += majorCellSize;
		}

		y = majorOffsetY;
		while (y < viewHeight) {
			g2.drawLine(0, y, viewWidth, y, 1);
			y += majorCellSize;
		}
	}

	public function drawRootPane(g2: Graphics): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (rootPane != null) {
			var thickness: Int = 1;
			g2.color = 0xffe7e7e7;

			var x: Int = rootPane.drawX;
			var y: Int = rootPane.drawY;
			var w: Int = rootPane.drawWidth;
			var h: Int = rootPane.drawHeight;

			g2.fillRect(x, y, w, thickness);
			g2.fillRect(x, y + h - thickness, w, thickness);
			g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
			g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
		}
	}

	/** Outlines every selected element. */
	public function drawSelection(g2: Graphics): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (rootPane == null) return;

		g2.color = 0xff469cff;
		for (element in Selection.elements) {
			if (element != rootPane) drawOutline(g2, getScreenRect(element), 2);
		}
	}

	/** The rectangle `element` is drawn in, in screen pixels: every parent draws its children translated by its own position. */
	public function getScreenRect(element: Element): TScreenRect {
		var x: Int = 0;
		var y: Int = 0;
		var current: Element = element;
		while (current != null) {
			x += current.drawX;
			y += current.drawY;
			current = current.parent;
		}
		return { x: x, y: y, w: element.drawWidth, h: element.drawHeight };
	}

	/**
	 * The top-most user element of the current scene at the screen point
	 * (`x`, `y`), at any depth, or null. Internal parts (a Button's label) are
	 * not user elements, so clicking them finds their element.
	 */
	public function getElementAt(x: Int, y: Int): Null<Element> {
		var rootPane: AnchorPane = sceneData.getRoot();
		return rootPane != null ? findElementAt(rootPane, x, y) : null;
	}

	function findElementAt(parent: Element, x: Int, y: Int): Null<Element> {
		var children: Array<Element> = sceneData.getChildren(parent);
		// Later children are drawn on top
		var i: Int = children.length;
		while (i > 0) {
			var child: Element = children[--i];
			if (!child.visible) continue;

			var rect: TScreenRect = getScreenRect(child);
			if (x >= rect.x && x < rect.x + rect.w && y >= rect.y && y < rect.y + rect.h) {
				var inner: Null<Element> = findElementAt(child, x, y);
				return inner != null ? inner : child;
			}
		}
		return null;
	}

	function drawOutline(g2: Graphics, rect: TScreenRect, thickness: Int): Void {
		g2.fillRect(rect.x, rect.y, rect.w, thickness);
		g2.fillRect(rect.x, rect.y + rect.h - thickness, rect.w, thickness);
		g2.fillRect(rect.x, rect.y + thickness, thickness, rect.h - thickness * 2);
		g2.fillRect(rect.x + rect.w - thickness, rect.y + thickness, thickness, rect.h - thickness * 2);
	}

	public function drawLayoutElements(g2: Graphics): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (rootPane == null) return;

		g2.color = 0xff808080;
		for (elem in sceneData.getElements()) {
			if (elem is AnchorPane || elem is RowLayout || elem is ColLayout) {
				drawOutline(g2, getScreenRect(elem), 1);
			}
		}
	}
}
