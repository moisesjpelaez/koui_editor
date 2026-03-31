package arm.types;

import koui.elements.Element;
import koui.elements.layouts.AnchorPane;

// --- JSON serialization types (shared between editor and runtime) ---

typedef TRadioGroupData = {
	var id: String;
	var activeButtonKey: Null<String>;
}

typedef TCanvasData = {
	var name: String;
	var version: String;
	var canvas: TCanvasSettings;
	var radioGroups: Array<TRadioGroupData>;
	var scenes: Array<TSceneData>;
}

typedef TCanvasSettings = {
	var width: Int;
	var height: Int;
	var settings: TSettings;
}

typedef TSettings = {
	var expandOnResize: Bool;
	var scaleOnResize: Bool;
	var autoScale: Bool;
	var scaleHorizontal: Bool;
	var scaleVertical: Bool;
}

typedef TSceneData = {
	var key: String;
	var active: Bool;
	var elements: Array<TElementData>;
}

typedef TElementData = {
	var key: String;
	var type: String;
	var tID: String;
	var posX: Int;
	var posY: Int;
	var width: Int;
	var height: Int;
	var anchor: Int;
	var visible: Bool;
	var disabled: Bool;
	var parentKey: Null<String>;
	var focusUp: Null<String>;
	var focusDown: Null<String>;
	var focusLeft: Null<String>;
	var focusRight: Null<String>;
	var properties: Dynamic;
}

// --- Editor runtime types ---

typedef TSceneEntry = {
	var key: String;
	var root: AnchorPane;
	var elements: Array<TElementEntry>;
	var active: Bool;
}

typedef TElementEntry = {
	var key: String;
	var element: Element;
}
