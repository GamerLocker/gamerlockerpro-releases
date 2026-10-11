using System.Net;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using SteamKit2;
using SteamKit2.Authentication;

sealed record SteamGroupResult(string Status, string Message);

static class SteamGroupMembership
{
    public const uint GroupAccountId = 46564927;
    public static SteamID GroupSteamId => new(GroupAccountId, 0, EUniverse.Public, EAccountType.Clan);
    public static readonly Uri GroupUri = new("https://steamcommunity.com/groups/GamerLocker/");

    public static bool IsMemberPage(string html) => Regex.IsMatch(html,
        "(?:onclick|href)\\s*=\\s*[\"'][^\"']*(?:ConfirmLeaveGroup|LeaveGroup\\s*\\(|action=leave)",
        RegexOptions.IgnoreCase);

    public static async Task<SteamGroupResult> EnsureMemberAsync(
        SteamAuthentication authentication, SteamID ownId, string refreshToken)
    {
        using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(12));
        try
        {
            // Client tokens must be exchanged over this authenticated CM connection.
            var token = await authentication.GenerateAccessTokenForAppAsync(ownId, refreshToken)
                .WaitAsync(cancellation.Token);
            var sessionId = Convert.ToHexString(RandomNumberGenerator.GetBytes(12)).ToLowerInvariant();
            var cookies = new CookieContainer();
            cookies.Add(GroupUri, new Cookie("steamLoginSecure",
                Uri.EscapeDataString($"{ownId.ConvertToUInt64()}||{token.AccessToken}"), "/") { Secure = true, HttpOnly = true });
            cookies.Add(GroupUri, new Cookie("sessionid", sessionId, "/") { Secure = true });
            using var handler = new HttpClientHandler { CookieContainer = cookies };
            using var http = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("GamerLocker/1.0");
            using var page = await http.GetAsync(GroupUri, cancellation.Token);
            page.EnsureSuccessStatusCode();
            if (IsMemberPage(await page.Content.ReadAsStringAsync(cancellation.Token)))
                return new("already_member", "Grupo GamerLocker: participante.");

            using var form = new FormUrlEncodedContent(new Dictionary<string, string> {
                ["action"] = "join", ["sessionID"] = sessionId,
            });
            // Same group action used by the Steam Community join button.
            using var response = await http.PostAsync(
                $"https://steamcommunity.com/gid/{GroupSteamId.ConvertToUInt64()}", form, cancellation.Token);
            response.EnsureSuccessStatusCode();
            var body = await response.Content.ReadAsStringAsync(cancellation.Token);
            if (IsMemberPage(body)) return new("joined", "Entrada no grupo GamerLocker confirmada.");
            using var verification = await http.GetAsync(GroupUri, cancellation.Token);
            verification.EnsureSuccessStatusCode();
            if (IsMemberPage(await verification.Content.ReadAsStringAsync(cancellation.Token)))
                return new("joined", "Entrada no grupo GamerLocker confirmada.");
            return new("failed", "A Steam nao confirmou a entrada no grupo GamerLocker.");
        }
        catch (OperationCanceledException)
        {
            return new("failed", "Tempo esgotado ao entrar no grupo GamerLocker.");
        }
        catch
        {
            // Never expose authentication tokens, cookies or server responses.
            return new("failed", "Nao foi possivel entrar no grupo GamerLocker nesta consulta.");
        }
    }
}
