package arm.panels;

import arm.data.SceneData;
import arm.events.ElementEvents;
import arm.events.SceneEvents;
import arm.base.Base;
import arm.base.UIBase;
import arm.tools.HierarchyUtils;
import arm.tools.NameUtils;
import arm.tools.ZuiUtils;
import arm.types.Enums;
import arm.types.Types;
import haxe.ds.ObjectMap;
import iron.system.Input;
import kha.Image;
import koui.elements.Element;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

@:access(zui.Zui)
class HierarchyPanel {
	// Layout constants
	static inline var INDENT_PER_DEPTH: Int = 15;
	static inline var EXPAND_BUTTON_WIDTH: Int = 25;
	static inline var DRAG_THRESHOLD: Float = 5.0;
	static inline var DROP_ZONE_TOP: Float = 0.25;
	static inline var DROP_ZONE_BOTTOM: Float = 0.75;
	static inline var GHOST_WIDTH: Float = 150;
	static inline var GHOST_OFFSET: Float = 10;
	static inline var RESIZE_GUTTER: Int = 4;

	// Scene management
	var sceneTabHandle: Handle;
	var sceneCounter: Int = 1;

	var sceneData: SceneData = SceneData.data;

	// Expand/collapse state - keyed by element reference
	var expanded: ObjectMap<Element, Bool> = new ObjectMap();

	// Drag-drop state - use Element references instead of indices
    var selectedElement: Element = null;
	var selectedElements: Array<Element> = [];
	var shiftAnchorElement: Element = null;
	var draggedItem: TElementEntry = null;
	var mouseDownOnItem: Bool = false;
	var clickedEmptySpace: Bool = false;
	var dropTargetElement: Element = null;
	var dropZone: DropZone = None;
	var isDragging: Bool = false;
	var dragStartX: Float = 0;
	var dragStartY: Float = 0;

	var icons: Image;

