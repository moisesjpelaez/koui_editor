package arm.panels;

import arm.Enums;
import arm.UIBase;
import arm.KouiEditor;
import zui.Zui.Handle;

enum DropZone {
	None;
	BeforeSibling;
	AsChild;
	AfterSibling;
}

class HierarchyPanel {
	// Layout constants
	static inline var INDENT_PER_DEPTH:Int = 15;
	static inline var EXPAND_BUTTON_WIDTH:Int = 25;
	static inline var DRAG_THRESHOLD:Float = 5.0;
	static inline var DROP_ZONE_TOP:Float = 0.25;
	static inline var DROP_ZONE_BOTTOM:Float = 0.75;
	static inline var GHOST_WIDTH:Float = 150;
	static inline var GHOST_OFFSET:Float = 10;

	// Scene management
	var sceneTabHandle:Handle;
	var sceneTabs:Array<String> = ["Scene"];
	var sceneCounter:Int = 1;

	// Expand/collapse state
	var expanded:Map<Int, Bool> = new Map();

	// Drag-drop state
	var draggedIndex:Int = -1;
	var dropTargetIndex:Int = -1;
	var dropZone:DropZone = None;
	var isDragging:Bool = false;
	var dragStartX:Float = 0;
	var dragStartY:Float = 0;

	public function new() {
		sceneTabHandle = new Handle();
	}

	public function draw(uiBase:UIBase, params:Dynamic):Void {
		var ui = uiBase.ui;

		if (ui.window(uiBase.hwnds[PanelHierarchy], params.tabx, 0, params.w, params.h0)) {
			drawSceneSelector(uiBase);
			ui.separator();
			if (KouiEditor.elements.length > 0) {
				drawItem(uiBase, 0, 0);
			}
		}

		drawDragGhost(uiBase);
		handleDragEnd(uiBase);
	}

	function drawSceneSelector(uiBase:UIBase) {
		var ui = uiBase.ui;
		ui.row([0.7, 0.15, 0.15]);

		sceneTabHandle.position = ui.combo(sceneTabHandle, sceneTabs, "", true);

		if (ui.button("+")) {
			sceneCounter++;
			sceneTabs.push("Scene " + sceneCounter);
			sceneTabHandle.position = sceneTabs.length - 1;
		}

		if (ui.button("-") && sceneTabs.length > 1) {
			var idx = sceneTabHandle.position;
			sceneTabs.splice(idx, 1);
			if (idx >= sceneTabs.length) {
				sceneTabHandle.position = sceneTabs.length - 1;
			}
		}
	}

	function drawDragGhost(uiBase:UIBase) {
		if (!isDragging || draggedIndex < 0 || draggedIndex >= KouiEditor.elements.length) return;

		var ui = uiBase.ui;
		var winX = @:privateAccess ui._windowX;
		var winY = @:privateAccess ui._windowY;

		var ghostX = ui.inputX - winX - GHOST_OFFSET;
		var ghostY = ui.inputY - winY - GHOST_OFFSET;
		var ghostH = ui.t.ELEMENT_H;

		ui.g.color = 0xDD222222;
		ui.g.fillRect(ghostX, ghostY, GHOST_WIDTH, ghostH);

		ui.g.color = 0xFF469CFF;
		ui.g.drawRect(ghostX, ghostY, GHOST_WIDTH, ghostH, 2);

		ui.g.color = 0xFFFFFFFF;
		ui.g.font = ui.ops.font;
		ui.g.drawString(KouiEditor.elements[draggedIndex].name, ghostX + 8, ghostY + 4);

		uiBase.hwnds[PanelHierarchy].redraws = 2;
	}

	function handleDragEnd(uiBase:UIBase) {
		if (!uiBase.ui.inputReleased || !isDragging) return;

		if (dropTargetIndex != -1 && dropZone != None) {
			performDrop();
		}

		resetDragState();
		uiBase.hwnds[PanelHierarchy].redraws = 3;
	}

	function resetDragState() {
		isDragging = false;
		draggedIndex = -1;
		dropTargetIndex = -1;
		dropZone = None;
	}

	function drawItem(uiBase:UIBase, itemIndex:Int, depth:Int) {
		if (itemIndex < 0 || itemIndex >= KouiEditor.elements.length) return;

		var ui = uiBase.ui;
		var entry = KouiEditor.elements[itemIndex];
		var hasChildren = entry.children.length > 0;
		var isExpanded = expanded.exists(itemIndex) ? expanded.get(itemIndex) : true;

		// Cache window coordinates
		var winX = @:privateAccess ui._windowX;
		var winY = @:privateAccess ui._windowY;
		var winW = @:privateAccess ui._windowW;
		var localX = @:privateAccess ui._x;
		var localY = @:privateAccess ui._y;
		var rowH = ui.t.ELEMENT_H;
		var indentWidth = depth * INDENT_PER_DEPTH;

		// Draw drop zone indicator
		drawDropIndicator(ui, itemIndex, localX, localY, winW, rowH, indentWidth);

		// Row layout
		if (hasChildren) {
			ui.row([indentWidth / winW, EXPAND_BUTTON_WIDTH / winW, 1]);
		} else {
			ui.row([indentWidth / winW, 1]);
		}

		ui.text(""); // Indent spacer

		// Expand/collapse button
		if (hasChildren && ui.button(isExpanded ? "v" : ">")) {
			expanded.set(itemIndex, !isExpanded);
		}

		// Item button with selection highlighting
		drawItemButton(ui, entry.name, itemIndex);

		// Handle interactions
		handleItemInteraction(uiBase, ui, itemIndex);
		handleDropDetection(ui, uiBase, itemIndex, winX, winY, localX, localY, winW, rowH);

		// Recursively draw children
		if (hasChildren && isExpanded) {
			for (childIndex in entry.children) {
				drawItem(uiBase, childIndex, depth + 1);
			}
		}
	}

