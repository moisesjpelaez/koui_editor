package arm;

import arm.ElementData;
import arm.ElementEvents;
import arm.base.Base;
import arm.base.UIBase;
import arm.panels.BottomPanel;
import arm.panels.HierarchyPanel;
import arm.panels.PropertiesPanel;
import arm.panels.ElementsPanel;
import arm.panels.TopToolbar;
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
import koui.elements.layouts.Layout;

class KouiEditor extends iron.Trait {
	var uiBase: UIBase;

	var anchorPane: AnchorPane;
	var sizeInit: Bool = false;

	// Created elements
	var elementsData: ElementData;
	var elements: Array<HierarchyEntry> = [];

	// Drag and drop state
	var selectedElement: Element = null;
	var draggedElement: Element = null;
	var dragOffsetX: Int = 0;
	var dragOffsetY: Int = 0;

	// Canvas controls
	var isPanning: Bool = false;
	var panStartX: Float = 0;
	var panStartY: Float = 0;
	var canvasPanX: Float = 100; // Initial left padding
	var canvasPanY: Float = 75;  // Initial top padding
	var initialScale: Float = 1.0;
	var currentScale: Float = 1.0;

	// Constants
	var borderSize: Int = 8;

	// Panels
	var topToolbar: TopToolbar = new TopToolbar();
	var bottomPanel: BottomPanel = new BottomPanel();
	var hierarchyPanel: HierarchyPanel = new HierarchyPanel();
	var propertiesPanel: PropertiesPanel = new PropertiesPanel();
	var elementsPanel: ElementsPanel = new ElementsPanel();

	public function new() {
		super();

		Assets.loadEverything(function() {
			elementsData = ElementData.data;
			elements = elementsData.elements;

			// Initialize framework
			Base.font = Assets.fonts.font_default;
			Base.init();
			Base.resizing.connect(onResized);

			// Create UIBase with the loaded font
			uiBase = new UIBase(Assets.fonts.font_default);

			Koui.init(function() {
				Koui.setPadding(100, 100, 75, 75);

				var canvasWidth: Int = Std.int(App.w() * 0.85);
				var canvasHeight: Int = Std.int(App.h() * 0.85);

				var argCount = Krom.getArgCount();
				// Arguments are: [0]=krom_path, [1]=koui_editor_path, [2]=koui_editor_path,
				//                [3]=canvas_arg, [4]=uiscale, [5]=resolution_x, [6]=resolution_y
				if (argCount >= 7) {
					var resX: Int = Std.parseInt(Krom.getArg(5));
					var resY: Int = Std.parseInt(Krom.getArg(6));
					if (resX != null && resY != null) {
						canvasWidth = resX;
						canvasHeight = resY;
					}
				}

				anchorPane = new AnchorPane(0, 0, canvasWidth, canvasHeight);
				anchorPane.setTID("fixed_anchorpane");
				Koui.add(anchorPane, Anchor.MiddleCenter);
				elements.push({ key: "AnchorPane", element: anchorPane });
				ElementData.root = anchorPane;
				hierarchyPanel.onElementAdded(elements[0]); // Manually register the root element in the hierarchy
			});

			App.onResize = onResized;

			ElementEvents.elementAdded.connect(onElementAdded);
			ElementEvents.elementSelected.connect(onElementSelected);
			ElementEvents.elementDropped.connect(onElementDropped);

			topToolbar.setIcons(Assets.images.icons);
		});

		notifyOnUpdate(update);
		notifyOnRender2D(render2D);
	}

