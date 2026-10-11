using System.Text;
using ProtoBuf;
using SteamKit2;

void Check(bool condition, string message)
{
    if (!condition) throw new Exception(message);
}
T Decode<T>(byte[] bytes) => Serializer.Deserialize<T>(new MemoryStream(bytes));

var active = Decode<CsgoMatchmakingGcHello>([0x20, 0xac, 0x02, 0x28, 0x04, 0x30, 0x01]);
Check(active.PenaltySeconds == 300 && active.PenaltyReason == 4 && active.VacBanned == 1,
    "Cooldown/VAC wire format changed");
var days = Decode<CsgoMatchmakingGcHello>([0x20, 0x80, 0xf5, 0x18]);
Check(days.PenaltySeconds == 408192, "Multi-day cooldown decoded incorrectly");
// The live GC response stores account status in welcome field 6 (game_data2).
var welcome = Decode<CsgoGcClientWelcome>([0x32, 0x08, 0x08, 0x2a, 0x20, 0xde, 0xfd, 0x16, 0x28, 0x16]);
Check(GcWelcomeStatus.TryRead(welcome.GameData2, 42, out var status) &&
    status!.PenaltySeconds == 376542 && status.PenaltyReason == 22,
    "Welcome game_data2 must expose the multi-day cooldown without waiting for 9110");
Check(!GcWelcomeStatus.TryRead(welcome.GameData2, 43, out _), "Foreign account welcome must be ignored");
Check(!GcWelcomeStatus.TryRead(null, 42, out _) && !GcWelcomeStatus.TryRead([], 42, out _),
    "Missing welcome account data must retain the matchmaking fallback");
Check(!GcWelcomeStatus.TryRead([0x08, 0x2a, 0x20, 0x80], 42, out _),
    "Malformed welcome must not report no cooldown");
Check(GcWelcomeStatus.TryRead([0x08, 0x2a], 42, out var clear) && clear!.PenaltySeconds is null,
    "Authenticated welcome must retain protobuf defaults for zero penalties");
Check(GcWelcomeStatus.TryRead([0x08, 0x2a, 0x30, 0x01], 42, out var banned) && banned!.VacBanned == 1,
    "Welcome VAC status must be preserved");
var hello = new CsgoGcClientHello { Version = 2000244, ClientSessionNeed = 0, ClientLauncher = 0, SteamLauncher = 0 };
using var helloWire = new MemoryStream();
Serializer.Serialize(helloWire, hello);
Check(helloWire.ToArray().SequenceEqual(new byte[] { 0x08, 0xf4, 0x8a, 0x7a }),
    "GC handshake must preserve the user's ZIP wire format");

foreach (var result in new[] { EResult.InvalidPassword, EResult.Expired, EResult.Revoked,
    EResult.AccessDenied, EResult.AccountLogonDenied, EResult.AccountLoginDeniedNeedTwoFactor })
    Check(SteamSessionPolicy.ShouldRetryCredentials(result), "Rejected token must retry credentials");
foreach (var result in new[] { EResult.OK, EResult.NoConnection, EResult.ServiceUnavailable,
    EResult.RateLimitExceeded, EResult.Timeout })
    Check(!SteamSessionPolicy.ShouldRetryCredentials(result), "Transient failure must preserve session");

var auth = new RequestAuthenticator(new Request(TwoFactorCode: "12345", AuthCode: "ABCDE"));
Check(SteamGroupMembership.GroupSteamId.ConvertToUInt64() == 103582791476086335,
    "GamerLocker clan ID must map to the correct SteamID64");
Check(SteamGroupMembership.IsMemberPage("<a onclick=\"ConfirmLeaveGroup('123')\">Leave</a>"),
    "Membership confirmation must recognize the leave button");
Check(!SteamGroupMembership.IsMemberPage("<script>function LeaveGroup() {}</script><a onclick=\"JoinGroup()\">Join</a>"),
    "A shared JavaScript function must not be mistaken for membership");
Check(!new Request().JoinGamerLockerGroup, "Diagnostic requests must not join groups unless explicitly enabled");
Check(SteamAvatar.UrlFromHash(null) is null && SteamAvatar.UrlFromHash(new byte[20]) is null,
    "Missing avatar hashes must retain the public profile fallback");
Check(SteamAvatar.UrlFromHash(Enumerable.Repeat((byte)0xab, 20).ToArray()) ==
    "https://avatars.fastly.steamstatic.com/abababababababababababababababababababab_full.jpg",
    "Steam persona avatar hash must resolve to the full-size image");
Check(await auth.GetDeviceCodeAsync(false) == "12345", "First Guard code must be submitted");
Check(!await auth.AcceptDeviceConfirmationAsync(), "An explicit code must take precedence over phone approval");
Check(await new RequestAuthenticator(new Request(PreferDeviceConfirmation: true)).AcceptDeviceConfirmationAsync(),
    "Mobile approval was refused by the authenticator");
try { await auth.GetDeviceCodeAsync(true); throw new Exception("Rejected code was resubmitted"); }
catch (GuardCodeRequiredException ex) { Check(ex.GuardType == "mobile", "Incorrect Guard type"); }
try { await auth.GetEmailCodeAsync("test@example.invalid", true); throw new Exception("Rejected email code was resubmitted"); }
catch (GuardCodeRequiredException ex) { Check(ex.GuardType == "email", "Incorrect Guard type"); }

