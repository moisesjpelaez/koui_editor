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
import koui.elements.Button;
import koui.elements.Checkbox;
import koui.elements.Element;
import koui.elements.Label;
import koui.elements.Panel;
import koui.elements.Progressbar;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout.Anchor;
import koui.utils.ElementMatchBehaviour.TypeMatchBehaviour;

import zui.Zui;
import zui.Zui.Handle;

@:access(koui.elements.Element, zui.Zui)
class PropertiesPanel {
    var tabHandle: Handle;

    // Settings
    var expandOnResizeHandle: Handle;
    var scaleOnResizeHandle: Handle;
    var scaleOnResizeGroup: Handle;
    var undoStackSizeHandle: Handle;

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

    // Progressbar handles
    var progressbarMinValueHandle: Handle;
    var progressbarMaxValueHandle: Handle;
    var progressbarTextHandle: Handle;
    var progressbarPrecisionHandle: Handle;
    var progressbarValueHandle: Handle;

    var sceneData: SceneData = SceneData.data;

    // Initial values for reset functionality
    var elementSizes: Map<Element, Vec2> = new Map();

    var icons: Image;

    public function new() {
        tabHandle = new Handle({position: 0});

        // Initialize settings handles
        expandOnResizeHandle = new Handle({selected: true});
        scaleOnResizeHandle = new Handle({selected: true});
        scaleOnResizeGroup = new Handle({position: 0});
        undoStackSizeHandle = new Handle({text: "50"});

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

        labelTextHandle = new Handle({text: "New Label"});

        buttonTextHandle = new Handle({text: "New Button"});
        // buttonIconHandle = new Handle({text: ""});
        // buttonIconSizeHandle = new Handle({text: "16"});
        buttonIsPressedHandle = new Handle({selected: false});
        buttonIsToggleHandle = new Handle({selected: false});

        checkboxTextHandle = new Handle({text: ""});
        checkboxIsCheckedHandle = new Handle({selected: false});

        progressbarValueHandle = new Handle({value: 0});
        progressbarMinValueHandle = new Handle({text: "0"});
        progressbarMaxValueHandle = new Handle({text: "1"});
        progressbarTextHandle = new Handle({text: ""});
        progressbarPrecisionHandle = new Handle({text: "1"});

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

            if (uiBase.ui.tab(tabHandle, "Settings")) {
                uiBase.ui.text("Undo and Redo", Center);
                uiBase.ui.separator();

                // Undo stack size input (25-256)
                undoStackSizeHandle.text = Std.string(CanvasSettings.undoStackSize);
                var stackSizeStr: String = uiBase.ui.textInput(undoStackSizeHandle, "Steps", Right);
                if (undoStackSizeHandle.changed) {
                    var val: Null<Int> = Std.parseInt(stackSizeStr);
                    if (val != null) {
                        // Clamp to valid range
                        val = Std.int(Math.max(25, Math.min(256, val)));
                        CanvasSettings.undoStackSize = val;
                        undoStackSizeHandle.text = Std.string(val);
                    }
                }

                uiBase.ui.text("On Window Resize", Center);
                uiBase.ui.separator();

                CanvasSettings.expandOnResize = uiBase.ui.check(expandOnResizeHandle, "Expand");
                if (CanvasSettings.expandOnResize) CanvasSettings.scaleOnResize = uiBase.ui.check(scaleOnResizeHandle, "Scale");

                if (CanvasSettings.expandOnResize && CanvasSettings.scaleOnResize) {
                    uiBase.ui.text("Scale Mode");

                    // Set radio selection based on current settings
                    if (CanvasSettings.autoScale) scaleOnResizeGroup.position = 0;
                    else if (CanvasSettings.scaleHorizontal) scaleOnResizeGroup.position = 1;
                    else if (CanvasSettings.scaleVertical) scaleOnResizeGroup.position = 2;

                    // Radio buttons for scale mode (all use the same handle)
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
                if (koui.theme.Style.getStyle(newTID) != null) {
                    ElementEvents.propertyChanged.emit(selectedElement, "TID", originalTID, newTID);
                    selectedElement.setTID(newTID);
                } else {
                    // TID not found in theme, show error and revert
                    trace('Error: TID "${newTID}" not found in theme. Reverting to "${originalTID}".');
                    tidHandle.text = originalTID;
                }

                uiBase.hwnds[PanelHierarchy].redraws = 2;
		        uiBase.hwnds[PanelProperties].redraws = 2;
            }
        }

        // Anchor - 3x3 grid selector
        ui.text("Anchor", Left);
        drawAnchorGrid(ui, selectedElement);

        // Position - label, reset button, and X/Y inputs in one row
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
        ui._y += 4;

        // Size - label, reset button, and Width/Height inputs in one row
        ui.row([1/4, 5/16, 5/16, 1/8]);
        ui.text("Size", Left);
        widthHandle.text = Std.string(selectedElement.width);
        var widthStr: String = ui.textInput(widthHandle, "W", Right);
        if (widthHandle.changed) {
            var val: Int = Std.parseInt(widthStr);
            if (val != null) {
                ElementEvents.propertyChanged.emit(selectedElement, "width", selectedElement.width, val);
                selectedElement.width = val;
                if (selectedElement is GridLayout) {
                    var grid: GridLayout = cast(selectedElement, GridLayout);
                    grid.resize(grid.layoutWidth, grid.layoutHeight);
                    grid.invalidateElem();
                    grid.onResize();
                }
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
                if (selectedElement is GridLayout) {
                    var grid: GridLayout = cast(selectedElement, GridLayout);
                    grid.resize(grid.layoutWidth, grid.layoutHeight);
                    grid.invalidateElem();
                    grid.onResize();
                }
            } else {
                // Reject non-numeric input, reset to current value
                heightHandle.text = Std.string(selectedElement.height);
            }
        }
        if (ZuiUtils.iconButton(ui, icons, 6, 2, "Reset Size", false, false, 0.4)) {
            var originalSize: Vec2 = elementSizes.get(selectedElement);
            ElementEvents.propertyChanged.emit(selectedElement, ["width", "height"], [selectedElement.width, selectedElement.height], [Std.int(originalSize.x), Std.int(originalSize.y)]);
            selectedElement.width = Std.int(originalSize.x);
            selectedElement.height = Std.int(originalSize.y);
            widthHandle.text = Std.string(selectedElement.width);
            heightHandle.text = Std.string(selectedElement.height);
            selectedElement.invalidateElem();
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
        } else if (selectedElement is koui.elements.Checkbox) {
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
        }
    }

    public function onElementAdded(entry: TElementEntry): Void {
        elementSizes.set(entry.element, new Vec2(entry.element.width, entry.element.height));
    }

    public function onElementSelected(element: Element): Void {
        selectedElement = element;

        // Update all handles with the new element's values
        if (element != null) {
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
        }
    }

    public function onElementRemoved(element: Element): Void {
        elementSizes.remove(element);
    }

    public function onCanvasLoaded(): Void {
        scaleOnResizeHandle.selected = CanvasSettings.scaleOnResize;

        if (CanvasSettings.autoScale) scaleOnResizeGroup.position = 0;
        else if (CanvasSettings.scaleHorizontal) scaleOnResizeGroup.position = 1;
        else if (CanvasSettings.scaleVertical) scaleOnResizeGroup.position = 2;
    }

    public function setIcons(iconsImage: Image): Void {
        icons = iconsImage;
    }
}