package arm.panels;

import arm.canvas.CanvasLoader;
import arm.data.SceneData;
import arm.data.Selection;
import arm.events.ElementEvents;
import arm.events.SceneEvents;
import arm.base.Base;
import arm.base.UIBase;
import arm.tools.HierarchyUtils;
import arm.tools.NameUtils;
import arm.tools.ZuiUtils;
import arm.types.Enums;
import arm.types.Types;
import iron.system.Input;
import kha.Image;
import koui.elements.Element;
import zui.Zui;
import zui.Zui.Handle;

/** An element's row as drawn, in screen pixels: its name starts at `nameX`, left of it are the indent and the +/- button. */
typedef THierarchyRow = {
	var element: Element;
	var y: Float;
	var h: Float;
	var nameX: Float;
}

@:access(zui.Zui)
class HierarchyPanel {
	// Layout constants, in pixels at UI scale 1
	static inline var INDENT_PER_DEPTH: Int = 15;
	static inline var EXPAND_BUTTON_WIDTH: Int = 25;
	static inline var DELETE_BUTTON_WIDTH: Int = 30;
	static inline var DRAG_THRESHOLD: Float = 5.0;
	static inline var DROP_ZONE_TOP: Float = 0.25;
	static inline var DROP_ZONE_BOTTOM: Float = 0.75;
	static inline var GHOST_WIDTH: Float = 150;
	static inline var GHOST_OFFSET: Float = 10;
	static inline var RESIZE_GUTTER: Int = 4;

	// Scene management
	var sceneTabHandle: Handle;

	var sceneData: SceneData = SceneData.data;

	// Expand/collapse state - keyed by element reference
	// Collapsed elements by "scene:path", so the state survives an undo (which recreates elements)
	var collapsed: Map<String, Bool> = new Map();

	// Drag-drop state - use Element references instead of indices
	var draggedItem: TElementEntry = null;
	var mouseDownOnItem: Bool = false;
	var dropTargetElement: Element = null;
	var dropZone: DropZone = None;
	var isDragging: Bool = false;
	var dragStartX: Float = 0;
	var dragStartY: Float = 0;

	/** The rows drawn last, in screen pixels, for the selection box and pressing on empty space. */
	var rows: Array<THierarchyRow> = [];
	/** The bottom of the scene's row: below it, a press outside the names is on empty space. */
	var rootRowBottom: Float = 0;

	// Selection box: pressing on empty space and dragging past DRAG_THRESHOLD pixels
	var boxPending: Bool = false;
	var boxActive: Bool = false;
	var boxStartX: Float = 0;
	var boxStartY: Float = 0;
	var boxEndX: Float = 0;
	var boxEndY: Float = 0;
	var boxToggles: Bool = false;
	var boxAdds: Bool = false;

	var icons: Image;

	public function new() {
		sceneTabHandle = new Handle();

		ElementEvents.selectionChanged.connect(onSelectionChanged);

		SceneEvents.sceneAdded.connect(onSceneAdded);
		SceneEvents.sceneChanged.connect(onSceneChanged);
		SceneEvents.sceneRemoved.connect(onSceneRemoved);

		// Initialize handle position to current scene
		updateTabPosition();
	}

	/** Get scene keys from SceneData - single source of truth */
	function getSceneTabs(): Array<String> {
		return [for (scene in sceneData.scenes) scene.key];
	}

	/** Update tab handle position to match current scene */
	public function updateTabPosition(): Void {
		if (sceneData.currentScene != null) {
			var tabs = getSceneTabs();
			var idx = tabs.indexOf(sceneData.currentScene.key);
			sceneTabHandle.position = idx >= 0 ? idx : 0;
		} else {
			sceneTabHandle.position = 0;
		}
	}

