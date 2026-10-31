package arm.editors;

import arm.panels.PropertyFields;
import arm.data.History;
import arm.tools.CanvasUtils;
import koui.elements.Element;
import koui.elements.ImagePanel;
import koui.Koui;
import zui.Zui;
import zui.Zui.Handle;

@:access(koui.Koui)
class ImagePanelEditor extends ElementEditor {
	var imageHandle: Handle = new Handle();
	var scaleHandle: Handle = new Handle();

	public function new() {
		super("ImagePanel", "Image Panel", "Basic", groups -> {
			var imagePanel: ImagePanel = new ImagePanel(null);
			imagePanel.width = 32;
			imagePanel.height = 32;
			imagePanel;
		});
	}

	override public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Image Properties", Center);
		ui.separator();

		// Available images from Koui.imageMap; a missing image shows as "(none)"
		var imageNames: Array<String> = ["(none)"];
		for (key in Koui.imageMap.keys()) {
			imageNames.push(key);
		}
		PropertyFields.combo(ui, imageHandle, "Image", imageNames, elements, e -> {
			var index: Int = imageNames.indexOf(CanvasUtils.getImageName(cast e));
			index >= 0 ? index : 0;
		}, (e, index) -> applyImage(cast e, index == 0 ? "" : imageNames[index]));

		var missing: Array<String> = [];
		for (e in elements) {
			if (!CanvasUtils.isImageMissing(cast e)) continue;
			var missingName: String = CanvasUtils.getImageName(cast e);
			if (missing.indexOf(missingName) < 0) missing.push(missingName);
		}
		if (missing.length > 0) {
			ui.text('Missing image ${missing.join(", ")}: the name is kept when saving', Left);
		}

		PropertyFields.check(ui, scaleHandle, "Scale to Size", elements, e -> (cast e: ImagePanel).scale, (e, scale) -> (cast e: ImagePanel).scale = scale);
	}

	/** Shows the image named `name` in `imagePanel`, or no image if `name` is "". */
	public function applyImage(imagePanel: ImagePanel, name: String): Void {
		if (name == "") {
			imagePanel.image = null;
			imagePanel.width = 32;
			imagePanel.height = 32;
		} else {
			var img: kha.Image = Koui.getImage(name);
			if (img == null) return;
			imagePanel.image = img;
		}
		// A chosen image (or none) replaces a missing one
		CanvasUtils.setImageName(imagePanel, name);
		Koui.updateElementSize(imagePanel);
		History.edited("Change image");
	}
}
