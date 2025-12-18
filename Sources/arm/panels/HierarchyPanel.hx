package arm.panels;

import arm.data.SceneData;
import arm.events.ElementEvents;
import arm.events.SceneEvents;
import arm.base.UIBase;
import arm.tools.HierarchyUtils;
import arm.tools.NameUtils;
import arm.tools.ZuiUtils;
import arm.types.Enums;
import haxe.ds.ObjectMap;
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

	// Scene management
	 var sceneTabHandle: Handle;
	var sceneTabs: Array<String> = [];
	var sceneCounter: Int = 1;

	var sceneData: SceneData = SceneData.data;

	// Expand/collapse state - keyed by element reference
	var expanded: ObjectMap<Element, Bool> = new ObjectMap();

	// Drag-drop state - use Element references instead of indices
    var selectedElement: Element = null;
	var draggedItem: THierarchyEntry = null;
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
		SceneEvents.sceneChanged.connect(onSceneChanged);
		SceneEvents.sceneRemoved.connect(onSceneRemoved);
		SceneEvents.sceneAdded.connect(onSceneAdded);

		// Initialize tabs from existing scenes
		if (sceneData.scenes.length > 0) {
			for (scene in sceneData.scenes) {
				sceneTabs.push(scene.key);
			}
			// set combo to currentScene if present
			if (sceneData.currentScene != null) {
				var idx = sceneTabs.indexOf(sceneData.currentScene.key);
				sceneTabHandle.position = idx >= 0 ? idx : 0;
			} else {
				sceneTabHandle.position = 0;
			}
		}
	}

	public function draw(uiBase: UIBase, params: Dynamic): Void {
		if (uiBase.ui.window(uiBase.hwnds[PanelHierarchy], params.tabx, 0, params.w, params.h0)) {
			// Ensure tabs have at least the current scene
			if (sceneTabs.length == 0 && sceneData.currentScene != null) {
				sceneTabs.push(sceneData.currentScene.key);
				sceneTabHandle.position = 0;
			}
			drawSceneSelector(uiBase);
			uiBase.ui.separator();

            // Draw root element (only if currentScene exists)
            if (sceneData.currentScene != null) {
                drawItem(uiBase, { key: sceneData.currentScene.key, element: sceneData.currentScene.root }, 0);
            }
		}

		drawDragGhost(uiBase);
		handleDragEnd(uiBase);
	}

	function drawSceneSelector(uiBase: UIBase) {
		uiBase.ui.row([0.7, 0.15, 0.15]);

		sceneTabHandle.position = uiBase.ui.combo(sceneTabHandle, sceneTabs, "", true);

		if (sceneTabHandle.changed) {
			var sceneName: String = sceneTabs[sceneTabHandle.position];
			SceneEvents.sceneChanged.emit(sceneName);
		}

		if (ZuiUtils.iconButton(uiBase.ui, icons, 1, 2, "Add Scene", false, false, 0.4)) {
			var newSceneName = NameUtils.generateUniqueName("Scene", sceneTabs);
			sceneTabs.push(newSceneName);
			sceneTabHandle.position = sceneTabs.length - 1;
			SceneEvents.sceneAdded.emit(newSceneName);
		}

		if (ZuiUtils.iconButton(uiBase.ui, icons, 1, 3, "Delete Scene", false, sceneTabs.length <= 1, 0.4)) {
			var idx: Int = sceneTabHandle.position;
			var sceneName: String = sceneTabs[idx];
			sceneTabs.splice(idx, 1);
			if (idx >= sceneTabs.length) {
				sceneTabHandle.position = sceneTabs.length - 1;
			}
			SceneEvents.sceneRemoved.emit(sceneName);
		}
	}

	function onSceneAdded(sceneName: String): Void {
		if (!sceneTabs.contains(sceneName)) {
			sceneTabs.push(sceneName);
		}
		sceneTabHandle.position = sceneTabs.indexOf(sceneName);
	}

	function onSceneRemoved(sceneName: String): Void {
		var idx = sceneTabs.indexOf(sceneName);
		if (idx >= 0) {
			sceneTabs.splice(idx, 1);
			if (sceneTabHandle.position >= sceneTabs.length) {
				sceneTabHandle.position = Std.int(Math.max(0, sceneTabs.length - 1));
			}
		}
	}

	function onSceneChanged(sceneName: String): Void {
		var idx = sceneTabs.indexOf(sceneName);
		if (idx == -1) {
			sceneTabs.push(sceneName);
			idx = sceneTabs.length - 1;
		}
		sceneTabHandle.position = idx;
	}

	function drawItem(uiBase: UIBase, entry: THierarchyEntry, depth: Int) {
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
				uiBase.ui.row([indentWidth / winW, EXPAND_BUTTON_WIDTH / winW, 0.8 - (indentWidth * 0.5 + EXPAND_BUTTON_WIDTH) / winW, 0.2 - (indentWidth * 0.5 + EXPAND_BUTTON_WIDTH) / winW]); // TODO: needs testing for nested children
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
				sceneTabs[currentIdx] = newName;
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
			var deleteClicked = ZuiUtils.iconButton(uiBase.ui, icons, 1, 3, "Delete", false, deleteDisabled, 0.4);
			if (deleteClicked) {
				ElementEvents.elementRemoved.emit(entry.element);
			}
			uiBase.ui._y += 4;
		}

		handleDropDetection(uiBase, entry, winX, winY, localX, localY, winW, rowH);

		// Recursively draw children
		if (hasChildren && isExpanded) {
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
		var isSelected: Bool = selectedElement == element;

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

	function handleItemInteraction(uiBase: UIBase, entry: THierarchyEntry) {
		var isRoot: Bool = sceneData.currentScene.root != null && entry.element == sceneData.currentScene.root;

		// Selection on click start
		if (uiBase.ui.isPushed) {
			if (entry.element == sceneData.currentScene.root) return;
            selectedElement = entry.element;
			ElementEvents.elementSelected.emit(entry.element);

			// Only allow dragging non-root elements
			if (!isRoot) {
				draggedItem = entry;
				dragStartX = uiBase.ui.inputX;
				dragStartY = uiBase.ui.inputY;
			}

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
		uiBase.ui.g.drawString(draggedItem.key, ghostX + 8, ghostY + 4);

		uiBase.hwnds[PanelHierarchy].redraws = 2;
		uiBase.hwnds[PanelProperties].redraws = 2;
	}

	function handleDragEnd(uiBase:UIBase) {
		if (!uiBase.ui.inputReleased || !isDragging) return;

		if (dropTargetElement != null && dropZone != None) {
			performDrop();
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

	function handleDropDetection(uiBase: UIBase, item: THierarchyEntry, winX: Float, winY: Float, localX: Float, localY: Float, winW: Float, rowH: Float) {
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
		if (draggedItem.element == dropTargetElement) return;
		ElementEvents.elementDropped.emit(draggedItem.element, dropTargetElement, dropZone);
	}

    function registerChildren(parent: Element): Void {
        var children: Array<Element> = HierarchyUtils.getChildren(parent);

        if (children != null &&children.length > 0) {
            expanded.set(parent, false);
        }

        for (child in children) {
            // Skip internal children (e.g., Button's _label)
            if (HierarchyUtils.shouldSkipInternalChild(parent, child)) {
                continue;
            }

            // Generate a key based on the class name, then add via centralized data
            var childKey: String = Type.getClassName(Type.getClass(child)).split(".").pop();
            ElementEvents.elementAdded.emit({ key: childKey, element: child });
            registerChildren(child);
        }
    }

    public function onElementSelected(element: Element): Void {
        selectedElement = element;
		if (selectedElement == null) draggedItem = null;
    }

    public function onElementAdded(entry: THierarchyEntry): Void {
		if (entry.element == sceneData.currentScene.root) return;
        onElementSelected(entry.element);
        registerChildren(entry.element);
    }

    public function setIcons(iconsImage: Image): Void {
        icons = iconsImage;
    }
}