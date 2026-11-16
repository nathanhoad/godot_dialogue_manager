using Godot;

[GlobalClass]
public partial class CSharpStaticState : RefCounted
{
  public const int STATIC_CONSTANT = 3;

  public static int StaticField = 42;

  public static string StaticProperty { get; set; } = "static";

  public static int StaticMethod() => 7;

  public int InstanceValue = 1;

  public class Nested
  {
    public const int NESTED_CONSTANT = 11;

    public static int NestedField = 12;

    public static string NestedProperty { get; set; } = "nested";

    public static int NestedMethod(int value) => value * 2;

    public int NestedInstanceValue = 1;

    public static class Deeper
    {
      public const string DEEPER_CONSTANT = "deeper";

      public static string DeeperMethod() => "deepest";
    }
  }
}
