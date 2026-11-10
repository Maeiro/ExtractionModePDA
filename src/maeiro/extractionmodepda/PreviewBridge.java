package maeiro.extractionmodepda;

import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.WeakHashMap;
import me.zed_0xff.zombie_buddy.Exposer;

public final class PreviewBridge {
    private static final Set<Object> scenes = Collections.newSetFromMap(new WeakHashMap<>());
    private static final Map<String, Field> fields = new HashMap<>();
    private static final Map<String, Method> methods = new HashMap<>();
    private static boolean warned;

    static { Exposer.exposeClass(PreviewBridge.class, "ExtractionModePDAPreviewBridge"); }

    private PreviewBridge() { }

    public static boolean ready() { return true; }

    public static void watch(Object scene) { scenes.add(scene); }

    private static Object field(Object object, String name) throws ReflectiveOperationException {
        String key = object.getClass().getName() + "#" + name;
        Field field = fields.get(key);
        if (field == null) {
            Class<?> type = object.getClass();
            while (type != null) {
                try { field = type.getDeclaredField(name); break; }
                catch (NoSuchFieldException ignored) { type = type.getSuperclass(); }
            }
            if (field == null) throw new NoSuchFieldException(key);
            field.setAccessible(true);
            fields.put(key, field);
        }
        return field.get(object);
    }

    private static Object call(Object object, String name, Object... args) throws ReflectiveOperationException {
        String key = object.getClass().getName() + "#" + name + "/" + args.length;
        Method method = methods.get(key);
        if (method == null) {
            Class<?> type = object.getClass();
            while (type != null && method == null) {
                for (Method candidate : type.getDeclaredMethods()) {
                    if (candidate.getName().equals(name) && candidate.getParameterCount() == args.length) {
                        method = candidate;
                        break;
                    }
                }
                type = type.getSuperclass();
            }
            if (method == null) throw new NoSuchMethodException(key);
            method.setAccessible(true);
            methods.put(key, method);
        }
        return method.invoke(object, args);
    }

    public static boolean skipPart(Object vehicle, Object part, boolean child) {
        try {
            if (!scenes.contains(field(vehicle, "scene"))) return false;
        } catch (ReflectiveOperationException failure) {
            return false;
        }
        try {
            Object id = child ? field(part, "parent") : call(part, "getId");
            Object info = id == null ? null : call(vehicle, "getModelInfoForPart", id);
            if (info == null) return child;
            Object model = field(info, "model");
            if (model == null || Boolean.TRUE.equals(field(model, "isStatic"))) return false;
            Object player = call(info, "getAnimationPlayer");
            if (player == null || !Boolean.TRUE.equals(call(player, "isReady"))) return true;
            Object skin = field(model, "tag");
            if (skin == null) return true;
            Object transforms = call(player, "getSkinTransforms", skin);
            if (transforms == null) {
                call(info, "updateAnimationPlayer");
                transforms = call(player, "getSkinTransforms", skin);
            }
            // B42 dereferences this array without a readiness check. Retry the part next frame.
            return transforms == null || Array.getLength(transforms) == 0;
        } catch (ReflectiveOperationException | RuntimeException failure) {
            if (!warned) {
                warned = true;
                System.out.println("[Extraction Mode PDA] Skipping an unavailable preview part: " + failure);
            }
            return true;
        }
    }
}
