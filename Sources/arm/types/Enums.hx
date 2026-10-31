package arm.types;

enum abstract BorderSide(Int) from Int to Int {
	var SideLeft: Int = 0;
	var SideRight: Int = 1;
	var SideTop: Int = 2;
	var SideBottom: Int = 3;
}

enum abstract LayoutSize(Int) from Int to Int {
	var LayoutSidebarW: Int = 0;
	var LayoutSidebarH0: Int = 1;
	var LayoutSidebarH1: Int = 2;
	var LayoutBottomH: Int = 3;
}

enum abstract PanelHandle(Int) from Int to Int {
	var PanelHierarchy: Int = 0;
	var PanelProperties: Int = 1;
	var PanelBottom: Int = 2;
}

/** The mouse cursors the editor uses, as Krom numbers them. */
enum abstract Cursor(Int) from Int to Int {
	var Default: Int = 0;
	var ResizeHorizontal: Int = 3;
	var ResizeVertical: Int = 4;
	/** From bottom-left to top-right. */
	var ResizeDiagonalUp: Int = 5;
	/** From top-left to bottom-right. */
	var ResizeDiagonalDown: Int = 6;
	var Move: Int = 9;
}

enum abstract DropZone(Int) from Int to Int {
	var None: Int = 0;
	var BeforeSibling: Int = 1;
	var AsChild: Int = 2;
	var AfterSibling: Int = 3;
}