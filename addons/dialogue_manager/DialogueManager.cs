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

        public static DialogueStartedEventHandler? DialogueStarted;
        public static PassedCueEventHandler? PassedCue;
        public static GotDialogueEventHandler? GotDialogue;
        public static MutatedEventHandler? Mutated;
        public static DialogueEndedEventHandler? DialogueEnded;

        [Signal] public delegate void ResolvedEventHandler(Variant value);

        private static Random random = new Random();

        private static GodotObject? instance;
        public static GodotObject Instance
        {
            get
            {
                if (instance == null)
                {
                    instance = Engine.GetSingleton("DialogueManager");
                    instance.Connect("dialogue_started", Callable.From((Resource dialogueResource) => DialogueStarted?.Invoke(dialogueResource)));
                    instance.Connect("passed_cue", Callable.From((string cue) => PassedCue?.Invoke(cue)));
                    instance.Connect("got_dialogue", Callable.From((RefCounted line) => GotDialogue?.Invoke(new DialogueLine(line))));
                    instance.Connect("mutated", Callable.From((Dictionary mutation) => Mutated?.Invoke(mutation)));
                    instance.Connect("dialogue_ended", Callable.From((Resource dialogueResource) => DialogueEnded?.Invoke(dialogueResource)));
                }
                return instance;
            }
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
            Instance.Call("_bridge_get_next_dialogue_line", id, dialogueResource, key, extraGameStates ?? new Array<Variant>(), (int)mutation_behaviour);
            while (true)
            {
                var result = await Instance.ToSignal(Instance, "bridge_get_next_dialogue_line_completed");
                if ((int)result[0] == id)
                {
                    return ((RefCounted)result[1] == null) ? null : new DialogueLine((RefCounted)result[1]);
                }
            }
        }

        public static async Task<DialogueLine?> GetLine(Resource dialogueResource, string key = "", Array<Variant>? extraGameStates = null)
        {
            int id = random.Next();
            Instance.Call("_bridge_get_line", id, dialogueResource, key, extraGameStates ?? new Array<Variant>());
            while (true)
            {
                var result = await Instance.ToSignal(Instance, "bridge_get_line_completed");
                if ((int)result[0] == id)
                {
                    return ((RefCounted)result[0] == null) ? null : new DialogueLine((RefCounted)result[0]);
                }
            }
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


        public static async void Mutate(Dictionary mutation, Array<Variant>? extraGameStates = null, bool isInlineMutation = false)
        {
            int id = random.Next();
            Instance.Call("_bridge_mutate", id, mutation, extraGameStates ?? new Array<Variant>(), isInlineMutation);
            while (true)
            {
                var result = await Instance.ToSignal(Instance, "bridge_mutated");
                if ((int)result[0] == id)
                {
                    return;
                }
            }
        }


        public static Array<Dictionary> GetMembersForScript(Script script)
        {
            string typeName = script.ResourcePath.GetFile().GetBaseName();
            var matchingType = Assembly.GetExecutingAssembly().GetTypes().FirstOrDefault(t => t.Name == typeName);
            if (matchingType == null) return new Array<Dictionary>();
            return GetMembersForType(matchingType);
        }


        public static Array<Dictionary> GetMembersForPropertyChain(Script script, Array<string> chain)
        {
            string typeName = script.ResourcePath.GetFile().GetBaseName();
            var currentType = Assembly.GetExecutingAssembly().GetTypes().FirstOrDefault(t => t.Name == typeName);
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
            var currentType = Assembly.GetExecutingAssembly().GetTypes().FirstOrDefault(t => t.Name == typeName);

            if (currentType == null) return new Dictionary();

            foreach (var segment in chain)
            {
                currentType = ResolvePropertyType(currentType, segment);
                if (currentType == null) return new Dictionary();
            }

            var methodInfo = currentType
                .GetMethods(BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.DeclaredOnly)
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

            var memberInfos = type.GetMembers(BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.DeclaredOnly);
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
                    { "name", param.Name },
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
            var field = type.GetField(memberName, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.DeclaredOnly);
            if (field != null) return field.FieldType;

            var prop = type.GetProperty(memberName, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.DeclaredOnly);
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
            var memberInfos = thing.GetType().GetMember(property, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.DeclaredOnly);
            return memberInfos.Length > 0;
        }


        public Variant ResolveThingConstant(GodotObject thing, string property)
        {
            var memberInfos = thing.GetType().GetMember(property, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.DeclaredOnly);
            foreach (var memberInfo in memberInfos)
            {
                if (memberInfo != null)
                {
                    try
                    {
                        switch (memberInfo.MemberType)
                        {
                            case MemberTypes.Field:
                                return ConvertValueToVariant((memberInfo as FieldInfo).GetValue(thing));

                            case MemberTypes.Property:
                                return ConvertValueToVariant((memberInfo as PropertyInfo).GetValue(thing));

                            case MemberTypes.NestedType:
                                var type = thing.GetType().GetNestedType(property);
                                if (type.IsEnum)
                                {
                                    return GetEnumAsDictionary(type);
                                }
                                break;

                            default:
                                continue;
                        }
                    }
                    catch (Exception e)
                    {
                        throw new Exception($"{property} is not supported by Variant.");
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


        Variant ConvertValueToVariant(object value)
        {
            if (value == null) return default;

            Type rawType = value.GetType();
            if (rawType.IsEnum)
            {
                var values = GetEnumAsDictionary(rawType);
                value = values[value.ToString()];
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
                GodotObject godotObj => Variant.From(godotObj),
                _ => default
            };
        }


        public Array<Dictionary> GetMethodList(GodotObject thing)
        {
            var methodList = new Array<Dictionary>();

            if (thing == null) return methodList;

            Type type = thing.GetType();
            MethodInfo[] methodInfos = type.GetMethods(BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public);

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

                    paramInfo["name"] = parameter.Name;
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
            return thing.GetType().GetMethods(BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public).Where(m => m.Name == method).FirstOrDefault(m =>
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
        private string id = "";
        public string Id
        {
            get => id;
            set => id = value;
        }

        private string type = "dialogue";
        public string Type
        {
            get => type;
            set => type = value;
        }

        private string next_id = "";
        public string NextId
        {
            get => next_id;
            set => next_id = value;
        }

        private string character = "";
        public string Character
        {
            get => character;
            set => character = value;
        }

        private string text = "";
        public string Text
        {
            get => text;
            set => text = value;
        }

        private string static_id = "";
        public string StaticId
        {
            get => static_id;
            set => static_id = value;
        }

        private Array<DialogueResponse> responses = new Array<DialogueResponse>();
        public Array<DialogueResponse> Responses
        {
            get => responses;
        }

        private string? time = null;
        public string? Time
        {
            get => time;
        }

        private Dictionary speeds = new Dictionary();
        public Dictionary Speeds
        {
            get => speeds;
        }

        private Array<Godot.Collections.Array> inline_mutations = new Array<Godot.Collections.Array>();
        public Array<Godot.Collections.Array> InlineMutations
        {
            get => inline_mutations;
        }

        private Array<DialogueLine> concurrent_lines = new Array<DialogueLine>();
        public Array<DialogueLine> ConcurrentLines
        {
            get => concurrent_lines;
        }

        private Array<Variant> extra_game_states = new Array<Variant>();
        public Array<Variant> ExtraGameStates
        {
            get => extra_game_states;
        }

        private Array<string> tags = new Array<string>();
        public Array<string> Tags
        {
            get => tags;
        }

        public DialogueLine(RefCounted data)
        {
            id = (string)data.Get("id");
            type = (string)data.Get("type");
            next_id = (string)data.Get("next_id");
            character = (string)data.Get("character");
            text = (string)data.Get("text");
            static_id = (string)data.Get("static_id");
            speeds = (Dictionary)data.Get("speeds");
            inline_mutations = (Array<Godot.Collections.Array>)data.Get("inline_mutations");
            time = (string)data.Get("time");
            tags = (Array<string>)data.Get("tags");

            foreach (var concurrent_line_data in (Array<RefCounted>)data.Get("concurrent_lines"))
            {
                concurrent_lines.Add(new DialogueLine(concurrent_line_data));
            }

            foreach (var response in (Array<RefCounted>)data.Get("responses"))
            {
                responses.Add(new DialogueResponse(response));
            }
        }


        public bool HasTag(string tagName)
        {
            string wrapped = $"{tagName}=";
            foreach (var tag in tags)
            {
                if (tag.StartsWith(wrapped))
                {
                    return true;
                }
            }
            return false;
        }


        public string GetTagValue(string tagName)
        {
            string wrapped = $"{tagName}=";
            foreach (var tag in tags)
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
            switch (type)
            {
                case "dialogue":
                    return $"<DialogueLine character=\"{character}\" text=\"{text}\">";
                case "mutation":
                    return "<DialogueLine mutation>";
                default:
                    return "";
            }
        }
    }


    public partial class DialogueResponse : RefCounted
    {
        private string next_id = "";
        public string NextId
        {
            get => next_id;
            set => next_id = value;
        }

        private bool is_allowed = true;
        public bool IsAllowed
        {
            get => is_allowed;
            set => is_allowed = value;
        }

        private string condition_as_text = "";
        public string ConditionAsText
        {
            get => condition_as_text;
            set => condition_as_text = value;
        }

        private string text = "";
        public string Text
        {
            get => text;
            set => text = value;
        }

        private string static_id = "";
        public string TranslationKey
        {
            get => static_id;
            set => static_id = value;
        }

        private Array<string> tags = new Array<string>();
        public Array<string> Tags
        {
            get => tags;
        }

        public DialogueResponse(RefCounted data)
        {
            next_id = (string)data.Get("next_id");
            is_allowed = (bool)data.Get("is_allowed");
            text = (string)data.Get("text");
            static_id = (string)data.Get("static_id");
            tags = (Array<string>)data.Get("tags");
        }

        public string GetTagValue(string tagName)
        {
            string wrapped = $"{tagName}=";
            foreach (var tag in tags)
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
            return $"<DialogueResponse text=\"{text}\"";
        }
    }
}

