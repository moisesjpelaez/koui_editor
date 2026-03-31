package arm.editors;

import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import koui.elements.Element;
import koui.elements.Slider;
import koui.elements.Slider.SliderOrientation;
import koui.Koui;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

@:access(koui.Koui)
class SliderEditor implements IElementEditor {
	var orientationHandle: Handle;
	var minValueHandle: Handle;
	var maxValueHandle: Handle;
	var precisionHandle: Handle;
	var valueHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Slider";
	function get_displayName(): String return "Slider";
	function get_category(): String return "Misc.";
	function get_isComposite(): Bool return true;

	public function matches(element: Element): Bool return Std.isOfType(element, Slider);

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Slider(0, 100);
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var minVal: Float = properties != null && properties.minValue != null ? properties.minValue : 0.0;
		var maxVal: Float = properties != null && properties.maxValue != null ? properties.maxValue : 1.0;
		var slider = new Slider(minVal, maxVal);
		if (properties != null) {
			if (properties.value != null) slider.value = properties.value;
			if (properties.precision != null) slider.precision = properties.precision;
			if (properties.orientation != null) slider.orientation = cast properties.orientation;
		}
		return slider;
	}

	public function serializeProperties(element: Element): Dynamic {
		var slider: Slider = cast element;
		return {
			value: slider.value,
			minValue: slider.minValue,
			maxValue: slider.maxValue,
			precision: slider.precision,
			orientation: cast slider.orientation
		};
	}

	public function initHandles(): Void {
		orientationHandle = new Handle();
		minValueHandle = new Handle();
		maxValueHandle = new Handle();
		precisionHandle = new Handle();
		valueHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Slider Properties", Center);
		ui.separator();

		var slider: Slider = cast element;

		var orientation: Array<String> = ["Up", "Down", "Left", "Right"];
		var currentIndex: Int = 0;
		switch (slider.orientation) {
			case Up: currentIndex = 0;
			case Down: currentIndex = 1;
			case Left: currentIndex = 2;
			case Right: currentIndex = 3;
		}
		orientationHandle.position = currentIndex;

		var newIndex: Int = ui.combo(orientationHandle, orientation, "Orientation", true, Right);
		if (orientationHandle.changed) {
			var newOrientation = slider.orientation;
			switch (newIndex) {
				case 0: newOrientation = Up;
				case 1: newOrientation = Down;
				case 2: newOrientation = Left;
				case 3: newOrientation = Right;
			}
			ElementEvents.propertyChanged.emit(slider, "orientation", slider.orientation, newOrientation);
			slider.orientation = newOrientation;
			Koui.updateElementSize(slider);
		}

		minValueHandle.text = Std.string(slider.minValue);
		var newMinStr: String = ui.textInput(minValueHandle, "Min Value", Right);
		if (minValueHandle.changed) {
			var newMin: Float = Std.parseFloat(newMinStr);
			if (!Math.isNaN(newMin)) {
				ElementEvents.propertyChanged.emit(slider, "minValue", slider.minValue, newMin);
				slider.minValue = newMin;
				slider.value = Math.max(newMin, slider.value);
			}
		}

		maxValueHandle.text = Std.string(slider.maxValue);
		var newMaxStr: String = ui.textInput(maxValueHandle, "Max Value", Right);
		if (maxValueHandle.changed) {
			var newMax: Float = Std.parseFloat(newMaxStr);
			if (!Math.isNaN(newMax)) {
				ElementEvents.propertyChanged.emit(slider, "maxValue", slider.maxValue, newMax);
				slider.maxValue = newMax;
				slider.value = Math.min(newMax, slider.value);
			}
		}

		precisionHandle.text = Std.string(slider.precision);
		var newPrecisionStr: String = ui.textInput(precisionHandle, "Precision", Right);
		var steps: Float = 0;
		if (precisionHandle.changed) {
			var newPrecision: Int = Std.parseInt(newPrecisionStr);
			if (newPrecision != null) {
				newPrecision = Std.int(Math.max(0, newPrecision));
				ElementEvents.propertyChanged.emit(slider, "precision", slider.precision, newPrecision);
				slider.precision = newPrecision;
				steps = Math.pow(10, -slider.precision);
				slider.value = Math.round(slider.value / steps) * steps;
			}
		}

		valueHandle.value = slider.value;
		steps = Math.pow(10, -slider.precision);
		var newValue: Float = ui.slider(valueHandle, "Value", slider.minValue, slider.maxValue, true, 1 / steps, true, Right);
		if (valueHandle.changed) {
			newValue = Math.round(newValue / steps) * steps;
			valueHandle.value = newValue;
			ElementEvents.propertyChanged.emit(slider, "value", slider.value, newValue);
			slider.value = newValue;
		}
	}
}
