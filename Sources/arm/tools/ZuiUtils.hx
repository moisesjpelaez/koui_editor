package arm.tools;

import arm.tools.ImageUtils;
import kha.Image;
import zui.Zui;
import zui.Zui.State;

@:access(zui.Zui)
class ZuiUtils {
	// A button showing the icon at tile (`tileX`, `tileY`) of the atlas; true when clicked
	public static function iconButton(ui: Zui, icons: Image, tileX: Int, tileY: Int, tooltip: String,
			highlight: Bool = false, disabled: Bool = false, scale: Float = 1.0): Bool {
		if (icons == null) return !disabled && ui.button("?");

		var col: Int = ui.t.WINDOW_BG_COL;
		if (col < 0) col += untyped 4294967296;
		var light: Bool = col > 0xff666666 + 4294967296;

		var iconAccent: Int = disabled ? 0x66aaaaaa : (light ? 0xff666666 : 0xffaaaaaa);
		if (highlight && !disabled) iconAccent = ui.t.HIGHLIGHT_COL;

		var startX: Float = ui._x;
		var startY: Float = ui._y;
		var buttonW: Float = ui._w;
		var buttonH: Float = ui.ELEMENT_H();

		var rect: TTileRect = ImageUtils.tile(tileX, tileY);
		var state: State;

		// A transparent hit area, with the icon drawn over it so it scales with the button
		state = ui.image(icons, 0x00000000, buttonH, rect.x, rect.y, rect.w, rect.h);

		var drawScale: Float = Math.max(0.0, Math.min(1.0, scale));
		var iconSize: Float = Math.min(buttonW, buttonH) * drawScale;
		var centerX: Float = startX + (buttonW - iconSize) * 0.5;
		var centerY: Float = startY + (buttonH - iconSize) * 0.5;

		ui.g.pipeline = ImageUtils.getPipeline();
		ui.g.color = iconAccent;
		ui.g.drawScaledSubImage(icons, rect.x, rect.y, rect.w, rect.h, centerX, centerY, iconSize, iconSize);
		ui.g.pipeline = null;

		if (!disabled && (state == State.Down || state == State.Started)) {
			ui.g.color = 0x55000000;
			ui.g.fillRect(startX, startY, buttonW, buttonH);
		} else if (!disabled && state == State.Hovered) {
			ui.g.color = 0x33ffffff;
			ui.g.fillRect(startX, startY, buttonW, buttonH);
		}

		if (!disabled && ui.isHovered) ui.tooltip(tooltip);
		return !disabled && state == State.Released;
	}
}