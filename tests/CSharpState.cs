using System.Threading.Tasks;
using Godot;

public partial class CSharpState : Node
{
  public const int SOME_CONSTANT = 2;

  [Export] public int SomeValue = 0;


  public async Task<Variant> GetAsyncValue()
  {
    await ToSignal(GetTree().CreateTimer(0.2f), Timer.SignalName.Timeout);
    return 100;
  }


  public async Task LongMutation()
  {
    await ToSignal(GetTree().CreateTimer(1.0f), Timer.SignalName.Timeout);
  }
}
