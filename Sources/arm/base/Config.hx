package arm.base;

import arm.types.Enums;

class Config {
	public static var raw: TConfig = null;

	public static function init() {
		if (raw == null) {
			raw = {};
			raw.layout = [];
			raw.layout[LayoutSidebarW] = 260;
			raw.layout[LayoutSidebarH0] = 300;
			raw.layout[LayoutSidebarH1] = 300;
			raw.layout[LayoutBottomH] = 200;
		}
	}
}

typedef TConfig = {
	@:optional public var layout: Array<Int>;
}
