package arm.panels;

import arm.data.History;
import arm.data.SceneData;
import arm.data.Selection;
import arm.editors.ElementRegistry;
import arm.editors.ElementEditor;
import arm.types.Enums;
import arm.base.UIBase;
import arm.tools.HierarchyUtils;
import arm.tools.NameUtils;
import arm.tools.ZuiUtils;

import kha.Image;
import koui.Koui;
import koui.elements.Element;
import koui.elements.layouts.Layout.Anchor;
import koui.theme.Style;

import zui.Zui;
import zui.Zui.Handle;

/** The right-hand panel's tabs: the selected elements' properties, plus the Radio Groups and Settings tabs. */
@:access(koui.Koui, koui.elements.Element, zui.Zui)
class PropertiesPanel {
	var tabHandle: Handle;
	var radioGroupsTab: RadioGroupsTab = new RadioGroupsTab();
	var settingsTab: SettingsTab = new SettingsTab();

	// Element handles
	var nameHandle: Handle;
	var tidHandle: Handle;
	var posXHandle: Handle;
	var posYHandle: Handle;
	var widthHandle: Handle;
	var heightHandle: Handle;
	var visibleHandle: Handle;
	var disabledHandle: Handle;
	var anchorHandle: Handle;
	var focusUpHandle: Handle;
	var focusDownHandle: Handle;
	var focusLeftHandle: Handle;
	var focusRightHandle: Handle;

	var sceneData: SceneData = SceneData.data;

	var icons: Image;

	public function new() {
		tabHandle = new Handle({position: 0});

		// Initialize property handles
		nameHandle = new Handle({text: ""});
		tidHandle = new Handle({text: ""});
		posXHandle = new Handle({text: "0"});
		posYHandle = new Handle({text: "0"});
		widthHandle = new Handle({text: "0"});
		heightHandle = new Handle({text: "0"});
		visibleHandle = new Handle({selected: true});
		disabledHandle = new Handle({selected: false});
		anchorHandle = new Handle({position: 0});
		focusUpHandle = new Handle({position: 0});
		focusDownHandle = new Handle({position: 0});
		focusLeftHandle = new Handle({position: 0});
		focusRightHandle = new Handle({position: 0});
	}

	public function draw(uiBase: UIBase, params: Dynamic): Void {
		if (uiBase.ui.window(uiBase.hwnds[PanelProperties], params.tabx, params.h0, params.w, params.h1)) {
			if (uiBase.ui.tab(tabHandle, "Properties")) {
				if (!Selection.isEmpty()) {
					drawProperties(uiBase);
				} else {
					uiBase.ui.text("No element selected");
				}
			}

			if (uiBase.ui.tab(tabHandle, "Radio Groups")) radioGroupsTab.draw(uiBase, icons);
			if (uiBase.ui.tab(tabHandle, "Settings")) settingsTab.draw(uiBase);
		}
	}

