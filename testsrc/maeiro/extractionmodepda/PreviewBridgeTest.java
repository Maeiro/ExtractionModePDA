package maeiro.extractionmodepda;

import java.util.HashMap;
import java.util.Map;

public final class PreviewBridgeTest {
    static class Model { boolean isStatic; Object tag = new Object(); }
    static class Player {
        boolean ready;
        Object[] transforms;
        public boolean isReady() { return ready; }
        public Object[] getSkinTransforms(Object skin) { return transforms; }
    }
    static class Info {
        Model model = new Model();
        Player player = new Player();
        boolean canInitialize = true;
        public Player getAnimationPlayer() { return player; }
        protected void updateAnimationPlayer() {
            if (canInitialize) player.transforms = new Object[]{new Object()};
        }
    }
    static class Part {
        String parent;
        public String getId() { return "door"; }
    }
    static class Vehicle {
        Object scene = new Object();
        Map<String, Info> parts = new HashMap<>();
        Info getModelInfoForPart(String id) { return parts.get(id); }
    }
    public static void main(String[] args) {
        Vehicle vehicle = new Vehicle();
        Part part = new Part();
        Info info = new Info();
        vehicle.parts.put("door", info);
        check(!PreviewBridge.skipPart(vehicle, part, false), "unrelated scenes are untouched");
        PreviewBridge.watch(vehicle.scene);
        check(previewcaller.InjectedCaller.skip(vehicle, part), "injected callers in another package can access the guard");
        check(PreviewBridge.skipPart(vehicle, part, false), "unready parts are deferred");
        info.player.ready = true;
        check(!PreviewBridge.skipPart(vehicle, part, false), "ready animation initializes transforms and renders");
        info.player.transforms = null;
        info.canInitialize = false;
        check(PreviewBridge.skipPart(vehicle, part, false), "null transforms never reach the native renderer");
        part.parent = "door";
        check(PreviewBridge.skipPart(vehicle, part, true), "attached parts wait for the parent animation");
        info.model.isStatic = true;
        check(!PreviewBridge.skipPart(vehicle, part, true), "static parents remain renderable");
        part.parent = "missing";
        check(PreviewBridge.skipPart(vehicle, part, true), "missing parents are skipped safely");
        System.out.println("PreviewBridgeTest passed");
    }
    private static void check(boolean condition, String reason) {
        if (!condition) throw new AssertionError(reason);
    }
}
