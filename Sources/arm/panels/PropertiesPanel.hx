package arm.panels;

import arm.canvas.CanvasLoader;
import arm.data.CanvasSettings;
import arm.data.History;
import arm.data.SceneData;
import arm.data.Selection;
import arm.events.SceneEvents;
import arm.events.ElementEvents;
import arm.editors.ElementRegistry;
import arm.editors.ElementEditor;
import arm.types.Enums;
import arm.types.Types;
import arm.base.UIBase;
import arm.data.EditorSettings;
import arm.tools.HierarchyUtils;
import arm.tools.NameUtils;
import arm.tools.ZuiUtils;

import iron.math.Vec2;
import kha.Image;
import koui.Koui;
import koui.elements.Element;
import koui.elements.RadioButton;
import koui.elements.layouts.Layout.Anchor;
import koui.theme.Style;
import koui.utils.RadioGroup;

import zui.Zui;
import zui.Zui.Handle;

import haxe.ds.StringMap;

@:access(koui.Koui, koui.elements.Element, koui.utils.RadioGroup, zui.Zui)
class PropertiesPanel {
	var tabHandle: Handle;

	// Settings
	var expandOnResizeHandle: Handle;
	var scaleOnResizeHandle: Handle;
	var scaleOnResizeGroup: Handle;
	var editorUiScaleHandle: Handle;

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

	// RadioGroups tab handles/state
	var radioGroupNameHandle: Handle;
	var radioGroupRenameHandles: StringMap<Handle>;
	var radioGroupAddHandles: StringMap<Handle>;

	var sceneData: SceneData = SceneData.data;

	// Initial values for reset functionality
	/** Size of each element when first selected, by "scene:path", for "Reset Size". */
	var elementSizes: Map<String, Vec2> = new Map();

	var icons: Image;

	public function new() {
		tabHandle = new Handle({position: 0});

		// Initialize settings handles
		expandOnResizeHandle = new Handle({selected: true});
		scaleOnResizeHandle = new Handle({selected: true});
		scaleOnResizeGroup = new Handle({position: 0});
		editorUiScaleHandle = new Handle({value: 1.0});
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

		radioGroupNameHandle = new Handle({text: "RadioGroup"});
		radioGroupRenameHandles = new StringMap();
		radioGroupAddHandles = new StringMap();

		// Create default RadioGroup on startup
		ensureRadioGroups();

		ElementEvents.selectionChanged.connect(onSelectionChanged);
		SceneEvents.canvasLoaded.connect(onCanvasLoaded);
	}