	public function draw(uiBase: UIBase, params: Dynamic): Void {
		var ui: Zui = uiBase.ui;
		mouseDownOnItem = false;
		if (ui.window(uiBase.hwnds[PanelHierarchy], params.tabx, 0, params.w, params.h0)) {
			rows = [];
			// The rows under the mouse set it again below; releasing over no row drops nowhere
			if (isDragging) {
				dropTargetElement = null;
				dropZone = None;
			}
			drawSceneSelector(uiBase);
			ui.separator();

			// Draw root element (only if currentScene exists)
			if (sceneData.currentScene != null) {
				drawItem(uiBase, { key: sceneData.currentScene.key, element: sceneData.currentScene.root }, 0);
			}

			// Pressing on empty space starts a selection box; releasing without dragging clears the selection
			if (ui.inputStarted && !mouseDownOnItem && isEmptySpace(uiBase, params)) {
				var keyboard = Input.getKeyboard();
				boxPending = true;
				boxActive = false;
				boxStartX = boxEndX = ui.inputX;
				boxStartY = boxEndY = ui.inputY;
				boxToggles = keyboard.down("control");
				boxAdds = keyboard.down("shift");
			}
			if (boxPending && ui.inputDown) {
				boxEndX = ui.inputX;
				boxEndY = ui.inputY;
				if (Math.abs(boxEndX - boxStartX) > DRAG_THRESHOLD || Math.abs(boxEndY - boxStartY) > DRAG_THRESHOLD) boxActive = true;
				uiBase.redrawPanels();
			}
			if (boxPending && ui.inputReleased) {
				if (boxActive) selectInBox();
				else if (!boxToggles && !boxAdds && !Base.isResizing) Selection.clear();
				boxPending = boxActive = false;
				uiBase.redrawPanels();
			}
		}
		if (!ui.inputDown && !ui.inputReleased) boxPending = boxActive = false;

		drawSelectionBox(uiBase);
		drawDragGhost(uiBase);
		handleDragEnd(uiBase);
	}

	/**
	 * Whether the mouse is on the panel's empty space: inside it (not on its
	 * resizable borders), below the scene's row, and not on a name, a +/- or a
	 * delete button. The indent left of a nested row counts as empty.
	 */
	function isEmptySpace(uiBase: UIBase, params: Dynamic): Bool {
		var ui: Zui = uiBase.ui;
		var x: Float = ui.inputX;
		var y: Float = ui.inputY;
		var gutter: Int = Std.int(Math.max(2, RESIZE_GUTTER * ui.SCALE()));
		if (x < params.tabx + gutter || x >= params.tabx + params.w || y >= params.h0 - gutter) return false;
		if (y < rootRowBottom) return false;
		for (row in rows) {
			if (y >= row.y && y < row.y + row.h) return x < row.nameX;
		}
		return true;
	}

	/** The selection box, in screen pixels. */
	function getBoxRect(): { x: Float, y: Float, w: Float, h: Float } {
		var x: Float = Math.min(boxStartX, boxEndX);
		var y: Float = Math.min(boxStartY, boxEndY);
		return { x: x, y: y, w: Math.abs(boxEndX - boxStartX), h: Math.abs(boxEndY - boxStartY) };
	}

	/**
	 * Selects the rows the box touches vertically. Shift adds them to the
	 * selection, Ctrl toggles them, otherwise they replace it.
	 */
	function selectInBox(): Void {
		var box = getBoxRect();
		var picked: Array<Element> = [for (row in rows) if (row.y < box.y + box.h && row.y + row.h > box.y) row.element];

		if (boxToggles) {
			var result: Array<Element> = Selection.elements.copy();
			for (element in picked) {
				if (!result.remove(element)) result.push(element);
			}
			Selection.setAll(result);
		} else if (boxAdds) {
			Selection.setAll(Selection.elements.concat(picked));
		} else {
			Selection.setAll(picked);
		}
	}

	function drawSelectionBox(uiBase: UIBase): Void {
		if (!boxActive) return;
		var ui: Zui = uiBase.ui;
		var box = getBoxRect();
		var x: Float = box.x - ui._windowX;
		var y: Float = box.y - ui._windowY;
		ui.g.color = 0x33469CFF;
		ui.g.fillRect(x, y, box.w, box.h);
		ui.g.color = 0xFF469CFF;
		ui.g.drawRect(x, y, box.w, box.h, 1);
		ui.g.color = 0xFFFFFFFF;
	}

