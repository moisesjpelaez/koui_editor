package arm.data;

import arm.types.Enums;

/**
 * The sizes of the editor's panels, in pixels, indexed by `LayoutSize`. They're
 * kept in the editor's settings file (see `EditorSettings`), so the panels
 * have the same sizes the next time the editor opens. UIBase keeps them within
 * the window every frame.
 */
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

	/** Takes the saved sizes, or the defaults if there are none (or they aren't 4 positive numbers). */
	public static function init(): Void {
		EditorSettings.init();
		var saved: Null<Array<Int>> = EditorSettings.data.layout;
		var valid: Bool = saved != null && saved.length == 4 && Lambda.foreach(saved, size -> Std.isOfType(size, Int) && size > 0);
		sizes = valid ? saved.copy() : defaults();
	}

	/** Saves the current sizes, after a panel border was dragged. */
	public static function save(): Void {
		EditorSettings.data.layout = sizes.copy();
		EditorSettings.save();
	}
}
