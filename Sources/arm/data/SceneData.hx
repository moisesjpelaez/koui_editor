package arm.data;

import arm.events.ElementEvents;
import arm.events.SceneEvents;
import arm.types.Types;
import koui.elements.layouts.AnchorPane;
import koui.elements.Element;
import koui.utils.RadioGroup;

class SceneData {
    public static var data: SceneData = new SceneData();
    public var scenes: Array<TSceneEntry> = [];
    public var currentScene: TSceneEntry;
    public var radioGroups: Array<RadioGroup> = [];

    public function new() {
        ElementEvents.elementAdded.connect(onElementAdded);
        SceneEvents.sceneChanged.connect(onSceneChanged);
        // Note: sceneRemoved and elementRemoved are handled by KouiEditor directly
        // to support undo/redo (commands need to capture state before mutation).
    }

    public function updateElementKey(element: Element, newKey: String): Void {
        if (currentScene == null) return;
        for (entry in currentScene.elements) {
            if (entry.element == element) {
                entry.key = newKey;
                return;
            }
        }
    }

    public function getElementKey(element: Element): String {
        if (currentScene == null) return null;
        for (entry in currentScene.elements) {
            if (entry.element == element) {
                return entry.key;
            }
        }
        return null;
    }

    public function onElementAdded(entry: TElementEntry): Void {
        if (currentScene == null) return;
        currentScene.elements.push({ key: entry.key, element: entry.element });
    }

    public function onElementRemoved(element: Element): Void {
        if (currentScene == null) return;
        for (i in 0...currentScene.elements.length) {
            if (currentScene.elements[i].element == element) {
                currentScene.elements.splice(i, 1);
                break;
            }
        }
    }

    function onSceneChanged(sceneKey: String): Void {
        if (currentScene != null) currentScene.active = false;
        for (i in 0...scenes.length) {
            if (scenes[i].key == sceneKey) {
                currentScene = scenes[i];
                currentScene.active = true;
                return;
            }
        }
    }

    function onSceneRemoved(sceneKey: String): Void {
        for (i in 0...scenes.length) {
            if (scenes[i].key == sceneKey) {
                scenes[i].active = false;
                scenes.splice(i, 1);
                // If the removed scene was the current scene, switch to another scene if available
                if (currentScene != null && currentScene.key == sceneKey) {
                    if (scenes.length > 0) {
                        currentScene = scenes[i > 0 ? i - 1 : 0];
                        currentScene.active = true;
                    } else {
                        currentScene = null;
                    }
                }
                return;
            }
        }
    }
}