using Godot;
using Godot.Collections;
using System;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;

#nullable enable

namespace DialogueManagerRuntime
{

    public enum MutationBehaviour
    {
        Wait,
        DoNotWait,
        Skip
    }

    public enum TranslationSource
    {
        None,
        Guess,
        CSV,
        PO
    }

    public partial class DialogueManager : RefCounted
    {
        public delegate void DialogueStartedEventHandler(Resource dialogueResource);
        public delegate void PassedCueEventHandler(string cue);
        public delegate void GotDialogueEventHandler(DialogueLine dialogueLine);
        public delegate void MutatedEventHandler(Dictionary mutation);
        public delegate void DialogueEndedEventHandler(Resource dialogueResource);

        public static event DialogueStartedEventHandler? DialogueStarted;
        public static event PassedCueEventHandler? PassedCue;
        public static event GotDialogueEventHandler? GotDialogue;
        public static event MutatedEventHandler? Mutated;
        public static event DialogueEndedEventHandler? DialogueEnded;

        [Signal] public delegate void ResolvedEventHandler(double id, Variant value);

        private static Random random = new Random();

        private static readonly System.Collections.Generic.Dictionary<int, TaskCompletionSource<RefCounted?>> getNextLineRequests = new();
        private static readonly System.Collections.Generic.Dictionary<int, TaskCompletionSource<RefCounted?>> getLineRequests = new();
        private static readonly System.Collections.Generic.Dictionary<int, TaskCompletionSource<bool>> mutateRequests = new();

        private static Type[]? cachedAssemblyTypes;
        private static Type[] AssemblyTypes => cachedAssemblyTypes ??= Assembly.GetExecutingAssembly().GetTypes();

        private static readonly System.Collections.Generic.Dictionary<Type, MethodInfo[]> MethodCache = new();
        private static MethodInfo[] GetMethodsForType(Type type)
        {
            if (!MethodCache.TryGetValue(type, out var methods))
            {
                methods = type.GetMethods(BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);
                MethodCache[type] = methods;
            }
            return methods;
        }

        private static void OnBridgeGetNextDialogueLineCompleted(int callId, RefCounted? line)
        {
            if (getNextLineRequests.Remove(callId, out var tcs))
            {
                tcs.SetResult(line);
            }
        }

        private static void OnBridgeGetLineCompleted(int callId, RefCounted? line)
        {
            if (getLineRequests.Remove(callId, out var tcs))
            {
                tcs.SetResult(line);
            }
        }

        private static void OnBridgeMutated(int callId)
        {
            if (mutateRequests.Remove(callId, out var tcs))
            {
                tcs.SetResult(true);
            }
        }

        private static GodotObject? instance;
        public static GodotObject Instance => instance ??= InitializeInstance();

        private static GodotObject InitializeInstance()
        {
            var dm = Engine.GetSingleton("DialogueManager");
            dm.Connect("dialogue_started", Callable.From((Resource dialogueResource) => DialogueStarted?.Invoke(dialogueResource)));
            dm.Connect("passed_cue", Callable.From((string cue) => PassedCue?.Invoke(cue)));
            dm.Connect("got_dialogue", Callable.From((RefCounted line) => GotDialogue?.Invoke(new DialogueLine(line))));
            dm.Connect("mutated", Callable.From((Dictionary mutation) => Mutated?.Invoke(mutation)));
            dm.Connect("dialogue_ended", Callable.From((Resource dialogueResource) => DialogueEnded?.Invoke(dialogueResource)));

            dm.Connect("bridge_get_next_dialogue_line_completed", Callable.From((int callId, RefCounted? line) => OnBridgeGetNextDialogueLineCompleted(callId, line)));
            dm.Connect("bridge_get_line_completed", Callable.From((int callId, RefCounted? line) => OnBridgeGetLineCompleted(callId, line)));
            dm.Connect("bridge_mutated", Callable.From((int callId) => OnBridgeMutated(callId)));

            return dm;
        }


