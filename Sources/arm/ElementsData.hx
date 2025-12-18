package arm;

import arm.ElementEvents;
import haxe.macro.Type.AbstractType;
import koui.elements.layouts.AnchorPane;
import koui.elements.Element;

typedef THierarchyEntry = {
	var key: String;
	var element: Element;
}

class ElementsData {
    public static var data: ElementsData = new ElementsData();
    public var root: AnchorPane;
    public var elements: Array<THierarchyEntry> = [];

    public function new() {
        ElementEvents.elementAdded.connect(onElementAdded);
        ElementEvents.elementRemoved.connect(onElementRemoved);
    }

    public function updateElementKey(element: Element, newKey: String): Void {
        for (entry in elements) {
            if (entry.element == element) {
                entry.key = newKey;
                return;
            }
        }
    }

    public function onElementAdded(entry: THierarchyEntry): Void {
        elements.push({ key: entry.key, element: entry.element });
    }

    public function onElementRemoved(element: Element): Void {
        for (i in 0...elements.length) {
            if (elements[i].element == element) {
                elements.splice(i, 1);
                break;
            }
        }
    }
}