package arm.editors;

import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import arm.tools.CanvasUtils;
import koui.elements.Element;
import koui.elements.ImagePanel;
import koui.Koui;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

@:access(koui.Koui)
class ImagePanelEditor implements IElementEditor {
	var imageHandle: Handle;
	var scaleHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "ImagePanel";
	function get_displayName(): String return "Image Panel";
	function get_category(): String return "Basic";
	function get_isComposite(): Bool return false;

	public function matches(element: Element): Bool return Std.isOfType(element, ImagePanel);

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		var imagePanel = new ImagePanel(null);
		imagePanel.width = 32;
		imagePanel.height = 32;
		return imagePanel;
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var imagePanel = new ImagePanel(null);
		if (properties != null) {
			if (properties.imageName != null && properties.imageName != "") {
				var img: kha.Image = Koui.getImage(properties.imageName);
				if (img != null) {
					imagePanel.image = img;
				}
			}
			if (properties.scale != null) {
				imagePanel.scale = properties.scale;
			}
		}
		return imagePanel;
	}

	public function serializeProperties(element: Element): Dynamic {
		var imagePanel: ImagePanel = cast element;
		return {
			imageName: CanvasUtils.getImageName(imagePanel.image),
			scale: imagePanel.scale
		};
	}

	public function initHandles(): Void {
		imageHandle = new Handle();
		scaleHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Image Properties", Center);
		ui.separator();

		var imagePanel: ImagePanel = cast element;

		// Build list of available images from Koui.imageMap
		var imageNames: Array<String> = ["(none)"];
		for (key in Koui.imageMap.keys()) {
			imageNames.push(key);
		}

		// Find current selection index
		var currentImageName: String = CanvasUtils.getImageName(imagePanel.image);
		var currentIndex: Int = 0;
		for (i in 0...imageNames.length) {
			if (imageNames[i] == currentImageName) {
				currentIndex = i;
				break;
			}
		}
		imageHandle.position = currentIndex;

		var newIndex: Int = ui.combo(imageHandle, imageNames, "Image", true, Right);
		if (imageHandle.changed) {
			var selectedName: String = imageNames[newIndex];
			if (selectedName == "(none)") {
				ElementEvents.propertyChanged.emit(imagePanel, "image", currentImageName, "");
				imagePanel.image = null;
				imagePanel.width = 32;
				imagePanel.height = 32;
			} else {
				var img: kha.Image = Koui.getImage(selectedName);
				if (img != null) {
					ElementEvents.propertyChanged.emit(imagePanel, "image", currentImageName, selectedName);
					imagePanel.image = img;
				}
			}
			Koui.updateElementSize(imagePanel);
		}

		scaleHandle.selected = imagePanel.scale;
		var newScale: Bool = ui.check(scaleHandle, "Scale to Size");
		if (newScale != imagePanel.scale) {
			ElementEvents.propertyChanged.emit(imagePanel, "scale", imagePanel.scale, newScale);
			imagePanel.scale = newScale;
		}
	}
}
