package arm.editors;

import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import koui.elements.Element;
import koui.elements.Progressbar;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

class ProgressbarEditor implements IElementEditor {
	var textHandle: Handle;
	var minValueHandle: Handle;
	var maxValueHandle: Handle;
	var precisionHandle: Handle;
	var valueHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Progressbar";
	function get_displayName(): String return "Progressbar";
	function get_category(): String return "Misc.";
	function get_isComposite(): Bool return true;

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Progressbar(0, 100);
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var minVal: Float = properties != null && properties.minValue != null ? properties.minValue : 0.0;
		var maxVal: Float = properties != null && properties.maxValue != null ? properties.maxValue : 1.0;
		var progressbar = new Progressbar(minVal, maxVal);
		if (properties != null) {
			if (properties.value != null) progressbar.value = properties.value;
			if (properties.text != null) progressbar.text = properties.text;
			if (properties.precision != null) progressbar.precision = properties.precision;
		}
		return progressbar;
	}

	public function serializeProperties(element: Element): Dynamic {
		var progressbar: Progressbar = cast element;
		return {
			value: progressbar.value,
			minValue: progressbar.minValue,
			maxValue: progressbar.maxValue,
			text: progressbar.text,
			precision: progressbar.precision
		};
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		minValueHandle = new Handle();
		maxValueHandle = new Handle();
		precisionHandle = new Handle();
		valueHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Progressbar Properties", Center);
		ui.separator();

		var progressbar: Progressbar = cast element;

		textHandle.text = progressbar.text;
		var newText: String = ui.textInput(textHandle, "Text", Right);
		if (textHandle.changed) {
			ElementEvents.propertyChanged.emit(progressbar, "text", progressbar.text, newText);
			progressbar.text = newText;
		}

		minValueHandle.text = Std.string(progressbar.minValue);
		var newMinStr: String = ui.textInput(minValueHandle, "Min Value", Right);
		if (minValueHandle.changed) {
			var newMin: Float = Std.parseFloat(newMinStr);
			if (!Math.isNaN(newMin)) {
				ElementEvents.propertyChanged.emit(progressbar, "minValue", progressbar.minValue, newMin);
				progressbar.minValue = newMin;
				progressbar.value = Math.max(newMin, progressbar.value);
			}
		}

		maxValueHandle.text = Std.string(progressbar.maxValue);
		var newMaxStr: String = ui.textInput(maxValueHandle, "Max Value", Right);
		if (maxValueHandle.changed) {
			var newMax: Float = Std.parseFloat(newMaxStr);
			if (!Math.isNaN(newMax)) {
				ElementEvents.propertyChanged.emit(progressbar, "maxValue", progressbar.maxValue, newMax);
				progressbar.maxValue = newMax;
				progressbar.value = Math.min(newMax, progressbar.value);
			}
		}

		precisionHandle.text = Std.string(progressbar.precision);
		var newPrecisionStr: String = ui.textInput(precisionHandle, "Precision", Right);
		var steps: Float = 0;
		if (precisionHandle.changed) {
			var newPrecision: Int = Std.parseInt(newPrecisionStr);
			if (newPrecision != null) {
				newPrecision = Std.int(Math.max(0, newPrecision));
				ElementEvents.propertyChanged.emit(progressbar, "precision", progressbar.precision, newPrecision);
				progressbar.precision = newPrecision;
				steps = Math.pow(10, -progressbar.precision);
				progressbar.value = Math.round(progressbar.value / steps) * steps;
			}
		}

		valueHandle.value = progressbar.value;
		steps = Math.pow(10, -progressbar.precision);
		var newValue: Float = ui.slider(valueHandle, "Value", progressbar.minValue, progressbar.maxValue, true, 1 / steps, true, Right);
		if (valueHandle.changed) {
			newValue = Math.round(newValue / steps) * steps;
			valueHandle.value = newValue;
			ElementEvents.propertyChanged.emit(progressbar, "value", progressbar.value, newValue);
			progressbar.value = newValue;
		}
	}
}