	public function draw(uiBase: UIBase, params: Dynamic): Void {
		var enforcedScale: Float = EditorSettings.getEditorUIScale();
		if (Math.abs(uiBase.ui.SCALE() - enforcedScale) > 0.0001) {
			uiBase.ui.setScale(enforcedScale);
		}

		if (uiBase.ui.window(uiBase.hwnds[PanelProperties], params.tabx, params.h0, params.w, params.h1)) {
			if (uiBase.ui.tab(tabHandle, "Properties")) {
				if (!Selection.isEmpty()) {
					drawProperties(uiBase);
				} else {
					uiBase.ui.text("No element selected");
				}
			}

			if (uiBase.ui.tab(tabHandle, "Radio Groups")) {
				drawRadioGroups(uiBase);
			}

			if (uiBase.ui.tab(tabHandle, "Settings")) {
				uiBase.ui.text("Editor UI", Center);
				uiBase.ui.separator();

				var currentEditorScale: Float = EditorSettings.getEditorUIScale();
				editorUiScaleHandle.value = currentEditorScale;

				var newEditorScale: Float = uiBase.ui.slider(editorUiScaleHandle, "Scale", 0.5, 4.0, true, 100, true, Right);
				if (editorUiScaleHandle.changed) {
					if (Math.isNaN(newEditorScale)) {
						newEditorScale = currentEditorScale;
					}
					newEditorScale = Math.round(newEditorScale * 100) / 100;
					newEditorScale = Math.max(0.5, Math.min(4.0, newEditorScale));
					editorUiScaleHandle.value = newEditorScale;
					EditorSettings.setEditorUIScale(newEditorScale);
					var appliedScale: Float = EditorSettings.getEditorUIScale();
					editorUiScaleHandle.value = appliedScale;
					uiBase.ui.setScale(appliedScale);
					uiBase.redrawPanels();
					uiBase.hwnds[PanelBottom].redraws = 2;
				}

				uiBase.ui._y += 4;
				uiBase.ui.separator();
				uiBase.ui.text("On Window Resize", Center);
				uiBase.ui.separator();

				// The checkboxes show the canvas' settings, which loading and undo change
				expandOnResizeHandle.selected = CanvasSettings.expandOnResize;
				scaleOnResizeHandle.selected = CanvasSettings.scaleOnResize;
				CanvasSettings.expandOnResize = uiBase.ui.check(expandOnResizeHandle, "Expand");
				if (CanvasSettings.expandOnResize) CanvasSettings.scaleOnResize = uiBase.ui.check(scaleOnResizeHandle, "Scale");

				if (CanvasSettings.expandOnResize && CanvasSettings.scaleOnResize) {
					uiBase.ui.text("Scale Mode");

					if (CanvasSettings.autoScale) scaleOnResizeGroup.position = 0;
					else if (CanvasSettings.scaleHorizontal) scaleOnResizeGroup.position = 1;
					else if (CanvasSettings.scaleVertical) scaleOnResizeGroup.position = 2;

					if (uiBase.ui.radio(scaleOnResizeGroup, 0, "Auto")) {
						CanvasSettings.autoScale = true;
						CanvasSettings.scaleHorizontal = false;
						CanvasSettings.scaleVertical = false;
					}

					if (uiBase.ui.radio(scaleOnResizeGroup, 1, "Horizontal")) {
						CanvasSettings.autoScale = false;
						CanvasSettings.scaleHorizontal = true;
						CanvasSettings.scaleVertical = false;
					}

					if (uiBase.ui.radio(scaleOnResizeGroup, 2, "Vertical")) {
						CanvasSettings.autoScale = false;
						CanvasSettings.scaleHorizontal = false;
						CanvasSettings.scaleVertical = true;
					}
				}
				if (expandOnResizeHandle.changed || scaleOnResizeHandle.changed || scaleOnResizeGroup.changed) {
					History.edited("Change canvas settings");
				}
			}

		}
	}

