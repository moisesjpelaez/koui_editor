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
import arm.data.Clipboard;
import arm.tools.CanvasUtils;
import arm.tools.HierarchyUtils;
import arm.tools.NameUtils;
import arm.types.Enums;
import arm.types.Types;
import arm.commands.CommandManager;
import arm.commands.PropertyChangeCommand;
import arm.commands.SceneAddCommand;
import arm.commands.SceneRemoveCommand;
import arm.commands.SceneRenameCommand;
import arm.commands.ElementAddCommand;
import arm.commands.ElementRemoveCommand;
import arm.commands.KeyRenameCommand;
import arm.editors.ElementRegistry;
import arm.editors.LabelEditor;
import arm.editors.ImagePanelEditor;
import arm.editors.PanelEditor;
import arm.editors.ButtonEditor;
import arm.editors.CheckboxEditor;
import arm.editors.RadioButtonEditor;
import arm.editors.AnchorPaneEditor;
import arm.editors.ColLayoutEditor;
import arm.editors.RowLayoutEditor;
import arm.editors.ProgressbarEditor;
import arm.editors.SliderEditor;

import iron.App;
import iron.math.Vec2;
import iron.system.Input;

import kha.Assets;
import kha.graphics2.Graphics;

import koui.Koui;
import koui.elements.Button;
import koui.elements.Checkbox;
import koui.elements.Element;
import koui.elements.Panel;
import koui.elements.Progressbar;
import koui.elements.Slider;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout;
import koui.elements.layouts.Layout.Anchor;
import koui.elements.layouts.RowLayout;
import koui.utils.SceneManager;