        public static Godot.Collections.Array GameStates
        {
            get => (Godot.Collections.Array)Instance.Get("game_states");
            set => Instance.Set("game_states", value);
        }


        public static bool IncludeSingletons
        {
            get => (bool)Instance.Get("include_singletons");
            set => Instance.Set("include_singletons", value);
        }


        public static bool IncludeClasses
        {
            get => (bool)Instance.Get("include_classes");
            set => Instance.Set("include_classes", value);
        }


        public static bool IncludeDialogueResourceAsSelf
        {
            get => (bool)Instance.Get("include_dialogue_resource_as_self");
            set => Instance.Set("include_dialogue_resource_as_self", value);
        }


        public static TranslationSource TranslationSource
        {
            get => (TranslationSource)(int)Instance.Get("translation_source");
            set => Instance.Set("translation_source", (int)value);
        }


        public static Func<Node> GetCurrentScene
        {
            set => Instance.Set("get_current_scene", Callable.From(value));
        }

        public static Resource CreateResourceFromText(string text)
        {
            return (Resource)Instance.Call("create_resource_from_text", text);
        }

        public static async Task<DialogueLine?> GetNextDialogueLine(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null, MutationBehaviour mutation_behaviour = MutationBehaviour.Wait)
        {
            int id = random.Next();
            var tcs = new TaskCompletionSource<RefCounted?>();
            getNextLineRequests[id] = tcs;

            Instance.Call("_bridge_get_next_dialogue_line", id, dialogueResource, key, extraGameStates ?? new Array<Variant>(), (int)mutation_behaviour);

            var line = await tcs.Task;
            return line == null ? null : new DialogueLine(line);
        }

        public static async Task<DialogueLine?> GetLine(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            int id = random.Next();
            var tcs = new TaskCompletionSource<RefCounted?>();
            getLineRequests[id] = tcs;

            Instance.Call("_bridge_get_line", id, dialogueResource, key, extraGameStates ?? new Array<Variant>());

            var line = await tcs.Task;
            return line == null ? null : new DialogueLine(line);
        }


