package arm.events;

import armory.system.Signal;
import koui.elements.Element;

class ElementEvents {
    public static var elementAdded: Signal = new Signal(); // args: (entry: TElementEntry)
    public static var selectionChanged: Signal = new Signal(); // no args, read arm.data.Selection
	public static var elementDropped: Signal = new Signal(); // args: (element: Element, target: Element, zone: DropZone)
    public static var elementNameChanged: Signal = new Signal(); // args: (element: Element, oldName: String, newName: String)
    public static var elementRemoved: Signal = new Signal(); // args: (element: Element)
}