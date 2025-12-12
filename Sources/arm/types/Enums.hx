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

enum abstract DropZone(Int) from Int to Int {
	var None: Int = 0;
	var BeforeSibling: Int = 1;
	var AsChild: Int = 2;
	var AfterSibling: Int = 3;
}