	function drawRadioGroups(uiBase: UIBase): Void {
		var ui: Zui = uiBase.ui;

		ensureRadioGroups();

		var radioGroups = sceneData.radioGroups;
		var radioEntries = getSceneRadioButtons();

		ui.text("Radio Group Management", Center);
		ui.separator();

		ui.row([3/4, 1/4]);
		var requestedId = ui.textInput(radioGroupNameHandle, "Group ID", Right);
		if (ZuiUtils.iconButton(ui, icons, 1, 2, "Create Radio Group", false, false, 0.7)) {
			createRadioGroup(requestedId);
			uiBase.hwnds[PanelProperties].redraws = 2;
		}

		ui._y += 4;
		ui.separator();

		if (radioGroups.length == 0) {
			ui.text("No radio groups yet.");
			return;
		}

		var groupToDelete: String = null;
		var groupToRename: { oldId: String, newId: String } = null;

		var groupIndex = 0;
		for (group in radioGroups) {
			ui.row([5/6, 1/6]);

			// Show rename input for group name
			var renameHandle = getRadioGroupRenameHandle(group.id);
			renameHandle.text = group.id;
			var newGroupName = ui.textInput(renameHandle, "", Left);

			if (renameHandle.changed && newGroupName != "" && newGroupName != group.id) {
				groupToRename = { oldId: group.id, newId: newGroupName };
			}

			// Only allow deleting groups after the first one
			var canDelete = groupIndex > 0;
			if (ZuiUtils.iconButton(ui, icons, 1, 3, "Delete group", false, !canDelete, 0.7)) {
				groupToDelete = group.id;
			}

			groupIndex++;

			ui.indent();

			var addHandle = getRadioGroupAddHandle(group.id);
			var addOptions: Array<String> = ["(add radio button)"];
			for (entry in radioEntries) addOptions.push(entry.key);
			var selectedAdd = ui.combo(addHandle, addOptions, "Add", true, Right);
			if (addHandle.changed && selectedAdd > 0 && selectedAdd < addOptions.length) {
				var button = radioEntries[selectedAdd - 1].button;
				addButtonToGroup(group, button);
				addHandle.position = 0;
				uiBase.hwnds[PanelProperties].redraws = 2;
			}

			if (group.buttons.length == 0) {
				ui.text("No buttons in this group.");
			} else {
				for (button in group.buttons.copy()) {
					// Groups are canvas-wide: a button can be in any scene
					var path: Null<String> = elementLabel(button);
					var label = path != null ? path : "(removed)";
					if (group.activeButton == button) label += " [active]";

					ui.row([5/6, 1/6]);
					ui.text(label, Left);

					if (ZuiUtils.iconButton(ui, icons, 7, 0, "Set Active", group.activeButton == button, false, 0.7)) {
						group.setActiveButton(button);
						History.edited("Set active radio button");
						uiBase.hwnds[PanelProperties].redraws = 2;
					}
				}
			}

			ui.unindent();
			ui._y += 2;
			ui.separator();
		}

		if (groupToDelete != null) {
			deleteRadioGroup(groupToDelete);
			uiBase.hwnds[PanelProperties].redraws = 2;
		}

		if (groupToRename != null) {
			renameRadioGroup(groupToRename.oldId, groupToRename.newId);
			uiBase.hwnds[PanelProperties].redraws = 2;
		}
	}

	function getSceneRadioButtons(): Array<{ key: String, button: RadioButton }> {
		var entries: Array<{ key: String, button: RadioButton }> = [];
		var currentScene = sceneData.currentScene;
		if (currentScene == null) return entries;

		for (element in sceneData.getElements()) {
			if (Std.isOfType(element, RadioButton)) {
				entries.push({ key: elementLabel(element), button: cast element });
			}
		}

		return entries;
	}

	function findRadioGroup(groupId: String): RadioGroup {
		for (group in sceneData.radioGroups) {
			if (group.id == groupId) return group;
		}
		return null;
	}

	function ensureRadioGroups(): Void {
		if (sceneData.radioGroups.length == 0) {
			sceneData.radioGroups.push(new RadioGroup("RadioGroup"));
		}
	}

	function getRadioGroupAddHandle(groupId: String): Handle {
		if (!radioGroupAddHandles.exists(groupId)) {
			radioGroupAddHandles.set(groupId, new Handle({position: 0}));
		}
		return radioGroupAddHandles.get(groupId);
	}

	function getRadioGroupRenameHandle(groupId: String): Handle {
		if (!radioGroupRenameHandles.exists(groupId)) {
			radioGroupRenameHandles.set(groupId, new Handle({text: groupId}));
		}
		return radioGroupRenameHandles.get(groupId);
	}

	function createRadioGroup(requestedId: String): Void {
		var baseId = StringTools.trim(requestedId != null ? requestedId : "");
		if (baseId == "") baseId = "RadioGroup";

		var uniqueId = getUniqueRadioGroupId(baseId);

		var group = new RadioGroup(uniqueId);
		sceneData.radioGroups.push(group);
		History.edited("Add radio group");
		radioGroupAddHandles.set(group.id, new Handle({position: 0}));
		radioGroupNameHandle.text = uniqueId;
	}

	function getUniqueRadioGroupId(requestedId: String): String {
		return NameUtils.nextUniqueName(requestedId, [for (group in sceneData.radioGroups) group.id]);
	}

