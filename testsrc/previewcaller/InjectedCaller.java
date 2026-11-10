package previewcaller;

import maeiro.extractionmodepda.PreviewBridge;

public final class InjectedCaller {
    private InjectedCaller() { }

    public static boolean skip(Object vehicle, Object part) {
        return PreviewBridge.skipPart(vehicle, part, false);
    }
}
