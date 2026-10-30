package arm.data;

import arm.events.ElementEvents;
import arm.events.SceneEvents;
import arm.tools.HierarchyUtils;
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

    /** The root pane of the current scene, or null if there is no scene. */
    public function getRoot(): Null<AnchorPane> {
        return currentScene != null ? currentScene.root : null;
    }

    public function getScene(sceneKey: String): Null<TSceneEntry> {
        for (scene in scenes) {
            if (scene.key == sceneKey) return scene;
        }
        return null;
    }

    public function updateElementKey(element: Element, newKey: String): Void {
        if (currentScene == null || !currentScene.keys.exists(element)) return;
        currentScene.keys.set(element, newKey);
    }

    public function getElementKey(element: Element, ?scene: TSceneEntry): Null<String> {
        if (scene == null) scene = currentScene;
        if (scene == null) return null;
        return scene.keys.get(element);
    }

    /** Whether `element` is a user element of the scene (not an internal part like a Button's label). */
    public function isRegistered(element: Element, ?scene: TSceneEntry): Bool {
        if (scene == null) scene = currentScene;
        return scene != null && scene.keys.exists(element);
    }

    public function registerElement(element: Element, key: String, ?scene: TSceneEntry): Void {
        if (scene == null) scene = currentScene;
        if (scene == null) return;
        scene.keys.set(element, key);
    }

    public function unregisterElement(element: Element, ?scene: TSceneEntry): Void {
        if (scene == null) scene = currentScene;
        if (scene == null) return;
        scene.keys.remove(element);
    }

    /** The user elements directly inside `parent`, in the order they are drawn. */
    public function getChildren(parent: Element, ?scene: TSceneEntry): Array<Element> {
        if (scene == null) scene = currentScene;
        if (scene == null) return [];
        return [for (child in HierarchyUtils.getChildren(parent)) if (scene.keys.exists(child)) child];
    }

    /** All user elements of the scene, parents before their children, in the order they are drawn. */
    public function getElements(?scene: TSceneEntry): Array<Element> {
        if (scene == null) scene = currentScene;
        var result: Array<Element> = [];
        if (scene != null) collectElements(scene.root, scene, result);
        return result;
    }

    function collectElements(parent: Element, scene: TSceneEntry, out: Array<Element>): Void {
        for (child in getChildren(parent, scene)) {
            out.push(child);
            collectElements(child, scene, out);
        }
    }

    /** Whether `element` is a user element attached to the current scene's tree. */
    public function isInCurrentScene(element: Element): Bool {
        if (currentScene == null || !currentScene.keys.exists(element)) return false;
        var current: Element = HierarchyUtils.getParentElement(element);
        while (current != null) {
            if (current == currentScene.root) return true;
            current = HierarchyUtils.getParentElement(current);
        }
        return false;
    }

    public function onElementAdded(entry: TElementEntry): Void {
        registerElement(entry.element, entry.key);
    }

    public function onElementRemoved(element: Element): Void {
        unregisterElement(element);
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
