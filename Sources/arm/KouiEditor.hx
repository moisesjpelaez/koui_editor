package arm;

import arm.data.SceneData;
import arm.data.EditorSettings;
import arm.data.History;
import arm.data.Selection;
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
import arm.editors.ElementRegistry;

import iron.App;
import iron.system.Input;

import kha.Assets;
import kha.graphics2.Graphics;

import koui.Koui;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;
import koui.utils.SceneManager;


@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.AnchorPane)
class KouiEditor extends iron.Trait {
	var uiBase: UIBase;

	var sizeInit: Bool = false;

	var sceneData: SceneData = SceneData.data;
	var viewport: CanvasViewport = new CanvasViewport();
	var canvasInput: CanvasInput;

	var topToolbar: TopToolbar = new TopToolbar();
	var bottomPanel: BottomPanel = new BottomPanel();
	var hierarchyPanel: HierarchyPanel = new HierarchyPanel();
	var propertiesPanel: PropertiesPanel = new PropertiesPanel();
	var elementsPanel: ElementsPanel = new ElementsPanel();

	// Koui's init (theme, first scene) can finish after the first updates
	var kouiReady: Bool = false;
	var canvasLoaded: Bool = false;
	var canvasWidth: Int = 1024;
	var canvasHeight: Int = 576;

