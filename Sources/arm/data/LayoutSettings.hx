package arm.data;

import arm.types.Enums;

// The panel sizes in pixels, by `LayoutSize`, kept in the editor's settings file
class LayoutSettings {
	public static var sizes: Array<Int> = defaults();

	static function defaults(): Array<Int> {
		var sizes: Array<Int> = [];
		sizes[LayoutSidebarW] = 260;
		sizes[LayoutSidebarH0] = 300;
		sizes[LayoutSidebarH1] = 300;
		sizes[LayoutBottomH] = 200;
		return sizes;
	}

	// The saved sizes, or the defaults if they aren't 4 positive numbers
	public static function init(): Void {
		EditorSettings.init();
		var saved: Null<Array<Int>> = EditorSettings.data.layout;
		var valid: Bool = saved != null && saved.length == 4 && Lambda.foreach(saved, size -> Std.isOfType(size, Int) && size > 0);
		sizes = valid ? saved.copy() : defaults();
	}

	// After a panel border was dragged
	public static function save(): Void {
		EditorSettings.data.layout = sizes.copy();
		EditorSettings.save();
	}
}
