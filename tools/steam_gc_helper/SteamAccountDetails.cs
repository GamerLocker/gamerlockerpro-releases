using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using SteamKit2;
using SteamKit2.Internal;

sealed record SteamOwnedGame(int AppId, string Name, int Minutes, int RecentMinutes, uint LastPlayed);
sealed record SteamInventoryItem(string Id, string Name, string Type, string IconUrl, string Amount, bool Tradable, bool Marketable, bool IsMedal);
sealed record SteamDetails(string SteamId64, List<SteamOwnedGame> Games, string GamesStatus,
    uint? SteamLevel, List<string> Badges, string BadgesStatus, List<SteamInventoryItem> Inventory,
    string InventoryStatus, bool InventoryComplete, uint InventoryAppId, long? CreatedAt = null);

static class SteamAccountDetails
{
    public static async Task<SteamDetails> FetchAsync(SteamClient client, string refreshToken, uint appId)
    {
        var id = client.SteamID!;
        var unified = client.GetHandler<SteamUnifiedMessages>()!;
        unified.CreateService<Player>();
        using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(22));
        var ct = cancellation.Token;
        var games = new List<SteamOwnedGame>();
        string gamesStatus = "unavailable", badgesStatus = "unavailable", inventoryStatus = "unavailable";
        uint? level = null;
        long? createdAt = null;
        var badges = new List<string>();
        var inventory = new List<SteamInventoryItem>();
        bool complete = false;
        var gamesTask = ReadGames();
        var levelTask = ReadLevel();
        var profileTask = ReadProfile();
        var communityTask = ReadCommunity();
        await Task.WhenAll(gamesTask, levelTask, profileTask, communityTask);
        return new(id.ConvertToUInt64().ToString(), games, gamesStatus, level, badges,
            badgesStatus, inventory, inventoryStatus, complete, appId, createdAt);

