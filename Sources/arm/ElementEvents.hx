package arm;

import armory.system.Signal;

class ElementEvents {
    public static var elementAdded: Signal = new Signal(); // args: (key: String, element: Element)
    public static var elementSelected: Signal = new Signal(); // args: (element: Element)
	public static var elementDropped: Signal = new Signal(); // args: (element: Element, target: Element, zone: DropZone)

    public function new() {

    }
}