	function drawSceneSelector(uiBase: UIBase) {
		uiBase.ui.row([0.7, 0.15, 0.15]);

		var sceneTabs = getSceneTabs();
		sceneTabHandle.position = uiBase.ui.combo(sceneTabHandle, sceneTabs, "", true);

		if (sceneTabHandle.changed) {
			var sceneName: String = sceneTabs[sceneTabHandle.position];
			SceneEvents.sceneChanged.emit(sceneName);
		}

		if (ZuiUtils.iconButton(uiBase.ui, icons, 1, 2, "Add Scene", false, false, 0.7)) {
			var newSceneName = NameUtils.generateUniqueName("Scene", sceneTabs);
			SceneEvents.sceneAdded.emit(newSceneName);
		}

		if (ZuiUtils.iconButton(uiBase.ui, icons, 1, 3, "Delete Scene", false, sceneTabs.length <= 1, 0.7)) {
			var sceneName: String = sceneTabs[sceneTabHandle.position];
			SceneEvents.sceneRemoved.emit(sceneName);
		}
	}

	function drawItem(uiBase: UIBase, entry: TElementEntry, depth: Int) {
		if (entry == null) return;

		var name: String = entry.key;
		var isRoot: Bool = entry.element == sceneData.currentScene.root;
		// Only user elements, not internal parts like a Button's label
		var children: Array<Element> = sceneData.getChildren(entry.element);
		var hasChildren: Bool = children.length > 0;
		var isExpanded: Bool = !collapsed.exists(expandKey(entry.element));

		// Cache window coordinates
		var ui: Zui = uiBase.ui;
		var winX: Float = ui._windowX;
		var winY: Float = ui._windowY;
		var localX: Float = ui._x;
		var localY: Float = ui._y;
		var rowW: Float = ui._w;
		var rowH: Float = ui.ELEMENT_H();

		// Fixed-width columns (Zui takes a negative ratio as pixels): the +/- and delete
		// columns are always there, so names at the same depth and the delete icons line up
		var scale: Float = ui.SCALE();
		var indentW: Float = depth * INDENT_PER_DEPTH * scale;
		var expandW: Float = EXPAND_BUTTON_WIDTH * scale;
		var deleteW: Float = isRoot ? 0 : DELETE_BUTTON_WIDTH * scale;
		var nameW: Float = Math.max(1, rowW - indentW - expandW - deleteW);

		// Draw drop zone indicator
		drawDropIndicator(ui, entry.element, localX, localY, rowW, rowH, indentW);

		var ratios: Array<Float> = [-indentW, -expandW, -nameW];
		if (!isRoot) ratios.push(-deleteW);
		ui.row(ratios);

		ui.text(""); // Indent spacer

		// Expand/collapse button; rows without children keep the space empty
		if (hasChildren) {
			if (ui.button(isExpanded ? "-" : "+")) {
				isExpanded ? collapsed.set(expandKey(entry.element), true) : collapsed.remove(expandKey(entry.element));
			}
		} else {
			ui.text("");
		}

		if (isRoot) rootRowBottom = winY + localY + rowH;
		else rows.push({ element: entry.element, y: winY + localY, h: rowH, nameX: winX + localX + indentW });

		// For root element, show scene name as text input for renaming
		if (isRoot) {
			var sceneTabs = getSceneTabs();
			var currentIdx: Int = sceneTabHandle.position;
			if (currentIdx >= sceneTabs.length) currentIdx = sceneTabs.length - 1;
			if (currentIdx < 0) currentIdx = 0;

			sceneTabHandle.text = sceneTabs[currentIdx];
			var newName: String = uiBase.ui.textInput(sceneTabHandle, "Name", zui.Zui.Align.Left);

			if (sceneTabHandle.changed && newName != "") {
				// Collect other scene names (excluding current)
				var otherScenes: Array<String> = [];
				for (i in 0...sceneTabs.length) {
					if (i != currentIdx) {
						otherScenes.push(sceneTabs[i]);
					}
				}

				// A taken name gets the next free number
				newName = NameUtils.nextUniqueName(newName, otherScenes);

				var oldName: String = sceneTabs[currentIdx];
				SceneEvents.sceneNameChanged.emit(oldName, newName);
			}
		} else {
			// Item button with selection highlighting
			drawItemButton(uiBase.ui, name, entry.element);
			handleItemInteraction(uiBase, entry);
		}

		// Delete icon button
		if (entry.element != sceneData.currentScene.root) {
			var deleteClicked = ZuiUtils.iconButton(uiBase.ui, icons, 1, 3, "Delete", false, false, 0.7);
			if (deleteClicked) {
				ElementEvents.elementRemoved.emit(entry.element);
			}
			uiBase.ui._y += 4;
		}

		handleDropDetection(uiBase, entry, winX, winY, localX, localY, rowW, rowH);

		// Recursively draw children
		if (hasChildren && isExpanded) {
			for (child in children) {
				drawItem(uiBase, { key: sceneData.getElementKey(child), element: child }, depth + 1);
			}
		}
	}

