package arm.base;

import armory.system.Signal;
import kha.Font;
import zui.Themes;

class Base {
	public static var font: Font = null;
	public static var theme: TTheme = null;
	@:isVar public static var isResizing(default, set): Bool = false;
	public static var uiEnabled = true;

	public static var resizing: Signal = new Signal();

	public static function init() {
		Config.init();
		theme = zui.Themes.dark;
		theme.FILL_WINDOW_BG = true; // Fill window background with color
	}

	static function set_isResizing(value: Bool) {
		resizing.emit();
		return isResizing = value;
	}
}
