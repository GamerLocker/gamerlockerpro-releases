static class GcPenalty
{
    // Timed griefing cooldowns observed with reason 22/23 count down below
    // zero after expiry and wrap around uint32. Do not treat that as 136 years.
    // Leave other reason codes untouched; they may represent a different ban.
    public static long RemainingSeconds(uint seconds, uint reason) =>
        seconds > int.MaxValue && (reason == 22 || reason == 23) ? 0 : seconds;
}
