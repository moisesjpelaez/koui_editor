package arm.panels;

import arm.ElementData;
import arm.ElementEvents;
import arm.KouiEditor;
import arm.base.UIBase;
import arm.tools.HierarchyUtils;
import arm.types.Enums;
import haxe.ds.ObjectMap;
import koui.elements.Element;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

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
	var sceneTabs: Array<String> = ["Scene"];
	var sceneCounter: Int = 1;

    var elements: Array<THierarchyEntry> = [];

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

	public function new() {
        elements = ElementData.data.elements;
		sceneTabHandle = new Handle();

		ElementEvents.elementAdded.connect(onElementAdded);
		ElementEvents.elementSelected.connect(onElementSelected);
	}

	public function draw(uiBase: UIBase, params: Dynamic): Void {
		if (uiBase.ui.window(uiBase.hwnds[PanelHierarchy], params.tabx, 0, params.w, params.h0)) {
			drawSceneSelector(uiBase);
			uiBase.ui.separator();

            // Draw root element
            drawItem(uiBase, elements[0], 0);
		}

		drawDragGhost(uiBase);
		handleDragEnd(uiBase);
	}

	function drawSceneSelector(uiBase: UIBase) {
		uiBase.ui.row([0.7, 0.15, 0.15]);

		sceneTabHandle.position = uiBase.ui.combo(sceneTabHandle, sceneTabs, "", true);

		if (uiBase.ui.button("+")) {
			sceneCounter++;
			sceneTabs.push("Scene " + sceneCounter);
			sceneTabHandle.position = sceneTabs.length - 1;
		}

		if (uiBase.ui.button("-") && sceneTabs.length > 1) {
			var idx: Int = sceneTabHandle.position;
			sceneTabs.splice(idx, 1);
			if (idx >= sceneTabs.length) {
				sceneTabHandle.position = sceneTabs.length - 1;
			}
		}
	}

	function drawItem(uiBase: UIBase, entry: THierarchyEntry, depth: Int) {
		if (entry == null) return;

		var name: String = entry.key;
		// Only show children that are user-facing containers (not internal elements like Button's _label)
		var allChildren: Array<Element> = HierarchyUtils.getChildren(entry.element);
		var children: Array<Element> = [];
		for (child in allChildren) {
			// Include containers and elements that are in our elements list
			for (e in elements) {
				if (e.element == child) {
					children.push(child);
					break;
				}
			}
		}
		var hasChildren: Bool = children.length > 0;
		var isExpanded: Bool = expanded.exists(entry.element) ? expanded.get(entry.element) : true;

		// Cache window coordinates
		var winX: Float = @:privateAccess uiBase.ui._windowX;
		var winY: Float = @:privateAccess uiBase.ui._windowY;
		var winW: Float = @:privateAccess uiBase.ui._windowW;
		var localX: Float = @:privateAccess uiBase.ui._x;
		var localY: Float = @:privateAccess uiBase.ui._y;
		var rowH: Int = uiBase.ui.t.ELEMENT_H;
		var indentWidth: Int = depth * INDENT_PER_DEPTH;

		// Draw drop zone indicator
		drawDropIndicator(uiBase.ui, entry.element, localX, localY, winW, rowH, indentWidth);

		// Row layout
		if (hasChildren) {
			uiBase.ui.row([indentWidth / winW, EXPAND_BUTTON_WIDTH / winW, 1]);
		} else {
			uiBase.ui.row([indentWidth / winW, 1]);
		}

		uiBase.ui.text(""); // Indent spacer

		// Expand/collapse button
		if (hasChildren && uiBase.ui.button(isExpanded ? "v" : ">")) {
			expanded.set(entry.element, !isExpanded);
		}

		// Item button with selection highlighting
		drawItemButton(uiBase.ui, name, entry.element);

		// Handle interactions
		handleItemInteraction(uiBase, entry);
		handleDropDetection(uiBase, entry, winX, winY, localX, localY, winW, rowH);

		// Recursively draw children
		if (hasChildren && isExpanded) {
			for (child in children) {
                for (entry in elements) {
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
		var isRoot: Bool = elements.length > 0 && entry.element == elements[0].element;

		// Selection on click start
		if (uiBase.ui.isPushed) {
			if (entry.element == ElementData.root) return;
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

		var winX: Float = @:privateAccess uiBase.ui._windowX;
		var winY: Float = @:privateAccess uiBase.ui._windowY;

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
		if (entry.element == ElementData.root) return;
        onElementSelected(entry.element);
        registerChildren(entry.element);
    }
}