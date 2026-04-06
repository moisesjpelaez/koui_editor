package arm;

import arm.data.SceneData;
import arm.data.EditorSettings;
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
import iron.system.Input;

import kha.Assets;
import kha.graphics2.Graphics;

import koui.Koui;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;
import koui.utils.SceneManager;

import arm.CanvasViewport;
import arm.DragDropHandler;

@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class KouiEditor extends iron.Trait {
	var uiBase: UIBase;

	var rootPane: AnchorPane;
	var sizeInit: Bool = false;

	// Created elements
	var sceneData: SceneData = SceneData.data;

	var selectedElement: Element = null;

	// Viewport controller
	var viewport: CanvasViewport = new CanvasViewport();

	// Drag and drop
	var dragDrop: DragDropHandler;

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

		// Register element editors
		ElementRegistry.register(new LabelEditor());
		ElementRegistry.register(new PanelEditor());
		ElementRegistry.register(new ImagePanelEditor());
		ElementRegistry.register(new ButtonEditor());
		ElementRegistry.register(new CheckboxEditor());
		ElementRegistry.register(new RadioButtonEditor());
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

			// Initialize editor settings
			EditorSettings.init();

			// Create UIBase with the loaded font
			uiBase = new UIBase(Assets.fonts.font_default);
			viewport.uiBase = uiBase;
			viewport.sceneData = sceneData;
			viewport.topToolbar = topToolbar;
			dragDrop = new DragDropHandler(uiBase, viewport, topToolbar);

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
			commandManager.clear();
			canvasLoaded = true;
		}
		uiBase.update();
		viewport.canvasControl(dragDrop.isInCanvas(), dragDrop.isInElementsPanel());

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

		dragDrop.rootPane = rootPane;
		dragDrop.update();
		selectedElement = dragDrop.selectedElement;
		Koui.render(g2);
		g2.begin(false);
		viewport.drawGrid(g2);
		viewport.drawRootPane(g2);
		viewport.drawLayoutElements(g2);
		dragDrop.drawSelectedElement(g2);
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
			var resetScale = viewport.viewReset;
			viewport.viewReset = false;
			applyResize(resetScale);
			sizeInit = true;
		}
	}

	function onResized() {
		applyResize(false);
	}

	function applyResize(resetScale: Bool) {
		viewport.onResized(resetScale ? false : sizeInit, baseH);
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
		dragDrop.selectedElement = element;

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