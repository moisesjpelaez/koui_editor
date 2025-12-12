package arm;

import koui.elements.Element;

typedef HierarchyEntry = {
	var key: String;
	var element: Element;
}

class ElementsData {
    public static var data: ElementsData = new ElementsData();

    public var elements: Array<HierarchyEntry> = [];

    public function new() {

    }

    public function onElementAdded(entry: HierarchyEntry): Void {
        elements.push({ key: entry.key, element: entry.element });
    }

    /**
     * Update the key for an existing element in the hierarchy.
     */
    public function updateElementKey(element: Element, newKey: String): Void {
        for (entry in elements) {
            if (entry.element == element) {
                entry.key = newKey;
                return;
            }
        }
    }
}