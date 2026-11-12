using Godot;

[GlobalClass]
public partial class CSharpDerivedState : CSharpBaseState
{
  public const int DERIVED_CONSTANT = 6;

  public static int DerivedStaticField = 11;

  public static string DerivedStaticProperty { get; set; } = "derived";

  public static int DerivedStaticMethod() => 12;
}