        async Task ReadGames()
        {
            try
            {
                var response = await unified.SendMessage<CPlayer_GetOwnedGames_Request, CPlayer_GetOwnedGames_Response>(
                    "Player.GetOwnedGames#1", new() { steamid = id.ConvertToUInt64(), include_appinfo = true,
                    include_played_free_games = true, include_free_sub = true, skip_unvetted_apps = false, language = "brazilian" }).ToTask().WaitAsync(ct);
                if (response.Result != EResult.OK) return;
                games.AddRange(response.Body.games.Select(g => new SteamOwnedGame(g.appid, g.name,
                    g.playtime_forever, g.playtime_2weeks, g.rtime_last_played)));
                gamesStatus = "ok";
            }
            catch { }
        }
        async Task ReadLevel()
        {
            try
            {
                var response = await unified.SendMessage<CPlayer_GetGameBadgeLevels_Request, CPlayer_GetGameBadgeLevels_Response>(
                    "Player.GetGameBadgeLevels#1", new() { appid = 730 }).ToTask().WaitAsync(ct);
                if (response.Result == EResult.OK) level = response.Body.player_level;
            }
            catch { }
        }
        async Task ReadProfile()
        {
            try
            {
                var request = new CPlayer_GetPlayerLinkDetails_Request();
                request.steamids.Add(id.ConvertToUInt64());
                var response = await unified.SendMessage<CPlayer_GetPlayerLinkDetails_Request, CPlayer_GetPlayerLinkDetails_Response>(
                    "Player.GetPlayerLinkDetails#1", request).ToTask().WaitAsync(ct);
                var account = response.Body.accounts.FirstOrDefault();
                if (response.Result == EResult.OK && account?.private_data?.time_created > 0)
                    createdAt = account.private_data.time_created;
            }
            catch { }
        }
        async Task ReadCommunity()
        {
            try
            {
                var token = await client.Authentication.GenerateAccessTokenForAppAsync(id, refreshToken).WaitAsync(ct);
                var cookies = new CookieContainer();
                var community = new Uri("https://steamcommunity.com");
                cookies.Add(community, new Cookie("steamLoginSecure", Uri.EscapeDataString($"{id.ConvertToUInt64()}||{token.AccessToken}"), "/") { Secure = true, HttpOnly = true });
                using var handler = new HttpClientHandler { CookieContainer = cookies };
                using var http = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
                http.DefaultRequestHeaders.UserAgent.ParseAdd("GamerLocker/1.0");
                await Task.WhenAll(ReadBadges(http), ReadInventory(http));
            }
            catch { }
        }
        async Task ReadBadges(HttpClient http)
        {
            try
            {
                var html = await http.GetStringAsync($"https://steamcommunity.com/profiles/{id.ConvertToUInt64()}/badges/?l=brazilian", ct);
                badges.AddRange(ParseBadgeNames(html));
                // Login/blocked HTML must not be reported as an empty badge collection.
                if (html.Contains("badge_row", StringComparison.OrdinalIgnoreCase) || html.Contains("badges_sheet", StringComparison.OrdinalIgnoreCase)) badgesStatus = "ok";
            }
            catch { }
        }
        async Task ReadInventory(HttpClient http)
        {
            string? start = null;
            try
            {
                for (int page = 0; page < 30; page++)
                {
                    var context = appId == 753 ? 6 : 2;
                    var url = $"https://steamcommunity.com/inventory/{id.ConvertToUInt64()}/{appId}/{context}?l=brazilian&count=5000";
                    if (start != null) url += "&start_assetid=" + Uri.EscapeDataString(start);
                    using var response = await http.GetAsync(url, ct);
                    if (!response.IsSuccessStatusCode)
                    {
                        if (inventory.Count == 0) inventoryStatus = response.StatusCode switch {
                            HttpStatusCode.Forbidden => "private",
                            HttpStatusCode.TooManyRequests => "rate_limited",
                            _ => "unavailable",
                        };
                        return;
                    }
                    using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
                    var body = document.RootElement;
                    if (!body.TryGetProperty("success", out var success) || !IsTrue(success)) return;
                    inventory.AddRange(ParseInventory(body));
                    inventoryStatus = "ok";
                    if (!body.TryGetProperty("more_items", out var more) || !IsTrue(more)) { complete = true; return; }
                    var next = body.GetProperty("last_assetid").GetString();
                    if (string.IsNullOrEmpty(next) || next == start) return;
                    start = next;
                }
            }
            catch { }
        }
    }

    public static List<string> ParseBadgeNames(string html) => Regex.Matches(html,
        "<[^>]+class=[\"'][^\"']*\\bbadge_title\\b[^\"']*[\"'][^>]*>(.*?)</div>", RegexOptions.Singleline | RegexOptions.IgnoreCase)
        .Select(m => WebUtility.HtmlDecode(Regex.Replace(m.Groups[1].Value, "<[^>]*>", " ")).Trim())
        .Where(s => s.Length > 0).Distinct().ToList();

    public static List<SteamInventoryItem> ParseInventory(JsonElement body)
    {
        var result = new List<SteamInventoryItem>();
        if (!body.TryGetProperty("assets", out var assets)) return result;
        var descriptions = new Dictionary<string, JsonElement>();
        if (body.TryGetProperty("descriptions", out var values))
            foreach (var d in values.EnumerateArray()) descriptions[$"{Text(d, "classid")}_{Text(d, "instanceid")}"] = d;
        foreach (var a in assets.EnumerateArray())
        {
            descriptions.TryGetValue($"{Text(a, "classid")}_{Text(a, "instanceid")}", out var d);
            var name = Text(d, "market_hash_name");
            if (name.Length == 0) name = Text(d, "name");
            var type = Text(d, "type");
            var medal = Regex.IsMatch(name + " " + type, "medal|medalha|coin|moeda|collectible|colecion", RegexOptions.IgnoreCase);
            var icon = Text(d, "icon_url");
            result.Add(new(Text(a, "assetid"), name.Length > 0 ? name : "Item " + Text(a, "assetid"), type,
                icon.Length > 0 ? "https://community.fastly.steamstatic.com/economy/image/" + icon : "",
                Text(a, "amount"), TrueProperty(d, "tradable"), TrueProperty(d, "marketable"), medal));
        }
        return result;
    }
    static string Text(JsonElement value, string name) => value.ValueKind == JsonValueKind.Object && value.TryGetProperty(name, out var p) ? p.ToString() : "";
    public static bool IsTrue(JsonElement value) => value.ValueKind == JsonValueKind.True || value.ToString() == "1";
    static bool TrueProperty(JsonElement value, string name) => value.ValueKind == JsonValueKind.Object && value.TryGetProperty(name, out var p) && IsTrue(p);
}