	public function new() {
		sceneTabHandle = new Handle();

		ElementEvents.elementAdded.connect(onElementAdded);
		ElementEvents.elementSelected.connect(onElementSelected);

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
		mouseDownOnItem = false;
		if (uiBase.ui.window(uiBase.hwnds[PanelHierarchy], params.tabx, 0, params.w, params.h0)) {
			drawSceneSelector(uiBase);
			uiBase.ui.separator();

            // Draw root element (only if currentScene exists)
            if (sceneData.currentScene != null) {
                drawItem(uiBase, { key: sceneData.currentScene.key, element: sceneData.currentScene.root }, 0);
            }

			// Click on empty space (no item captured the mouse-down) → deselect on release
			// Only track clicks that originated inside the hierarchy panel
			if (!mouseDownOnItem && uiBase.ui.inputStarted) {
				var mouse = Input.getMouse();
				var gutter: Int = Std.int(Math.max(2, RESIZE_GUTTER * uiBase.ui.SCALE()));
				var inResizableGutter: Bool = mouse.x < params.tabx + gutter || mouse.y >= params.h0 - gutter;
				if (!inResizableGutter && mouse.x >= params.tabx && mouse.x < params.tabx + params.w && mouse.y >= 0 && mouse.y < params.h0) {
					clickedEmptySpace = true;
				}
			}
			if (clickedEmptySpace && uiBase.ui.inputReleased && !isDragging && !Base.isResizing) {
				clickedEmptySpace = false;
				selectedElement = null;
				selectedElements = [];
				ElementEvents.elementSelected.emit(null);
				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;
			}
		}
		if (!uiBase.ui.inputDown) clickedEmptySpace = false;

		drawDragGhost(uiBase);
		handleDragEnd(uiBase);
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
		// Only show children that are user-facing containers (not internal elements like Button's _label)
		var allChildren: Array<Element> = HierarchyUtils.getChildren(entry.element);
		var children: Array<Element> = [];
		for (child in allChildren) {
			// Include containers and elements that are in our elements list
			var currentScene = SceneData.data.currentScene;
			if (currentScene == null) continue;
			for (e in currentScene.elements) {
				if (e.element == child) {
					children.push(child);
					break;
				}
			}
		}
		var hasChildren: Bool = children.length > 0;
		var isExpanded: Bool = expanded.exists(entry.element) ? expanded.get(entry.element) : true;

		// Cache window coordinates
		var winX: Float = uiBase.ui._windowX;
		var winY: Float = uiBase.ui._windowY;
		var winW: Float = uiBase.ui._windowW;
		var localX: Float = uiBase.ui._x;
		var localY: Float = uiBase.ui._y;
		var rowH: Int = uiBase.ui.t.ELEMENT_H;
		var indentWidth: Int = depth * INDENT_PER_DEPTH;

		// Draw drop zone indicator
		drawDropIndicator(uiBase.ui, entry.element, localX, localY, winW, rowH, indentWidth);

		// Row layout with delete icon column
		if (entry.element == sceneData.currentScene.root) {
			if (hasChildren) {
				uiBase.ui.row([indentWidth / winW, EXPAND_BUTTON_WIDTH / winW, 1 - (indentWidth + EXPAND_BUTTON_WIDTH) / winW]);
			} else {
				uiBase.ui.row([indentWidth / winW, 1 - indentWidth / winW]);
			}
		} else {
			if (hasChildren) {
				uiBase.ui.row([indentWidth / winW, EXPAND_BUTTON_WIDTH / winW, 0.8 - (indentWidth * 0.5 + EXPAND_BUTTON_WIDTH * 0.5) / winW, 0.2 - (indentWidth * 0.5 + EXPAND_BUTTON_WIDTH * 0.5) / winW]);
			} else {
				uiBase.ui.row([indentWidth / winW, 0.8 - indentWidth * 0.5 / winW, 0.2 - indentWidth * 0.5 / winW]);
			}
		}

		uiBase.ui.text(""); // Indent spacer

		// Expand/collapse button
		if (hasChildren && uiBase.ui.button(isExpanded ? "v" : ">")) {
			expanded.set(entry.element, !isExpanded);
		}

		// For root element, show scene name as text input for renaming
		if (entry.element == sceneData.currentScene.root) {
			var sceneTabs = getSceneTabs();
			if (sceneTabs.length == 0) return; // nothing to edit
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

				// Check for conflicts and ensure uniqueness
				if (otherScenes.indexOf(newName) != -1) {
					var parts: Array<String> = newName.split("_");
					var baseName: String = parts[0];
					newName = NameUtils.generateUniqueName(baseName, otherScenes, "_");
				}

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
			var deleteDisabled = entry.element == sceneData.currentScene.root;
			var deleteClicked = ZuiUtils.iconButton(uiBase.ui, icons, 1, 3, "Delete", false, deleteDisabled, 0.7);
			if (deleteClicked) {
				ElementEvents.elementRemoved.emit(entry.element);
			}
			uiBase.ui._y += 4;
		}

		handleDropDetection(uiBase, entry, winX, winY, localX, localY, winW, rowH);

		// Recursively draw children
		if (hasChildren && isExpanded) {
			// Add vertical spacing before children
			for (child in children) {
				var currentScene = SceneData.data.currentScene;
				if (currentScene == null) continue;
                for (entry in currentScene.elements) {
                    if (entry.element == child) {
                        drawItem(uiBase, entry, depth + 1);
                        break;
                    }
                }
			}
		}
	}