	public function new() {
		super();

		ElementRegistry.registerAll();

		Assets.loadEverything(function() {
			Base.init();
			Base.resizing.connect(onResized);
			CanvasUtils.init();
			EditorSettings.init();

			uiBase = new UIBase(Assets.fonts.font_default);
			viewport.uiBase = uiBase;
			viewport.sceneData = sceneData;
			viewport.topToolbar = topToolbar;
			canvasInput = new CanvasInput(uiBase, viewport, topToolbar, elementsPanel);

			Koui.init(function() {
				Koui.setPadding(100, 100, 75, 75);

				canvasWidth = Std.int(App.w());
				canvasHeight = Std.int(App.h());

				// The game's resolution, see CanvasUtils.init for the arguments
				var argCount = Krom.getArgCount();
				if (argCount >= 6) {
					var resX: Int = Std.parseInt(Krom.getArg(4));
					var resY: Int = Std.parseInt(Krom.getArg(5));
					if (resX != null && resY != null) {
						canvasWidth = resX;
						canvasHeight = resY;
					}
				}

				SceneManager.addScene(SceneData.FIRST_SCENE, (scene) -> setupRootScene(scene, SceneData.FIRST_SCENE));
				CanvasUtils.refreshTheme();

				topToolbar.snapMaxValue = Math.min(canvasWidth, canvasHeight) * 0.5;
				topToolbar.applySavedSnap();
				kouiReady = true;
			});

			App.onResize = onResized;

			ElementEvents.elementAdded.connect(onElementAdded);
			ElementEvents.selectionChanged.connect(onSelectionChanged);
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

	function setupRootScene(scene: AnchorPane, sceneName: String): Void {
		scene.setSize(canvasWidth, canvasHeight);
		scene.setTID("_fixed_anchorpane");
		scene.anchor = Anchor.MiddleCenter;
		scene.invalidateElem();
		var s: TSceneEntry = {
			key: sceneName,
			root: scene,
			keys: new Map()
		};
		sceneData.scenes.push(s);
		sceneData.currentScene = s;
	}

	function update() {
		if (uiBase == null || !kouiReady) return;
		if (!canvasLoaded) { // The canvas loads into the scene Koui's init made
			CanvasUtils.loadCanvas();
			History.reset();
			canvasLoaded = true;
		}

		// Record last frame's edits, unless a drag is still going on
		var mouse: Mouse = Input.getMouse();
		var mouseHeld: Bool = mouse.down("left") || mouse.down("right") || mouse.down("middle");
		if (!mouseHeld) History.commitPending();

		uiBase.update();
		viewport.canvasControl(canvasInput.isInCanvas());
		canvasInput.update();

		var keyboard: Keyboard = Input.getKeyboard();
		var isTyping: Bool = uiBase.ui.isTyping;
		// Shortcuts that replace or remove elements wait for the mouse buttons to be up:
		// a drag or resize would keep changing elements that are gone
		var canEdit: Bool = !isTyping && !mouseHeld;

		if (canEdit && keyboard.started("delete")) {
			deleteSelection();
		}
		if (!isTyping && keyboard.down("control") && keyboard.started("c")) {
			copySelection(false);
		}
		if (canEdit && keyboard.down("control") && keyboard.started("x")) {
			copySelection(true);
		}
		if (canEdit && keyboard.down("control") && keyboard.started("v")) {
			paste();
		}
		if (canEdit && keyboard.down("control") && !keyboard.down("shift") && keyboard.started("z")) {
			if (History.undo()) {
				hierarchyPanel.updateTabPosition();
				uiBase.redrawPanels();
			}
		}
		// Ctrl+Shift+Z or Ctrl+Y
		if (canEdit && keyboard.down("control") && (keyboard.down("shift") && keyboard.started("z") || keyboard.started("y"))) {
			if (History.redo()) {
				hierarchyPanel.updateTabPosition();
				uiBase.redrawPanels();
			}
		}
		if (canEdit && keyboard.down("control") && keyboard.started("d")) {
			duplicateSelection();
		}

		// Toolbar: save, load, clear, reload theme
		if (!isTyping && keyboard.down("control") && keyboard.started("s")) {
			CanvasUtils.saveCanvas();
		}
		if (canEdit && keyboard.down("control") && keyboard.started("o")) {
			CanvasUtils.loadCanvas();
		}
		if (canEdit && keyboard.down("control") && keyboard.started("n")) {
			CanvasUtils.clearToEmptyScene();
		}
		if (canEdit && keyboard.down("control") && keyboard.started("r")) {
			CanvasUtils.refreshTheme();
		}

		// Snapping: toggle (Shift+S), size (Ctrl+[ / Ctrl+])
		if (!isTyping && keyboard.down("shift") && !keyboard.down("control") && keyboard.started("s")) {
			topToolbar.toggleSnapping();
		}
		if (!isTyping && keyboard.down("control") && keyboard.started("[")) {
			topToolbar.setSnapValue(topToolbar.snapValue - TopToolbar.SNAP_STEP);
		}
		if (!isTyping && keyboard.down("control") && keyboard.started("]")) {
			topToolbar.setSnapValue(topToolbar.snapValue + TopToolbar.SNAP_STEP);
		}
	}

	// Deletes the selected elements, with everything inside them
	public function deleteSelection(): Void {
		for (element in Selection.getTopLevel()) {
			ElementEvents.elementRemoved.emit(element);
		}
	}

	// Copies the selected elements to the clipboard, and removes them if `cut` is true
	public function copySelection(cut: Bool): Void {
		var topLevel: Array<Element> = Selection.getTopLevel();
		if (topLevel.length == 0) return;

		var data: Array<TElementData> = [];
		for (element in topLevel) {
			for (elementData in CanvasUtils.serializeElementTree(element)) data.push(elementData);
		}
		Clipboard.clipboardData = data;
		Clipboard.isCut = cut;

		if (cut) deleteSelection();
	}

	// Pastes the clipboard into the primary selected container, or into the scene
	public function paste(): Void {
		if (Clipboard.clipboardData.length == 0) return;

		Selection.setAll(CanvasUtils.pasteElements(Clipboard.clipboardData, Selection.primary));
		History.edited("Paste");
		if (Clipboard.isCut) {
			Clipboard.clipboardData = [];
			Clipboard.isCut = false;
		}
		uiBase.redrawPanels();
	}

	// Duplicates the selected elements in their containers, like a paste, without touching the clipboard
	public function duplicateSelection(): Void {
		var copies: Array<Element> = [];
		for (element in Selection.getTopLevel()) {
			var data: Array<TElementData> = CanvasUtils.serializeElementTree(element);
			for (copy in CanvasUtils.pasteElements(data, HierarchyUtils.getParentElement(element))) copies.push(copy);
		}
		if (copies.length == 0) return;

		Selection.setAll(copies);
		History.edited("Duplicate");
		uiBase.redrawPanels();
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

		Koui.render(g2);
		g2.begin(false);
		viewport.drawGrid(g2);
		viewport.drawRootPane(g2);
		viewport.drawLayoutElements(g2);
		canvasInput.drawSelectedElements(g2);
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
		viewport.onResized(resetScale ? false : sizeInit, canvasHeight);
	}

	function onSelectionChanged(): Void {
		uiBase.redrawPanels();
	}

	function onElementDropped(element: Element, target: Element, zone: DropZone): Void {
		if (element == null || target == null) return;
		if (element == target) return;

		var rootPane: AnchorPane = sceneData.getRoot();

		var newParent: Element = null;
		switch (zone) {
			case AsChild:
				newParent = target;
			case BeforeSibling | AfterSibling:
				newParent = HierarchyUtils.getParentElement(target);
			case None:
				return;
		}

		// Dropped on the scene's row: the element goes first in the scene
		var droppedOnScene: Bool = target == rootPane;
		if (droppedOnScene) newParent = rootPane;

		if (!droppedOnScene && newParent != null && !HierarchyUtils.canAcceptChild(newParent)) {
			uiBase.redrawPanels();
			return;
		}

		// Names are unique among siblings: a taken name gets a free number in the new parent
		var currentName: String = sceneData.getElementKey(element);
		if (currentName == null) currentName = "";
		var uniqueName: String = NameUtils.ensureUniqueName(currentName, element, newParent);

		if (droppedOnScene) {
			var rootFirstElement: Element = rootPane.elements[0];
			if (rootFirstElement != element) HierarchyUtils.moveRelativeToTarget(element, rootFirstElement, true);
		} else {
			switch (zone) {
				case AsChild:
					HierarchyUtils.moveAsChild(element, target);
				case BeforeSibling:
					HierarchyUtils.moveRelativeToTarget(element, target, true);
				case AfterSibling:
					HierarchyUtils.moveRelativeToTarget(element, target, false);
				case None:
			}
		}

		if (uniqueName != currentName) {
			sceneData.updateElementKey(element, uniqueName);
		}
		History.edited("Move");

		uiBase.redrawPanels();
	}

	function onElementAdded(entry: TElementEntry): Void {
		var rootPane: AnchorPane = sceneData.getRoot();
		if (rootPane == null) return;

		rootPane.add(entry.element, Anchor.TopLeft);

		var uniqueName: String = NameUtils.generateName(entry.element, rootPane);
		entry.key = uniqueName;
		sceneData.updateElementKey(entry.element, uniqueName);

		Selection.select(entry.element);
		History.edited("Add element");
	}

	function onElementRemoved(element: Element): Void {
		for (descendant in collectDescendants(element)) {
			sceneData.unregisterElement(descendant);
		}

		// Row/Col layouts close the gap
		HierarchyUtils.detachFromCurrentParent(element);
		element.destroy();

		Selection.refresh();
		History.edited("Delete");
	}

	// `element` and the user elements inside it
	function collectDescendants(element: Element): Array<Element> {
		var result: Array<Element> = [element];
		for (child in sceneData.getChildren(element)) {
			for (descendant in collectDescendants(child)) result.push(descendant);
		}
		return result;
	}

	function onSceneAdded(sceneName: String): Void {
		SceneManager.addScene(sceneName, (scene) -> setupRootScene(scene, sceneName));
		SceneManager.setScene(sceneName);
		viewport.applyPan();
		Selection.clear();
		hierarchyPanel.updateTabPosition();
		History.edited("Add scene");
	}

	function onSceneChanged(sceneName: String): Void {
		SceneManager.setScene(sceneName);
		viewport.applyPan();
		Selection.clear();
	}

	function onSceneNameChanged(oldKey: String, newKey: String): Void {
		SceneManager.renameScene(oldKey, newKey);
		sceneData.currentScene.key = newKey;
		History.edited("Rename scene");
	}

	function onSceneRemoved(sceneName: String): Void {
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

		SceneManager.removeScene(sceneName);
		sceneEntry.root.destroy();
		sceneData.scenes.splice(sceneIndex, 1);

		// Show the scene before it
		if (sceneData.scenes.length > 0) {
			var idx = sceneIndex > 0 ? sceneIndex - 1 : 0;
			SceneManager.setScene(sceneData.scenes[idx].key);
			SceneEvents.sceneChanged.emit(sceneData.scenes[idx].key);
		}

		Selection.clear();
		hierarchyPanel.updateTabPosition();
		History.edited("Delete scene");
	}
}
