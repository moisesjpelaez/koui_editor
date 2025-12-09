package arm;

enum abstract BorderSide(Int) from Int to Int {
	var SideLeft = 0;
	var SideRight = 1;
	var SideTop = 2;
	var SideBottom = 3;
}

enum abstract LayoutSize(Int) from Int to Int {
	var LayoutSidebarW = 0;
	var LayoutSidebarH0 = 1;
	var LayoutSidebarH1 = 2;
	var LayoutBottomH = 3;
}

enum abstract PanelHandle(Int) from Int to Int {
	var PanelTop = 0;
	var PanelBottom = 1;
	var PanelCenter = 2;
}
