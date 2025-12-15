package arm;

import koui.elements.layouts.AnchorPane;
import arm.ElementEvents;
import koui.elements.Element;

typedef THierarchyEntry = {
	var key: String;
	var element: Element;
}

class ElementData {
    public static var data: ElementData = new ElementData();
    public static var root: AnchorPane;
    public var elements: Array<THierarchyEntry> = [];

    public function new() {
        ElementEvents.elementAdded.connect(onElementAdded);
    }

    public function onElementAdded(entry: THierarchyEntry): Void {
        elements.push({ key: entry.key, element: entry.element });
    }

    public function updateElementKey(element: Element, newKey: String): Void {
        for (entry in elements) {
            if (entry.element == element) {
                entry.key = newKey;
                return;
            }
        }
    }
}