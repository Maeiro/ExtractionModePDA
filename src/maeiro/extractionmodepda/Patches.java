package maeiro.extractionmodepda;

import me.zed_0xff.zombie_buddy.Patch;

public final class Patches {
    private Patches() { }

    @Patch(className = "zombie.gameStates.MainScreenState", methodName = "enter", warmUp = true)
    public static class ExposePreviewBridge {
        @Patch.OnExit
        public static void exit() { PreviewBridge.ready(); }
    }

    @Patch(className = "zombie.vehicles.UI3DScene$VehicleRenderData", methodName = "initPartModel", warmUp = true)
    public static class GuardAnimatedPart {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) Object vehicle, @Patch.Argument(1) Object part) {
            return PreviewBridge.skipPart(vehicle, part, false);
        }
    }

    @Patch(className = "zombie.vehicles.UI3DScene$VehicleRenderData", methodName = "initChildPartModel", warmUp = true)
    public static class GuardAttachedPart {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(@Patch.Argument(0) Object vehicle, @Patch.Argument(2) Object part) {
            return PreviewBridge.skipPart(vehicle, part, true);
        }
    }
}
