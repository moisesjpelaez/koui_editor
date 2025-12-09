package arm;

import kha.Font;
import kha.Image;
import zui.Zui;

class Base {
	public static var font: Font = null;
	public static var theme: zui.Themes.TTheme = null;
	public static var isResizing = false;
	public static var uiEnabled = true;

	public static function init() {
		Config.init();
		theme = zui.Themes.dark;
		theme.FILL_WINDOW_BG = true; // Fill window background with color
	}
}
