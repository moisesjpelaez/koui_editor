package arm.panels;

import arm.Enums;
import arm.UIBase;
import zui.Zui.Handle;

typedef HierarchyItem = {
	var id: String;
	var name: String;
	var children: Array<Int>; // Indices to other items in the array
}

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

	// Hierarchy data
	var items:Array<HierarchyItem> = [];
	var expanded:Map<String, Bool> = new Map();

	// Selection state
	var selectedItemIndex:Int = -1;

	// Drag-drop state
	var draggedItemIndex:Int = -1;
	var dropTargetIndex:Int = -1;
	var dropZone:DropZone = None;
	var isDragging:Bool = false;
	var dragStartX:Float = 0;
	var dragStartY:Float = 0;

	public function new() {
		sceneTabHandle = new Handle();
		initializeTestData();
	}

	function initializeTestData() {
		items = [
			{id: "anchorPane", name: "AnchorPane (Root)", children: [1, 4, 6]},
			{id: "panelA", name: "Panel A", children: [2, 3]},
			{id: "button1", name: "Button 1", children: []},
			{id: "button2", name: "Button 2", children: []},
			{id: "panelB", name: "Panel B", children: [5]},
			{id: "label1", name: "Label 1", children: []},
			{id: "label2", name: "Label 2", children: []}
		];

		for (item in items) {
			expanded.set(item.id, true);
		}
	}

	public function draw(uiBase:UIBase, params:Dynamic):Void {
		var ui = uiBase.ui;

		if (ui.window(uiBase.hwnds[PanelTop], params.tabx, 0, params.w, params.h0)) {
			drawSceneSelector(uiBase);
			ui.separator();
			drawItem(uiBase, 0, 0);
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
		if (!isDragging || draggedItemIndex < 0 || draggedItemIndex >= items.length) return;

		var ui = uiBase.ui;
		var draggedItem = items[draggedItemIndex];
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
		ui.g.drawString(draggedItem.name, ghostX + 8, ghostY + 4);

		uiBase.hwnds[PanelTop].redraws = 2;
	}

	function handleDragEnd(uiBase:UIBase) {
		if (!uiBase.ui.inputReleased || !isDragging) return;

		if (dropTargetIndex != -1 && dropZone != None) {
			performDrop();
		}

		resetDragState();
		uiBase.hwnds[PanelTop].redraws = 3;
	}

	function resetDragState() {
		isDragging = false;
		draggedItemIndex = -1;
		dropTargetIndex = -1;
		dropZone = None;
	}

	function drawItem(uiBase:UIBase, itemIndex:Int, depth:Int) {
		var ui = uiBase.ui;
		var item = items[itemIndex];
		var hasChildren = item.children.length > 0;
		var isExpanded = expanded.get(item.id);

		// Cache window coordinates once
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
			expanded.set(item.id, !isExpanded);
		}

		// Item button with selection highlighting
		drawItemButton(ui, item, itemIndex);

		// Handle interactions
		handleItemInteraction(uiBase, ui, itemIndex, localY);
		handleDropDetection(ui, uiBase, itemIndex, winX, winY, localX, localY, winW, rowH);

		// Recursively draw children
		if (hasChildren && isExpanded) {
			for (childIndex in item.children) {
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

	function drawItemButton(ui:zui.Zui, item:HierarchyItem, itemIndex:Int) {
		var isSelected = selectedItemIndex == itemIndex;

		// Save theme colors
		var savedCol = ui.t.BUTTON_COL;
		var savedHover = ui.t.BUTTON_HOVER_COL;
		var savedPressed = ui.t.BUTTON_PRESSED_COL;

		if (isSelected) {
			ui.t.BUTTON_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_HOVER_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_PRESSED_COL = ui.t.HIGHLIGHT_COL;
		}

		ui.button(item.name, Left);

		// Restore theme colors
		ui.t.BUTTON_COL = savedCol;
		ui.t.BUTTON_HOVER_COL = savedHover;
		ui.t.BUTTON_PRESSED_COL = savedPressed;
	}

	function handleItemInteraction(uiBase:UIBase, ui:zui.Zui, itemIndex:Int, rowY:Float) {
		// Selection on click
		if (ui.isReleased) {
			selectedItemIndex = itemIndex;

			// Only allow dragging non-root items
			if (itemIndex != 0) {
				draggedItemIndex = itemIndex;
				dragStartX = ui.inputX;
				dragStartY = ui.inputY;
			}
			uiBase.hwnds[PanelTop].redraws = 2;
		}

		// Start drag after threshold
		if (draggedItemIndex == itemIndex && ui.inputDown && !isDragging) {
			var dx = ui.inputX - dragStartX;
			var dy = ui.inputY - dragStartY;
			if (Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD) {
				isDragging = true;
				uiBase.hwnds[PanelTop].redraws = 2;
			}
		}
	}

	function handleDropDetection(ui:zui.Zui, uiBase:UIBase, itemIndex:Int, winX:Float, winY:Float, localX:Float, localY:Float, winW:Float, rowH:Float) {
		if (!isDragging || draggedItemIndex == -1 || draggedItemIndex == itemIndex) return;

		var absX = winX + localX;
		var absY = winY + localY;

		var inBounds = ui.inputX >= absX && ui.inputX <= absX + winW && ui.inputY >= absY && ui.inputY <= absY + rowH;

		if (!inBounds || isDescendant(itemIndex, draggedItemIndex)) return;

		dropTargetIndex = itemIndex;

		var ratio = (ui.inputY - absY) / rowH;
		if (ratio < DROP_ZONE_TOP) {
			dropZone = BeforeSibling;
		} else if (ratio > DROP_ZONE_BOTTOM) {
			dropZone = AfterSibling;
		} else {
			dropZone = AsChild;
		}

		uiBase.hwnds[PanelTop].redraws = 2;
	}

	function performDrop() {
		if (draggedItemIndex == -1 || dropTargetIndex == -1 || dropZone == None) return;
		if (draggedItemIndex == dropTargetIndex) return;

		var targetItem = items[dropTargetIndex];

		// Find target's parent BEFORE any modifications
		var targetParentIndex = findParent(dropTargetIndex);

		// Remove dragged item from its current parent
		var oldParentIndex = findParent(draggedItemIndex);
		if (oldParentIndex != -1) {
			items[oldParentIndex].children.remove(draggedItemIndex);
		}

		switch (dropZone) {
			case AsChild:
				targetItem.children.push(draggedItemIndex);
				expanded.set(targetItem.id, true);

			case BeforeSibling:
				insertAsSibling(targetParentIndex, dropTargetIndex, draggedItemIndex, 0);

			case AfterSibling:
				insertAsSibling(targetParentIndex, dropTargetIndex, draggedItemIndex, 1);

			case None:
		}
	}

	function insertAsSibling(parentIndex:Int, targetIndex:Int, draggedIndex:Int, offset:Int) {
		if (parentIndex != -1) {
			var parent = items[parentIndex];
			var pos = parent.children.indexOf(targetIndex);
			if (pos != -1) {
				parent.children.insert(pos + offset, draggedIndex);
			}
		} else if (targetIndex == 0) {
			// Can't be sibling of root - add as child instead
			if (offset == 0) {
				items[0].children.insert(0, draggedIndex);
			} else {
				items[0].children.push(draggedIndex);
			}
		}
	}

	function findParent(childIndex:Int):Int {
		for (i in 0...items.length) {
			if (items[i].children.indexOf(childIndex) != -1) {
				return i;
			}
		}
		return -1;
	}

	function isDescendant(targetIndex:Int, ancestorIndex:Int):Bool {
		var current = targetIndex;
		while (current != -1) {
			current = findParent(current);
			if (current == ancestorIndex) return true;
		}
		return false;
	}
}