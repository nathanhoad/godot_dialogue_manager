using Godot;

[GlobalClass]
public partial class CSharpBaseState : RefCounted
{
  public const int BASE_CONSTANT = 5;

  public enum BaseThings
  {
    FirstBaseThing,
    SecondBaseThing
  }

  public static int BaseStaticField = 10;

  public static string BaseStaticProperty { get; set; } = "base";

  public static int BaseStaticMethod() => 13;
}
