package arm.panels;

import arm.base.UIBase;
import arm.data.CanvasSettings;
import arm.data.EditorSettings;
import arm.data.History;
import arm.types.Enums;

import zui.Zui;
import zui.Zui.Handle;

/** The Properties panel's Settings tab: the editor's UI scale and the canvas' window resize settings. */
@:access(zui.Zui)
class SettingsTab {
	var uiScaleHandle: Handle = new Handle({value: 1.0});
	var expandOnResizeHandle: Handle = new Handle({selected: true});
	var scaleOnResizeHandle: Handle = new Handle({selected: true});
	var scaleModeHandle: Handle = new Handle({position: 0});

	public function new() {}

	public function draw(uiBase: UIBase): Void {
		var ui: Zui = uiBase.ui;

		ui.text("Editor UI", Center);
		ui.separator();

		// The scale is applied when Zui is made (UIBase) and here when it changes
		uiScaleHandle.value = EditorSettings.getEditorUIScale();
		var scale: Float = ui.slider(uiScaleHandle, "Scale", 0.5, 4.0, true, 100, true, Right);
		if (uiScaleHandle.changed && !Math.isNaN(scale)) {
			EditorSettings.setEditorUIScale(Math.round(scale * 100) / 100);
			ui.setScale(EditorSettings.getEditorUIScale());
			uiBase.redrawPanels();
			uiBase.hwnds[PanelBottom].redraws = 2;
		}

		ui._y += 4;
		ui.separator();
		ui.text("On Window Resize", Center);
		ui.separator();

		// The checkboxes show the canvas' settings, which loading and undo change
		expandOnResizeHandle.selected = CanvasSettings.expandOnResize;
		scaleOnResizeHandle.selected = CanvasSettings.scaleOnResize;
		CanvasSettings.expandOnResize = ui.check(expandOnResizeHandle, "Expand");
		if (CanvasSettings.expandOnResize) CanvasSettings.scaleOnResize = ui.check(scaleOnResizeHandle, "Scale");

		if (CanvasSettings.expandOnResize && CanvasSettings.scaleOnResize) {
			ui.text("Scale Mode");

			if (CanvasSettings.autoScale) scaleModeHandle.position = 0;
			else if (CanvasSettings.scaleHorizontal) scaleModeHandle.position = 1;
			else if (CanvasSettings.scaleVertical) scaleModeHandle.position = 2;

			if (ui.radio(scaleModeHandle, 0, "Auto")) setScaleMode(true, false, false);
			if (ui.radio(scaleModeHandle, 1, "Horizontal")) setScaleMode(false, true, false);
			if (ui.radio(scaleModeHandle, 2, "Vertical")) setScaleMode(false, false, true);
		}

		if (expandOnResizeHandle.changed || scaleOnResizeHandle.changed || scaleModeHandle.changed) {
			History.edited("Change canvas settings");
		}
	}

	static function setScaleMode(auto: Bool, horizontal: Bool, vertical: Bool): Void {
		CanvasSettings.autoScale = auto;
		CanvasSettings.scaleHorizontal = horizontal;
		CanvasSettings.scaleVertical = vertical;
	}
}
