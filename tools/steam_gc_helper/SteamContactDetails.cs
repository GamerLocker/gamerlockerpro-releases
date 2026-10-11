using System.Net;
using System.Text.RegularExpressions;
using SteamKit2;

static class SteamContactDetails
{
    public static async Task<string?> FetchPhoneAsync(SteamClient client, string refreshToken)
    {
        try
        {
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(7));
            var id = client.SteamID!;
            var token = await client.Authentication.GenerateAccessTokenForAppAsync(id, refreshToken)
                .WaitAsync(timeout.Token);
            var cookies = new CookieContainer();
            cookies.Add(new Uri("https://store.steampowered.com"), new Cookie("steamLoginSecure",
                Uri.EscapeDataString($"{id.ConvertToUInt64()}||{token.AccessToken}"), "/") { Secure = true, HttpOnly = true });
            using var handler = new HttpClientHandler { CookieContainer = cookies };
            using var http = new HttpClient(handler);
            http.DefaultRequestHeaders.UserAgent.ParseAdd("GamerLocker/1.0");
            var html = await http.GetStringAsync("https://store.steampowered.com/account/?l=english", timeout.Token);
            return ParsePhone(html);
        }
        catch { return null; }
    }

    internal static string? ParsePhone(string html)
    {
        // The account page may provide only a masked number. Preserve that mask.
        // Never treat scripts, dates or arbitrary numbers as a phone number.
        foreach (Match match in Regex.Matches(html,
            "<(?:span|div)[^>]*class=[\"'][^\"']*(?:account_data_field|phone_number)[^\"']*[\"'][^>]*>([^<]+)</(?:span|div)>",
            RegexOptions.IgnoreCase))
        {
            var value = WebUtility.HtmlDecode(match.Groups[1].Value).Trim();
            if (value.Length is >= 4 and <= 40 &&
                Regex.IsMatch(value, @"^[+\d\s()*xX•●-]+$") &&
                value.Count(char.IsDigit) >= 2 &&
                (value.StartsWith('+') || value.Contains('*') || value.Contains('•') || value.Contains('●')))
                return value;
        }
        return null;
    }
}
