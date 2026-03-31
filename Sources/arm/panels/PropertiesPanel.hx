package arm.panels;

import arm.data.CanvasSettings;
import arm.data.SceneData;
import arm.events.SceneEvents;
import arm.events.ElementEvents;
import arm.editors.ElementRegistry;
import arm.commands.CommandManager;
import arm.commands.KeyRenameCommand;
import arm.types.Enums;
import arm.types.Types;
import arm.base.UIBase;
import arm.tools.CanvasUtils;
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

                    ui.row([5/6, 1/6]);
                    ui.text(label, Left);

                    if (ZuiUtils.iconButton(ui, icons, 7, 0, "Set Active", group.activeButton == button, false, 0.4)) {
                        group.setActiveButton(button);
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
            if (newName != null && newName != "" && newName != elemName) {
                sceneData.updateElementKey(selectedElement, newName);
                if (!CommandManager.instance.isUndoRedoing) {
                    CommandManager.instance.record(new KeyRenameCommand(selectedElement, elemName, newName));
                }
            }
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
        var editor = ElementRegistry.getForElement(selectedElement);
        if (editor != null) {
            editor.drawProperties(uiBase.ui, selectedElement);
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

            // Sync type-specific editor handles
            var editor = ElementRegistry.getForElement(element);
            if (editor != null) editor.syncHandles(element);
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