	function drawDropIndicator(ui:zui.Zui, itemIndex:Int, x:Float, y:Float, w:Float, h:Float, indent:Float) {
		if (!isDragging || dropTargetIndex != itemIndex || dropZone == None) return;

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

	function drawItemButton(ui:zui.Zui, name:String, itemIndex:Int) {
		var isSelected = KouiEditor.selectedElement == KouiEditor.elements[itemIndex].element;

		// Save theme colors
		var savedCol = ui.t.BUTTON_COL;
		var savedHover = ui.t.BUTTON_HOVER_COL;
		var savedPressed = ui.t.BUTTON_PRESSED_COL;

		if (isSelected) {
			ui.t.BUTTON_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_HOVER_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_PRESSED_COL = ui.t.HIGHLIGHT_COL;
		}

		ui.button(name, Left);

		// Restore theme colors
		ui.t.BUTTON_COL = savedCol;
		ui.t.BUTTON_HOVER_COL = savedHover;
		ui.t.BUTTON_PRESSED_COL = savedPressed;
	}

	function handleItemInteraction(uiBase:UIBase, ui:zui.Zui, itemIndex:Int) {
		// Selection on click start
		if (ui.isPushed) {
			KouiEditor.selectedElement = KouiEditor.elements[itemIndex].element;

			// Only allow dragging non-root elements
			if (itemIndex != 0) {
				draggedIndex = itemIndex;
				dragStartX = ui.inputX;
				dragStartY = ui.inputY;
			}
			uiBase.hwnds[PanelHierarchy].redraws = 2;
		}

		// Start drag after threshold
		if (draggedIndex == itemIndex && ui.inputDown && !isDragging && KouiEditor.selectedElement != null) {
			var dx = ui.inputX - dragStartX;
			var dy = ui.inputY - dragStartY;
			if (Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD) {
				isDragging = true;
				uiBase.hwnds[PanelHierarchy].redraws = 2;
			}
		}
	}

	function handleDropDetection(ui:zui.Zui, uiBase:UIBase, itemIndex:Int, winX:Float, winY:Float, localX:Float, localY:Float, winW:Float, rowH:Float) {
		if (!isDragging || draggedIndex == -1 || draggedIndex == itemIndex) return;

		var absX = winX + localX;
		var absY = winY + localY;

		var inBounds = ui.inputX >= absX && ui.inputX <= absX + winW && ui.inputY >= absY && ui.inputY <= absY + rowH;

		if (!inBounds || isDescendant(itemIndex, draggedIndex)) return;

		dropTargetIndex = itemIndex;

		var ratio = (ui.inputY - absY) / rowH;
		if (ratio < DROP_ZONE_TOP) {
			dropZone = BeforeSibling;
		} else if (ratio > DROP_ZONE_BOTTOM) {
			dropZone = AfterSibling;
		} else {
			dropZone = AsChild;
		}

		uiBase.hwnds[PanelHierarchy].redraws = 2;
	}

	function performDrop() {
		if (draggedIndex == -1 || dropTargetIndex == -1 || dropZone == None) return;
		if (draggedIndex == dropTargetIndex) return;

		// Find current parent of dragged item
		var oldParentIndex = KouiEditor.findParent(draggedIndex);
		var targetParentIndex = KouiEditor.findParent(dropTargetIndex);

		// Remove from old parent
		if (oldParentIndex != -1) {
			KouiEditor.elements[oldParentIndex].children.remove(draggedIndex);
		}

		switch (dropZone) {
			case AsChild:
				KouiEditor.elements[dropTargetIndex].children.push(draggedIndex);
				expanded.set(dropTargetIndex, true);

			case BeforeSibling:
				insertAsSibling(targetParentIndex, dropTargetIndex, draggedIndex, 0);

			case AfterSibling:
				insertAsSibling(targetParentIndex, dropTargetIndex, draggedIndex, 1);

			case None:
		}
	}

	function insertAsSibling(parentIndex:Int, targetIndex:Int, draggedIdx:Int, offset:Int) {
		if (parentIndex != -1) {
			var children = KouiEditor.elements[parentIndex].children;
			var pos = children.indexOf(targetIndex);
			if (pos != -1) {
				children.insert(pos + offset, draggedIdx);
			}
		} else if (targetIndex == 0) {
			// Target is root - add as child instead
			var rootChildren = KouiEditor.elements[0].children;
			if (offset == 0) {
				rootChildren.insert(0, draggedIdx);
			} else {
				rootChildren.push(draggedIdx);
			}
		}
	}

	function isDescendant(targetIndex:Int, ancestorIndex:Int):Bool {
		var current = targetIndex;
		while (current != -1) {
			current = KouiEditor.findParent(current);
			if (current == ancestorIndex) return true;
		}
		return false;
	}
}