	function drawProperties(uiBase: UIBase): Void {
		var ui: Zui = uiBase.ui;
		var elements: Array<Element> = Selection.elements;
		var single: Bool = elements.length == 1;

		// The type-specific section only shows when all selected elements share a type
		var editor: ElementEditor = PropertyFields.shared(elements, e -> ElementRegistry.getForElement(e));
		if (!single) ui.text('${elements.length} elements selected', Left);
		ui.text(editor != null ? editor.typeName : "Mixed types", Right);
		if (editor != null) editor.drawProperties(ui, elements);

		ui.text("Element Properties", Center);
		ui.separator();

		if (single) drawKeyField(uiBase, elements[0]);

		// TID: a theme ID the theme doesn't have is rejected
		PropertyFields.value(ui, tidHandle, "TID", elements, e -> e.getTID(), setTID, s -> s, s -> {
			if (s != "" && Style.getStyle(s) != null) return s;
			trace('Error: TID "${s}" not found in theme.');
			return null;
		});
		ui._y += 4;

		// Elements sized by their theme keep the theme's anchor, position and size
		var placeable: Array<Element> = elements.filter(e -> !isDynamicallySized(e));
		if (placeable.length == 0) {
			for (label in ["Anchor", "Position", "Size"]) {
				ui.row([1/4, 3/4]);
				ui.text(label, Left);
				ui.text("Dynamically Sized", Left);
			}
		} else {
			if (placeable.length < elements.length) {
				ui.text('${elements.length - placeable.length} theme-sized element(s) keep their layout', Left);
			}

			ui.text("Anchor", Left);
			drawAnchorGrid(ui, placeable);

			// Position - label, X/Y inputs and reset button in one row
			ui.row([1/4, 5/16, 5/16, 1/8]);
			ui.text("Position", Left);
			PropertyFields.int(ui, posXHandle, "X", placeable, e -> e.posX, (e, x) -> e.posX = x);
			PropertyFields.int(ui, posYHandle, "Y", placeable, e -> e.posY, (e, y) -> e.posY = y);
			if (ZuiUtils.iconButton(ui, icons, 6, 2, "Reset Position", false, false, 0.7)) {
				PropertyFields.apply("Reset position", placeable, (e, _) -> e.setPosition(0, 0), 0);
			}
			ui._y += 4;

			// Size - label, W/H inputs and reset button in one row
			ui.row([1/4, 5/16, 5/16, 1/8]);
			ui.text("Size", Left);
			PropertyFields.int(ui, widthHandle, "W", placeable, e -> e.width, (e, w) -> { e.width = w; Koui.updateElementSize(e); });
			PropertyFields.int(ui, heightHandle, "H", placeable, e -> e.height, (e, h) -> { e.height = h; Koui.updateElementSize(e); });
			if (ZuiUtils.iconButton(ui, icons, 6, 2, "Reset Size", false, false, 0.7)) {
				// Each element goes back to the size a new one of its type has
				PropertyFields.apply("Reset size", placeable, (e, _) -> {
					var size = ElementRegistry.getForElement(e).resetSize(e);
					e.width = size.width;
					e.height = size.height;
					Koui.updateElementSize(e);
				}, 0);
			}
		}
		ui._y += 4;

		PropertyFields.check(ui, visibleHandle, "Visible", elements, e -> e.visible, (e, v) -> e.visible = v);
		PropertyFields.check(ui, disabledHandle, "Disabled", elements, e -> e.disabled, (e, d) -> e.disabled = d);

		if (single && elements[0].canFocus) drawNavigation(ui, elements[0]);
	}

	/** The Key (name) field of a single element; names are unique among siblings. */
	function drawKeyField(uiBase: UIBase, element: Element): Void {
		var ui: Zui = uiBase.ui;
		var elemName: String = sceneData.getElementKey(element);
		if (elemName == null) elemName = "";

		nameHandle.text = elemName;
		var newName: String = ui.textInput(nameHandle, "Key", Right);
		// The rename goes to the element it was typed for, even if the selection changed since
		element = PropertyFields.textEditTargets(ui, nameHandle, [element])[0];
		elemName = sceneData.getElementKey(element);
		if (nameHandle.changed) {
			// "/" separates the names in an element's path
			if (elemName != null && newName != null && newName != "" && newName != elemName && newName.indexOf("/") < 0) {
				// Names are unique among siblings; a taken name gets a free number instead
				var uniqueName: String = NameUtils.ensureUniqueName(newName, element, HierarchyUtils.getParentElement(element));
				if (uniqueName != elemName) {
					sceneData.updateElementKey(element, uniqueName);
					History.edited("Rename");
				}
			}
			uiBase.redrawPanels();
		}
	}

	function setTID(element: Element, tID: String): Void {
		element.setTID(tID);
		// Theme-sized elements are placed by the theme
		var style: Style = Style.getStyle(tID);
		if (style.size.minWidth != 0 || style.size.minHeight != 0) element.setPosition(0, 0);
		Koui.updateElementSize(element);
	}

	static function isDynamicallySized(element: Element): Bool {
		return element.style != null && (element.style.size.minWidth != 0 || element.style.size.minHeight != 0);
	}

