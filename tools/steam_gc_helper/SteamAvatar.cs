static class SteamAvatar
{
    public static string? UrlFromHash(byte[]? hash)
    {
        if (hash is null || (hash.Length != 20 && hash.Length != 21)) return null;
        if (hash.Take(20).All(value => value == 0)) return null;
        var value = Convert.ToHexString(hash.AsSpan(0, 20)).ToLowerInvariant();
        return $"https://avatars.fastly.steamstatic.com/{value}_full.jpg";
    }
}
