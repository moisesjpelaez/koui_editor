package arm.panels;

import arm.ElementsData;
import arm.ElementEvents;
import arm.types.Enums;
import arm.base.UIBase;

import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Label;

import zui.Zui.Handle;

class PropertiesPanel {
    var propertiesTabHandle: Handle;
    var settingsTabHandle: Handle;

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

    public function new() {
        propertiesTabHandle = new Handle();
        settingsTabHandle = new Handle();

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
    }

    public function draw(uiBase: UIBase, params: Dynamic): Void {
        if (uiBase.ui.window(uiBase.hwnds[PanelProperties], params.tabx, params.h0, params.w, params.h1)) {
            if (uiBase.ui.tab(propertiesTabHandle, "Properties")) {
                if (selectedElement != null) {
                    drawProperties(uiBase);
                } else {
                    uiBase.ui.text("No element selected");
                }
            }

            if (uiBase.ui.tab(settingsTabHandle, "Settings")) {
                // Settings content here
            }
		}
    }

    function drawProperties(uiBase: UIBase): Void {
        var ui = uiBase.ui;

        // Get element name from ElementsData
        var elemName = "";
        for (entry in ElementsData.data.elements) {
            if (entry.element == selectedElement) {
                elemName = entry.key;
                break;
            }
        }

        ui.text("Element", Center);
        ui.separator();

        // Key (Name) - editable text input
        nameHandle.text = elemName;
        var newName = ui.textInput(nameHandle, "Key", Right);
        if (nameHandle.changed) {
            if (newName != null && newName != "") ElementsData.data.updateElementKey(selectedElement, newName);
        }

        // TID - editable text input
        var originalTID = selectedElement.getTID();
        tidHandle.text = originalTID;
        var newTID = ui.textInput(tidHandle, "TID", Right);
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
        var posXStr = ui.textInput(posXHandle, "X", Right);
        if (posXHandle.changed) {
            var val = Std.parseInt(posXStr);
            if (val != null) {
                selectedElement.posX = val;
            } else {
                // Reject non-numeric input, reset to current value
                posXHandle.text = Std.string(selectedElement.posX);
            }
        }

        posYHandle.text = Std.string(selectedElement.posY);
        var posYStr = ui.textInput(posYHandle, "Y", Right);
        if (posYHandle.changed) {
            var val = Std.parseInt(posYStr);
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
        var widthStr = ui.textInput(widthHandle, "Width", Right);
        if (widthHandle.changed) {
            var val = Std.parseInt(widthStr);
            if (val != null) {
                selectedElement.width = val;
            } else {
                // Reject non-numeric input, reset to current value
                widthHandle.text = Std.string(selectedElement.width);
            }
        }

        heightHandle.text = Std.string(selectedElement.height);
        var heightStr = ui.textInput(heightHandle, "Height", Right);
        if (heightHandle.changed) {
            var val = Std.parseInt(heightStr);
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

        if (selectedElement is Label) {
            ui.text("Label", Center);
            ui.separator();

            var label: Label = cast(selectedElement, Label);
            labelTextHandle.text = label.text;
            var newText = ui.textInput(labelTextHandle, "Text", Right);
            if (labelTextHandle.changed) {
                if (newText != null && newText != "") label.text = newText;
            }
        } else if (selectedElement is Button) {
            ui.text("Button", Center);
            ui.separator();

            var button: Button = cast(selectedElement, Button);
            buttonTextHandle.text = button.text;
            var newText = ui.textInput(buttonTextHandle, "Text", Right);
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
            var elemName = "";
            for (entry in ElementsData.data.elements) {
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
}