	function drawNavigation(ui: Zui, element: Element): Void {
		ui._y += 4;
		ui.text("Navigation", Left);
		ui.separator();

		// Listed by path and picked by position: names are only unique among siblings
		var focusable: Array<Element> = [for (other in sceneData.getElements()) if (other != element && other.canFocus) other];
		var labels: Array<String> = ["(none)"].concat([for (other in focusable) sceneData.getLabel(other)]);

		var drawFocusCombo = function(label: String, handle: Handle, target: Element, setTarget: Element->Void) {
			handle.position = focusable.indexOf(target) + 1;
			var picked: Int = ui.combo(handle, labels, label, true, Right);
			if (handle.changed) {
				setTarget(picked > 0 ? focusable[picked - 1] : null);
				History.edited('Change $label');
			}
		};

		drawFocusCombo("Focus Up", focusUpHandle, element.focusUp, function(e) element.focusUp = e);
		drawFocusCombo("Focus Down", focusDownHandle, element.focusDown, function(e) element.focusDown = e);
		drawFocusCombo("Focus Left", focusLeftHandle, element.focusLeft, function(e) element.focusLeft = e);
		drawFocusCombo("Focus Right", focusRightHandle, element.focusRight, function(e) element.focusRight = e);
	}

	function drawAnchorGrid(ui: Zui, elements: Array<Element>) {
		// No anchor is highlighted when the elements' anchors differ
		var currentAnchor: Null<Anchor> = PropertyFields.shared(elements, e -> e.anchor);

		// Define the anchor positions in a 3x3 grid
		var anchors = [
			[Anchor.TopLeft, Anchor.TopCenter, Anchor.TopRight],
			[Anchor.MiddleLeft, Anchor.MiddleCenter, Anchor.MiddleRight],
			[Anchor.BottomLeft, Anchor.BottomCenter, Anchor.BottomRight]
		];

		// Store original colors and sizes
		var origButtonCol = ui.t.BUTTON_COL;
		var origButtonHoverCol = ui.t.BUTTON_HOVER_COL;
		var origButtonPressedCol = ui.t.BUTTON_PRESSED_COL;
		var origButtonH = ui.t.BUTTON_H;
		var origElementH = ui.t.ELEMENT_H;
		var origElementOffset = ui.t.ELEMENT_OFFSET;

		// Make buttons square and smaller, reduce spacing
		var buttonSize = Std.int(origButtonH * 0.8);
		ui.t.BUTTON_H = buttonSize;
		ui.t.ELEMENT_H = buttonSize;
		ui.t.ELEMENT_OFFSET = 4;

		// Draw 3 rows
		for (row in 0...3) {
			ui.row([1/3, 1/3, 1/3]);

			for (col in 0...3) {
				var anchor = anchors[row][col];
				var isSelected = (anchor == currentAnchor);

				// Highlight selected anchor with different color
				if (isSelected) {
					ui.t.BUTTON_COL = ui.t.HIGHLIGHT_COL;
					ui.t.BUTTON_HOVER_COL = ui.t.HIGHLIGHT_COL;
					ui.t.BUTTON_PRESSED_COL = ui.t.HIGHLIGHT_COL;
				}

				// Use simple icon representation
				if (ui.button("")) {
					PropertyFields.apply("Change anchor", elements, (e, a) -> { e.anchor = a; e.invalidateElem(); }, anchor);
				}

				// Restore colors if they were changed
				if (isSelected) {
					ui.t.BUTTON_COL = origButtonCol;
					ui.t.BUTTON_HOVER_COL = origButtonHoverCol;
					ui.t.BUTTON_PRESSED_COL = origButtonPressedCol;
				}
			}
		}

		// Restore original button height and spacing
		ui.t.BUTTON_H = origButtonH;
		ui.t.ELEMENT_H = origElementH;
		ui.t.ELEMENT_OFFSET = origElementOffset;
		ui._y += 2;
	}

	public function setIcons(iconsImage: Dynamic): Void {
		icons = cast iconsImage;
	}
}
