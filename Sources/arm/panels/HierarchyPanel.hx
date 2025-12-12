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
	var isDragging: Bool = false;
	var dragStartX: Float = 0;
	var dragStartY: Float = 0;
	var dragOffsetX: Float = 0;
	var dragOffsetY: Float = 0;

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

			// Draw dragged item ghost (floating rect)
			if (isDragging && draggedItemIndex != -1) {
				var draggedItem = items[draggedItemIndex];
				var ghostX = uiBase.ui.inputX + dragOffsetX;
				var ghostY = uiBase.ui.inputY + dragOffsetY;
				var ghostW = 200;
				var ghostH = uiBase.ui.t.ELEMENT_H;

				// Semi-transparent background
				uiBase.ui.g.color = 0xAA1B1B1B;
				uiBase.ui.g.fillRect(ghostX, ghostY, ghostW, ghostH);

				// Border
				uiBase.ui.g.color = 0xFF469CFF;
				uiBase.ui.g.drawRect(ghostX, ghostY, ghostW, ghostH, 1);

				// Text
				uiBase.ui.g.color = 0xFFFFFFFF;
				uiBase.ui.g.font = uiBase.ui.ops.font;
				uiBase.ui.g.drawString(draggedItem.name, ghostX + 5, ghostY + 5);

				uiBase.hwnds[PanelTop].redraws = 2;
			}
		}

		// Handle drop when mouse released (outside window block to catch all releases)
		if (uiBase.ui.inputReleased && isDragging) {
			if (dropTargetIndex != -1 && dropZone != None) {
				performDrop();
			}
			isDragging = false;
			draggedItemIndex = -1;
			dropTargetIndex = -1;
			dropZone = None;
			uiBase.hwnds[PanelTop].redraws = 3;
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

		// Visual feedback: show drop indicator on target
		if (isDragging && dropTargetIndex == itemIndex && dropZone != None) {
			ui.g.color = 0xFF469CFF;
			switch (dropZone) {
				case BeforeSibling:
					// Blue line at top
					ui.g.fillRect(@:privateAccess ui._x + indentWidth, rowY, @:privateAccess ui._windowW - indentWidth, 2);
				case AfterSibling:
					// Blue line at bottom
					ui.g.fillRect(@:privateAccess ui._x + indentWidth, rowY + rowH - 2, @:privateAccess ui._windowW - indentWidth, 2);
				case AsChild:
					// Blue box outline indicating it will become a child
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

		// Item name button with selection visual feedback
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

		// Handle button press: start selection and potential drag
		if (buttonPressed) {
			selectedItemIndex = itemIndex;
			draggedItemIndex = itemIndex;
			dragStartX = ui.inputX;
			dragStartY = ui.inputY;
			// Calculate offset: where the element's top-left is relative to cursor
			var elementAbsX = @:privateAccess ui._windowX + @:privateAccess ui._x;
			var elementAbsY = @:privateAccess ui._windowY + rowY;
			dragOffsetX = elementAbsX - ui.inputX;
			dragOffsetY = elementAbsY - ui.inputY;
			uiBase.hwnds[PanelTop].redraws = 2;
		}

		// Convert selection to drag if mouse moved enough while button down
		if (draggedItemIndex == itemIndex && ui.inputDown && !isDragging) {
			var dx = ui.inputX - dragStartX;
			var dy = ui.inputY - dragStartY;
			var distance = Math.sqrt(dx * dx + dy * dy);
			if (distance > 3) {
				isDragging = true;
				uiBase.hwnds[PanelTop].redraws = 2;
			}
		}

		// Detect drop target while dragging over items
		if (isDragging && draggedItemIndex != -1 && draggedItemIndex != itemIndex) {
			var winX = @:privateAccess ui._windowX + @:privateAccess ui._x;
			var winY = @:privateAccess ui._windowY + rowY;
			var winW = @:privateAccess ui._windowW;

			if (ui.inputX > winX && ui.inputX < winX + winW &&
			    ui.inputY > winY && ui.inputY < winY + rowH) {

				if (!isDescendant(itemIndex, draggedItemIndex)) {
					dropTargetIndex = itemIndex;

					// Determine drop zone based on Y position within row
					var relY = ui.inputY - winY;
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
		if (draggedItemIndex == dropTargetIndex) return; // Can't drop on self

		var draggedItem = items[draggedItemIndex];
		var targetItem = items[dropTargetIndex];

		trace('Dropping "${draggedItem.name}" onto "${targetItem.name}" as ${dropZone}');

		// Find the target's parent BEFORE any modifications
		var targetParentIndex = findParent(dropTargetIndex);

		// Find and remove dragged item from its current parent
		var oldParentIndex = findParent(draggedItemIndex);
		if (oldParentIndex != -1) {
			items[oldParentIndex].children.remove(draggedItemIndex);
		}

		// Perform the drop based on zone
		switch (dropZone) {
			case AsChild:
				// Add as last child of target
				targetItem.children.push(draggedItemIndex);
				// Auto-expand target to show the new child
				expanded.set(targetItem.id, true);

			case BeforeSibling:
				// Insert before target in parent's children array
				if (targetParentIndex != -1) {
					var parent = items[targetParentIndex];
					var targetPos = parent.children.indexOf(dropTargetIndex);
					if (targetPos != -1) {
						parent.children.insert(targetPos, draggedItemIndex);
					}
				} else if (dropTargetIndex == 0) {
					// Target is root - can't insert before root, add as first child instead
					items[0].children.insert(0, draggedItemIndex);
				}

			case AfterSibling:
				// Insert after target in parent's children array
				if (targetParentIndex != -1) {
					var parent = items[targetParentIndex];
					var targetPos = parent.children.indexOf(dropTargetIndex);
					if (targetPos != -1) {
						parent.children.insert(targetPos + 1, draggedItemIndex);
					}
				} else if (dropTargetIndex == 0) {
					// Target is root - can't insert after root, add as last child instead
					items[0].children.push(draggedItemIndex);
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