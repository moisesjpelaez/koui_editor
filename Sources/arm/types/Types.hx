package arm.types;

import koui.elements.Element;
import koui.elements.layouts.AnchorPane;

// --- JSON serialization types (shared between editor and runtime) ---
// Format 2.0. Elements are referenced by path: the names from the scene root
// down to the element, joined by "/" (e.g. "Menu/Buttons/Play").

typedef TRadioGroupData = {
	var id: String;
	var activeButton: Null<TElementRef>;
}

/** An element anywhere in the canvas. */
typedef TElementRef = {
	var scene: String;
	var path: String;
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
	/** Parents always come before their children. */
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
	/** Path of the parent element; "" for the scene root. */
	var parent: String;
	/** Paths of the elements focus moves to, in the same scene. */
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
	/** The name of every user element in this scene. Their order comes from the Koui tree. */
	var keys: Map<Element, String>;
}

typedef TElementEntry = {
	var key: String;
	var element: Element;
}
