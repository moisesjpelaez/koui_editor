package arm.panels;

import arm.data.CanvasSettings;
import arm.data.SceneData;
import arm.events.SceneEvents;
import arm.events.ElementEvents;
import arm.types.Enums;
import arm.base.UIBase;
import arm.tools.CanvasUtils;
import arm.tools.ZuiUtils;

import iron.math.Vec2;
import kha.Image;
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
import koui.elements.layouts.Layout.Anchor;
import koui.theme.Style;
import koui.utils.ElementMatchBehaviour.TypeMatchBehaviour;
import koui.utils.RadioGroup;

import zui.Zui;
import zui.Zui.Handle;

import haxe.ds.ObjectMap;
import haxe.ds.StringMap;
import StringTools;

@:access(koui.Koui, koui.elements.Element, koui.utils.RadioGroup, zui.Zui)
class PropertiesPanel {
    static var instance: PropertiesPanel;
    static var defaultRadioGroup: RadioGroup;

    var tabHandle: Handle;

    // Settings
    var expandOnResizeHandle: Handle;
    var scaleOnResizeHandle: Handle;
    var scaleOnResizeGroup: Handle;
    // Properties
    var selectedElement: Element = null;

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

    // Label handles
    var labelTextHandle: Handle;

    // Button handles
    var buttonTextHandle: Handle;
    var buttonIconHandle: Handle;
    var buttonIconSizeHandle: Handle;
    var buttonIsPressedHandle: Handle;
    var buttonIsToggleHandle: Handle;

    // Checkbox handles
    var checkboxIsCheckedHandle: Handle;
    var checkboxTextHandle: Handle;

    // RadioButton handles
    var radioButtonIsCheckedHandle: Handle;
    var radioButtonTextHandle: Handle;
    var radioButtonGroupHandle: Handle;

    // Progressbar handles
    var progressbarMinValueHandle: Handle;
    var progressbarMaxValueHandle: Handle;
    var progressbarTextHandle: Handle;
    var progressbarPrecisionHandle: Handle;
    var progressbarValueHandle: Handle;

    // ImagePanel handles
    var imagePanelImageHandle: Handle;
    var imagePanelScaleHandle: Handle;

    // Slider handles
    var sliderMaxValueHandle: Handle;
    var sliderMinValueHandle: Handle;
    var sliderValueHandle: Handle;
    var sliderOrientationHandle: Handle;
    var sliderPrecisionHandle: Handle;

    // RadioGroups tab handles/state
    var radioGroupNameHandle: Handle;
    var radioGroupRenameHandles: StringMap<Handle>;
    var radioGroupAddHandles: StringMap<Handle>;

    var sceneData: SceneData = SceneData.data;

    // Initial values for reset functionality
    var elementSizes: ObjectMap<Element, Vec2> = new ObjectMap();

    var icons: Image;

    public function new() {
        tabHandle = new Handle({position: 0});

        // Initialize settings handles
        expandOnResizeHandle = new Handle({selected: true});
        scaleOnResizeHandle = new Handle({selected: true});
        scaleOnResizeGroup = new Handle({position: 0});
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

        labelTextHandle = new Handle({text: "New Label"});

        buttonTextHandle = new Handle({text: "New Button"});
        // buttonIconHandle = new Handle({text: ""});
        // buttonIconSizeHandle = new Handle({text: "16"});
        buttonIsPressedHandle = new Handle({selected: false});
        buttonIsToggleHandle = new Handle({selected: false});

        checkboxTextHandle = new Handle({text: ""});
        checkboxIsCheckedHandle = new Handle({selected: false});

        radioButtonTextHandle = new Handle({text: ""});
        radioButtonIsCheckedHandle = new Handle({selected: false});
        radioButtonGroupHandle = new Handle({position: 0});

        progressbarValueHandle = new Handle({value: 0});
        progressbarMinValueHandle = new Handle({text: "0"});
        progressbarMaxValueHandle = new Handle({text: "1"});
        progressbarTextHandle = new Handle({text: ""});
        progressbarPrecisionHandle = new Handle({text: "1"});

        imagePanelImageHandle = new Handle({position: 0});
        imagePanelScaleHandle = new Handle({selected: false});

        sliderMaxValueHandle = new Handle({text: "1"});
        sliderMinValueHandle = new Handle({text: "0"});
        sliderValueHandle = new Handle({value: 0});
        sliderOrientationHandle = new Handle({position: 3});
        sliderPrecisionHandle = new Handle({text: "1"});

        radioGroupNameHandle = new Handle({text: "RadioGroup"});
        radioGroupRenameHandles = new StringMap();
        radioGroupAddHandles = new StringMap();

        // Create default RadioGroup on startup
        ensureRadioGroups();

        instance = this;

        ElementEvents.elementAdded.connect(onElementAdded);
        ElementEvents.elementSelected.connect(onElementSelected);
        ElementEvents.elementRemoved.connect(onElementRemoved);
        SceneEvents.canvasLoaded.connect(onCanvasLoaded);
    }