import arm.CanvasViewport;

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
	var wasMouseDown: Bool = false;
	var dragOffsetX: Int = 0;
	var dragOffsetY: Int = 0;
	var anchorOffsetX: Int = 0;
	var anchorOffsetY: Int = 0;
	var dragStartX: Float = 0;
	var dragStartY: Float = 0;

	// Constants
	var borderSize: Int = 8;

	// Viewport controller
	var viewport: CanvasViewport = new CanvasViewport();

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

	var commandManager: CommandManager;

	public function new() {
		super();

		commandManager = new CommandManager();

		// Register element editors (order matters: specific types before their parent classes)
		ElementRegistry.register(new LabelEditor());
		ElementRegistry.register(new PanelEditor());
		ElementRegistry.register(new ImagePanelEditor());
		ElementRegistry.register(new ButtonEditor());
		ElementRegistry.register(new RadioButtonEditor());
		ElementRegistry.register(new CheckboxEditor());
		ElementRegistry.register(new AnchorPaneEditor());
		ElementRegistry.register(new ColLayoutEditor());
		ElementRegistry.register(new RowLayoutEditor());
		ElementRegistry.register(new ProgressbarEditor());
		ElementRegistry.register(new SliderEditor());

		Assets.loadEverything(function() {
			// Initialize framework
			Base.font = Assets.fonts.font_default;
			Base.init();
			Base.resizing.connect(onResized);

			// Initialize canvas utilities
			CanvasUtils.init();

			// Create UIBase with the loaded font
			uiBase = new UIBase(Assets.fonts.font_default);
			viewport.uiBase = uiBase;
			viewport.sceneData = sceneData;
			viewport.topToolbar = topToolbar;

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

				SceneManager.addScene("Scene_1", (scene) -> setupRootScene(scene, "Scene_1"));
				CanvasUtils.refreshTheme();

				// Set snap max value based on canvas size
				topToolbar.snapMaxValue = Math.min(canvasWidth, canvasHeight) * 0.5;
			});

			App.onResize = onResized;

			ElementEvents.elementAdded.connect(onElementAdded);
			ElementEvents.elementSelected.connect(onElementSelected);
			ElementEvents.elementDropped.connect(onElementDropped);
			ElementEvents.elementRemoved.connect(onElementRemoved);
			ElementEvents.propertyChanged.connect(onPropertyChangedForUndo);

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

	function isInCanvas(): Bool {
		var mouse: Mouse = Input.getMouse();
		var canvasMargin1: Vec2 = new Vec2(App.w() - uiBase.getSidebarW() - borderSize * 0.5, App.h() - uiBase.getBottomH() - borderSize * 0.5);
		var canvasMargin2: Vec2 = new Vec2(canvasMargin1.x - borderSize * 0.5, App.h() - uiBase.getSidebarH1() - borderSize * 0.5);
		return mouse.x < canvasMargin1.x && mouse.y < canvasMargin1.y || mouse.x < canvasMargin2.x && mouse.y < canvasMargin2.y;
	}

	function isInHierarchyPanel(): Bool {
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

	function setupRootScene(scene: AnchorPane, sceneName: String): Void {
		scene.setSize(canvasWidth, canvasHeight);
		scene.setTID("_fixed_anchorpane");
		scene.anchor = Anchor.MiddleCenter;
		scene.invalidateElem();
		var s: TSceneEntry = {
		    key: sceneName,
		    root: scene,
		    elements: [],
		    active: true
		};
		sceneData.scenes.push(s);
		sceneData.currentScene = s;
		rootPane = scene;
		viewport.rootPane = rootPane;
		hierarchyPanel.onElementAdded({ key: sceneName, element: scene });
	}

	function update() {
		if (uiBase == null) return;
		if (!canvasLoaded) { // HACK: ensure canvas is loaded after Koui init
			CanvasUtils.loadCanvas();
			canvasLoaded = true;
		}
		uiBase.update();
		viewport.canvasControl(isInCanvas());

		var keyboard: Keyboard = Input.getKeyboard();
		var isTyping: Bool = uiBase.ui.isTyping;

		if (!isTyping && keyboard.started("delete") && selectedElement != null && selectedElement != rootPane) {
			ElementEvents.elementRemoved.emit(selectedElement);
		}

		// Copy (Ctrl+C)
		if (!isTyping && keyboard.down("control") && keyboard.started("c") && selectedElement != null && selectedElement != rootPane) {
			Clipboard.clipboardData = CanvasUtils.serializeElementTree(selectedElement);
			Clipboard.isCut = false;
		}

		// Cut (Ctrl+X)
		if (!isTyping && keyboard.down("control") && keyboard.started("x") && selectedElement != null && selectedElement != rootPane) {
			Clipboard.clipboardData = CanvasUtils.serializeElementTree(selectedElement);
			Clipboard.isCut = true;
			ElementEvents.elementRemoved.emit(selectedElement);
		}

		// Paste (Ctrl+V)
		if (!isTyping && keyboard.down("control") && keyboard.started("v") && Clipboard.clipboardData.length > 0) {
			CanvasUtils.pasteElements(Clipboard.clipboardData, selectedElement);
			if (Clipboard.isCut) {
				Clipboard.clipboardData = [];
				Clipboard.isCut = false;
			}
			uiBase.hwnds[PanelHierarchy].redraws = 2;
			uiBase.hwnds[PanelProperties].redraws = 2;
		}

		// Undo (Ctrl+Z)
		if (!isTyping && keyboard.down("control") && !keyboard.down("shift") && keyboard.started("z")) {
			if (commandManager.undo()) {
				rootPane = SceneManager.activeScene;
				viewport.rootPane = rootPane;
				hierarchyPanel.updateTabPosition();
				ElementEvents.elementSelected.emit(selectedElement);
				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;
			}
		}

		// Redo (Ctrl+Shift+Z or Ctrl+Y)
		if (!isTyping && keyboard.down("control") && (keyboard.down("shift") && keyboard.started("z") || keyboard.started("y"))) {
			if (commandManager.redo()) {
				rootPane = SceneManager.activeScene;
				viewport.rootPane = rootPane;
				hierarchyPanel.updateTabPosition();
				ElementEvents.elementSelected.emit(selectedElement);
				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;
			}
		}
	}

	function updateDragAndDrop() {
		if (viewport.isPanning) return;

		// FIXME: elements flicker on mouse start and release
		var mouse: Mouse = Input.getMouse();
		var mouseDown: Bool = mouse.down();
		var mouseJustPressed: Bool = mouseDown && !wasMouseDown;

		if (mouseJustPressed && isInCanvas()) {
			var element: Element = getElementAtPositionUnclipped(Std.int(mouse.x), Std.int(mouse.y));

			if (element != null && element != rootPane) {
				// Select parent element instead of internal children
				if (element.parent is Button || element.parent is Checkbox || element.parent is Progressbar || element.parent is Slider || element is Panel && element.parent != rootPane) {
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

	function drawRightPanels() {
		var tabx: Int = uiBase.getTabX();
		var w: Int = uiBase.getSidebarW();
		var h0: Int = uiBase.getSidebarH0();
		var h1: Int = uiBase.getSidebarH1();

		hierarchyPanel.draw(uiBase, {tabx: tabx, w: w, h0: h0});
		propertiesPanel.draw(uiBase, {tabx: tabx, h0: h0, w: w, h1: h1});
	}

	function render2D(g2: Graphics) {
		if (uiBase == null) return;
		g2.end();

		updateDragAndDrop();
		Koui.render(g2);
		g2.begin(false);
		viewport.drawGrid(g2);
		viewport.drawRootPane(g2);
		viewport.drawLayoutElements(g2);
		viewport.drawSelectedElement(g2, selectedElement, draggedElement);
		g2.end();

		uiBase.ui.begin(g2);
		uiBase.adjustHeightsToWindow();
		topToolbar.draw(uiBase);
		elementsPanel.draw(uiBase);
		drawRightPanels();
		bottomPanel.draw(uiBase);
		uiBase.ui.end();

		g2.begin(false);

		if (!sizeInit || viewport.viewReset) {
			viewport.viewReset = false;
			onResized();
			sizeInit = true;
		}
	}

	function onResized() {
		viewport.onResized(sizeInit, baseH);
	}

	function onPropertyChangedForUndo(element: Element, properties: Dynamic, oldValues: Dynamic, newValues: Dynamic): Void {
		if (commandManager.isUndoRedoing) return;

		var props: Array<String>;
		var olds: Array<Dynamic>;
		var news: Array<Dynamic>;

		if (Std.isOfType(properties, String)) {
			props = [cast properties];
			olds = [oldValues];
			news = [newValues];
		} else {
			props = cast properties;
			olds = cast oldValues;
			news = cast newValues;
		}

		// Skip if nothing actually changed (e.g. click without drag)
		var hasChange = false;
		for (i in 0...props.length) {
			if (olds[i] != news[i]) { hasChange = true; break; }
		}
		if (!hasChange) return;

		commandManager.record(new PropertyChangeCommand(element, props, olds, news));
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

		// Record for undo (SceneData.onElementAdded already pushed the entry via event)
		if (!commandManager.isUndoRedoing) {
			commandManager.record(new ElementAddCommand(entry.element, uniqueName, rootPane));
		}
	}

	function onElementRemoved(element: Element): Void {
		if (commandManager.isUndoRedoing) return; // Commands handle removal directly

		// Collect ALL entries for this element and its descendants BEFORE removing
		var allEntries = collectDescendantEntries(element);
		var parentElement = HierarchyUtils.getParentElement(element);

		// Remove all entries from SceneData (since SceneData is no longer auto-connected)
		for (entry in allEntries) {
			sceneData.onElementRemoved(entry.element);
		}

		// Detach from parent (children stay attached to element)
		HierarchyUtils.detachFromCurrentParent(element);

		if (selectedElement == element) {
			selectedElement = null;
			ElementEvents.elementSelected.emit(null);
		}

		// Record for undo
		var key = allEntries.length > 0 ? allEntries[0].key : "";
		commandManager.record(new ElementRemoveCommand(element, key, parentElement, 0, allEntries));
	}

	/** Recursively collect TElementEntry records for an element and all its descendants. */
	function collectDescendantEntries(element: Element): Array<TElementEntry> {
		var result: Array<TElementEntry> = [];
		var currentScene = sceneData.currentScene;
		if (currentScene == null) return result;

		// Find this element's entry
		for (entry in currentScene.elements) {
			if (entry.element == element) {
				result.push({key: entry.key, element: entry.element});
				break;
			}
		}

		// Recursively collect children's entries
		var children = HierarchyUtils.getChildren(element);
		for (child in children) {
			var childEntries = collectDescendantEntries(child);
			for (ce in childEntries) {
				result.push(ce);
			}
		}

		return result;
	}

	function onSceneAdded(sceneName: String): Void {
		if (commandManager.isUndoRedoing) return; // Commands handle scene creation directly

		SceneManager.addScene(sceneName, (scene) -> setupRootScene(scene, sceneName));
		SceneManager.setScene(sceneName);
		selectedElement = null;
		ElementEvents.elementSelected.emit(null);
		hierarchyPanel.updateTabPosition();

		// Find the just-created scene entry and record for undo
		for (scene in sceneData.scenes) {
			if (scene.key == sceneName) {
				commandManager.record(new SceneAddCommand(sceneName, scene));
				break;
			}
		}
	}

	function onSceneChanged(sceneName: String): Void {
		SceneManager.setScene(sceneName);
		rootPane = SceneManager.activeScene;
		viewport.rootPane = rootPane;
	}

	function onSceneNameChanged(oldKey: String, newKey: String): Void {
		if (commandManager.isUndoRedoing) return; // Commands handle renaming directly

		SceneManager.renameScene(oldKey, newKey);
		sceneData.currentScene.key = newKey;

		commandManager.record(new SceneRenameCommand(oldKey, newKey));
	}

	function onSceneRemoved(sceneName: String): Void {
		if (commandManager.isUndoRedoing) return; // Commands handle removal directly

		// Capture backup BEFORE removal
		var sceneEntry: TSceneEntry = null;
		var sceneIndex: Int = 0;
		for (i in 0...sceneData.scenes.length) {
			if (sceneData.scenes[i].key == sceneName) {
				sceneEntry = sceneData.scenes[i];
				sceneIndex = i;
				break;
			}
		}

		if (sceneEntry == null) return;

		// Remove from SceneManager
		SceneManager.removeScene(sceneName);

		// Remove from SceneData
		sceneEntry.active = false;
		sceneData.scenes.splice(sceneIndex, 1);

		// Switch to another scene
		if (sceneData.scenes.length > 0) {
			var idx = sceneIndex > 0 ? sceneIndex - 1 : 0;
			if (idx >= sceneData.scenes.length) idx = sceneData.scenes.length - 1;
			SceneManager.setScene(sceneData.scenes[idx].key);
			SceneEvents.sceneChanged.emit(sceneData.scenes[idx].key);
		}

		selectedElement = null;
		ElementEvents.elementSelected.emit(null);
		hierarchyPanel.updateTabPosition();

		// Record for undo
		commandManager.record(new SceneRemoveCommand(sceneName, sceneEntry, sceneIndex));
	}
}