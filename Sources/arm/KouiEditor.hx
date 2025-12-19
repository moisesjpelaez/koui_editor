package arm;

import arm.data.SceneData;
import arm.events.ElementEvents;
import arm.events.SceneEvents;
import arm.base.Base;
import arm.base.UIBase;
import arm.panels.BottomPanel;
import arm.panels.HierarchyPanel;
import arm.panels.PropertiesPanel;
import arm.panels.ElementsPanel;
import arm.panels.TopToolbar;
import arm.tools.CanvasUtils;
import arm.tools.EditorUtils;
import arm.tools.HierarchyUtils;
import arm.tools.NameUtils;
import arm.types.Enums;

import iron.App;
import iron.Scene;
import iron.math.Vec2;
import iron.system.Input;

import kha.Assets;
import kha.graphics2.Graphics;

import koui.Koui;
import koui.elements.Button;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout;
import koui.elements.layouts.Layout.Anchor;
import koui.elements.layouts.RowLayout;
import koui.utils.SceneManager;

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class KouiEditor extends iron.Trait {
	var uiBase: UIBase;

	var rootPane: AnchorPane;
	var sizeInit: Bool = false;

	// Created elements
	var sceneData: SceneData = SceneData.data;
	// var elements: Array<TElementEntry> = SceneData.data.elements;

	// Drag and drop state
	var selectedElement: Element = null;
	var draggedElement: Element = null;
	var dragAnchor: Anchor = TopLeft;
	var dragOffsetX: Int = 0;
	var dragOffsetY: Int = 0;
	var anchorOffsetX: Int = 0;
	var anchorOffsetY: Int = 0;
	var dragStartX: Float = 0;
	var dragStartY: Float = 0;

	// Canvas controls
	var isPanning: Bool = false;
	var panStartX: Float = 0;
	var panStartY: Float = 0;
	var canvasPanX: Float = 0;
	var canvasPanY: Float = 0;
	var initialScale: Float = 0.8;
	var currentScale: Float = 0.8;

	// Constants
	var borderSize: Int = 8;

	// Panels
	var topToolbar: TopToolbar = new TopToolbar();
	var bottomPanel: BottomPanel = new BottomPanel();
	var hierarchyPanel: HierarchyPanel = new HierarchyPanel();
	var propertiesPanel: PropertiesPanel = new PropertiesPanel();
	var elementsPanel: ElementsPanel = new ElementsPanel();
	var baseH: Int = 576;

	var canvasLoaded: Bool = false; // HACK: ensure canvas is loaded after Koui init
	var canvasWidth: Int = 1024;
	var canvasHeight: Int = 576;

	public function new() {
		super();

		Assets.loadEverything(function() {
			// Initialize framework
			Base.font = Assets.fonts.font_default;
			Base.init();
			Base.resizing.connect(onResized);

			// Initialize canvas utilities
			CanvasUtils.init();

			// Initialize undo/redo system
			EditorUtils.init();

			// Create UIBase with the loaded font
			uiBase = new UIBase(Assets.fonts.font_default);

			Koui.init(function() {
				Koui.setPadding(100, 100, 75, 75);

				canvasWidth = Std.int(App.w());
				canvasHeight = Std.int(App.h());

				var argCount = Krom.getArgCount();
				// Arguments are: [0]=krom_path, [1]=koui_editor_path, [2]=koui_editor_path,
				//                [3]=canvas_arg, [4]=uiscale, [5]=resolution_x, [6]=resolution_y, [7]=project_dir, [8]=project_ext
				if (argCount >= 7) {
					var resX: Int = Std.parseInt(Krom.getArg(5));
					var resY: Int = Std.parseInt(Krom.getArg(6));
					if (resX != null && resY != null) {
						canvasWidth = resX;
						canvasHeight = resY;
					}
				}
				baseH = canvasHeight;

				SceneManager.addScene("Scene_1", setupRootScene);
				CanvasUtils.refreshTheme();

				// Set snap max value based on canvas size
				topToolbar.snapMaxValue = Math.min(canvasWidth, canvasHeight) * 0.5;
			});

			App.onResize = onResized;

			ElementEvents.elementAdded.connect(onElementAdded);
			ElementEvents.elementSelected.connect(onElementSelected);
			ElementEvents.elementDropped.connect(onElementDropped);
			ElementEvents.elementRemoved.connect(onElementRemoved);

			SceneEvents.sceneAdded.connect(onSceneAdded);
			SceneEvents.sceneChanged.connect(onSceneChanged);
			SceneEvents.sceneNameChanged.connect(onSceneNameChanged);
			SceneEvents.sceneRemoved.connect(onSceneRemoved);

			topToolbar.setIcons(Assets.images.icons);
			hierarchyPanel.setIcons(Assets.images.icons);
			propertiesPanel.setIcons(Assets.images.icons);
		});

		notifyOnUpdate(update);
		notifyOnRender2D(render2D);
	}

	function setupRootScene(scene: AnchorPane): Void {
		scene.setSize(canvasWidth, canvasHeight);
		scene.setTID("fixed_anchorpane");
		scene.anchor = Anchor.MiddleCenter;
		scene.invalidateElem();
		var s: TSceneEntry = {
		    key: "Scene_1",
		    root: scene,
		    elements: [],
		    active: true
		};
		sceneData.scenes.push(s);
		sceneData.currentScene = s;
		rootPane = scene;
		hierarchyPanel.onElementAdded({ key: sceneData.currentScene.key, element: sceneData.currentScene.root }); // Manually register the root element in the
	}

	function update() {
		if (uiBase == null) return;
		if (!canvasLoaded) { // HACK: ensure canvas is loaded after Koui init
			CanvasUtils.loadCanvas();
			canvasLoaded = true;
		}
		uiBase.update();
		canvasControl();
		updateDragAndDrop();

		var keyboard: Keyboard = Input.getKeyboard();
		if (keyboard.started("delete") && selectedElement != null && selectedElement != rootPane) {
			ElementEvents.elementRemoved.emit(selectedElement);
		}
	}

	function canvasControl() {
		var mouse: Mouse = Input.getMouse();
		var keyboard: Keyboard = Input.getKeyboard();

		// Calculate canvas area (exclude UI panels)
		var canvasArea: Vec2 = new Vec2(App.w() - uiBase.getSidebarW() - borderSize, App.h() - uiBase.getBottomH() - borderSize);
		var isInCanvas: Bool = mouse.x < canvasArea.x && mouse.y < canvasArea.y;

		// Handle middle mouse button panning
		if (mouse.started("middle") && isInCanvas) {
			isPanning = true;
			panStartX = mouse.x;
			panStartY = mouse.y;
		}
		else if (mouse.down("middle") && isPanning) {
			// Calculate delta movement
			var deltaX: Float = mouse.x - panStartX;
			var deltaY: Float = mouse.y - panStartY;

			// Update canvas pan via padding
			canvasPanX += deltaX;
			canvasPanY += deltaY;

			rootPane.posX = Std.int(canvasPanX / Koui.uiScale);
			rootPane.posY = Std.int(canvasPanY / Koui.uiScale);
			rootPane.drawX = Std.int(rootPane.posX * Koui.uiScale);
			rootPane.drawY = Std.int(rootPane.posY * Koui.uiScale);
			Koui.anchorPane.elemUpdated(rootPane);

			// Update start position for next frame
			panStartX = mouse.x;
			panStartY = mouse.y;

			Krom.setMouseCursor(9);
		}
		else if (!mouse.down("middle") && isPanning) {
			isPanning = false;
			Krom.setMouseCursor(0); // Default cursor
		}

		// FIXME: elements flicker when zooming
		if (isInCanvas && !isPanning) {
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

		// Handle '1' key reset
		if (keyboard.started("1")) resetCanvasView();
	}

	function resetCanvasView() {
			canvasPanX = 0;
			canvasPanY = 0;

			rootPane.posX = Std.int(canvasPanX / Koui.uiScale);
			rootPane.posY = Std.int(canvasPanY / Koui.uiScale);
			rootPane.drawX = Std.int(rootPane.posX * Koui.uiScale);
			rootPane.drawY = Std.int(rootPane.posY * Koui.uiScale);
			Koui.anchorPane.elemUpdated(rootPane);

			sizeInit = false;
	}

	function updateDragAndDrop() {
		if (isPanning) return;

		// FIXME: elements flicker on mouse start and release
		var mouse: Mouse = Input.getMouse();
		if (mouse.started()) {
			var element: Element = getElementAtPositionUnclipped(Std.int(mouse.x), Std.int(mouse.y));
			var canvasArea: Vec2 = new Vec2(App.w() - uiBase.getSidebarW() - borderSize, App.h() - uiBase.getBottomH() - borderSize); // TODO: use a more accurate variable name
			var hierarchyArea: Vec2 = new Vec2(canvasArea.x + 2 * borderSize, App.h() - uiBase.getSidebarH1() - borderSize); // TODO: use a more accurate variable name

			if (element != null && element != rootPane) {
				if (element.parent is Button) selectedElement = element.parent;
				else selectedElement = element;
				ElementEvents.elementSelected.emit(selectedElement);

				draggedElement = selectedElement;

				// Store original anchor and switch to TopLeft BEFORE calculating offset
				dragAnchor = draggedElement.getAnchorResolved();
				draggedElement.anchor = TopLeft;
				draggedElement.invalidateElem();

				// Now calculate offset using TopLeft-based posX/posY
				dragOffsetX = Std.int(mouse.x - draggedElement.posX * Koui.uiScale);
				dragOffsetY = Std.int(mouse.y - draggedElement.posY * Koui.uiScale);

				dragStartX = draggedElement.posX;
				dragStartY = draggedElement.posY;
			} else if (mouse.x < canvasArea.x && mouse.y < canvasArea.y || mouse.x > hierarchyArea.x && mouse.y < hierarchyArea.y) {
				selectedElement = null;
				draggedElement = null;
				ElementEvents.elementSelected.emit(null);
			}
		} else if (mouse.down() && draggedElement != null) {
			// Calculate new position in TopLeft space
			var elemX = Std.int(mouse.x - dragOffsetX);
			var elemY = Std.int(mouse.y - dragOffsetY);

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
				draggedElement.invalidateElem();

				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;

				ElementEvents.propertyChanged.emit(draggedElement, ["posX", "posY"], [dragStartX, dragStartY], [draggedElement.posX, draggedElement.posY]);
			}
			draggedElement = null;
		}
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

	function drawRightPanels() {
		// Adjust heights if window was resized
		var tabx: Int = uiBase.getTabX();
		var w: Int = uiBase.getSidebarW();
		var h0: Int = uiBase.getSidebarH0();
		var h1: Int = uiBase.getSidebarH1();

		hierarchyPanel.draw(uiBase, {tabx: tabx, w: w, h0: h0});
		propertiesPanel.draw(uiBase, {tabx: tabx, h0: h0, w: w, h1: h1});
	}

	function drawGrid(g2: Graphics) {
		if (!topToolbar.snappingEnabled || rootPane == null) return;

		var cellSize: Float = topToolbar.snapValue * currentScale;
		if (cellSize < 4) return; // Don't draw if cells are too small

		// Visible area (canvas area only, excluding sidebar)
		var viewWidth: Float = App.w() - uiBase.getSidebarW();
		var viewHeight: Float = App.h() - uiBase.getBottomH();

		// Calculate grid offset based on rootPane's actual screen position
		// This ensures grid aligns with the rootPane regardless of its anchor
		var offsetX: Float = rootPane.drawX % cellSize;
		var offsetY: Float = rootPane.drawY % cellSize;

		// Minor grid lines (every cell)
		var minorAlpha: Int = 0x30; // ~19% opacity
		g2.color = (minorAlpha << 24) | 0xffffff;

		// Vertical lines
		var x: Float = offsetX;
		while (x < viewWidth) {
			g2.drawLine(x, 0, x, viewHeight, 1);
			x += cellSize;
		}

		// Horizontal lines
		var y: Float = offsetY;
		while (y < viewHeight) {
			g2.drawLine(0, y, viewWidth, y, 1);
			y += cellSize;
		}

		// Major grid lines (every 4 cells)
		var majorCellSize: Float = cellSize * 4;
		var majorOffsetX: Float = rootPane.drawX % majorCellSize;
		var majorOffsetY: Float = rootPane.drawY % majorCellSize;

		var majorAlpha: Int = 0x50; // ~31% opacity
		g2.color = (majorAlpha << 24) | 0xffffff;

		// Vertical major lines
		x = majorOffsetX;
		while (x < viewWidth) {
			g2.drawLine(x, 0, x, viewHeight, 1);
			x += majorCellSize;
		}

		// Horizontal major lines
		y = majorOffsetY;
		while (y < viewHeight) {
			g2.drawLine(0, y, viewWidth, y, 1);
			y += majorCellSize;
		}
	}

	function drawAnchorPane(g2: Graphics) {
		// Draw border with g2 in screen coordinates using drawX/drawY
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

	function drawSelectedElement(g2: Graphics) {
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

	function drawLayoutElements(g2: Graphics) {
		// Draw thin borders around layout elements (RowLayout, ColLayout) since they're invisible
		if (sceneData.currentScene == null) return;

		var thickness: Int = 1;
		g2.color = 0xff808080; // Gray color to distinguish from canvas border

		for (entry in sceneData.currentScene.elements) {
			var elem: Element = entry.element;
			if (Std.isOfType(elem, RowLayout) || Std.isOfType(elem, ColLayout)) {
				var x: Int = elem.drawX + rootPane.drawX;
				var y: Int = elem.drawY + rootPane.drawY;
				var w: Int = elem.drawWidth;
				var h: Int = elem.drawHeight;

				if (elem.layout != rootPane) {
					x += elem.layout.drawX;
					y += elem.layout.drawY;
				}

				g2.fillRect(x, y, w, thickness);
				g2.fillRect(x, y + h - thickness, w, thickness);
				g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
				g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
			}
		}
	}

	function render2D(g2: Graphics) {
		if (uiBase == null) return;
		g2.end();

		Koui.render(g2);
		g2.begin(false);
		drawGrid(g2);
		drawAnchorPane(g2);
		drawLayoutElements(g2);
		drawSelectedElement(g2);
		g2.end();

		uiBase.ui.begin(g2);
		uiBase.adjustHeightsToWindow();
		topToolbar.draw(uiBase);
		elementsPanel.draw(uiBase);
		drawRightPanels();
		bottomPanel.draw(uiBase);
		uiBase.ui.end();

		g2.begin(false);

		if (!sizeInit) {
			onResized();
			sizeInit = true;
		}
	}

	function onResized() {
		if (!sizeInit) {
			Koui.uiScale = ((App.h() - uiBase.getBottomH()) / baseH) * initialScale;
			currentScale = Koui.uiScale;
		}
		Koui.onResize(App.w() - uiBase.getSidebarW(), App.h() - uiBase.getBottomH());
		if (Scene.active != null && Scene.active.camera != null) {
			Scene.active.camera.buildProjection();
		}
	}

	function onElementSelected(element: Element): Void {
		selectedElement = element;

		uiBase.hwnds[PanelHierarchy].redraws = 2;
		uiBase.hwnds[PanelProperties].redraws = 2;
	}

	function onElementDropped(element: Element, target: Element, zone: DropZone): Void {
		if (element == null || target == null) return;
		if (element == target) return;

		// Determine new parent before mutation
		var newParent: Element = null;
		switch (zone) {
			case AsChild:
				newParent = target;
			case BeforeSibling | AfterSibling:
				newParent = HierarchyUtils.getParentElement(target);
			case None:
				return;
		}

		// Check if dropping as sibling to root AnchorPane (which has no parent)
		var currentParent: Element = HierarchyUtils.getParentElement(element);
		if (target == rootPane) {
			var rootFirstElement: Element = cast(target, AnchorPane).elements[0];
			if (rootFirstElement != element) HierarchyUtils.moveRelativeToTarget(element, rootFirstElement, true);
			uiBase.hwnds[PanelHierarchy].redraws = 2;
			uiBase.hwnds[PanelProperties].redraws = 2;
			return;
		}

		// Validate newParent can accept children
		if (newParent != null && !HierarchyUtils.canAcceptChild(newParent)) {
			uiBase.hwnds[PanelHierarchy].redraws = 2;
			uiBase.hwnds[PanelProperties].redraws = 2;
			return;
		}

		// Get current name and ensure it's unique in new parent
		var currentName: String = "";
		var currentScene = SceneData.data.currentScene;
		if (currentScene != null) {
			for (entry in currentScene.elements) {
				if (entry.element == element) {
					currentName = entry.key;
					break;
				}
			}
		}
		var uniqueName: String = NameUtils.ensureUniqueName(currentName, element, newParent);

		// Perform the mutation
		switch (zone) {
			case AsChild:
				HierarchyUtils.moveAsChild(element, target, rootPane);
			case BeforeSibling:
				HierarchyUtils.moveRelativeToTarget(element, target, true);
			case AfterSibling:
				HierarchyUtils.moveRelativeToTarget(element, target, false);
			case None:
		}

		// Update name if it changed due to conflict
		if (uniqueName != currentName) {
			sceneData.updateElementKey(element, uniqueName);
		}

		uiBase.hwnds[PanelHierarchy].redraws = 2;
		uiBase.hwnds[PanelProperties].redraws = 2;
	}

	function onElementAdded(entry: TElementEntry): Void {
		rootPane.add(entry.element, Anchor.TopLeft);

		// Generate unique name based on parent's children
		var uniqueName: String = NameUtils.generateName(entry.element, rootPane);
		entry.key = uniqueName;
		sceneData.updateElementKey(entry.element, uniqueName);

		ElementEvents.elementSelected.emit(entry.element);
	}

	function onElementRemoved(element: Element): Void {
		rootPane.remove(element);
		selectedElement = null;
		ElementEvents.elementSelected.emit(null);
	}

	function onSceneAdded(sceneName: String): Void {
		SceneManager.addScene(sceneName, setupRootScene);
		SceneManager.setScene(sceneName);
		sceneData.currentScene.key = sceneName;
	}

	function onSceneChanged(sceneName: String): Void {
		SceneManager.setScene(sceneName);
		rootPane = SceneManager.activeScene;
	}

	function onSceneNameChanged(oldKey: String, newKey: String): Void {
		// Cache all elements from current scene before removing
		var currentScene = sceneData.currentScene;
		var cachedElements: Array<{key: String, element: Element, anchor: Int}> = [];

		for (entry in currentScene.elements) {
			// Store element with its anchor position
			cachedElements.push({
				key: entry.key,
				element: entry.element,
				anchor: cast entry.element.anchor
			});
			// Remove from old root so it doesn't get destroyed
			rootPane.remove(entry.element);
		}

		// Remove old scene entry from sceneData to avoid duplicate
		var sceneIdx = sceneData.scenes.indexOf(currentScene);
		if (sceneIdx >= 0) {
			sceneData.scenes.splice(sceneIdx, 1);
		}

		// Remove from SceneManager and re-add with new name
		SceneManager.removeScene(oldKey);
		SceneManager.addScene(newKey, setupRootScene);
		SceneManager.setScene(newKey);
		sceneData.currentScene.key = newKey;

		// Restore all cached elements to the new root pane
		for (cached in cachedElements) {
			rootPane.add(cached.element, cast cached.anchor);
			sceneData.currentScene.elements.push({key: cached.key, element: cached.element});
		}
	}

	function onSceneRemoved(sceneName: String): Void {
		SceneManager.removeScene(sceneName);
	}
}