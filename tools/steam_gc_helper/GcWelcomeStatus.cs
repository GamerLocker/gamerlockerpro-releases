using ProtoBuf;

[ProtoContract]
sealed class CsgoGcClientWelcome : IExtensible
{
    [ProtoMember(6)] public byte[]? GameData2 { get; set; }
    [ProtoMember(3)] public List<GcSubscribedCache> Caches { get; set; } = [];
    private IExtension? extensionObject;
    public IExtension GetExtensionObject(bool createIfMissing) =>
        Extensible.GetExtensionObject(ref extensionObject, createIfMissing);
}

[ProtoContract]
sealed class GcAccountStatus
{
    [ProtoMember(1)] public uint? AccountId { get; set; }
    [ProtoMember(4)] public uint? PenaltySeconds { get; set; }
    [ProtoMember(5)] public uint? PenaltyReason { get; set; }
    [ProtoMember(6)] public int VacBanned { get; set; }
    [ProtoMember(17)] public int? PlayerLevel { get; set; }
}

[ProtoContract]
sealed class GcSubscribedCache
{
    [ProtoMember(2)] public List<GcSubscribedType> Objects { get; set; } = [];
    [ProtoMember(4)] public GcCacheOwner? Owner { get; set; }
}
[ProtoContract]
sealed class GcCacheOwner
{
    [ProtoMember(2)] public ulong Id { get; set; }
}
[ProtoContract]
sealed class GcSubscribedType
{
    [ProtoMember(1)] public int TypeId { get; set; }
    [ProtoMember(2)] public List<byte[]> Data { get; set; } = [];
}
[ProtoContract]
sealed class GcEconAccount
{
    [ProtoMember(13)] public uint? BonusXpFlags { get; set; }
    [ProtoMember(14)] public uint? ElevatedState { get; set; }
}

static class GcWelcomeStatus
{
    public static bool? ReadPrime(CsgoGcClientWelcome welcome, ulong ownSteamId)
    {
        foreach (var cache in welcome.Caches.Where(c => c.Owner?.Id == ownSteamId))
        foreach (var type in cache.Objects.Where(t => t.TypeId == 7))
        foreach (var data in type.Data)
        {
            try {
                var account = Serializer.Deserialize<GcEconAccount>(new MemoryStream(data));
                if (account.ElevatedState == 5 || (account.BonusXpFlags.GetValueOrDefault() & 16) != 0) return true;
                if (account.ElevatedState.GetValueOrDefault() == 0 &&
                    (account.ElevatedState.HasValue || account.BonusXpFlags.HasValue) &&
                    (account.BonusXpFlags.GetValueOrDefault() & 16) == 0) return false;
            } catch { }
        }
        return null;
    }
    public static bool TryRead(byte[]? data, uint ownAccountId, out GcAccountStatus? status)
    {
        status = null;
        if (data is null || data.Length == 0 || ownAccountId == 0) return false;
        try
        {
            var account = Serializer.Deserialize<GcAccountStatus>(new MemoryStream(data));
            if (account.AccountId != ownAccountId) return false;
            // This is the authenticated account's welcome snapshot, not a public
            // player profile. Optional numeric fields default to zero in protobuf.
            status = account;
            return true;
        }
        catch (Exception ex) when (ex is ProtoException or IOException or OverflowException or InvalidOperationException)
        {
            return false;
        }
    }
}