        public static CanvasLayer ShowExampleDialogueBalloon(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (CanvasLayer)Instance.Call("show_example_dialogue_balloon", dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }


        public static Node ShowDialogueBalloonScene(string balloonScene, Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon_scene", balloonScene, dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }

        public static Node ShowDialogueBalloonScene(PackedScene balloonScene, Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon_scene", balloonScene, dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }

        public static Node ShowDialogueBalloonScene(Node balloonScene, Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon_scene", balloonScene, dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }


        public static Node ShowDialogueBalloon(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            return (Node)Instance.Call("show_dialogue_balloon", dialogueResource, key, extraGameStates ?? new Array<Variant>());
        }


        public static Array<string> StaticIdToLineIds(Resource dialogueResource, string staticId)
        {
            return (Array<string>)Instance.Call("static_id_to_line_ids", dialogueResource, staticId);
        }


        public static string StaticIdToLineId(Resource dialogueResource, string staticId)
        {
            return (string)Instance.Call("static_id_to_line_id", dialogueResource, staticId);
        }


        public static async Task Mutate(Dictionary mutation, Array<Variant>? extraGameStates = null, bool isInlineMutation = false)
        {
            int id = random.Next();
            var tcs = new TaskCompletionSource<bool>();
            mutateRequests[id] = tcs;

            Instance.Call("_bridge_mutate", id, mutation, extraGameStates ?? new Array<Variant>(), isInlineMutation);

            await tcs.Task;
        }


        public static Array<Dictionary> GetMembersForScript(Script script)
        {
            string typeName = script.ResourcePath.GetFile().GetBaseName();
            var matchingType = AssemblyTypes.FirstOrDefault(t => t.Name == typeName);

            if (matchingType == null) return new Array<Dictionary>();

            return GetMembersForType(matchingType);
        }


        public static Array<Dictionary> GetMembersForPropertyChain(Script script, Array<string> chain)
        {
            string typeName = script.ResourcePath.GetFile().GetBaseName();
            var currentType = AssemblyTypes.FirstOrDefault(t => t.Name == typeName);

            if (currentType == null) return new Array<Dictionary>();

            foreach (var segment in chain)
            {
                currentType = ResolvePropertyType(currentType, segment);
                if (currentType == null) return new Array<Dictionary>();
            }

            return GetMembersForType(currentType);
        }


        public static Dictionary GetMethodInfoForPropertyChain(Script script, Array<string> chain, string methodName)
        {
            string typeName = script.ResourcePath.GetFile().GetBaseName();
            var currentType = AssemblyTypes.FirstOrDefault(t => t.Name == typeName);

            if (currentType == null) return new Dictionary();

            foreach (var segment in chain)
            {
                currentType = ResolvePropertyType(currentType, segment);
                if (currentType == null) return new Dictionary();
            }

            var methodInfo = currentType
                .GetMethods(BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public)
                .FirstOrDefault(m => m.Name == methodName && !m.IsSpecialName);
            if (methodInfo == null) return new Dictionary();

            return BuildMethodDictionary(methodInfo);
        }


        private static Array<Dictionary> GetMembersForType(Type type)
        {
            Array<Dictionary> members = new Array<Dictionary>();

            if (type.IsEnum)
            {
                foreach (var name in type.GetEnumNames())
                {
                    members.Add(new Dictionary() {
                        { "name", name },
                        { "type", "enum" }
                    });
                }
                return members;
            }

            var memberInfos = type.GetMembers(BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);
            foreach (var memberInfo in memberInfos)
            {
                switch (memberInfo.MemberType)
                {
                    case MemberTypes.Field:
                        FieldInfo fieldInfo = (FieldInfo)memberInfo;
                        string fieldType;
                        if (fieldInfo.FieldType.ToString().Contains("EventHandler"))
                        {
                            fieldType = "signal";
                        }
                        else if (fieldInfo.IsLiteral)
                        {
                            fieldType = "constant";
                        }
                        else
                        {
                            fieldType = "property";
                        }
                        members.Add(new Dictionary() {
                            { "name", memberInfo.Name },
                            { "type", fieldType },
                            { "class_name", GetFriendlyTypeName(fieldInfo.FieldType) }
                        });
                        break;

                    case MemberTypes.Property:
                        PropertyInfo propInfo = (PropertyInfo)memberInfo;
                        members.Add(new Dictionary() {
                            { "name", memberInfo.Name },
                            { "type", "property" },
                            { "class_name", GetFriendlyTypeName(propInfo.PropertyType) }
                        });
                        break;

                    case MemberTypes.Method:
                        MethodInfo methodInfo = (MethodInfo)memberInfo;
                        if (methodInfo.IsSpecialName) continue;
                        members.Add(BuildMethodDictionary(methodInfo));
                        break;

                    case MemberTypes.NestedType:
                        members.Add(new Dictionary() {
                            { "name", memberInfo.Name },
                            { "type", "constant" }
                        });
                        break;

                    default:
                        continue;
                }
            }

            return members;
        }


        private static Dictionary BuildMethodDictionary(MethodInfo methodInfo)
        {
            var args = new Array<Dictionary>();
            foreach (var param in methodInfo.GetParameters())
            {
                args.Add(new Dictionary() {
                    { "name", param.Name ?? "" },
                    { "type", (int)Variant.Type.Nil },
                    { "class_name", GetFriendlyTypeName(param.ParameterType) }
                });
            }
            return new Dictionary() {
                { "name", methodInfo.Name },
                { "type", "method" },
                { "args", args }
            };
        }


        private static Type? ResolvePropertyType(Type type, string memberName)
        {
            var field = type.GetField(memberName, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);
            if (field != null) return field.FieldType;

            var prop = type.GetProperty(memberName, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);
            if (prop != null) return prop.PropertyType;

            var nested = type.GetNestedType(memberName, BindingFlags.Public);
            if (nested != null) return nested;

            return null;
        }


        private static string GetFriendlyTypeName(Type type)
        {
            if (type == typeof(int)) return "int";
            if (type == typeof(long)) return "long";
            if (type == typeof(float)) return "float";
            if (type == typeof(double)) return "double";
            if (type == typeof(bool)) return "bool";
            if (type == typeof(string)) return "string";
            if (type == typeof(void)) return "void";
            if (type == typeof(byte)) return "byte";
            if (type == typeof(short)) return "short";
            if (type == typeof(char)) return "char";
            if (type == typeof(decimal)) return "decimal";
            return type.Name;
        }


        public bool ThingHasConstant(GodotObject thing, string property)
        {
            var memberInfos = thing.GetType().GetMember(property, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);
            return memberInfos.Length > 0;
        }


        public Variant ResolveThingConstant(GodotObject thing, string property)
        {
            var memberInfos = thing.GetType().GetMember(property, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);
            foreach (var memberInfo in memberInfos)
            {
                if (memberInfo != null)
                {
                    try
                    {
                        switch (memberInfo)
                        {
                            case FieldInfo fieldInfo:
                                return ConvertValueToVariant(fieldInfo.GetValue(thing));

                            case PropertyInfo propInfo:
                                return ConvertValueToVariant(propInfo.GetValue(thing));

                            case Type nestedType when nestedType.IsEnum:
                                return GetEnumAsDictionary(nestedType);

                            default:
                                break;
                        }
                    }
                    catch (Exception e)
                    {
                        throw new Exception($"{property} is not supported by Variant.", e);
                    }
                }
            }

            throw new Exception($"{property} is not a public constant on {thing}");
        }


        Dictionary GetEnumAsDictionary(Type enumType)
        {
            Dictionary dictionary = new Dictionary();
            foreach (var value in enumType.GetEnumValuesAsUnderlyingType())
            {
                var key = enumType.GetEnumName(value);
                if (key != null)
                {
                    dictionary.Add(key, ConvertValueToVariant(value));
                }
            }
            return dictionary;
        }


        Variant ConvertValueToVariant(object? value)
        {
            if (value == null) return default;

            Type rawType = value.GetType();
            if (rawType.IsEnum)
            {
                value = Convert.ChangeType(value, Enum.GetUnderlyingType(rawType));
            }

            return value switch
            {
                Variant v => v,
                bool v => Variant.From(v),
                byte v => Variant.From((long)v),
                sbyte v => Variant.From((long)v),
                short v => Variant.From((long)v),
                ushort v => Variant.From((long)v),
                int v => Variant.From((long)v),
                uint v => Variant.From((long)v),
                long v => Variant.From(v),
                ulong v => Variant.From((long)v),
                float v => Variant.From((double)v),
                double v => Variant.From(v),
                string v => Variant.From(v),
                Godot.Collections.Array v => v,
                Godot.Collections.Dictionary v => v,
                GodotObject godotObj => Variant.From(godotObj),
                _ => ConvertOtherValueToVariant(value, rawType)
            };
        }


        // Anything Variant supports that isn't covered by the fast paths above (typed collections like Array<T> and Dictionary<TKey, TValue>, packed arrays,
        // Vector2/3/4, Color, etc) is boxed through the generic marshaller so it survives the trip into GDScript instead of silently becoming null.
        Variant ConvertOtherValueToVariant(object value, Type rawType)
        {
            try
            {
                MethodInfo from = typeof(Variant)
                    .GetMethods(BindingFlags.Public | BindingFlags.Static)
                    .First(m => m.Name == nameof(Variant.From) && m.IsGenericMethodDefinition)
                    .MakeGenericMethod(rawType);
                return (Variant)from.Invoke(null, new[] { value })!;
            }
            catch (Exception)
            {
                return default;
            }
        }


        public Array<Dictionary> GetMethodList(GodotObject thing)
        {
            var methodList = new Array<Dictionary>();

            if (thing == null) return methodList;

            Type type = thing.GetType();
            MethodInfo[] methodInfos = GetMethodsForType(type);

            foreach (MethodInfo method in methodInfos)
            {
                if (method.IsSpecialName) continue;

                var methodInfo = new Dictionary();
                methodInfo["name"] = method.Name;
                methodInfo["flags"] = 0;
                methodInfo["dotnet"] = true;

                var argsList = new Array<Dictionary>();
                ParameterInfo[] parameters = method.GetParameters();

                foreach (ParameterInfo parameter in parameters)
                {
                    var paramInfo = new Dictionary() { };
                    Variant.Type godotType = ConvertToVariantType(parameter.ParameterType);

                    paramInfo["name"] = parameter.Name ?? "";
                    paramInfo["type"] = (int)godotType;
                    if (godotType == Variant.Type.Object)
                    {
                        paramInfo["class_name"] = parameter.ParameterType.Name;
                    }
                    else
                    {
                        paramInfo["class_name"] = string.Empty;
                    }

                    argsList.Add(paramInfo);
                }

                methodInfo["args"] = argsList;
                methodList.Add(methodInfo);
            }

            return methodList;
        }


        private Variant.Type ConvertToVariantType(Type type)
        {
            if (type == typeof(void)) return Variant.Type.Nil;
            if (type == typeof(bool)) return Variant.Type.Bool;
            if (type == typeof(long) || type == typeof(int) || type == typeof(short) || type == typeof(byte)) return Variant.Type.Int;
            if (type == typeof(double) || type == typeof(float)) return Variant.Type.Float;
            if (type == typeof(string)) return Variant.Type.String;

            if (type == typeof(Vector2)) return Variant.Type.Vector2;
            if (type == typeof(Vector2I)) return Variant.Type.Vector2I;
            if (type == typeof(Rect2)) return Variant.Type.Rect2;
            if (type == typeof(Rect2I)) return Variant.Type.Rect2I;
            if (type == typeof(Vector3)) return Variant.Type.Vector3;
            if (type == typeof(Vector3I)) return Variant.Type.Vector3I;
            if (type == typeof(Transform2D)) return Variant.Type.Transform2D;
            if (type == typeof(Vector4)) return Variant.Type.Vector4;
            if (type == typeof(Vector4I)) return Variant.Type.Vector4I;
            if (type == typeof(Plane)) return Variant.Type.Plane;
            if (type == typeof(Quaternion)) return Variant.Type.Quaternion;
            if (type == typeof(Aabb)) return Variant.Type.Aabb;
            if (type == typeof(Basis)) return Variant.Type.Basis;
            if (type == typeof(Transform3D)) return Variant.Type.Transform3D;
            if (type == typeof(Projection)) return Variant.Type.Projection;

            if (type == typeof(Color)) return Variant.Type.Color;
            if (type == typeof(StringName)) return Variant.Type.StringName;
            if (type == typeof(NodePath)) return Variant.Type.NodePath;
            if (type == typeof(Rid)) return Variant.Type.Rid;

            if (typeof(GodotObject).IsAssignableFrom(type)) return Variant.Type.Object;
            if (typeof(Dictionary).IsAssignableFrom(type)) return Variant.Type.Dictionary;
            if (typeof(Godot.Collections.Array).IsAssignableFrom(type)) return Variant.Type.Array;

            if (type == typeof(byte[])) return Variant.Type.PackedByteArray;
            if (type == typeof(int[])) return Variant.Type.PackedInt32Array;
            if (type == typeof(long[])) return Variant.Type.PackedInt64Array;
            if (type == typeof(float[])) return Variant.Type.PackedFloat32Array;
            if (type == typeof(double[])) return Variant.Type.PackedFloat64Array;
            if (type == typeof(string[])) return Variant.Type.PackedStringArray;
            if (type == typeof(Vector2[])) return Variant.Type.PackedVector2Array;
            if (type == typeof(Vector3[])) return Variant.Type.PackedVector3Array;
            if (type == typeof(Color[])) return Variant.Type.PackedColorArray;
            if (type == typeof(Vector4[])) return Variant.Type.PackedVector4Array;

            return Variant.Type.Nil;
        }

        private bool IsCompatible(Type expectedType, Type providedType)
        {
            if (expectedType.IsAssignableFrom(providedType)) return true;

            Variant.Type expectedVariant = ConvertToVariantType(expectedType);
            Variant.Type actualVariant = ConvertToVariantType(providedType);

            return expectedVariant == actualVariant && expectedVariant != Variant.Type.Nil;
        }



        public bool ThingHasMethod(GodotObject thing, string method, Array<Variant> args)
        {
            return GetMethodInfoFor(thing, method, args) != null;
        }


        public async void ResolveThingMethod(float id, GodotObject thing, string method, Array<Variant> args)
        {
            // Add a single frame wait in case the method returns before signals can listen
            await ToSignal(Engine.GetMainLoop(), SceneTree.SignalName.ProcessFrame);

            var methodInfo = GetMethodInfoFor(thing, method, args);

            if (methodInfo == null)
            {
                EmitSignal(SignalName.Resolved, id, default);
                return;
            }

#nullable disable
            // Convert the method args to something reflection can handle
            ParameterInfo[] argTypes = methodInfo.GetParameters();
            object[] _args = new object[argTypes.Length];
            for (int i = 0; i < argTypes.Length; i++)
            {
                // check if args is assignable from derived type
                if (i < args.Count && args[i].Obj != null)
                {
                    if (argTypes[i].ParameterType.IsAssignableFrom(args[i].Obj.GetType()))
                    {
                        _args[i] = args[i].Obj;
                    }
                    // fallback to assigning primitive types
                    else
                    {
                        _args[i] = Convert.ChangeType(args[i].Obj, argTypes[i].ParameterType);
                    }
                }
                else if (argTypes[i].DefaultValue != null)
                {
                    _args[i] = argTypes[i].DefaultValue;
                }
            }

            // invoke method and handle the result based on return type
            object result = methodInfo.Invoke(thing, _args);

            if (result is Task taskResult)
            {
                await taskResult;
                try
                {
                    object value = taskResult.GetType().GetProperty("Result").GetValue(taskResult);
                    EmitSignal(SignalName.Resolved, id, ConvertValueToVariant(value));
                }
                catch (Exception)
                {
                    EmitSignal(SignalName.Resolved, id, default);
                }
            }
            else
            {
                EmitSignal(SignalName.Resolved, id, ConvertValueToVariant(result));
            }
        }
#nullable enable


        private MethodInfo? GetMethodInfoFor(GodotObject thing, string method, Array<Variant> args)
        {
            return GetMethodsForType(thing.GetType()).Where(m => m.Name == method).FirstOrDefault(m =>
            {
                ParameterInfo[] parameters = m.GetParameters();

                if (args.Count > parameters.Length) return false;

                for (int i = args.Count; i < parameters.Length; i++)
                {
                    if (!parameters[i].IsOptional) return false;
                }

                Type[] argTypes = args.Select(arg =>
                {
                    // If the item is boxed inside a Godot Variant, extract its actual type.
                    if (arg is Variant godotVariant)
                    {
                        return godotVariant.VariantType switch
                        {
                            Variant.Type.Nil => typeof(object),
                            Variant.Type.Bool => typeof(bool),
                            Variant.Type.Int => typeof(long), // Godot ints map to C# longs
                            Variant.Type.Float => typeof(double), // Godot floats map to C# doubles
                            Variant.Type.String => typeof(string),
                            Variant.Type.Object => godotVariant.AsGodotObject()?.GetType() ?? typeof(object),
                            _ => godotVariant.Obj?.GetType() ?? typeof(object)
                        };
                    }

                    return arg.GetType();
                }).ToArray();

                // Check each given parameter type against what the method wants.
                for (int i = 0; i < argTypes.Length; i++)
                {
                    Type expectedType = parameters[i].ParameterType;
                    Type actualType = argTypes[i];

                    // If a parameter isn't compatible skip this method overload.
                    if (!IsCompatible(expectedType, actualType))
                    {
                        return false;
                    }
                }

                return true;
            });
        }


        public static string GetErrorMessage(int error)
        {
            return (string)Instance.Call("_bridge_get_error_message", error);
        }
    }


    public partial class DialogueLine : RefCounted
    {
        public string Id { get; set; } = "";
        public string Type { get; set; } = "dialogue";
        public string NextId { get; set; } = "";
        public string Character { get; set; } = "";
        public string Text { get; set; } = "";
        public string StaticId { get; set; } = "";
        public Array<DialogueResponse> Responses { get; } = new Array<DialogueResponse>();
        public string? Time { get; private set; }
        public Dictionary Speeds { get; private set; } = new Dictionary();
        public Array<Godot.Collections.Array> InlineMutations { get; private set; } = new Array<Godot.Collections.Array>();
        public Array<DialogueLine> ConcurrentLines { get; } = new Array<DialogueLine>();
        public Array<Variant> ExtraGameStates { get; } = new Array<Variant>();
        public Array<string> Tags { get; private set; } = new Array<string>();

        public DialogueLine(RefCounted data)
        {
            Id = (string)data.Get("id");
            Type = (string)data.Get("type");
            NextId = (string)data.Get("next_id");
            Character = (string)data.Get("character");
            Text = (string)data.Get("text");
            StaticId = (string)data.Get("static_id");
            Speeds = (Dictionary)data.Get("speeds");
            InlineMutations = (Array<Godot.Collections.Array>)data.Get("inline_mutations");
            Time = (string)data.Get("time");
            Tags = (Array<string>)data.Get("tags");

            foreach (var concurrent_line_data in (Array<RefCounted>)data.Get("concurrent_lines"))
            {
                ConcurrentLines.Add(new DialogueLine(concurrent_line_data));
            }

            foreach (var response in (Array<RefCounted>)data.Get("responses"))
            {
                Responses.Add(new DialogueResponse(response));
            }
        }


        public bool HasTag(string tagName)
        {
            if (Tags.Contains(tagName))
            {
                return true;
            }
            else
            {
                string wrapped = $"{tagName}=";
                foreach (var tag in Tags)
                {
                    if (tag.StartsWith(wrapped))
                    {
                        return true;
                    }
                }
                return false;
            }
        }


        public string GetTagValue(string tagName)
        {
            string wrapped = $"{tagName}=";
            foreach (var tag in Tags)
            {
                if (tag.StartsWith(wrapped))
                {
                    return tag.Substring(wrapped.Length);
                }
            }
            return "";
        }

        public override string ToString()
        {
            switch (Type)
            {
                case "dialogue":
                    return $"<DialogueLine character=\"{Character}\" text=\"{Text}\">";
                case "mutation":
                    return "<DialogueLine mutation>";
                default:
                    return "";
            }
        }
    }


    public partial class DialogueResponse : RefCounted
    {
        public string NextId { get; set; } = "";
        public bool IsAllowed { get; set; } = true;
        public string ConditionAsText { get; set; } = "";
        public string Text { get; set; } = "";
        public string TranslationKey { get; set; } = "";
        public Array<string> Tags { get; private set; } = new Array<string>();

        public DialogueResponse(RefCounted data)
        {
            NextId = (string)data.Get("next_id");
            IsAllowed = (bool)data.Get("is_allowed");
            Text = (string)data.Get("text");
            TranslationKey = (string)data.Get("static_id");
            Tags = (Array<string>)data.Get("tags");
        }

        public bool HasTag(string tagName)
        {
            if (Tags.Contains(tagName))
            {
                return true;
            }
            else
            {
                string wrapped = $"{tagName}=";
                foreach (var tag in Tags)
                {
                    if (tag.StartsWith(wrapped))
                    {
                        return true;
                    }
                }
                return false;
            }
        }

        public string GetTagValue(string tagName)
        {
            string wrapped = $"{tagName}=";
            foreach (var tag in Tags)
            {
                if (tag.StartsWith(wrapped))
                {
                    return tag.Substring(wrapped.Length);
                }
            }
            return "";
        }

        public override string ToString()
        {
            return $"<DialogueResponse text=\"{Text}\"";
        }
    }
}

