package arm;

import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Label;

typedef HierarchyEntry = {
	var key: String;
	var element: Element;
}

// Use single data entry point
class ElementsData {
    public static var data: ElementsData = new ElementsData();

    public var elements: Array<HierarchyEntry> = [];
    public var buttonsCount: Int = 0;
    public var labelsCount: Int = 0;

    public function new() {

    }

    public function onElementAdded(entry: HierarchyEntry): Void {
        var key: String = entry.key;

        if (entry.element is Button) {
            buttonsCount++;
            key += '_' + buttonsCount;
        } else if (entry.element is Label) {
            labelsCount++;
            key += '_' + labelsCount;
        }

        elements.push({ key: key, element: entry.element });
    }
}