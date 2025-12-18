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
	 * @param scale Icon scale factor (1.0 = full size, 0.4 = 40%)
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

		if (scale < 1.0) {
			// Scaled icon: invisible hit area + manually drawn scaled icon
			state = ui.image(icons, 0x00000000, null, rect.x, rect.y, Std.int(buttonH), Std.int(buttonH));

			var scaledW: Float = rect.w * scale;
			var scaledH: Float = rect.h * scale;
			var centerX: Float = startX + (buttonW - scaledW) * 0.5;
			var centerY: Float = startY + (buttonH - scaledH) * 0.5;

			ui.g.pipeline = ImageUtils.getPipeline();
			ui.g.color = iconAccent;
			ui.g.drawScaledSubImage(icons, rect.x, rect.y, rect.w, rect.h, centerX, centerY, scaledW, scaledH);
			ui.g.pipeline = null;
		} else {
			// Full-size icon
			ui.g.pipeline = ImageUtils.getPipeline();
			state = ui.image(icons, iconAccent, null, rect.x, rect.y, rect.w, rect.h);
			ui.g.pipeline = null;
		}

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