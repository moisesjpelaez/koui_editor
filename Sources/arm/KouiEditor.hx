package arm;

import arm.Enums;
import iron.App;
import iron.Scene;
import kha.Assets;
import kha.graphics2.Graphics;
import kha.Color;
import zui.Id;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

import koui.Koui;
import koui.elements.Element;
import koui.elements.Button;
import koui.elements.Label;
import koui.elements.Panel;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;
import koui.utils.SceneManager;
import iron.system.Input;

import arm.panels.BottomPanel;
import arm.panels.HierarchyPanel;
import arm.panels.PropertiesPanel;
import arm.panels.ElementsPanel;

typedef HierarchyEntry = {
	var name:String;
	var element:Element;
	var children:Array<Int>;
}

class KouiEditor extends iron.Trait {
	var uiBase: UIBase;

	var anchorPane: AnchorPane;
	var sizeInit: Bool = false;

	// Created elements - single source of truth for hierarchy
	public static var elements:Array<HierarchyEntry> = [];
	public static var buttonsCount:Int = 0;
	public static var labelsCount:Int = 0;

	// Drag and drop state
	public static var selectedElement: Element = null;
	public static var draggedElement: Element = null;
	var dragOffsetX: Int = 0;
	var dragOffsetY: Int = 0;

	// Panels
	var bottomPanel: BottomPanel = new BottomPanel();
	var hierarchyPanel: HierarchyPanel = new HierarchyPanel();
	var propertiesPanel: PropertiesPanel = new PropertiesPanel();
	var elementsPanel: ElementsPanel = new ElementsPanel();

	public function new() {
		super();

		Assets.loadEverything(function() {
			// Initialize framework
			Base.font = Assets.fonts.font_default;
			Base.init();
			Base.resizing.connect(onResized);

			// Create UIBase with the loaded font
			uiBase = new UIBase(Assets.fonts.font_default);

			Koui.init(function() {
				Koui.setPadding(100, 100, 75, 75);
				anchorPane = new AnchorPane(0, 0, Std.int(App.w() * 0.85), Std.int(App.h() * 0.85));
				anchorPane.setTID("fixed_anchorpane");
				Koui.add(anchorPane, Anchor.MiddleCenter);
				elements.push({name: "AnchorPane", element: anchorPane, children: []});
			});

			App.onResize = onResized;
		});

		notifyOnUpdate(update);
		notifyOnRender2D(render2D);
	}

	function update() {
		if (uiBase == null) return;
		uiBase.update();
		updateDragAndDrop();

		var keyboard: Keyboard = Input.getKeyboard();
		if (keyboard.started("delete") && selectedElement != null && selectedElement != anchorPane) {
			var idx = findIndex(selectedElement);
			if (idx > 0) {
				anchorPane.remove(selectedElement);
				removeElement(idx);
				selectedElement = null;
				uiBase.hwnds[PanelHierarchy].redraws = 2;
			}
		}
	}

	function updateDragAndDrop() {
		var mouse: Mouse = Input.getMouse();

		if (mouse.started()) {
			var element: Element = Koui.getElementAtPosition(Std.int(mouse.x), Std.int(mouse.y));
			if (element != null && element != anchorPane) {
				if (element.parent is Button) selectedElement = element.parent;
				else selectedElement = element;
				draggedElement = selectedElement;
				dragOffsetX = Std.int(mouse.x - draggedElement.posX * Koui.uiScale);
				dragOffsetY = Std.int(mouse.y - draggedElement.posY * Koui.uiScale);
			} else {
				selectedElement = null;
				draggedElement = null;
			}
			uiBase.hwnds[PanelHierarchy].redraws = 2;
		} else if (mouse.down() && draggedElement != null) {
			draggedElement.setPosition(Std.int(mouse.x) - dragOffsetX, Std.int(mouse.y) - dragOffsetY);
			@:privateAccess draggedElement.invalidateElem();
		} else {
			if (draggedElement != null) {
				draggedElement.setPosition(Std.int(draggedElement.posX / Koui.uiScale), Std.int(draggedElement.posY / Koui.uiScale));
				@:privateAccess draggedElement.invalidateElem();
			}
			draggedElement = null;
			uiBase.hwnds[PanelHierarchy].redraws = 2;
		}
	}

	function drawRightPanels() {
		// Adjust heights if window was resized
		var tabx: Int = uiBase.getTabX();
		var w: Int = uiBase.getSidebarW();
		var h0: Int = uiBase.getSidebarH0();
		var h1: Int = uiBase.getSidebarH1();

		hierarchyPanel.draw(uiBase, {tabx: tabx, w: w, h0: h0});
		propertiesPanel.draw(uiBase, {tabx: tabx, h0: h0, w: w, h1: h1});
	}