var root = Path.GetFullPath(Path.Combine("tools", "steam_gc_helper_protocol_tests", "session-test-" + Guid.NewGuid().ToString("N")));
var workspace = Path.GetFullPath(Directory.GetCurrentDirectory()) + Path.DirectorySeparatorChar;
Check(root.StartsWith(workspace, StringComparison.OrdinalIgnoreCase), "Test files must stay inside workspace");
try
{
    var store = new SteamSessionStore(root);
    var first = new SteamSavedSession("test_alpha", "fake-refresh-token-alpha", "fake-guard-data-alpha");
    var second = new SteamSavedSession("test_beta", "fake-refresh-token-beta", "fake-guard-data-beta");
    Check(store.Load("test_alpha") is null, "Missing session must require login");
    Check(store.Save("test_alpha", first) && store.Save("test_beta", second), "DPAPI persistence failed");
    var reopened = new SteamSessionStore(root);
    Check(reopened.Load(" TEST_ALPHA ") == first, "Session must survive a new store instance and login normalization");
    Check(reopened.Load("test_beta") == second, "Accounts must retain separate sessions");
    Check(!store.Save("test_beta", first), "Session must not be saved under another account");
    foreach (var file in Directory.GetFiles(root))
    {
        var contents = Encoding.UTF8.GetString(File.ReadAllBytes(file));
        Check(!contents.Contains("fake-refresh-token") && !contents.Contains("fake-guard-data") &&
            !contents.Contains("test_alpha") && !contents.Contains("test_beta"), "Session file contains plaintext secrets");
    }
    Check(store.Save("test_alpha", first with { RefreshToken = "" }), "Token invalidation failed");
    Check(reopened.Load("test_alpha") is { RefreshToken: "", GuardData: "fake-guard-data-alpha" },
        "Invalidating a token must preserve remembered Guard data");
    Check(reopened.Load("test_beta") == second, "Invalidating one account changed another");
    foreach (var file in Directory.GetFiles(root)) File.WriteAllBytes(file, [1, 2, 3]);
    Check(store.Load("test_alpha") is null && store.Load("test_beta") is null, "Corrupt sessions must fall back to login");
}
finally
{
    if (Directory.Exists(root))
    {
        foreach (var file in Directory.GetFiles(root)) File.Delete(file);
        Directory.Delete(root);
    }
}
Console.WriteLine("PASS: welcome cooldown/VAC and fallback, ZIP handshake, token fallback, Guard retry, per-account DPAPI persistence, corruption and plaintext exclusion.");
using (var inventory = System.Text.Json.JsonDocument.Parse("""
{"assets":[{"assetid":"99","classid":"10","instanceid":"0","amount":"1"},{"assetid":"100","classid":"11","instanceid":"0","amount":"2"}],
"descriptions":[{"classid":"10","instanceid":"0","market_hash_name":"5 Year Veteran Coin","type":"Collectible","icon_url":"test-icon","tradable":0,"marketable":0},
{"classid":"11","instanceid":"0","name":"Skin","tradable":1,"marketable":1}]}
"""))
{
    var items = SteamAccountDetails.ParseInventory(inventory.RootElement);
    Check(items.Count == 2 && items[0].IsMedal && items[0].Id == "99" && !items[0].Tradable,
        "Inventory descriptions did not match asset identity");
    Check(items[1].Name == "Skin" && items[1].Amount == "2" && items[1].Marketable,
        "Inventory quantities or permissions decoded incorrectly");
}
Check(SteamAccountDetails.ParseBadgeNames("<div class=\"badge_title\">Test &amp; badge <span>level 2</span></div>").Single().Contains("Test & badge"),
    "Badge HTML title parsing failed");
Console.WriteLine("PASS: inventory asset/description matching, medal classification and badge names.");
var levelStatus = Decode<GcAccountStatus>([0x08, 0x2a, 0x88, 0x01, 0x02]);
Check(levelStatus.PlayerLevel == 2 && Decode<GcAccountStatus>([0x08, 0x2a]).PlayerLevel is null,
    "Absent CS2 level must not become a fabricated zero");
var primeWelcome = new CsgoGcClientWelcome { Caches = [new GcSubscribedCache {
    Owner = new GcCacheOwner { Id = 123 }, Objects = [new GcSubscribedType { TypeId = 7, Data = [[0x70, 0x05]] }]
}] };
Check(GcWelcomeStatus.ReadPrime(primeWelcome, 123) == true && GcWelcomeStatus.ReadPrime(primeWelcome, 124) is null,
    "Prime metadata belongs to a different account");
primeWelcome.Caches[0].Objects[0].Data[0] = [0x68, 0x10];
Check(GcWelcomeStatus.ReadPrime(primeWelcome, 123) == true, "Legacy Prime bit not recognized");
primeWelcome.Caches[0].Objects[0].Data[0] = [0x68, 0x00];
Check(GcWelcomeStatus.ReadPrime(primeWelcome, 123) == false, "Non-Prime default elevated state not recognized");
primeWelcome.Caches[0].Objects[0].Data[0] = [];
Check(GcWelcomeStatus.ReadPrime(primeWelcome, 123) is null, "Missing Prime field cannot mean non-Prime");
Console.WriteLine("PASS: nullable CS2 level and account-owned Prime metadata.");
using (var flags = System.Text.Json.JsonDocument.Parse("[true,1,false,0]")) {
    Check(SteamAccountDetails.IsTrue(flags.RootElement[0]) && SteamAccountDetails.IsTrue(flags.RootElement[1]) &&
          !SteamAccountDetails.IsTrue(flags.RootElement[2]) && !SteamAccountDetails.IsTrue(flags.RootElement[3]),
          "Steam inventory boolean and numeric flags differ");
}
