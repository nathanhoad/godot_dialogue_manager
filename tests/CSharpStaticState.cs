using Godot;

[GlobalClass]
public partial class CSharpStaticState : RefCounted
{
  public const int STATIC_CONSTANT = 3;

  public static int StaticField = 42;

  public static string StaticProperty { get; set; } = "static";

  public static int StaticMethod() => 7;

  public int InstanceValue = 1;
}