	function drawItemButton(ui: Zui, name: String, element: Element) {
		var isSelected: Bool = Selection.contains(element);

		// Save theme colors
		var savedCol: Int = ui.t.BUTTON_COL;
		var savedHover: Int = ui.t.BUTTON_HOVER_COL;
		var savedPressed: Int = ui.t.BUTTON_PRESSED_COL;

		if (isSelected) {
			ui.t.BUTTON_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_HOVER_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_PRESSED_COL = ui.t.HIGHLIGHT_COL;
		}

		ui.button(name, Align.Left);

		// Restore theme colors
		ui.t.BUTTON_COL = savedCol;
		ui.t.BUTTON_HOVER_COL = savedHover;
		ui.t.BUTTON_PRESSED_COL = savedPressed;
	}

	function handleItemInteraction(uiBase: UIBase, entry: TElementEntry) {
		// Mouse down: begin drag tracking only (selection happens on release)
		if (uiBase.ui.isPushed && uiBase.ui.inputStarted) {
			mouseDownOnItem = true;
			draggedItem = entry;
			dragStartX = uiBase.ui.inputX;
			dragStartY = uiBase.ui.inputY;
			uiBase.hwnds[PanelHierarchy].redraws = 2;
		}

		// Mouse up: apply selection — but not if we just finished a drag drop
		if (uiBase.ui.isReleased && !isDragging) {
			draggedItem = null;

			var shiftHeld: Bool = Input.getKeyboard().down("shift");
			var ctrlHeld: Bool = Input.getKeyboard().down("control");
			if (shiftHeld) {
				var anchor: Element = Selection.rangeAnchor;
				if (anchor == null) anchor = Selection.primary;
				if (anchor == null) anchor = entry.element;

				var rangeSelection: Array<Element> = getShiftRangeSelection(anchor, entry.element);
				if (rangeSelection.length == 0) rangeSelection = [entry.element];

				Selection.setAll(mergeSelection(rangeSelection), entry.element);
				if (Selection.rangeAnchor == null) Selection.rangeAnchor = anchor;
			} else if (ctrlHeld) {
				Selection.toggle(entry.element);
				Selection.rangeAnchor = entry.element;
			} else {
				Selection.select(entry.element);
			}

			uiBase.redrawPanels();
		}

		// Start drag after threshold
		// Entries are made anew each frame: compare their elements
		if (draggedItem != null && draggedItem.element == entry.element && uiBase.ui.inputDown && !isDragging) {
			var dx: Float = uiBase.ui.inputX - dragStartX;
			var dy: Float = uiBase.ui.inputY - dragStartY;

			if (Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD) {
				isDragging = true;
				uiBase.redrawPanels();
			}
		}
	}

	function getShiftRangeSelection(anchor: Element, target: Element): Array<Element> {
		if (anchor == null || target == null) return [];

		var siblingRange: Array<Element> = getSiblingRangeSelection(anchor, target);
		if (siblingRange.length > 0) return siblingRange;

		return getVisibleRangeSelection(anchor, target);
	}

	function mergeSelection(rangeSelection: Array<Element>): Array<Element> {
		var merged: Array<Element> = Selection.elements.copy();
		for (element in rangeSelection) {
			if (merged.indexOf(element) < 0) merged.push(element);
		}

		var visible: Array<Element> = getVisibleHierarchyElements();
		merged.sort(function(a, b) {
			var ia: Int = visible.indexOf(a);
			var ib: Int = visible.indexOf(b);
			if (ia < 0 && ib < 0) return 0;
			if (ia < 0) return 1;
			if (ib < 0) return -1;
			return ia - ib;
		});

		return merged;
	}