	function update() {
		if (uiBase == null) return;
		uiBase.update();
		canvasControl();
		updateDragAndDrop();

		var keyboard: Keyboard = Input.getKeyboard();
		if (keyboard.started("delete") && selectedElement != null && selectedElement != anchorPane) {
			anchorPane.remove(selectedElement);
			for (i in 0...elements.length) {
				if (elements[i].element == selectedElement) {
					elements.splice(i, 1);
					break;
				}
			}
			selectedElement = null;
			ElementEvents.elementSelected.emit(null);
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
			Krom.setMouseCursor(1); // Hand cursor (grabbing)
		}
		else if (mouse.down("middle") && isPanning) {
			// Calculate delta movement
			var deltaX: Float = mouse.x - panStartX;
			var deltaY: Float = mouse.y - panStartY;

			// Update canvas pan via padding
			canvasPanX += deltaX;
			canvasPanY += deltaY;

			@:privateAccess anchorPane.posX = Std.int(canvasPanX / Koui.uiScale);
			@:privateAccess anchorPane.posY = Std.int(canvasPanY / Koui.uiScale);
			@:privateAccess anchorPane.drawX = Std.int(@:privateAccess anchorPane.posX * Koui.uiScale);
			@:privateAccess anchorPane.drawY = Std.int(@:privateAccess anchorPane.posY * Koui.uiScale);
			@:privateAccess Koui.anchorPane.elemUpdated(anchorPane);

			// Update start position for next frame
			panStartX = mouse.x;
			panStartY = mouse.y;
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
		if (keyboard.started("1")) {
			canvasPanX = 0;
			canvasPanY = 0;

			@:privateAccess anchorPane.posX = Std.int(canvasPanX / Koui.uiScale);
			@:privateAccess anchorPane.posY = Std.int(canvasPanY / Koui.uiScale);
			@:privateAccess anchorPane.drawX = Std.int(@:privateAccess anchorPane.posX * Koui.uiScale);
			@:privateAccess anchorPane.drawY = Std.int(@:privateAccess anchorPane.posY * Koui.uiScale);
			@:privateAccess Koui.anchorPane.elemUpdated(anchorPane);

			sizeInit = false;
		}
	}

	function updateDragAndDrop() {
		if (isPanning) return;

		// FIXME: elements flicker on mouse start and on mouse release
		var mouse: Mouse = Input.getMouse();
		if (mouse.started()) {
			var element: Element = Koui.getElementAtPosition(Std.int(mouse.x), Std.int(mouse.y));
			var canvasArea: Vec2 = new Vec2(App.w() - uiBase.getSidebarW() - borderSize, App.h() - uiBase.getBottomH() - borderSize); // TODO: use a better variable name
			var hierarchyArea: Vec2 = new Vec2(canvasArea.x + 2 * borderSize, App.h() - uiBase.getSidebarH1() - borderSize); // TODO: use a better variable name
			if (element != null && element != anchorPane) {
				if (element.parent is Button) selectedElement = element.parent;
				else selectedElement = element;
				ElementEvents.elementSelected.emit(selectedElement);
				draggedElement = selectedElement;
				dragOffsetX = Std.int(mouse.x - draggedElement.posX * Koui.uiScale);
				dragOffsetY = Std.int(mouse.y - draggedElement.posY * Koui.uiScale);
			} else if (mouse.x < canvasArea.x && mouse.y < canvasArea.y || mouse.x > hierarchyArea.x && mouse.y < hierarchyArea.y) {
				selectedElement = null;
				draggedElement = null;
				ElementEvents.elementSelected.emit(null);
			}
		} else if (mouse.down() && draggedElement != null) {
			draggedElement.setPosition(Std.int(mouse.x - dragOffsetX), Std.int(mouse.y - dragOffsetY));
			@:privateAccess draggedElement.invalidateElem();
		} else {
			if (draggedElement != null) {
				draggedElement.setPosition(Std.int(draggedElement.posX / Koui.uiScale), Std.int(draggedElement.posY / Koui.uiScale));
				@:privateAccess draggedElement.invalidateElem();
			}
			draggedElement = null;
			uiBase.hwnds[PanelHierarchy].redraws = 2;
			uiBase.hwnds[PanelProperties].redraws = 2;
		}
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

	function drawAnchorPane(g2: Graphics) {
		// Draw border with g2 in screen coordinates using drawX/drawY
		if (anchorPane != null) {
			var thickness: Int = 1;
			g2.color = 0xffe7e7e7;

			var x: Int = @:privateAccess anchorPane.drawX;
			var y: Int = @:privateAccess anchorPane.drawY;
			var w: Int = @:privateAccess anchorPane.drawWidth;
			var h: Int = @:privateAccess anchorPane.drawHeight;

			g2.fillRect(x, y, w, thickness);
			g2.fillRect(x, y + h - thickness, w, thickness);
			g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
			g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
		}
	}

	function drawSelectedElement(g2: Graphics) {
		if (selectedElement != null && selectedElement != anchorPane) {
			var thickness: Int = 2;
			g2.color = 0xff469cff;

			var x: Int = draggedElement != selectedElement ? @:privateAccess selectedElement.drawX + @:privateAccess anchorPane.drawX : Std.int(@:privateAccess selectedElement.drawX / Koui.uiScale) + @:privateAccess anchorPane.drawX;
			var y: Int = draggedElement != selectedElement ? @:privateAccess selectedElement.drawY + @:privateAccess anchorPane.drawY : Std.int(@:privateAccess selectedElement.drawY / Koui.uiScale) + @:privateAccess anchorPane.drawY;
			var w: Int = @:privateAccess selectedElement.drawWidth;
			var h: Int = @:privateAccess selectedElement.drawHeight;

			g2.fillRect(x, y, w, thickness);
			g2.fillRect(x, y + h - thickness, w, thickness);
			g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
			g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
		}
	}

	function render2D(g2: Graphics) {
		if (uiBase == null) return;
		g2.end();

		Koui.render(g2);
		g2.begin(false);
		drawAnchorPane(g2);
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
			Koui.uiScale = (App.h() - uiBase.getBottomH()) / 576;
			initialScale = Koui.uiScale;
			currentScale = initialScale;
		}
		@:privateAccess Koui.onResize(App.w() - uiBase.getSidebarW(), App.h() - uiBase.getBottomH());
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
		if (target == anchorPane) {
			var rootFirstElement: Element = @:privateAccess cast(target, AnchorPane).elements[0];
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
		for (entry in elementsData.elements) {
			if (entry.element == element) {
				currentName = entry.key;
				break;
			}
		}
		var uniqueName: String = NameUtils.ensureUniqueName(currentName, element, newParent);

		// Perform the mutation
		switch (zone) {
			case AsChild:
				HierarchyUtils.moveAsChild(element, target, anchorPane);
			case BeforeSibling:
				HierarchyUtils.moveRelativeToTarget(element, target, true);
			case AfterSibling:
				HierarchyUtils.moveRelativeToTarget(element, target, false);
			case None:
		}

		// Update name if it changed due to conflict
		if (uniqueName != currentName) {
			elementsData.updateElementKey(element, uniqueName);
		}

		uiBase.hwnds[PanelHierarchy].redraws = 2;
		uiBase.hwnds[PanelProperties].redraws = 2;
	}

	function onElementAdded(entry: HierarchyEntry): Void {
		anchorPane.add(entry.element, Anchor.TopLeft);

		// Generate unique name based on parent's children
		var uniqueName: String = NameUtils.generateName(entry.element, anchorPane);
		entry.key = uniqueName;
		elementsData.updateElementKey(entry.element, uniqueName);

		ElementEvents.elementSelected.emit(entry.element);
	}
}