	function deleteRadioGroup(groupId: String): Void {
		var radioGroups = sceneData.radioGroups;
		var index = -1;
		for (i in 0...radioGroups.length) {
			if (radioGroups[i].id == groupId) {
				index = i;
				break;
			}
		}
		if (index < 0) return;

		var group = radioGroups[index];
		// Move all buttons to the default (first) group
		var defaultGroup = radioGroups[0];
		for (button in group.buttons.copy()) {
			group.remove(button);
			button.group = defaultGroup;
			defaultGroup.add(button);
		}

		radioGroups.splice(index, 1);
		History.edited("Delete radio group");
		radioGroupAddHandles.remove(groupId);
		radioGroupRenameHandles.remove(groupId);
	}

	function renameRadioGroup(oldId: String, newId: String): Void {
		var trimmedNewId = StringTools.trim(newId);
		if (trimmedNewId == "" || trimmedNewId == oldId) return;

		// Check for conflicts
		if (findRadioGroup(trimmedNewId) != null) return;

		var group = findRadioGroup(oldId);
		if (group == null) return;

		group.id = trimmedNewId;
		History.edited("Rename radio group");

		// Update handle mappings
		var addHandle = radioGroupAddHandles.get(oldId);
		if (addHandle != null) {
			radioGroupAddHandles.remove(oldId);
			radioGroupAddHandles.set(trimmedNewId, addHandle);
		}

		var renameHandle = radioGroupRenameHandles.get(oldId);
		if (renameHandle != null) {
			radioGroupRenameHandles.remove(oldId);
			radioGroupRenameHandles.set(trimmedNewId, renameHandle);
		}
	}

	function addButtonToGroup(group: RadioGroup, button: RadioButton): Void {
		if (button == null || group == null || button.group == group) return;

		if (button.group != null) {
			button.group.remove(button);
		}

		button.group = group;
		group.add(button);
		History.edited("Change radio group");
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
				// Each element goes back to its own first size
				PropertyFields.apply("Reset size", placeable, (e, _) -> {
					var originalSize: Vec2 = elementSizes.get(sizeKey(e));
					if (originalSize == null) return;
					e.width = Std.int(originalSize.x);
					e.height = Std.int(originalSize.y);
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
		var labels: Array<String> = ["(none)"].concat([for (other in focusable) elementLabel(other)]);

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

	/** The element's path in the current scene, "scene: path" in another one, or null if it's in no scene. */
	function elementLabel(element: Element): Null<String> {
		for (scene in sceneData.scenes) {
			if (!scene.keys.exists(element)) continue;
			var path: String = CanvasLoader.getPath(element, scene.root, scene.keys);
			return scene == sceneData.currentScene ? path : scene.key + ": " + path;
		}
		return null;
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

	function onSelectionChanged(): Void {
		// Remember each element's first size, for "Reset Size"
		for (element in Selection.elements) {
			if (!elementSizes.exists(sizeKey(element))) {
				elementSizes.set(sizeKey(element), new Vec2(element.width, element.height));
			}
		}

	}

	function sizeKey(element: Element): String {
		var scene: TSceneEntry = sceneData.currentScene;
		return scene.key + ":" + CanvasLoader.getPath(element, scene.root, scene.keys);
	}

	public function onCanvasLoaded(): Void {
		var editorScale: Float = EditorSettings.getEditorUIScale();
		editorUiScaleHandle.value = editorScale;
		if (UIBase.inst != null && UIBase.inst.ui != null) {
			UIBase.inst.ui.setScale(editorScale);
		}

		radioGroupAddHandles = new StringMap();
		radioGroupRenameHandles = new StringMap();
		radioGroupNameHandle.text = "RadioGroup";

		ensureRadioGroups();
	}

	public function setIcons(iconsImage: Dynamic): Void {
		icons = cast iconsImage;
	}
}