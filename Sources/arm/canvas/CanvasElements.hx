package arm.canvas;

import arm.types.Types;

import koui.Koui;
import koui.elements.Button;
import koui.elements.Checkbox;
import koui.elements.Element;
import koui.elements.ImagePanel;
import koui.elements.Label;
import koui.elements.Panel;
import koui.elements.Progressbar;
import koui.elements.RadioButton;
import koui.elements.Slider;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;
import koui.utils.ElementMatchBehaviour.TypeMatchBehaviour;
import koui.utils.RadioGroup;

/**
 * Creates elements from canvas data and saves their type-specific properties.
 * Shared by the editor and the game runtime, so it must not use editor UI code.
 */
@:access(koui.Koui, koui.elements.Element)
class CanvasElements {
	/** The element types a canvas can contain, as saved in the "type" field. */
	public static final types: Array<String> = [
		"Label", "Panel", "ImagePanel", "Button", "Checkbox", "RadioButton",
		"AnchorPane", "ColLayout", "RowLayout", "Progressbar", "Slider"
	];

	/** The saved type of `element`, or null if a canvas can't contain it. */
	public static function getType(element: Element): Null<String> {
		var className: String = Type.getClassName(Type.getClass(element));
		var typeName: String = className.substr(className.lastIndexOf(".") + 1);
		return types.indexOf(typeName) >= 0 ? typeName : null;
	}

	/**
	 * Creates an element from its data, or returns null for an unknown type.
	 * Radio buttons join the group with the saved id, which is created if needed.
	 */
	public static function create(data: TElementData, radioGroups: Map<String, RadioGroup>): Null<Element> {
		var p: Dynamic = data.properties;
		var element: Element;

		switch (data.type) {
			case "Label":
				element = new Label(p.text);

			case "Panel":
				element = new Panel();

			case "ImagePanel":
				var imagePanel: ImagePanel = new ImagePanel(null);
				if (p.imageName != "") {
					var image: kha.Image = Koui.getImage(p.imageName);
					if (image != null) imagePanel.image = image;
				}
				imagePanel.scale = p.scale;
				element = imagePanel;

			case "Button":
				var button: Button = new Button(p.text);
				button.isToggle = p.isToggle;
				button.isPressed = p.isPressed;
				element = button;

			case "Checkbox":
				var checkbox: Checkbox = new Checkbox(p.text);
				checkbox.isChecked = p.isChecked;
				var checkSquare: Panel = checkbox.getChild(new TypeMatchBehaviour(Panel));
				if (checkSquare != null) checkSquare.setContextElement(checkbox.isChecked ? "checked" : "");
				element = checkbox;

			case "RadioButton":
				var group: RadioGroup = radioGroups.get(p.radioGroup);
				if (group == null) {
					group = new RadioGroup(p.radioGroup);
					radioGroups.set(p.radioGroup, group);
				}
				element = new RadioButton(group, p.text);

			case "AnchorPane":
				element = new AnchorPane(data.posX, data.posY, data.width, data.height);

			case "ColLayout":
				element = new ColLayout(data.posX, data.posY, data.width, data.height, 0);

			case "RowLayout":
				element = new RowLayout(data.posX, data.posY, data.width, data.height, 0);

			case "Progressbar":
				var progressbar: Progressbar = new Progressbar(p.minValue, p.maxValue);
				progressbar.value = p.value;
				progressbar.text = p.text;
				progressbar.precision = p.precision;
				element = progressbar;

			case "Slider":
				var slider: Slider = new Slider(p.minValue, p.maxValue);
				slider.value = p.value;
				slider.precision = p.precision;
				slider.orientation = cast p.orientation;
				element = slider;

			default:
				return null;
		}

		element.posX = data.posX;
		element.posY = data.posY;
		element.width = data.width;
		element.height = data.height;
		element.anchor = cast data.anchor;
		element.visible = data.visible;
		element.disabled = data.disabled;
		if (data.tID != "") element.setTID(data.tID);

		return element;
	}

	/** The type-specific properties of `element`, as saved in the "properties" field. */
	public static function serializeProperties(element: Element): Dynamic {
		switch (getType(element)) {
			case "Label":
				var label: Label = cast element;
				return { text: label.text };

			case "ImagePanel":
				var imagePanel: ImagePanel = cast element;
				return { imageName: getImageName(imagePanel.image), scale: imagePanel.scale };

			case "Button":
				var button: Button = cast element;
				return { text: button.text, isToggle: button.isToggle, isPressed: button.isPressed };

			case "Checkbox":
				var checkbox: Checkbox = cast element;
				return { text: checkbox.text, isChecked: checkbox.isChecked };

			case "RadioButton":
				// Which button is checked is saved once, as the group's active button
				var radioButton: RadioButton = cast element;
				return { text: radioButton.text, radioGroup: radioButton.group.id };

			case "Progressbar":
				var progressbar: Progressbar = cast element;
				return {
					value: progressbar.value,
					minValue: progressbar.minValue,
					maxValue: progressbar.maxValue,
					text: progressbar.text,
					precision: progressbar.precision
				};

			case "Slider":
				var slider: Slider = cast element;
				return {
					value: slider.value,
					minValue: slider.minValue,
					maxValue: slider.maxValue,
					precision: slider.precision,
					orientation: cast slider.orientation
				};

			default:
				return {};
		}
	}

	/** The asset name of `image` in `Koui.imageMap`, or "" if it has none. */
	public static function getImageName(image: kha.Image): String {
		if (image == null) return "";
		for (key in Koui.imageMap.keys()) {
			if (Koui.imageMap.get(key) == image) return key;
		}
		return "";
	}
}