	function getSiblingRangeSelection(anchor: Element, target: Element): Array<Element> {
		var anchorParent: Element = HierarchyUtils.getParentElement(anchor);
		var targetParent: Element = HierarchyUtils.getParentElement(target);
		if (anchorParent == null || targetParent == null || anchorParent != targetParent) return [];

		var siblings: Array<Element> = sceneData.getChildren(anchorParent);
		var iAnchor: Int = siblings.indexOf(anchor);
		var iTarget: Int = siblings.indexOf(target);
		if (iAnchor < 0 || iTarget < 0) return [];

		var start: Int = iAnchor < iTarget ? iAnchor : iTarget;
		var end: Int = iAnchor > iTarget ? iAnchor : iTarget;
		var result: Array<Element> = [];
		for (i in start...end + 1) result.push(siblings[i]);
		return result;
	}

	function getVisibleRangeSelection(anchor: Element, target: Element): Array<Element> {
		var visible: Array<Element> = getVisibleHierarchyElements();
		var iAnchor: Int = visible.indexOf(anchor);
		var iTarget: Int = visible.indexOf(target);
		if (iAnchor < 0 || iTarget < 0) return [];

		var start: Int = iAnchor < iTarget ? iAnchor : iTarget;
		var end: Int = iAnchor > iTarget ? iAnchor : iTarget;
		var result: Array<Element> = [];
		for (i in start...end + 1) result.push(visible[i]);
		return result;
	}

	function getVisibleHierarchyElements(): Array<Element> {
		var result: Array<Element> = [];
		var currentScene = sceneData.currentScene;
		if (currentScene == null || currentScene.root == null) return result;

		collectVisibleElements(currentScene.root, result, true);
		return result;
	}

	function collectVisibleElements(element: Element, out: Array<Element>, isRoot: Bool): Void {
		if (element == null) return;
		if (!isRoot) out.push(element);

		var children: Array<Element> = sceneData.getChildren(element);
		if (children.length == 0) return;

		var isExpanded: Bool = !collapsed.exists(expandKey(element));
		if (!isExpanded) return;

		for (child in children) {
			collectVisibleElements(child, out, false);
		}
	}

	function drawDragGhost(uiBase: UIBase) {
		if (!isDragging || draggedItem == null) return;

		var winX: Float = uiBase.ui._windowX;
		var winY: Float = uiBase.ui._windowY;

		var ghostX: Float = uiBase.ui.inputX - winX - GHOST_OFFSET;
		var ghostY: Float = uiBase.ui.inputY - winY - GHOST_OFFSET;
		var ghostH: Float = uiBase.ui.ELEMENT_H();

		uiBase.ui.g.color = 0xDD222222;
		uiBase.ui.g.fillRect(ghostX, ghostY, GHOST_WIDTH, ghostH);

		uiBase.ui.g.color = 0xFF469CFF;
		uiBase.ui.g.drawRect(ghostX, ghostY, GHOST_WIDTH, ghostH, 2);

		uiBase.ui.g.color = 0xFFFFFFFF;
		uiBase.ui.g.font = uiBase.ui.ops.font;
		var dragCount: Int = (Selection.elements.length > 1 && Selection.contains(draggedItem.element)) ? Selection.elements.length : 1;
		var dragLabel: String = dragCount > 1 ? '${draggedItem.key} (+${dragCount - 1})' : draggedItem.key;
		uiBase.ui.g.drawString(dragLabel, ghostX + 8, ghostY + 4);

		uiBase.redrawPanels();
	}

	function handleDragEnd(uiBase:UIBase) {
		if (!uiBase.ui.inputReleased || !isDragging) return;

		if (dropTargetElement != null && dropZone != None) {
			performDrop();
		}

		// Select the dragged element when the drag ends
		if (draggedItem != null) {
			var ctrlHeld: Bool = Input.getKeyboard().down("control");
			var wasMultiSelected: Bool = Selection.elements.length > 1 && Selection.contains(draggedItem.element);
			if (ctrlHeld || wasMultiSelected) {
				// Keep the multi-selection, with the dragged element as the primary one
				Selection.add(draggedItem.element);
			} else {
				Selection.select(draggedItem.element);
			}
		}

		isDragging = false;
		draggedItem = null;
		dropTargetElement = null;
		dropZone = None;

		uiBase.hwnds[PanelHierarchy].redraws = 3;
	}