    public function draw(uiBase: UIBase, params: Dynamic): Void {
        if (uiBase.ui.window(uiBase.hwnds[PanelProperties], params.tabx, params.h0, params.w, params.h1)) {
            if (uiBase.ui.tab(tabHandle, "Properties")) {
                if (selectedElement != null) {
                    drawProperties(uiBase);
                } else {
                    uiBase.ui.text("No element selected");
                }
            }

            if (uiBase.ui.tab(tabHandle, "Radio Groups")) {
                drawRadioGroups(uiBase);
            }

            if (uiBase.ui.tab(tabHandle, "Settings")) {
                uiBase.ui.text("On Window Resize", Center);
                uiBase.ui.separator();

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
        if (ZuiUtils.iconButton(ui, icons, 1, 2, "Create Radio Group", false, false, 0.4)) {
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
            if (ZuiUtils.iconButton(ui, icons, 1, 3, "Delete group", false, !canDelete, 0.4)) {
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
                    var key = sceneData.getElementKey(button);
                    var label = key != null ? key : "(removed)";
                    if (group.activeButton == button) label += " [active]";

                    ui.row([2/3, 1/6, 1/6]);
                    ui.text(label, Left);

                    if (ZuiUtils.iconButton(ui, icons, 7, 0, "Set Active", group.activeButton == button, false, 0.4)) {
                        group.setActiveButton(button);
                        uiBase.hwnds[PanelProperties].redraws = 2;
                    }

                    if (ZuiUtils.iconButton(ui, icons, 1, 3, "Remove from group", false, false, 0.4)) {
                        removeButtonFromGroup(group, button);
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

        for (entry in currentScene.elements) {
            if (Std.isOfType(entry.element, RadioButton)) {
                entries.push({ key: entry.key, button: cast entry.element });
            }
        }

        return entries;
    }

    function getAvailableRadioGroups(currentRadioButton: RadioButton = null): Array<RadioGroup> {
        ensureRadioGroups();
        return sceneData.radioGroups;
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
        defaultRadioGroup = sceneData.radioGroups[0];
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
        radioGroupAddHandles.set(group.id, new Handle({position: 0}));
        radioGroupNameHandle.text = uniqueId;
    }

    function getUniqueRadioGroupId(requestedId: String): String {
        if (findRadioGroup(requestedId) == null) return requestedId;

        var prefix = requestedId;
        var nextIndex = 1;
        var suffixPattern = ~/^(.*)_(\d+)$/;
        if (suffixPattern.match(requestedId)) {
            prefix = suffixPattern.matched(1);
            var parsed = Std.parseInt(suffixPattern.matched(2));
            if (parsed != null) nextIndex = parsed + 1;
        }

        var candidate = prefix + "_" + nextIndex;
        while (findRadioGroup(candidate) != null) {
            nextIndex++;
            candidate = prefix + "_" + nextIndex;
        }

        return candidate;
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
    }

    function removeButtonFromGroup(group: RadioGroup, button: RadioButton): Void {
        if (button == null || group == null) return;

        group.remove(button);

        // Move to default (first) group instead of creating orphan solo groups
        var defaultGroup = sceneData.radioGroups[0];
        button.group = defaultGroup;
        defaultGroup.add(button);
    }

    function drawProperties(uiBase: UIBase): Void {
        var ui: Zui = uiBase.ui;

        // Get element name from SceneData
        var elemName = "";
        var currentScene = SceneData.data.currentScene;
        if (currentScene != null) {
            for (entry in currentScene.elements) {
                if (entry.element == selectedElement) {
                    elemName = entry.key;
                    break;
                }
            }
        }

		var elementType = CanvasUtils.getElementType(selectedElement);
		ui.text(elementType, Right);
        // Check if element is dynamically sized based on theme's minWidth/minHeight
        var isDynamicWidth: Bool = selectedElement.style != null && selectedElement.style.size.minWidth != 0;
        var isDynamicHeight: Bool = selectedElement.style != null && selectedElement.style.size.minHeight != 0;
        var isDynamicallySized: Bool = isDynamicWidth || isDynamicHeight;

        drawElementProperties(uiBase);

        ui.text("Element Properties", Center);
        ui.separator();
        // Key (Name) - editable text input
        nameHandle.text = elemName;
        var newName: String = ui.textInput(nameHandle, "Key", Right);
        if (nameHandle.changed) {
            if (newName != null && newName != "") sceneData.updateElementKey(selectedElement, newName);
            uiBase.hwnds[PanelHierarchy].redraws = 2;
            uiBase.hwnds[PanelProperties].redraws = 2;
        }

        // TID - editable text input
        var originalTID: String = selectedElement.getTID();
        tidHandle.text = originalTID;
        var newTID: String = ui.textInput(tidHandle, "TID", Right);
        if (tidHandle.changed) {
            if (newTID != null && newTID != "") {
                // Check if TID exists in theme
                var style: Style = Style.getStyle(newTID);
                if (style != null) {
                    ElementEvents.propertyChanged.emit(selectedElement, "TID", originalTID, newTID);
                    selectedElement.setTID(newTID);
                    if (style.size.minWidth != 0 || style.size.minHeight != 0) {
                        selectedElement.setPosition(0, 0);
                    }
                } else {
                    // TID not found in theme, show error and revert
                    trace('Error: TID "${newTID}" not found in theme. Reverting to "${originalTID}".');
                    tidHandle.text = originalTID;
                }

                Koui.updateElementSize(selectedElement);
                uiBase.hwnds[PanelHierarchy].redraws = 2;
		        uiBase.hwnds[PanelProperties].redraws = 2;
            }
        }

        // Anchor - 3x3 grid selector
        if (isDynamicallySized) {
            ui.row([1/4, 3/4]);
            ui.text("Anchor", Left);
            ui.text("Dynamically Sized", Left);
        } else {
            ui.text("Anchor", Left);
            drawAnchorGrid(ui, selectedElement);
        }

        // Position - label, reset button, and X/Y inputs in one row
        if (isDynamicallySized) {
            ui.row([1/4, 3/4]);
            ui.text("Position", Left);
            ui.text("Dynamically Sized", Left);
        } else {
            ui.row([1/4, 5/16, 5/16, 1/8]);
            ui.text("Position", Left);
            posXHandle.text = Std.string(selectedElement.posX);
            var posXStr: String = ui.textInput(posXHandle, "X", Right);
            if (posXHandle.changed) {
                var val: Int = Std.parseInt(posXStr);
                if (val != null) {
                    ElementEvents.propertyChanged.emit(selectedElement, "posX", selectedElement.posX, val);
                    selectedElement.posX = val;
                } else {
                    // Reject non-numeric input, reset to current value
                    posXHandle.text = Std.string(selectedElement.posX);
                }
            }
            posYHandle.text = Std.string(selectedElement.posY);
            var posYStr: String = ui.textInput(posYHandle, "Y", Right);
            if (posYHandle.changed) {
                var val: Int = Std.parseInt(posYStr);
                if (val != null) {
                    ElementEvents.propertyChanged.emit(selectedElement, "posY", selectedElement.posY, val);
                    selectedElement.posY = val;
                } else {
                    // Reject non-numeric input, reset to current value
                    posYHandle.text = Std.string(selectedElement.posY);
                }
            }
            if (ZuiUtils.iconButton(ui, icons, 6, 2, "Reset Position", false, false, 0.4)) {
                ElementEvents.propertyChanged.emit(selectedElement, ["posX", "posY"], [selectedElement.posX, selectedElement.posY], [0, 0]);
                selectedElement.posX = 0;
                selectedElement.posY = 0;
                posXHandle.text = Std.string(0);
                posYHandle.text = Std.string(0);
                selectedElement.invalidateElem();
            }
        }
        ui._y += 4;

        // Size - label, reset button, and Width/Height inputs in one row
        if (isDynamicallySized) {
            ui.row([1/4, 3/4]);
            ui.text("Size", Left);
            ui.text("Dynamically Sized", Left);
        } else {
            ui.row([1/4, 5/16, 5/16, 1/8]);
            ui.text("Size", Left);
            widthHandle.text = Std.string(selectedElement.width);
            var widthStr: String = ui.textInput(widthHandle, "W", Right);
            if (widthHandle.changed) {
                var val: Int = Std.parseInt(widthStr);
                if (val != null) {
                    ElementEvents.propertyChanged.emit(selectedElement, "width", selectedElement.width, val);
                    selectedElement.width = val;
                    Koui.updateElementSize(selectedElement);
                } else {
                    // Reject non-numeric input, reset to current value
                    widthHandle.text = Std.string(selectedElement.width);
                }
            }
            heightHandle.text = Std.string(selectedElement.height);
            var heightStr: String = ui.textInput(heightHandle, "H", Right);
            if (heightHandle.changed) {
                var val: Int = Std.parseInt(heightStr);
                if (val != null) {
                    ElementEvents.propertyChanged.emit(selectedElement, "height", selectedElement.height, val);
                    selectedElement.height = val;
                    Koui.updateElementSize(selectedElement);
                } else {
                    // Reject non-numeric input, reset to current value
                    heightHandle.text = Std.string(selectedElement.height);
                }
            }
            if (ZuiUtils.iconButton(ui, icons, 6, 2, "Reset Size", false, false, 0.4)) {
                var originalSize: Vec2 = elementSizes.get(selectedElement);
                if (originalSize != null) {
                    ElementEvents.propertyChanged.emit(selectedElement, ["width", "height"], [selectedElement.width, selectedElement.height], [Std.int(originalSize.x), Std.int(originalSize.y)]);
                    selectedElement.width = Std.int(originalSize.x);
                    selectedElement.height = Std.int(originalSize.y);
                    widthHandle.text = Std.string(selectedElement.width);
                    heightHandle.text = Std.string(selectedElement.height);
                    Koui.updateElementSize(selectedElement);
                }
            }
        }
        ui._y += 4;

        // Visible checkbox
        visibleHandle.selected = selectedElement.visible;
        var newVisible = ui.check(visibleHandle, "Visible");
        if (newVisible != selectedElement.visible) {
            ElementEvents.propertyChanged.emit(selectedElement, "visible", selectedElement.visible, newVisible);
            selectedElement.visible = newVisible;
        }

        // Disabled checkbox
        disabledHandle.selected = selectedElement.disabled;
        var newDisabled = ui.check(disabledHandle, "Disabled");
        if (newDisabled != selectedElement.disabled) {
            ElementEvents.propertyChanged.emit(selectedElement, "disabled", selectedElement.disabled, newDisabled);
            selectedElement.disabled = newDisabled;
        }

        if (selectedElement.canFocus) {
            ui._y += 4;
            ui.text("Navigation", Left);
            ui.separator();

            var focusableNames: Array<String> = ["(none)"];
            var elementMap: Map<String, Element> = new Map();
            if (currentScene != null) {
                for (entry in currentScene.elements) {
                    if (entry.element != selectedElement && entry.element.canFocus) {
                        focusableNames.push(entry.key);
                        elementMap.set(entry.key, entry.element);
                    }
                }
            }

            var drawFocusCombo = function(label: String, handle: Handle, currentTarget: Element, setTarget: Element->Void, propertyName: String) {
                var newIdx = ui.combo(handle, focusableNames, label, true, Right);
                if (handle.changed) {
                    var selectedName = focusableNames[newIdx];
                    var newTarget = selectedName == "(none)" ? null : elementMap.get(selectedName);
                    ElementEvents.propertyChanged.emit(selectedElement, propertyName, currentTarget, newTarget);
                    setTarget(newTarget);
                }
            };

            drawFocusCombo("Focus Up", focusUpHandle, selectedElement.focusUp, function(e) selectedElement.focusUp = e, "focusUp");
            drawFocusCombo("Focus Down", focusDownHandle, selectedElement.focusDown, function(e) selectedElement.focusDown = e, "focusDown");
            drawFocusCombo("Focus Left", focusLeftHandle, selectedElement.focusLeft, function(e) selectedElement.focusLeft = e, "focusLeft");
            drawFocusCombo("Focus Right", focusRightHandle, selectedElement.focusRight, function(e) selectedElement.focusRight = e, "focusRight");
        }
    }

    function drawAnchorGrid(ui: Zui, element: Element) {
        var currentAnchor = element.anchor;

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
                    ElementEvents.propertyChanged.emit(element, "anchor", currentAnchor, anchor);
                    element.anchor = anchor;
                    element.invalidateElem();
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

    function drawElementProperties(uiBase: UIBase) {
        var ui: Zui = uiBase.ui;

        if (selectedElement is Label) {
            ui.text("Label Properties", Center);
            ui.separator();

            var label: Label = cast(selectedElement, Label);
            labelTextHandle.text = label.text;
            var newText: String = ui.textInput(labelTextHandle, "Text", Right);
            if (labelTextHandle.changed) {
                if (newText != null && newText != "") {
                    ElementEvents.propertyChanged.emit(label, "text", label.text, newText);
                    label.text = newText;
                }
            }
        } else if (selectedElement is Button) {
            ui.text("Button Properties", Center);
            ui.separator();

            var button: Button = cast(selectedElement, Button);
            buttonTextHandle.text = button.text;
            var newText: String = ui.textInput(buttonTextHandle, "Text", Right);
            if (buttonTextHandle.changed) {
                if (newText != null && newText != "") {
                    ElementEvents.propertyChanged.emit(button, "text", button.text, newText);
                    button.text = newText;
                }
            }

            // TODO: Icon
            // TODO: Icon Size

            buttonIsPressedHandle.selected = button.isToggle && button.isPressed;
            var newPressed = ui.check(buttonIsPressedHandle, "Is Pressed");
            if (newPressed != button.isPressed) {
                ElementEvents.propertyChanged.emit(button, "isPressed", button.isPressed, newPressed);
                button.isPressed = newPressed;
            }

            buttonIsToggleHandle.selected = button.isToggle;
            var newToggle = ui.check(buttonIsToggleHandle, "Is Toggle");
            if (newToggle != button.isToggle) {
                ElementEvents.propertyChanged.emit(button, "isToggle", button.isToggle, newToggle);
                button.isToggle = newToggle;
            }
        } else if (selectedElement is RadioButton) {
            ui.text("Radio Button Properties", Center);
            ui.separator();

            var radioButton: RadioButton = cast(selectedElement, RadioButton);

            radioButtonTextHandle.text = radioButton.text;
            var newText: String = ui.textInput(radioButtonTextHandle, "Text", Right);
            if (radioButtonTextHandle.changed) {
                if (newText != null && newText != "") {
                    ElementEvents.propertyChanged.emit(radioButton, "text", radioButton.text, newText);
                    radioButton.text = newText;
                }
            }

            radioButtonIsCheckedHandle.selected = radioButton.isChecked;
            var newChecked = ui.check(radioButtonIsCheckedHandle, "Is Checked");
            if (newChecked != radioButton.isChecked) {
                ElementEvents.propertyChanged.emit(radioButton, "isChecked", radioButton.isChecked, newChecked);
                if (newChecked) {
                    radioButton.group.setActiveButton(radioButton);
                } else {
                    radioButton.isChecked = false;
                    var checkSquare: Panel = radioButton.getChild(new TypeMatchBehaviour(Panel));
                    checkSquare.setContextElement("");
                }
            }

            var availableGroups = getAvailableRadioGroups(radioButton);
            var groupNames: Array<String> = [];
            var currentIndex = 0;
            for (i in 0...availableGroups.length) {
                groupNames.push(availableGroups[i].id);
                if (radioButton.group != null && (availableGroups[i] == radioButton.group || availableGroups[i].id == radioButton.group.id)) {
                    currentIndex = i;
                }
            }

            if (groupNames.length == 0) {
                groupNames.push("(none)");
                radioButtonGroupHandle.position = 0;
                ui.combo(radioButtonGroupHandle, groupNames, "Radio Group", true, Right);
            } else {
                radioButtonGroupHandle.position = currentIndex;
                var newGroupIndex = ui.combo(radioButtonGroupHandle, groupNames, "Radio Group", true, Right);
                if (radioButtonGroupHandle.changed && newGroupIndex >= 0 && newGroupIndex < availableGroups.length) {
                    var newGroup = availableGroups[newGroupIndex];
                    if (radioButton.group == null || (radioButton.group != newGroup && radioButton.group.id != newGroup.id)) {
                        var oldGroupId = radioButton.group != null ? radioButton.group.id : "";
                        addButtonToGroup(newGroup, radioButton);
                        ElementEvents.propertyChanged.emit(radioButton, "radioGroup", oldGroupId, newGroup.id);
                    }
                }
            }
        } else if (selectedElement is Checkbox) {
            ui.text("Checkbox Properties", Center);
            ui.separator();

            var checkbox: Checkbox = cast(selectedElement, Checkbox);

            checkboxTextHandle.text = checkbox.text;
            var newText: String = ui.textInput(checkboxTextHandle, "Text", Right);
            if (checkboxTextHandle.changed) {
                if (newText != null && newText != "") {
                    ElementEvents.propertyChanged.emit(checkbox, "text", checkbox.text, newText);
                    checkbox.text = newText;
                }
            }

            checkboxIsCheckedHandle.selected = checkbox.isChecked;
            var newChecked = ui.check(checkboxIsCheckedHandle, "Is Checked");
            if (newChecked != checkbox.isChecked) {
                ElementEvents.propertyChanged.emit(checkbox, "isChecked", checkbox.isChecked, newChecked);
                checkbox.isChecked = newChecked;
                // Update the internal Panel's visual state
                var checkSquare: Panel = checkbox.getChild(new TypeMatchBehaviour(Panel));
                checkSquare.setContextElement(newChecked ? "checked" : "");
            }
        } else if (selectedElement is Progressbar) {
            ui.text("Progressbar Properties", Center);
            ui.separator();

            var progressbar: Progressbar = cast(selectedElement, Progressbar);

            progressbarTextHandle.text = progressbar.text;
            var newText: String = ui.textInput(progressbarTextHandle, "Text", Right);
            if (progressbarTextHandle.changed) {
                ElementEvents.propertyChanged.emit(progressbar, "text", progressbar.text, newText);
                progressbar.text = newText;
            }

            progressbarMinValueHandle.text = Std.string(progressbar.minValue);
            var newMinStr: String = ui.textInput(progressbarMinValueHandle, "Min Value", Right);
            if (progressbarMinValueHandle.changed) {
                var newMin: Float = Std.parseFloat(newMinStr);
                if (!Math.isNaN(newMin)) {
                    ElementEvents.propertyChanged.emit(progressbar, "minValue", progressbar.minValue, newMin);
                    progressbar.minValue = newMin;
                    progressbar.value = Math.max(newMin, progressbar.value);
                }
            }

            progressbarMaxValueHandle.text = Std.string(progressbar.maxValue);
            var newMaxStr: String = ui.textInput(progressbarMaxValueHandle, "Max Value", Right);
            if (progressbarMaxValueHandle.changed) {
                var newMax: Float = Std.parseFloat(newMaxStr);
                if (!Math.isNaN(newMax)) {
                    ElementEvents.propertyChanged.emit(progressbar, "maxValue", progressbar.maxValue, newMax);
                    progressbar.maxValue = newMax;
                    progressbar.value = Math.min(newMax, progressbar.value);
                }
            }

            progressbarPrecisionHandle.text = Std.string(progressbar.precision);
            var newPrecisionStr: String = ui.textInput(progressbarPrecisionHandle, "Precision", Right);
            var steps: Float = 0;
            if (progressbarPrecisionHandle.changed) {
                var newPrecision: Int = Std.parseInt(newPrecisionStr);
                if (newPrecision != null) {
                    newPrecision = Std.int(Math.max(0, newPrecision));
                    ElementEvents.propertyChanged.emit(progressbar, "precision", progressbar.precision, newPrecision);
                    progressbar.precision = newPrecision;
                    steps = Math.pow(10, -progressbar.precision);
                    progressbar.value = Math.round(progressbar.value / steps) * steps;
                }
            }

            // Value slider (below min/max so bounds are set first)
            progressbarValueHandle.value = progressbar.value;
            steps = Math.pow(10, -progressbar.precision);
            var newValue: Float = ui.slider(progressbarValueHandle, "Value", progressbar.minValue, progressbar.maxValue, true, 1 / steps, true, Right);
            if (progressbarValueHandle.changed) {
                newValue = Math.round(newValue / steps) * steps;
                progressbarValueHandle.value = newValue;
                ElementEvents.propertyChanged.emit(progressbar, "value", progressbar.value, newValue);
                progressbar.value = newValue;
            }
        } else if (selectedElement is ImagePanel) {
            ui.text("Image Properties", Center);
            ui.separator();

            var imagePanel: ImagePanel = cast(selectedElement, ImagePanel);

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
            imagePanelImageHandle.position = currentIndex;

            // Image dropdown
            var newIndex: Int = ui.combo(imagePanelImageHandle, imageNames, "Image", true, Right);
            if (imagePanelImageHandle.changed) {
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

            // Scale checkbox
            imagePanelScaleHandle.selected = imagePanel.scale;
            var newScale: Bool = ui.check(imagePanelScaleHandle, "Scale to Size");
            if (newScale != imagePanel.scale) {
                ElementEvents.propertyChanged.emit(imagePanel, "scale", imagePanel.scale, newScale);
                imagePanel.scale = newScale;
            }
        } else if (selectedElement is Slider) {
            ui.text("Slider Properties", Center);
            ui.separator();

            var slider: Slider = cast(selectedElement, Slider);

            var orientation: Array<String> = ["Up", "Down", "Left", "Right"];
            var currentIndex: Int = 0;
            switch (slider.orientation) {
                case Up: currentIndex = 0;
                case Down: currentIndex = 1;
                case Left: currentIndex = 2;
                case Right: currentIndex = 3;
            }
            sliderOrientationHandle.position = currentIndex;

            var newIndex: Int = ui.combo(sliderOrientationHandle, orientation, "Orientation", true, Right);
            if (sliderOrientationHandle.changed) {
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

            sliderMinValueHandle.text = Std.string(slider.minValue);
            var newMinStr: String = ui.textInput(sliderMinValueHandle, "Min Value", Right);
            if (sliderMinValueHandle.changed) {
                var newMin: Float = Std.parseFloat(newMinStr);
                if (!Math.isNaN(newMin)) {
                    ElementEvents.propertyChanged.emit(slider, "minValue", slider.minValue, newMin);
                    slider.minValue = newMin;
                    slider.value = Math.max(newMin, slider.value);
                }
            }

            sliderMaxValueHandle.text = Std.string(slider.maxValue);
            var newMaxStr: String = ui.textInput(sliderMaxValueHandle, "Max Value", Right);
            if (sliderMaxValueHandle.changed) {
                var newMax: Float = Std.parseFloat(newMaxStr);
                if (!Math.isNaN(newMax)) {
                    ElementEvents.propertyChanged.emit(slider, "maxValue", slider.maxValue, newMax);
                    slider.maxValue = newMax;
                    slider.value = Math.min(newMax, slider.value);
                }
            }

            sliderPrecisionHandle.text = Std.string(slider.precision);
            var newPrecisionStr: String = ui.textInput(sliderPrecisionHandle, "Precision", Right);
            var steps: Float = 0;
            if (sliderPrecisionHandle.changed) {
                var newPrecision: Int = Std.parseInt(newPrecisionStr);
                if (newPrecision != null) {
                    newPrecision = Std.int(Math.max(0, newPrecision));
                    ElementEvents.propertyChanged.emit(slider, "precision", slider.precision, newPrecision);
                    slider.precision = newPrecision;
                    steps = Math.pow(10, -slider.precision);
                    slider.value = Math.round(slider.value / steps) * steps;
                }
            }

            sliderValueHandle.value = slider.value;
            steps = Math.pow(10, -slider.precision);
            var newValue: Float = ui.slider(sliderValueHandle, "Value", slider.minValue, slider.maxValue, true, 1 / steps, true, Right);
            if (sliderValueHandle.changed) {
                newValue = Math.round(newValue / steps) * steps;
                sliderValueHandle.value = newValue;
                ElementEvents.propertyChanged.emit(slider, "value", slider.value, newValue);
                slider.value = newValue;
            }
        }
    }

    public function onElementAdded(entry: TElementEntry): Void {
        ensureRadioGroups();
        elementSizes.set(entry.element, new Vec2(entry.element.width, entry.element.height));

        if (Std.isOfType(entry.element, RadioButton)) {
            var radioButton: RadioButton = cast entry.element;
            if (radioButton.group != null) {
                // Ensure the button's group is registered globally
                if (findRadioGroup(radioButton.group.id) == null) {
                    sceneData.radioGroups.push(radioButton.group);
                    radioGroupAddHandles.set(radioButton.group.id, new Handle({position: 0}));
                    radioGroupRenameHandles.set(radioButton.group.id, new Handle({text: radioButton.group.id}));
                }
            }
        }
    }

    public function onElementSelected(element: Element): Void {
        selectedElement = element;

        // Update all handles with the new element's values
        if (element != null) {
            // Register element size if not already tracked (for elements loaded from file)
            if (!elementSizes.exists(element)) {
                elementSizes.set(element, new Vec2(element.width, element.height));
            }

            // Find element name
            var elemName: String = "";
            var currentScene = SceneData.data.currentScene;
            if (currentScene != null) {
                for (entry in currentScene.elements) {
                    if (entry.element == element) {
                        elemName = entry.key;
                        break;
                    }
                }
            }

            nameHandle.text = elemName;
            tidHandle.text = element.getTID();
            posXHandle.text = Std.string(element.posX);
            posYHandle.text = Std.string(element.posY);
            widthHandle.text = Std.string(element.width);
            heightHandle.text = Std.string(element.height);
            visibleHandle.selected = element.visible;
            disabledHandle.selected = element.disabled;
            anchorHandle.position = element.anchor;

            if (element.canFocus) {
                var getIndex = function(targetElem: Element): Int {
                    if (targetElem == null) return 0;
                    var idx = 1;
                    if (currentScene != null) {
                        for (entry in currentScene.elements) {
                            if (entry.element != element && entry.element.canFocus) {
                                if (entry.element == targetElem) return idx;
                                idx++;
                            }
                        }
                    }
                    return 0;
                };

                focusUpHandle.position = getIndex(element.focusUp);
                focusDownHandle.position = getIndex(element.focusDown);
                focusLeftHandle.position = getIndex(element.focusLeft);
                focusRightHandle.position = getIndex(element.focusRight);
            }
        }
    }

    public function onElementRemoved(element: Element): Void {
        elementSizes.remove(element);

        if (Std.isOfType(element, RadioButton)) {
            var radioButton: RadioButton = cast element;
            if (radioButton.group != null) {
                radioButton.group.remove(radioButton);
            }
        }
    }

    public static function getDefaultRadioGroup(): RadioGroup {
        if (instance != null) instance.ensureRadioGroups();
        return defaultRadioGroup;
    }

    public function onCanvasLoaded(): Void {
        scaleOnResizeHandle.selected = CanvasSettings.scaleOnResize;

        radioGroupAddHandles = new StringMap();
        radioGroupRenameHandles = new StringMap();
        radioGroupNameHandle.text = "RadioGroup";

        ensureRadioGroups();

        if (CanvasSettings.autoScale) scaleOnResizeGroup.position = 0;
        else if (CanvasSettings.scaleHorizontal) scaleOnResizeGroup.position = 1;
        else if (CanvasSettings.scaleVertical) scaleOnResizeGroup.position = 2;
    }

    public function setIcons(iconsImage: Dynamic): Void {
        icons = cast iconsImage;
    }
}