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
    BeforeSibling;  // Top 25% of row
    AsChild;        // Middle 50% of row
    AfterSibling;   // Bottom 25% of row
}

class HierarchyPanel {
    var sceneTabHandle: Handle;
    var sceneTabs: Array<String> = ["Scene"];
	var sceneCounter: Int = 1;

	// Test hierarchy data (hardcoded)
	var items: Array<HierarchyItem> = [];

	// Expand/collapse state
	var expanded: Map<String, Bool> = new Map();

	// Selection state
	var selectedItemIndex: Int = -1;

	// Drag-drop state
	var draggedItemIndex: Int = -1;
	var dropTargetIndex: Int = -1;
	var dropZone: DropZone = None;

    public function new() {
        sceneTabHandle = new Handle();
		initializeTestData();
    }

	function initializeTestData() {
		// Create test hierarchy:
		// AnchorPane (root - index 0)
		//   ├─ Panel A (index 1)
		//   │   ├─ Button 1 (index 2)
		//   │   └─ Button 2 (index 3)
		//   ├─ Panel B (index 4)
		//   │   └─ Label 1 (index 5)
		//   └─ Label 2 (index 6)

		items = [
			{id: "anchorPane", name: "AnchorPane (Root)", children: [1, 4, 6]},  // 0
			{id: "panelA", name: "Panel A", children: [2, 3]},                    // 1
			{id: "button1", name: "Button 1", children: []},                      // 2
			{id: "button2", name: "Button 2", children: []},                      // 3
			{id: "panelB", name: "Panel B", children: [5]},                       // 4
			{id: "label1", name: "Label 1", children: []},                        // 5
			{id: "label2", name: "Label 2", children: []}                         // 6
		];

		// Default: all expanded
		for (item in items) {
			expanded.set(item.id, true);
		}
	}

    public function draw(uiBase: UIBase, params: Dynamic): Void {
        if (uiBase.ui.window(uiBase.hwnds[PanelTop], params.tabx, 0, params.w, params.h0)) {
			// Scene selector row: [Dropdown] [+] [x]
			uiBase.ui.row([0.7, 0.15, 0.15]);

			// Scene dropdown
			sceneTabHandle.position = uiBase.ui.combo(sceneTabHandle, sceneTabs, "", true);

			// Add scene button
			if (uiBase.ui.button("+")) {
				sceneCounter++;
				var newName = "Scene " + sceneCounter;
				sceneTabs.push(newName);
				sceneTabHandle.position = sceneTabs.length - 1;
			}

			// Delete scene button
			if (uiBase.ui.button("-")) {
				if (sceneTabs.length > 1) {
					var currentIndex = sceneTabHandle.position;
					if (currentIndex > 0) sceneTabHandle.position = currentIndex - 1;
					sceneTabs.splice(currentIndex, 1);
					if (sceneTabHandle.position >= sceneTabs.length) {
						sceneTabHandle.position = sceneTabs.length - 1;
					}
				}
			}

			uiBase.ui.separator();

			// Draw hierarchy tree starting from root (AnchorPane at index 0)
			drawItem(uiBase, 0, 0);

			// Handle drop when mouse released
			if (uiBase.ui.inputReleased && draggedItemIndex != -1) {
				if (dropTargetIndex != -1 && dropZone != None) {
					performDrop();
					uiBase.hwnds[PanelTop].redraws = 2;
				}
				draggedItemIndex = -1;
				dropTargetIndex = -1;
				dropZone = None;
			}
		}
    }