	function drawAnchorPane(g2: Graphics) {
		// Draw border with g2 in screen coordinates using drawX/drawY
		if (anchorPane != null) {
			var thickness: Int = 1;
			g2.color = 0xffe7e7e7;

			var x: Int = @:privateAccess anchorPane.drawX;
			var y: Int = @:privateAccess anchorPane.drawY;
			var w: Int = @:privateAccess anchorPane.drawWidth;
			var h: Int = @:privateAccess anchorPane.drawHeight;

			g2.fillRect(x, y, w, thickness);
			g2.fillRect(x, y + h - thickness, w, thickness);
			g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
			g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
		}
	}

	function drawSelectedElement(g2: Graphics) {
		if (selectedElement != null && selectedElement != anchorPane) {
			var thickness: Int = 2;
			g2.color = 0xff469cff;

			var x: Int = draggedElement != selectedElement ? @:privateAccess selectedElement.drawX + @:privateAccess anchorPane.drawX : Std.int(@:privateAccess selectedElement.drawX / Koui.uiScale) + @:privateAccess anchorPane.drawX;
			var y: Int = draggedElement != selectedElement ? @:privateAccess selectedElement.drawY + @:privateAccess anchorPane.drawY : Std.int(@:privateAccess selectedElement.drawY / Koui.uiScale) + @:privateAccess anchorPane.drawY;
			var w: Int = @:privateAccess selectedElement.drawWidth;
			var h: Int = @:privateAccess selectedElement.drawHeight;

			g2.fillRect(x, y, w, thickness);
			g2.fillRect(x, y + h - thickness, w, thickness);
			g2.fillRect(x, y + thickness, thickness, h - thickness * 2);
			g2.fillRect(x + w - thickness, y + thickness, thickness, h - thickness * 2);
		}
	}

	function render2D(g2: Graphics) {
		if (uiBase == null) return;
		g2.end();

		Koui.render(g2);
		g2.begin(false);
		drawAnchorPane(g2);
		drawSelectedElement(g2);
		g2.end();

		uiBase.ui.begin(g2);
		uiBase.adjustHeightsToWindow();
		elementsPanel.draw(uiBase, anchorPane);
		drawRightPanels();
		bottomPanel.draw(uiBase);
		uiBase.ui.end();

		g2.begin(false);

		if (!sizeInit) {
			onResized();
			sizeInit = true;
		}
	}

	function onResized() {
		Koui.uiScale = (App.h() - uiBase.getBottomH()) / 576;
		@:privateAccess Koui.onResize(App.w() - uiBase.getSidebarW(), App.h() - uiBase.getBottomH());
		if (Scene.active != null && Scene.active.camera != null) {
			Scene.active.camera.buildProjection();
		}
	}

	// Helper functions for hierarchy management
	public static function addElement(name:String, element:Element, parentIndex:Int):Int {
		var newIndex = elements.length;
		elements.push({name: name, element: element, children: []});
		if (parentIndex >= 0 && parentIndex < elements.length) {
			elements[parentIndex].children.push(newIndex);
		}
		return newIndex;
	}

	public static function removeElement(index:Int):Void {
		if (index <= 0 || index >= elements.length) return;

		// Find parent and remove from its children
		for (i in 0...elements.length) {
			var children = elements[i].children;
			var pos = children.indexOf(index);
			if (pos != -1) {
				children.splice(pos, 1);
				break;
			}
		}

		// Recursively remove all descendants
		var toRemove = [index];
		var i = 0;
		while (i < toRemove.length) {
			var idx = toRemove[i];
			for (childIdx in elements[idx].children) {
				toRemove.push(childIdx);
			}
			i++;
		}

		// Sort descending to remove from end first (preserves indices)
		toRemove.sort(function(a, b) return b - a);
		for (idx in toRemove) {
			elements.splice(idx, 1);
			// Update all children indices that are greater than removed index
			for (entry in elements) {
				for (j in 0...entry.children.length) {
					if (entry.children[j] > idx) {
						entry.children[j]--;
					}
				}
			}
		}
	}

	public static function findParent(childIndex:Int):Int {
		for (i in 0...elements.length) {
			if (elements[i].children.indexOf(childIndex) != -1) {
				return i;
			}
		}
		return -1;
	}

	public static function findIndex(element:Element):Int {
		for (i in 0...elements.length) {
			if (elements[i].element == element) {
				return i;
			}
		}
		return -1;
	}
}