	function drawDropIndicator(ui: Zui, element: Element, x: Float, y: Float, w: Float, h: Float, indent: Float) {
		if (!isDragging || dropTargetElement != element || dropZone == None) return;

		ui.g.color = 0xFF469CFF;
		switch (dropZone) {
			case BeforeSibling:
				ui.g.fillRect(x + indent, y, w - indent, 2);
			case AfterSibling:
				ui.g.fillRect(x + indent, y + h - 2, w - indent, 2);
			case AsChild:
				ui.g.drawRect(x + indent, y, w - indent, h, 2);
			case None:
		}
		ui.g.color = 0xFFFFFFFF;
	}

	function handleDropDetection(uiBase: UIBase, item: TElementEntry, winX: Float, winY: Float, localX: Float, localY: Float, winW: Float, rowH: Float) {
		if (!isDragging || draggedItem == null || draggedItem.element == item.element) return;

		var absX: Float = winX + localX;
		var absY: Float = winY + localY;

		var inBounds: Bool = uiBase.ui.inputX >= absX && uiBase.ui.inputX <= absX + winW && uiBase.ui.inputY >= absY && uiBase.ui.inputY <= absY + rowH;

		if (!inBounds || HierarchyUtils.isDescendant(item.element, draggedItem.element)) return;

		dropTargetElement = item.element;

		var ratio: Float = (uiBase.ui.inputY - absY) / rowH;
		if (ratio < DROP_ZONE_TOP) {
			dropZone = BeforeSibling;
		} else if (ratio > DROP_ZONE_BOTTOM) {
			dropZone = AfterSibling;
		} else {
			// Only allow AsChild if target can accept children
			if (HierarchyUtils.canAcceptChild(item.element)) {
				dropZone = AsChild;
			} else {
				// Fall back to AfterSibling for non-containers
				dropZone = AfterSibling;
			}
		}

		uiBase.redrawPanels();
	}

	function performDrop() {
		if (draggedItem == null || dropTargetElement == null || dropZone == None) return;

		// Determine which elements to drop
		var isMulti: Bool = Selection.elements.length > 1 && Selection.contains(draggedItem.element);
		// Selected elements inside other selected ones move with them
		var elemsToDrop: Array<Element> = isMulti ? Selection.getTopLevel() : [draggedItem.element];

		// Filter out the target itself and any ancestor of the target
		elemsToDrop = elemsToDrop.filter(e -> e != dropTargetElement && !HierarchyUtils.isDescendant(dropTargetElement, e));
		if (elemsToDrop.length == 0) return;

		// Sort by hierarchy order so relative order is preserved
		var sceneElements: Array<Element> = sceneData.getElements();
		elemsToDrop.sort((a, b) -> sceneElements.indexOf(a) - sceneElements.indexOf(b));

		// For BeforeSibling: normal order → each inserts before target, pushing earlier ones ahead
		// For AfterSibling:  reverse order → each inserts after target, pulling earlier ones forward
		// For AsChild: order doesn't matter
		if (dropZone == AfterSibling) elemsToDrop.reverse();

		for (elem in elemsToDrop) {
			ElementEvents.elementDropped.emit(elem, dropTargetElement, dropZone);
		}
	}

	function expandKey(element: Element): String {
		var scene: TSceneEntry = sceneData.currentScene;
		return scene.key + ":" + CanvasLoader.getPath(element, scene.root, scene.keys);
	}

	function onSelectionChanged(): Void {
		if (Selection.isEmpty()) draggedItem = null;
	}

	public function setIcons(iconsImage: Image): Void {
		icons = iconsImage;
	}

	function onSceneAdded(sceneName: String): Void {
		updateTabPosition();
	}

	function onSceneChanged(sceneName: String): Void {
		updateTabPosition();
	}

	function onSceneRemoved(sceneName: String): Void {
		updateTabPosition();
	}
}