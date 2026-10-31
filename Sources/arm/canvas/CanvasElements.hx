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

/** How canvases create and save one element type. */
typedef TElementType = {
	/** The saved "type", which is also the Koui class' name. */
	var name: String;
	/** Creates the element from its saved data; `p` is its "properties". Position, size and the other common fields are set after. */
	var create: (p: Dynamic, data: TElementData, radioGroups: Map<String, RadioGroup>) -> Element;
	/** The element's "properties" to save. */
	var save: Element -> Dynamic;
}

/**
 * Creates elements from canvas data and saves their type-specific properties.
 * Shared by the editor and the game runtime, so it must not use editor UI code.
 * A new element type is one entry in `types`.
 */
@:access(koui.Koui, koui.elements.Element)
class CanvasElements {
	/** The element types a canvas can contain. */
	public static final types: Array<TElementType> = [
		{
			name: "Label",
			create: (p, data, groups) -> new Label(p.text),
			save: e -> ({ text: (cast e: Label).text }: Dynamic)
		},
		{
			name: "Panel",
			create: (p, data, groups) -> new Panel(),
			save: e -> ({}: Dynamic)
		},
		{
			name: "ImagePanel",
			create: (p, data, groups) -> {
				var imagePanel: ImagePanel = new ImagePanel(null);
				if (p.imageName != "") imagePanel.image = Koui.getImage(p.imageName);
				imagePanel.scale = p.scale;
				imagePanel;
			},
			save: e -> ({ imageName: getImageName((cast e: ImagePanel).image), scale: (cast e: ImagePanel).scale }: Dynamic)
		},
		{
			name: "Button",
			create: (p, data, groups) -> {
				var button: Button = new Button(p.text);
				button.isToggle = p.isToggle;
				button.isPressed = p.isPressed;
				button;
			},
			save: (e: Element) -> {
				var button: Button = cast e;
				return ({ text: button.text, isToggle: button.isToggle, isPressed: button.isPressed }: Dynamic);
			}
		},
		{
			name: "Checkbox",
			create: (p, data, groups) -> {
				var checkbox: Checkbox = new Checkbox(p.text);
				setChecked(checkbox, p.isChecked);
				checkbox;
			},
			save: e -> ({ text: (cast e: Checkbox).text, isChecked: (cast e: Checkbox).isChecked }: Dynamic)
		},
		{
			// Which button is checked is saved once, as the group's active button
			name: "RadioButton",
			create: (p, data, groups) -> {
				var group: RadioGroup = groups.get(p.radioGroup);
				if (group == null) {
					group = new RadioGroup(p.radioGroup);
					groups.set(p.radioGroup, group);
				}
				new RadioButton(group, p.text);
			},
			save: e -> ({ text: (cast e: RadioButton).text, radioGroup: (cast e: RadioButton).group.id }: Dynamic)
		},
		{
			name: "AnchorPane",
			create: (p, data, groups) -> new AnchorPane(data.posX, data.posY, data.width, data.height),
			save: e -> ({}: Dynamic)
		},
		{
			name: "ColLayout",
			create: (p, data, groups) -> new ColLayout(data.posX, data.posY, data.width, data.height, 0),
			save: e -> ({}: Dynamic)
		},
		{
			name: "RowLayout",
			create: (p, data, groups) -> new RowLayout(data.posX, data.posY, data.width, data.height, 0),
			save: e -> ({}: Dynamic)
		},
		{
			name: "Progressbar",
			create: (p, data, groups) -> {
				var progressbar: Progressbar = new Progressbar(p.minValue, p.maxValue);
				progressbar.value = p.value;
				progressbar.text = p.text;
				progressbar.precision = p.precision;
				progressbar;
			},
			save: (e: Element) -> {
				var progressbar: Progressbar = cast e;
				return ({ value: progressbar.value, minValue: progressbar.minValue, maxValue: progressbar.maxValue, text: progressbar.text, precision: progressbar.precision }: Dynamic);
			}
		},
		{
			name: "Slider",
			create: (p, data, groups) -> {
				var slider: Slider = new Slider(p.minValue, p.maxValue);
				slider.value = p.value;
				slider.precision = p.precision;
				slider.orientation = cast p.orientation;
				slider;
			},
			save: (e: Element) -> {
				var slider: Slider = cast e;
				return ({ value: slider.value, minValue: slider.minValue, maxValue: slider.maxValue, precision: slider.precision, orientation: (cast slider.orientation: Int) }: Dynamic);
			}
		}
	];

	/** The saved type of `element`, or null if a canvas can't contain it. */
	public static function getType(element: Element): Null<String> {
		var className: String = Type.getClassName(Type.getClass(element));
		var name: String = className.substr(className.lastIndexOf(".") + 1);
		return find(name) != null ? name : null;
	}

	/**
	 * Creates an element from its data, or returns null for an unknown type.
	 * Radio buttons join the group with the saved id, which is created if needed.
	 */
	public static function create(data: TElementData, radioGroups: Map<String, RadioGroup>): Null<Element> {
		var type: Null<TElementType> = find(data.type);
		if (type == null) return null;

		var element: Element = type.create(data.properties, data, radioGroups);
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
		var type: Null<TElementType> = find(getType(element));
		return type != null ? type.save(element) : {};
	}

	/** Checks or unchecks `checkbox` (or radio button) and shows it: Koui's isChecked doesn't update the check square. */
	public static function setChecked(checkbox: Checkbox, checked: Bool): Void {
		checkbox.isChecked = checked;
		var checkSquare: Panel = checkbox.getChild(new TypeMatchBehaviour(Panel));
		if (checkSquare != null) checkSquare.setContextElement(checked ? "checked" : "");
	}

	/** The asset name of `image` in `Koui.imageMap`, or "" if it has none. */
	public static function getImageName(image: kha.Image): String {
		if (image == null) return "";
		for (key in Koui.imageMap.keys()) {
			if (Koui.imageMap.get(key) == image) return key;
		}
		return "";
	}

	static function find(name: Null<String>): Null<TElementType> {
		for (type in types) {
			if (type.name == name) return type;
		}
		return null;
	}
}