	function drawItem(uiBase: UIBase, itemIndex: Int, depth: Int) {
		var ui = uiBase.ui;
		var item = items[itemIndex];
		var hasChildren = item.children.length > 0;
		var isExpanded = expanded.get(item.id);

		// Calculate row position for drag-drop detection
		var rowY = @:privateAccess ui._y;
		var rowH = ui.t.ELEMENT_H;
		var indentWidth = depth * 15;

		// Visual feedback: highlight if selected
		if (selectedItemIndex == itemIndex) {
			ui.g.color = ui.t.HIGHLIGHT_COL;
			ui.g.fillRect(@:privateAccess ui._x, rowY, @:privateAccess ui._windowW, rowH);
			ui.g.color = 0xFFFFFFFF;
		}

		// Visual feedback: highlight drop zone
		if (dropTargetIndex == itemIndex && dropZone != None && draggedItemIndex != -1) {
			ui.g.color = 0xFF469CFF;
			switch (dropZone) {
				case BeforeSibling:
					// Blue line at top
					ui.g.fillRect(@:privateAccess ui._x + indentWidth, rowY, @:privateAccess ui._windowW - indentWidth, 2);
				case AfterSibling:
					// Blue line at bottom
					ui.g.fillRect(@:privateAccess ui._x + indentWidth, rowY + rowH - 2, @:privateAccess ui._windowW - indentWidth, 2);
				case AsChild:
					// Blue box outline
					ui.g.drawRect(@:privateAccess ui._x + indentWidth, rowY, @:privateAccess ui._windowW - indentWidth - 10, rowH, 2);
				case None:
			}
			ui.g.color = 0xFFFFFFFF;
		}

		// Row layout: [indent] [expand button if has children] [name]
		if (hasChildren) {
			ui.row([indentWidth / @:privateAccess ui._windowW, 25 / @:privateAccess ui._windowW, 1]);
		} else {
			ui.row([indentWidth / @:privateAccess ui._windowW, 1]);
		}

		// Indent spacer - always consume the indent column
		ui.text("");

		// Expand/collapse button
		if (hasChildren) {
			if (ui.button(isExpanded ? "v" : ">")) {
				expanded.set(item.id, !isExpanded);
			}
		}

		// Item name button - has hover/pressed states
		// Save button color and override if selected
		var savedButtonCol = ui.t.BUTTON_COL;
		var savedButtonHoverCol = ui.t.BUTTON_HOVER_COL;
		var savedButtonPressedCol = ui.t.BUTTON_PRESSED_COL;

		if (selectedItemIndex == itemIndex) {
			ui.t.BUTTON_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_HOVER_COL = ui.t.HIGHLIGHT_COL;
			ui.t.BUTTON_PRESSED_COL = ui.t.HIGHLIGHT_COL;
		}

		var buttonPressed = ui.button(item.name, Left);

		// Restore colors
		ui.t.BUTTON_COL = savedButtonCol;
		ui.t.BUTTON_HOVER_COL = savedButtonHoverCol;
		ui.t.BUTTON_PRESSED_COL = savedButtonPressedCol;

		// Handle selection on button press
		if (buttonPressed) {
			selectedItemIndex = itemIndex;
			draggedItemIndex = itemIndex;
			trace('Selected: ${item.name}');
			uiBase.hwnds[PanelTop].redraws = 2;
		}

		// Drag over (detect drop target and zone)
		if (draggedItemIndex != -1 && draggedItemIndex != itemIndex && ui.inputDown) {
			if (ui.inputX > @:privateAccess ui._x && ui.inputX < @:privateAccess ui._x + @:privateAccess ui._windowW &&
			    ui.inputY > rowY && ui.inputY < rowY + rowH) {

				// Check if this would create a circular reference
				if (!isDescendant(itemIndex, draggedItemIndex)) {
					dropTargetIndex = itemIndex;

					// Determine drop zone based on Y position within row
					var relY = ui.inputY - rowY;
					var ratio = relY / rowH;

					if (ratio < 0.25) {
						dropZone = BeforeSibling;
					} else if (ratio > 0.75) {
						dropZone = AfterSibling;
					} else {
						dropZone = AsChild;
					}

					uiBase.hwnds[PanelTop].redraws = 2;
				}
			}
		}

		// Draw children if expanded
		if (hasChildren && isExpanded) {
			for (childIndex in item.children) {
				drawItem(uiBase, childIndex, depth + 1);
			}
		}
	}

	function performDrop() {
		if (draggedItemIndex == -1 || dropTargetIndex == -1 || dropZone == None) return;

		var draggedItem = items[draggedItemIndex];
		var targetItem = items[dropTargetIndex];

		trace('Dropping "${draggedItem.name}" onto "${targetItem.name}" as ${dropZone}');

		// Find and remove dragged item from its current parent
		var oldParentIndex = findParent(draggedItemIndex);
		if (oldParentIndex != -1) {
			items[oldParentIndex].children.remove(draggedItemIndex);
		}

		// Perform the drop based on zone
		switch (dropZone) {
			case AsChild:
				// Add as child of target
				targetItem.children.push(draggedItemIndex);
				// Auto-expand target to show the new child
				expanded.set(targetItem.id, true);

			case BeforeSibling:
				// Insert before target in parent's children array
				var parentIndex = findParent(dropTargetIndex);
				if (parentIndex != -1) {
					var parent = items[parentIndex];
					var targetPos = parent.children.indexOf(dropTargetIndex);
					parent.children.insert(targetPos, draggedItemIndex);
				}

			case AfterSibling:
				// Insert after target in parent's children array
				var parentIndex = findParent(dropTargetIndex);
				if (parentIndex != -1) {
					var parent = items[parentIndex];
					var targetPos = parent.children.indexOf(dropTargetIndex);
					parent.children.insert(targetPos + 1, draggedItemIndex);
				}

			case None:
		}

		trace('New hierarchy:');
		printHierarchy(0, 0);
	}

	// Find the parent of an item (returns index or -1 if not found)
	function findParent(childIndex: Int): Int {
		for (i in 0...items.length) {
			if (items[i].children.indexOf(childIndex) != -1) {
				return i;
			}
		}
		return -1;
	}

	// Check if targetIndex is a descendant of ancestorIndex (prevents circular references)
	function isDescendant(targetIndex: Int, ancestorIndex: Int): Bool {
		var currentIndex = targetIndex;
		while (currentIndex != -1) {
			currentIndex = findParent(currentIndex);
			if (currentIndex == ancestorIndex) return true;
		}
		return false;
	}

	// Debug: print hierarchy to console
	function printHierarchy(itemIndex: Int, depth: Int) {
		var item = items[itemIndex];
		var indent = "";
		for (i in 0...depth) indent += "  ";
		trace('${indent}${item.name}');

		for (childIndex in item.children) {
			printHierarchy(childIndex, depth + 1);
		}
	}
}