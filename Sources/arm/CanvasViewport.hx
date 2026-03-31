package arm;

import arm.base.UIBase;
import arm.data.SceneData;
import arm.panels.TopToolbar;

import iron.App;
import iron.Scene;
import iron.math.Vec2;
import iron.system.Input;

import kha.graphics2.Graphics;

import koui.Koui;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout;
import koui.elements.layouts.RowLayout;

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
	public var rootPane: AnchorPane;
	public var uiBase: UIBase;
	public var topToolbar: TopToolbar;
	public var sceneData: SceneData;

	public function new() {}

	public function canvasControl(isInCanvas: Bool, isInElementsPanel: Bool): Void {
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

			rootPane.posX = Std.int(canvasPanX / Koui.uiScale);
			rootPane.posY = Std.int(canvasPanY / Koui.uiScale);
			rootPane.drawX = Std.int(rootPane.posX * Koui.uiScale);
			rootPane.drawY = Std.int(rootPane.posY * Koui.uiScale);
			Koui.anchorPane.elemUpdated(rootPane);

			panStartX = mouse.x;
			panStartY = mouse.y;

			Krom.setMouseCursor(9);
		}
		else if (!mouse.down("middle") && isPanning) {
			isPanning = false;
			Krom.setMouseCursor(0);
		}

		// FIXME: elements flicker when zooming
		if (isInCanvas && !isPanning && !isInElementsPanel) {
			if (mouse.wheelDelta < 0) {
				currentScale += 0.1;
				currentScale = Math.min(3.0, currentScale);
				Koui.uiScale = currentScale;
			} else if (mouse.wheelDelta > 0) {
				currentScale -= 0.1;
				currentScale = Math.max(0.25, currentScale);
				Koui.uiScale = currentScale;
			}
		}

		if (keyboard.started("f") && isInCanvas) resetCanvasView();
	}

	public function resetCanvasView(): Void {
		canvasPanX = 0;
		canvasPanY = 0;

		rootPane.posX = Std.int(canvasPanX / Koui.uiScale);
		rootPane.posY = Std.int(canvasPanY / Koui.uiScale);
		rootPane.drawX = Std.int(rootPane.posX * Koui.uiScale);
		rootPane.drawY = Std.int(rootPane.posY * Koui.uiScale);
		Koui.anchorPane.elemUpdated(rootPane);

		viewReset = true;
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

	public function drawSelectedElement(g2: Graphics, selectedElement: Element, draggedElement: Element): Void {
		if (selectedElement != null && selectedElement != rootPane) {
			var thickness: Int = 2;
			g2.color = 0xff469cff;

			var x: Int = draggedElement != selectedElement || selectedElement is Layout ? selectedElement.drawX + rootPane.drawX : Std.int(selectedElement.drawX / Koui.uiScale) + rootPane.drawX;
			var y: Int = draggedElement != selectedElement || selectedElement is Layout ? selectedElement.drawY + rootPane.drawY : Std.int(selectedElement.drawY / Koui.uiScale) + rootPane.drawY;
			var w: Int = selectedElement.drawWidth;
			var h: Int = selectedElement.drawHeight;

			var finalPos: Vec2 = sumLayout(selectedElement, 0, 0);
			if (selectedElement.layout != rootPane) {
				x += Std.int(finalPos.x);
				y += Std.int(finalPos.y);
			}

			g2.fillRect(x, y, w, thickness);
			g2.fillRect(x, y + h - thickness, w, thickness);
			g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
			g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
		}
	}

	function sumLayout(elem: Element, x: Int, y: Int): Vec2 {
		if (elem.layout != null && elem.layout != rootPane) {
			return sumLayout(elem.layout, x + elem.layout.drawX, y + elem.layout.drawY);
		} else {
			return new Vec2(x, y);
		}
	}

	public function drawLayoutElements(g2: Graphics): Void {
		if (sceneData.currentScene == null) return;

		var thickness: Int = 1;
		g2.color = 0xff808080;

		for (entry in sceneData.currentScene.elements) {
			var elem: Element = entry.element;
			if (elem == rootPane) continue;

			if (elem is AnchorPane || elem is RowLayout || elem is ColLayout) {
				var x: Int = elem.drawX + rootPane.drawX;
				var y: Int = elem.drawY + rootPane.drawY;
				var w: Int = elem.drawWidth;
				var h: Int = elem.drawHeight;

				var finalPos: Vec2 = sumLayout(elem, 0, 0);
				if (elem.layout != rootPane) {
					x += Std.int(finalPos.x);
					y += Std.int(finalPos.y);
				}

				g2.fillRect(x, y, w, thickness);
				g2.fillRect(x, y + h - thickness, w, thickness);
				g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
				g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
			}
		}
	}
}
