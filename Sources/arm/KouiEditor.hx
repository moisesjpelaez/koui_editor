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

class KouiEditor extends iron.Trait {
	var uiBase: UIBase;
	var themeTextHandle: Handle;
	var sceneTabHandle: Handle;
	var propertiesTabHandle: Handle;
	var themeTabHandle: Handle;

	// Main editing AnchorPane
	var anchorPane: AnchorPane;
	var button: Button;

	// Dynamic scene tabs
	var sceneTabs: Array<String> = ["Scene"];
	var sceneCounter: Int = 1;

	var sizeInit: Bool = false;

	var buttons: Map<String, Button> = new Map();
	var buttonsCount: Int = 0;
	var labels: Map<String, Label> = new Map();
	var labelsCount: Int = 0;

	// Drag and drop state
	var draggedElement: Element = null;
	var dragOffsetX: Int = 0; // offset from element's posX to mouse position (in unscaled layout coords)
	var dragOffsetY: Int = 0;

	public function new() {
		super();

		Assets.loadEverything(function() {
			// Initialize framework
			Base.font = Assets.fonts.font_default;
			Base.init();
			Base.resizing.connect(onResized);

			// Create UIBase with the loaded font
			uiBase = new UIBase(Assets.fonts.font_default);

			// Initialize handles
			themeTextHandle = new Handle();
			sceneTabHandle = new Handle();
			propertiesTabHandle = new Handle();
			themeTabHandle = new Handle();

			Koui.init(function() {
				Koui.setPadding(100, 100, 75, 75);

				anchorPane = new AnchorPane(0, 0, Std.int(App.w() * 0.85), Std.int(App.h() * 0.85));
				anchorPane.setTID("fixed_anchorpane");

				Koui.add(anchorPane, Anchor.MiddleCenter);
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
	}

	function updateDragAndDrop() {
		var mouse: Mouse = Input.getMouse();

		if (mouse.started()) {
			var element: Element = Koui.getElementAtPosition(Std.int(mouse.x), Std.int(mouse.y));
			if (element != null && element != anchorPane) {
				if (element.parent is Button) draggedElement = element.parent;
				else draggedElement = element;
				dragOffsetX = Std.int(mouse.x - draggedElement.posX * Koui.uiScale);
				dragOffsetY = Std.int(mouse.y - draggedElement.posY * Koui.uiScale);
			}
		} else if (mouse.down() && draggedElement != null) {
			draggedElement.setPosition(Std.int(mouse.x) - dragOffsetX, Std.int(mouse.y) - dragOffsetY);
			@:privateAccess draggedElement.invalidateElem();
		} else {
			if (draggedElement != null) {
				draggedElement.setPosition(Std.int(draggedElement.posX / Koui.uiScale), Std.int(draggedElement.posY / Koui.uiScale));
				@:privateAccess draggedElement.invalidateElem();
			}
			draggedElement = null;
		}
	}

	function drawElementsPanel() {
		// No background for this panel
		uiBase.ui.t.FILL_WINDOW_BG = false;
		if (uiBase.ui.window(Id.handle(), 10, 10, 100, App.h() - uiBase.getBottomH() - 20, false)) {
			if (uiBase.ui.panel(Id.handle({selected: true}), "Basic")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("Label")) {
					var key: String = "label_" + Std.string(labelsCount);
					var label: Label = new Label("New Label");
					labels.set(key, label);
					anchorPane.add(label, Anchor.TopLeft);
					labelsCount++;
				}

				if (uiBase.ui.button("Image Panel")) {
					trace("Image Panel");
				}

				if (uiBase.ui.button("Panel")) {
					trace("Panel");
				}

				uiBase.ui.unindent();
			}

			if (uiBase.ui.panel(Id.handle({selected: true}), "Buttons")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("Button")) {
					var key: String = "button_" + Std.string(buttonsCount);
					var button: Button = new Button("New Button");
					buttons.set(key, button);
					anchorPane.add(button, Anchor.TopLeft);
					buttonsCount++;
				}

				if (uiBase.ui.button("Checkbox")) {
					trace("Checkbox");
				}

				if (uiBase.ui.button("Radio")) {
					trace("Radio");
				}

				uiBase.ui.unindent();
			}

			if (uiBase.ui.panel(Id.handle({selected: true}), "Layout")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("AnchorPane")) {
					trace("AnchorPane");
				}

				if (uiBase.ui.button("GridLayout")) {
					trace("GridLayout");
				}

				if (uiBase.ui.button("ColLayout")) {
					trace("ColLayout");
				}

				if (uiBase.ui.button("RowLayout")) {
					trace("RowLayout");
				}

				if (uiBase.ui.button("Expander")) {
					trace("Expander");
				}

				uiBase.ui.unindent();
			}
		}
		// Restore background for other panels
		uiBase.ui.t.FILL_WINDOW_BG = true;
	}

	function drawRightPanels() {
		// Adjust heights if window was resized
		uiBase.adjustHeightsToWindow();

		var tabx: Int = uiBase.getTabX();
		var w: Int = uiBase.getSidebarW();
		var h0: Int = uiBase.getSidebarH0();
		var h1: Int = uiBase.getSidebarH1();

		// Top panel - Scene selector
		if (uiBase.ui.window(uiBase.hwnds[PanelTop], tabx, 0, w, h0)) {
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

			uiBase.ui.text('Editing: ${sceneTabs[sceneTabHandle.position]}');
		}

		// Bottom panel
		if (uiBase.ui.window(uiBase.hwnds[PanelBottom], tabx, h0, w, h1)) {
			uiBase.ui.tab(propertiesTabHandle, "Properties");
		}
	}

	function drawBottomPanel() {
		var bottomH: Int = uiBase.getBottomH();

		// Skip drawing if panel is too small
		if (bottomH < UIBase.MIN_PANEL_SIZE) return;

		var panelX: Int = 0;
		var panelY: Int = App.h() - bottomH;
		var panelW: Int = uiBase.getTabX();

		if (uiBase.ui.window(uiBase.hwnds[PanelCenter], panelX, panelY, panelW, bottomH)) {
			uiBase.ui.tab(themeTabHandle, "Theme");
			uiBase.ui.row([0.075, 0.075, 0.075, 0.075]);
			if (uiBase.ui.button("Load")) {
				trace("Load");
			}
			if (uiBase.ui.button("Save")) {
				trace("Save");
			}
			if (uiBase.ui.button("Save As")) {
				trace("Save As");
			}
			if (uiBase.ui.button("Clear")) {
				trace("Clear");
			}

			uiBase.ui.row([1]);
			if (themeTabHandle.position == 0) {
				zui.Ext.textAreaLineNumbers = true;
				zui.Ext.textAreaScrollPastEnd = true;
				zui.Ext.textArea(uiBase.ui, themeTextHandle);
				zui.Ext.textAreaLineNumbers = false;
				zui.Ext.textAreaScrollPastEnd = false;
			}
		}
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

	function render2D(g2: Graphics) {
		if (uiBase == null) return;
		g2.end();

		Koui.render(g2);
		g2.begin(false);
		drawAnchorPane(g2);
		g2.end();

		uiBase.ui.begin(g2);
		drawElementsPanel();
		drawRightPanels();
		drawBottomPanel();
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
}
