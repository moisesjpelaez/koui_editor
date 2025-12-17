package arm.panels;

import arm.CanvasSettings;
import arm.ElementsData;
import arm.ElementEvents;
import arm.types.Enums;
import arm.base.UIBase;

import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Label;

import zui.Zui;
import zui.Zui.Handle;

class PropertiesPanel {
    var tabHandle: Handle;

    // Settings
    var scaleOnResizeHandle: Handle;
    var scaleOnResizeGroup: Handle;
    var expandHorizontalHandle: Handle;
    var expandVerticalHandle: Handle;
    var autoExpandHandle: Handle;

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

    // Label handles
    var labelTextHandle: Handle;

    // Button handles
    var buttonTextHandle: Handle;
    var buttonIconHandle: Handle;
    var buttonIconSizeHandle: Handle;
    var buttonIsPressedHandle: Handle;
    var buttonIsToggleHandle: Handle;

    var elementsData: ElementsData = ElementsData.data;
    var elements: Array<THierarchyEntry> = ElementsData.data.elements;

    public function new() {
        tabHandle = new Handle({position: 0});

        // Initialize settings handles
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

        labelTextHandle = new Handle({text: "New Label"});

        buttonTextHandle = new Handle({text: "New Button"});
        // buttonIconHandle = new Handle({text: ""});
        // buttonIconSizeHandle = new Handle({text: "16"});
        buttonIsPressedHandle = new Handle({selected: false});
        buttonIsToggleHandle = new Handle({selected: false});
        // TODO: button events. Use Signals?

        ElementEvents.elementSelected.connect(onElementSelected);
        ElementEvents.canvasLoaded.connect(onCanvasLoaded);
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

            if (uiBase.ui.tab(tabHandle, "Settings")) {
                uiBase.ui.text("Canvas Scale", Center);
                uiBase.ui.separator();

                CanvasSettings.scaleOnResize = uiBase.ui.check(scaleOnResizeHandle, "Scale on Resize");

                if (CanvasSettings.scaleOnResize) {
                    uiBase.ui.text("Scale Mode");

                    // Set radio selection based on current settings
                    if (CanvasSettings.expandHorizontal) scaleOnResizeGroup.position = 0;
                    else if (CanvasSettings.expandVertical) scaleOnResizeGroup.position = 1;
                    else if (CanvasSettings.autoExpand) scaleOnResizeGroup.position = 2;

                    // Radio buttons for scale mode (all use the same handle)
                    if (uiBase.ui.radio(scaleOnResizeGroup, 0, "Expand Horizontal")) {
                        CanvasSettings.expandHorizontal = true;
                        CanvasSettings.expandVertical = false;
                        CanvasSettings.autoExpand = false;
                    }

                    if (uiBase.ui.radio(scaleOnResizeGroup, 1, "Expand Vertical")) {
                        CanvasSettings.expandHorizontal = false;
                        CanvasSettings.expandVertical = true;
                        CanvasSettings.autoExpand = false;
                    }

                    if (uiBase.ui.radio(scaleOnResizeGroup, 2, "Auto Expand")) {
                        CanvasSettings.expandHorizontal = false;
                        CanvasSettings.expandVertical = false;
                        CanvasSettings.autoExpand = true;
                    }
                }
            }
		}
    }

    function drawProperties(uiBase: UIBase): Void {
        var ui: Zui = uiBase.ui;

        // Get element name from ElementsData
        var elemName = "";
        for (entry in elements) {
            if (entry.element == selectedElement) {
                elemName = entry.key;
                break;
            }
        }

        drawElementProperties(uiBase);

        ui.text("Element", Center);
        ui.separator();

        // Key (Name) - editable text input
        nameHandle.text = elemName;
        var newName: String = ui.textInput(nameHandle, "Key", Right);
        if (nameHandle.changed) {
            if (newName != null && newName != "") elementsData.updateElementKey(selectedElement, newName);
        }

        // TID - editable text input
        var originalTID: String = selectedElement.getTID();
        tidHandle.text = originalTID;
        var newTID: String = ui.textInput(tidHandle, "TID", Right);
        if (tidHandle.changed) {
            if (newTID != null && newTID != "") {
                // Check if TID exists in theme
                if (koui.theme.Style.getStyle(newTID) != null) {
                    selectedElement.setTID(newTID);
                } else {
                    // TID not found in theme, show error and revert
                    trace('Error: TID "${newTID}" not found in theme. Reverting to "${originalTID}".');
                    tidHandle.text = originalTID;
                }
            }
        }

        // Position - two columns for X and Y
        ui.text("Position", Left);
        ui.row([1/2, 1/2]);
        posXHandle.text = Std.string(selectedElement.posX);
        var posXStr: String = ui.textInput(posXHandle, "X", Right);
        if (posXHandle.changed) {
            var val: Int = Std.parseInt(posXStr);
            if (val != null) {
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
                selectedElement.posY = val;
            } else {
                // Reject non-numeric input, reset to current value
                posYHandle.text = Std.string(selectedElement.posY);
            }
        }

        // Size - two columns for Width and Height
        ui.text("Size", Left);
        ui.row([1/2, 1/2]);
        widthHandle.text = Std.string(selectedElement.width);
        var widthStr: String = ui.textInput(widthHandle, "Width", Right);
        if (widthHandle.changed) {
            var val: Int = Std.parseInt(widthStr);
            if (val != null) {
                selectedElement.width = val;
            } else {
                // Reject non-numeric input, reset to current value
                widthHandle.text = Std.string(selectedElement.width);
            }
        }

        heightHandle.text = Std.string(selectedElement.height);
        var heightStr: String = ui.textInput(heightHandle, "Height", Right);
        if (heightHandle.changed) {
            var val: Int = Std.parseInt(heightStr);
            if (val != null) {
                selectedElement.height = val;
            } else {
                // Reject non-numeric input, reset to current value
                heightHandle.text = Std.string(selectedElement.height);
            }
        }

        // Visible checkbox
        visibleHandle.selected = selectedElement.visible;
        selectedElement.visible = ui.check(visibleHandle, "Visible");

        // Disabled checkbox
        disabledHandle.selected = selectedElement.disabled;
        selectedElement.disabled = ui.check(disabledHandle, "Disabled");
    }

    function drawElementProperties(uiBase: UIBase) {
        var ui: Zui = uiBase.ui;

        if (selectedElement is Label) {
            ui.text("Label", Center);
            ui.separator();

            var label: Label = cast(selectedElement, Label);
            labelTextHandle.text = label.text;
            var newText: String = ui.textInput(labelTextHandle, "Text", Right);
            if (labelTextHandle.changed) {
                if (newText != null && newText != "") label.text = newText;
            }
        } else if (selectedElement is Button) {
            ui.text("Button", Center);
            ui.separator();

            var button: Button = cast(selectedElement, Button);
            buttonTextHandle.text = button.text;
            var newText: String = ui.textInput(buttonTextHandle, "Text", Right);
            if (buttonTextHandle.changed) {
                if (newText != null && newText != "") button.text = newText;
            }

            // TODO: Icon
            // TODO: Icon Size

            buttonIsPressedHandle.selected = button.isToggle && button.isPressed;
            button.isPressed = ui.check(buttonIsPressedHandle, "Is Pressed");

            buttonIsToggleHandle.selected = button.isToggle;
            button.isToggle = ui.check(buttonIsToggleHandle, "Is Toggle");
        }
    }

    public function onElementSelected(element: Element): Void {
        selectedElement = element;

        // Update all handles with the new element's values
        if (element != null) {
            // Find element name
            var elemName: String = "";
            for (entry in elements) {
                if (entry.element == element) {
                    elemName = entry.key;
                    break;
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
        }
    }

    public function onCanvasLoaded(): Void {
        scaleOnResizeHandle.selected = CanvasSettings.scaleOnResize;

        if (CanvasSettings.expandHorizontal) scaleOnResizeGroup.position = 0;
        else if (CanvasSettings.expandVertical) scaleOnResizeGroup.position = 1;
        else if (CanvasSettings.autoExpand) scaleOnResizeGroup.position = 2;
    }
}