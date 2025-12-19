package arm.events;

import armory.system.Signal;

class SceneEvents {
    public static var canvasLoaded: Signal = new Signal();
    public static var sceneAdded: Signal = new Signal(); // args: (sceneKey: String)
    public static var sceneChanged: Signal = new Signal(); // args: (sceneKey: String)
    public static var sceneNameChanged: Signal = new Signal(); // args: (oldKey: String, newKey: String)
    public static var sceneRemoved: Signal = new Signal(); // args: (sceneKey: String)
}