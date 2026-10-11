using ProtoBuf;

[ProtoContract]
sealed class CsgoGcClientWelcome : IExtensible
{
    [ProtoMember(6)] public byte[]? GameData2 { get; set; }
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
}

static class GcWelcomeStatus
{
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
