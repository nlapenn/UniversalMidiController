namespace ControllerApp.Model
{
    public readonly struct NrpnAddress
    {
        public readonly int Msb;
        public readonly int Lsb;

        public NrpnAddress(int msb, int lsb)
        {
            Msb = msb;
            Lsb = lsb;
        }

        public override string ToString() => $"MSB={Msb} LSB={Lsb}";
    }
}
