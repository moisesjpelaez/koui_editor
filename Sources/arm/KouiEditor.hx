package arm;

import arm.Enums;
import iron.App;
import kha.Assets;
import kha.graphics2.Graphics;
import zui.Id;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

class KouiEditor extends iron.Trait {
	var uiBase: UIBase;
	var themeTextHandle: Handle;
	var sceneTabHandle: Handle;
	var propertiesTabHandle: Handle;
	var themeTabHandle: Handle;

	// Dynamic scene tabs
	var sceneTabs: Array<String> = ["Scene"];
	var sceneCounter: Int = 1;

	public function new() {
		super();

		Assets.loadEverything(function() {
			// Initialize framework
			Base.font = Assets.fonts.font_default;
			Base.init();

			// Create UIBase with the loaded font
			uiBase = new UIBase(Assets.fonts.font_default);

			// Initialize handles
			themeTextHandle = new Handle();
			sceneTabHandle = new Handle();
			propertiesTabHandle = new Handle();
			themeTabHandle = new Handle();
		});

		notifyOnUpdate(update);
		notifyOnRender2D(render2D);
	}

	function update() {
		if (uiBase == null) return;
		uiBase.update();
	}

	function drawElementsPanel() {
		// No background for this panel
		uiBase.ui.t.FILL_WINDOW_BG = false;
		if (uiBase.ui.window(Id.handle(), 10, 10, 100, App.h() - uiBase.getBottomH() - 20, false)) {
			if (uiBase.ui.panel(Id.handle({selected: true}), "Basic")) {
				uiBase.ui.indent();

				if (uiBase.ui.button("Label")) {
					trace("Label");
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
					trace("Button");
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
			// Tabs
			uiBase.ui.tab(themeTabHandle, "Theme");

			if (themeTabHandle.position == 0) {
				zui.Ext.textAreaLineNumbers = true;
				zui.Ext.textAreaScrollPastEnd = true;
				zui.Ext.textArea(uiBase.ui, themeTextHandle);
				zui.Ext.textAreaLineNumbers = false;
				zui.Ext.textAreaScrollPastEnd = false;
			}
		}
	}

	function render2D(g2: Graphics) {
		if (uiBase == null) return;

		g2.end();
		uiBase.ui.begin(g2);

		drawElementsPanel();
		drawRightPanels();
		drawBottomPanel();

		uiBase.ui.end();
		g2.begin(false);
	}
}
