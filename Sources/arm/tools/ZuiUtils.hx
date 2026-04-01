package arm.tools;

import arm.tools.ImageUtils;
import kha.Image;
import zui.Zui;
import zui.Zui.State;

@:access(zui.Zui)
class ZuiUtils {
	/**
	 * Draws an icon button using a tile from the icons atlas.
	 * @param ui The Zui instance
	 * @param icons The icons atlas image
	 * @param tileX X tile index in the atlas
	 * @param tileY Y tile index in the atlas
	 * @param tooltip Tooltip text shown on hover
	 * @param highlight If true, uses highlight color for the icon
	 * @param disabled If true, icon is dimmed and clicks are ignored
	 * @param scale Icon scale factor (1.0 = full size)
	 * @return True if the button was clicked
	 */
	public static function iconButton(ui: Zui, icons: Image, tileX: Int, tileY: Int, tooltip: String,
			highlight: Bool = false, disabled: Bool = false, scale: Float = 1.0): Bool {
		if (icons == null) return !disabled && ui.button("?");

		var col: Int = ui.t.WINDOW_BG_COL;
		if (col < 0) col += untyped 4294967296;
		var light: Bool = col > 0xff666666 + 4294967296;

		// Base color
		var iconAccent: Int = disabled ? 0x66aaaaaa : (light ? 0xff666666 : 0xffaaaaaa);
		if (highlight && !disabled) iconAccent = ui.t.HIGHLIGHT_COL;

		var startX: Float = ui._x;
		var startY: Float = ui._y;
		var buttonW: Float = ui._w;
		var buttonH: Float = ui.ELEMENT_H();

		var rect: TTileRect = ImageUtils.tile(tileX, tileY);
		var state: State;

		// Use a transparent hit area and draw icon manually so size tracks button/UI scale.
		state = ui.image(icons, 0x00000000, buttonH, rect.x, rect.y, rect.w, rect.h);

		var drawScale: Float = Math.max(0.0, Math.min(1.0, scale));
		var iconSize: Float = Math.min(buttonW, buttonH) * drawScale;
		var centerX: Float = startX + (buttonW - iconSize) * 0.5;
		var centerY: Float = startY + (buttonH - iconSize) * 0.5;

		ui.g.pipeline = ImageUtils.getPipeline();
		ui.g.color = iconAccent;
		ui.g.drawScaledSubImage(icons, rect.x, rect.y, rect.w, rect.h, centerX, centerY, iconSize, iconSize);
		ui.g.pipeline = null;

		// Hover and pressed visual feedback
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