    function drawItemButton(ui: Zui, name: String, element: Element) {
		var isSelected: Bool = selectedElements.indexOf(element) >= 0;

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
		var isRoot: Bool = sceneData.currentScene.root != null && entry.element == sceneData.currentScene.root;

		// Mouse down: begin drag tracking only (selection happens on release)
		if (uiBase.ui.isPushed && uiBase.ui.inputStarted) {
			mouseDownOnItem = true;
			if (!isRoot) {
				draggedItem = entry;
				dragStartX = uiBase.ui.inputX;
				dragStartY = uiBase.ui.inputY;
			}
			uiBase.hwnds[PanelHierarchy].redraws = 2;
		}

		// Mouse up: apply selection — but not if we just finished a drag drop
		if (uiBase.ui.isReleased && !isDragging) {
			draggedItem = null;
			if (entry.element == sceneData.currentScene.root) return;

			var shiftHeld: Bool = Input.getKeyboard().down("shift");
			var ctrlHeld: Bool = Input.getKeyboard().down("control");
			if (shiftHeld) {
				var anchor: Element = shiftAnchorElement;
				if (anchor == null) anchor = selectedElement;
				if (anchor == null) anchor = entry.element;

				var rangeSelection: Array<Element> = getShiftRangeSelection(anchor, entry.element);
				if (rangeSelection.length == 0) rangeSelection = [entry.element];

				selectedElements = mergeSelection(rangeSelection);
				selectedElement = entry.element;
				if (shiftAnchorElement == null) shiftAnchorElement = anchor;
			} else if (ctrlHeld) {
				var idx: Int = selectedElements.indexOf(entry.element);
				if (idx >= 0) {
					selectedElements.splice(idx, 1);
					selectedElement = selectedElements.length > 0 ? selectedElements[selectedElements.length - 1] : null;
				} else {
					selectedElements.push(entry.element);
					selectedElement = entry.element;
				}
				shiftAnchorElement = entry.element;
			} else {
				selectedElement = entry.element;
				selectedElements = [entry.element];
				shiftAnchorElement = entry.element;
			}
			ElementEvents.elementSelected.emit(selectedElement);

			uiBase.hwnds[PanelHierarchy].redraws = 2;
			uiBase.hwnds[PanelProperties].redraws = 2;
		}

		// Start drag after threshold
		if (entry != null &&draggedItem == entry && uiBase.ui.inputDown && !isDragging) {
			var dx: Float = uiBase.ui.inputX - dragStartX;
			var dy: Float = uiBase.ui.inputY - dragStartY;

            if (Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD) {
				isDragging = true;
				uiBase.hwnds[PanelHierarchy].redraws = 2;
				uiBase.hwnds[PanelProperties].redraws = 2;
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
		var merged: Array<Element> = selectedElements.copy();
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

		var siblings: Array<Element> = getVisibleHierarchyChildren(anchorParent);
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

		var children: Array<Element> = getVisibleHierarchyChildren(element);
		if (children.length == 0) return;

		var isExpanded: Bool = expanded.exists(element) ? expanded.get(element) : true;
		if (!isExpanded) return;

		for (child in children) {
			collectVisibleElements(child, out, false);
		}
	}

	function getVisibleHierarchyChildren(parent: Element): Array<Element> {
		var currentScene = sceneData.currentScene;
		if (currentScene == null || parent == null) return [];

		var children: Array<Element> = [];
		var allChildren: Array<Element> = HierarchyUtils.getChildren(parent);
		for (child in allChildren) {
			for (entry in currentScene.elements) {
				if (entry.element == child) {
					children.push(child);
					break;
				}
			}
		}
		return children;
	}

    function drawDragGhost(uiBase: UIBase) {
		if (!isDragging || draggedItem == null) return;

		var winX: Float = uiBase.ui._windowX;
		var winY: Float = uiBase.ui._windowY;

		var ghostX: Float = uiBase.ui.inputX - winX - GHOST_OFFSET;
		var ghostY: Float = uiBase.ui.inputY - winY - GHOST_OFFSET;
		var ghostH: Int = uiBase.ui.t.ELEMENT_H;

		uiBase.ui.g.color = 0xDD222222;
		uiBase.ui.g.fillRect(ghostX, ghostY, GHOST_WIDTH, ghostH);

		uiBase.ui.g.color = 0xFF469CFF;
		uiBase.ui.g.drawRect(ghostX, ghostY, GHOST_WIDTH, ghostH, 2);

		uiBase.ui.g.color = 0xFFFFFFFF;
		uiBase.ui.g.font = uiBase.ui.ops.font;
		var dragCount: Int = (selectedElements.length > 1 && selectedElements.indexOf(draggedItem.element) >= 0) ? selectedElements.length : 1;
		var dragLabel: String = dragCount > 1 ? '${draggedItem.key} (+${dragCount - 1})' : draggedItem.key;
		uiBase.ui.g.drawString(dragLabel, ghostX + 8, ghostY + 4);

		uiBase.hwnds[PanelHierarchy].redraws = 2;
		uiBase.hwnds[PanelProperties].redraws = 2;
	}

	function handleDragEnd(uiBase:UIBase) {
		if (!uiBase.ui.inputReleased || !isDragging) return;

		if (dropTargetElement != null && dropZone != None) {
			performDrop();
		}

		// Select the dragged element when the drag ends
		if (draggedItem != null) {
			var ctrlHeld: Bool = Input.getKeyboard().down("control");
			var wasMultiSelected: Bool = selectedElements.length > 1 && selectedElements.indexOf(draggedItem.element) >= 0;
			if (ctrlHeld) {
				if (selectedElements.indexOf(draggedItem.element) < 0) {
					selectedElements.push(draggedItem.element);
				}
				selectedElement = draggedItem.element;
			} else if (wasMultiSelected) {
				// Keep the full multi-selection after dropping multiple selected elements.
				selectedElement = draggedItem.element;
			} else {
				selectedElement = draggedItem.element;
				selectedElements = [draggedItem.element];
			}
			ElementEvents.elementSelected.emit(selectedElement);
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

		uiBase.hwnds[PanelHierarchy].redraws = 2;
		uiBase.hwnds[PanelProperties].redraws = 2;
	}

	function performDrop() {
		if (draggedItem == null || dropTargetElement == null || dropZone == None) return;

		// Determine which elements to drop
		var isMulti: Bool = selectedElements.length > 1 && selectedElements.indexOf(draggedItem.element) >= 0;
		var elemsToDrop: Array<Element> = isMulti ? selectedElements.copy() : [draggedItem.element];

		// Filter out the target itself and any ancestor of the target
		elemsToDrop = elemsToDrop.filter(e -> e != dropTargetElement && !HierarchyUtils.isDescendant(dropTargetElement, e));
		if (elemsToDrop.length == 0) return;

		// Sort by scene order so relative order is preserved
		var sceneElements = sceneData.currentScene.elements;
		elemsToDrop.sort(function(a, b) {
			var ia = -1; var ib = -1;
			for (i in 0...sceneElements.length) {
				if (sceneElements[i].element == a) ia = i;
				if (sceneElements[i].element == b) ib = i;
			}
			return ia - ib;
		});

		// For BeforeSibling: normal order → each inserts before target, pushing earlier ones ahead
		// For AfterSibling:  reverse order → each inserts after target, pulling earlier ones forward
		// For AsChild: order doesn't matter
		if (dropZone == AfterSibling) elemsToDrop.reverse();

		for (elem in elemsToDrop) {
			ElementEvents.elementDropped.emit(elem, dropTargetElement, dropZone);
		}
	}

    function registerChildren(parent: Element): Void {
        var children: Array<Element> = HierarchyUtils.getChildren(parent);

        if (children != null && children.length > 0) {
            expanded.set(parent, false);
        }

        for (child in children) {
            // Skip internal children (e.g., Button's _label)
            if (HierarchyUtils.shouldSkipInternalChild(parent, child)) {
                continue;
            }

            // Recursively register expand state for nested children
            registerChildren(child);
        }
    }

    public function onElementSelected(element: Element): Void {
        selectedElement = element;
		if (element == null) {
			selectedElements = [];
			shiftAnchorElement = null;
		} else if (selectedElements.indexOf(element) < 0) {
			// External selection (e.g. canvas click) — reset to single
			selectedElements = [element];
			shiftAnchorElement = element;
		}
		if (selectedElement == null) draggedItem = null;
    }

    public function onElementAdded(entry: TElementEntry): Void {
		if (entry.element == sceneData.currentScene.root) return;
        onElementSelected(entry.element);
        registerChildren(entry.element);
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