package arm.editors;

import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import koui.elements.Element;
import koui.elements.Label;
import koui.utils.RadioGroup;
import kha.graphics2.HorTextAlignment;
import kha.graphics2.VerTextAlignment;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

class LabelEditor implements IElementEditor {
	var textHandle: Handle;
	var horAlignHandle: Handle;
	var vertAlignHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Label";
	function get_displayName(): String return "Label";
	function get_category(): String return "Basic";
	function get_isComposite(): Bool return false;

	public function matches(element: Element): Bool return Std.isOfType(element, Label);

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Label("New Label");
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var text: String = properties != null && properties.text != null ? properties.text : "";
		var label = new Label(text);
		if (properties != null) {
			if (properties.alignmentHor != null)
				label.alignmentHor = cast properties.alignmentHor;
			if (properties.alignmentVert != null)
				label.alignmentVert = cast properties.alignmentVert;
		}
		return label;
	}

	public function serializeProperties(element: Element): Dynamic {
		var label: Label = cast element;
		return {
			text: label.text,
			alignmentHor: cast label.alignmentHor,
			alignmentVert: cast label.alignmentVert
		};
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		horAlignHandle = new Handle();
		vertAlignHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Label Properties", Center);
		ui.separator();

		var label: Label = cast element;
		textHandle.text = label.text;
		var newText: String = ui.textInput(textHandle, "Text", Right);
		if (textHandle.changed) {
			if (newText != null && newText != "") {
				ElementEvents.propertyChanged.emit(label, "text", label.text, newText);
				label.text = newText;
			}
		}

		var horOptions: Array<String> = ["Left", "Center", "Right"];
		horAlignHandle.position = switch (label.alignmentHor) {
			case TextLeft: 0;
			case TextCenter: 1;
			case TextRight: 2;
		};
		var newHorIndex: Int = ui.combo(horAlignHandle, horOptions, "Hor. Alignment", true, Right);
		if (horAlignHandle.changed) {
			var newHorAlign: HorTextAlignment = switch (newHorIndex) {
				case 1: TextCenter;
				case 2: TextRight;
				default: TextLeft;
			};
			ElementEvents.propertyChanged.emit(label, "alignmentHor", label.alignmentHor, newHorAlign);
			label.alignmentHor = newHorAlign;
		}

		var vertOptions: Array<String> = ["Top", "Middle", "Bottom"];
		vertAlignHandle.position = switch (label.alignmentVert) {
			case TextTop: 0;
			case TextMiddle: 1;
			case TextBottom: 2;
		};
		var newVertIndex: Int = ui.combo(vertAlignHandle, vertOptions, "Vert. Alignment", true, Right);
		if (vertAlignHandle.changed) {
			var newVertAlign: VerTextAlignment = switch (newVertIndex) {
				case 1: TextMiddle;
				case 2: TextBottom;
				default: TextTop;
			};
			ElementEvents.propertyChanged.emit(label, "alignmentVert", label.alignmentVert, newVertAlign);
			label.alignmentVert = newVertAlign;
		}
	}
}
