using System.Text.Json;
using ProtoBuf;
using SteamKit2;
using SteamKit2.GC;
using SteamKit2.Internal;
using SteamKit2.Authentication;

const uint Cs2AppId = 730;
const uint GcClientWelcome = 4004;
const uint GcClientHello = 4006;
const uint MatchmakingClient2GcHello = 9109;
const uint MatchmakingGc2ClientHello = 9110;
const uint ServerNotificationForUserPenalty = 9118;
const uint Cs2GcClientVersion = 2000244;

var jsonOptions = new JsonSerializerOptions
{
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    PropertyNameCaseInsensitive = true,
};

var inputLine = Console.ReadLine();
if (string.IsNullOrWhiteSpace(inputLine))
{
    WriteResult(new Result("error", Message: "Entrada JSON ausente."));
    return;
}

Request? request;
try
{
    request = JsonSerializer.Deserialize<Request>(inputLine, jsonOptions);
}
catch (Exception ex)
{
    WriteResult(new Result("error", Message: $"JSON invalido: {ex.Message}"));
    return;
}

if (request is null || string.IsNullOrWhiteSpace(request.Username) ||
    (!request.SavedSessionOnly && string.IsNullOrEmpty(request.Password)))
{
    WriteResult(new Result("missing_credentials", Message: "Usuario ou senha ausente."));
    return;
}

var timeoutSeconds = Math.Clamp(request.TimeoutSeconds <= 0 ? 45 : request.TimeoutSeconds, 15, 75);
var client = new SteamClient();
var manager = new CallbackManager(client);
var user = client.GetHandler<SteamUser>();
var gc = client.GetHandler<SteamGameCoordinator>();
var friends = client.GetHandler<SteamFriends>();
var finished = false;
var gcReady = false;
var helloAttempts = 0;
var matchmakingAttempts = 0;
var observedGcMessages = new HashSet<uint>();
Timer? helloTimer = null;
Timer? matchmakingTimer = null;
Result? result = null;
var sessionStore = new SteamSessionStore();
var savedSession = sessionStore.Load(request.Username);
if (request.SavedSessionOnly && string.IsNullOrWhiteSpace(savedSession?.RefreshToken))
{
    WriteResult(new Result("session_missing", Message: "Sessao salva indisponivel."));
    return;
}
SteamSavedSession? pendingSession = null;
var loggingOnWithSavedToken = false;
string? sessionWarning = null;
var reconnectPending = false;
var cmReconnectAttempts = 0;
// Avoid colliding with the Steam desktop client's automatically generated LoginID.
var helperLoginId = (uint)System.Security.Cryptography.RandomNumberGenerator.GetInt32(1, int.MaxValue);
Task<SteamGroupResult>? groupJoinTask = null;
string? profileSteamId = null;
string? profileAvatarUrl = null;
string? profileName = null;

void Finish(Result value)
{
    if (finished) return;
    result = value with { SessionWarning = sessionWarning };
    finished = true;
    helloTimer?.Dispose();
    matchmakingTimer?.Dispose();
}

void SendGcHello()
{
    if (finished || gcReady) return;
    try
    {
        helloAttempts++;
        var hello = new ClientGCMsgProtobuf<CsgoGcClientHello>(GcClientHello);
        // CS2 currently requires a GC client version in ClientHello. This mirrors
        // the current node-globaloffensive handshake used for AppID 730.
        hello.Body.Version = Cs2GcClientVersion;
        hello.Body.ClientSessionNeed = 0;
        hello.Body.ClientLauncher = 0;
        hello.Body.SteamLauncher = 0;
        gc!.Send(hello, Cs2AppId);
    }
    catch (Exception ex)
    {
        Finish(new Result("error", Message: $"Falha ao iniciar sessao do GC: {ex.Message}"));
    }
}

void SendMatchmakingHello()
{
    if (finished || !gcReady) return;
    try
    {
        matchmakingAttempts++;
        var hello = new ClientGCMsgProtobuf<CsgoMatchmakingClientHello>(MatchmakingClient2GcHello);
        gc!.Send(hello, Cs2AppId);
    }
    catch (Exception ex)
    {
        Finish(new Result("error", Message: $"Falha ao solicitar status do CS2: {ex.Message}"));
    }
}

var authStarted = false;

async Task AuthenticateWithCredentials()
{
    try
    {
        var authenticator = new RequestAuthenticator(request);
        var authSession = await client.Authentication.BeginAuthSessionViaCredentialsAsync(new AuthSessionDetails
        {
            Username = request.Username.Trim(),
            Password = request.Password,
            IsPersistentSession = true,
            GuardData = savedSession?.GuardData,
            Authenticator = authenticator,
            DeviceFriendlyName = $"{Environment.MachineName} (GamerLocker)",
        });

        var poll = await authSession.PollingWaitForResultAsync();

        if (finished) return;

        pendingSession = new SteamSavedSession(
            string.IsNullOrWhiteSpace(poll.AccountName) ? request.Username.Trim() : poll.AccountName,
            poll.RefreshToken,
            poll.NewGuardData ?? savedSession?.GuardData);

        user!.LogOn(new SteamUser.LogOnDetails
        {
            Username = string.IsNullOrWhiteSpace(poll.AccountName) ? request.Username.Trim() : poll.AccountName,
            AccessToken = poll.RefreshToken,
            ShouldRememberPassword = true,
            LoginID = helperLoginId,
            MachineName = $"{Environment.MachineName} (GamerLocker)",
        });
    }
    catch (GuardCodeRequiredException ex)
    {
        Finish(new Result(
            ex.GuardType == "email" ? "steam_guard_required" : "two_factor_required",
            Message: ex.Message,
            GuardType: ex.GuardType));
    }
    catch (AuthenticationException ex)
    {
        Finish(new Result("login_failed", Message: $"Login Steam recusado: {ex.Result} / {ex.Message}"));
    }
    catch (Exception ex)
    {
        Finish(new Result("login_failed", Message: $"Falha na autenticacao Steam: {ex.Message}"));
    }
}

manager.Subscribe<SteamClient.ConnectedCallback>(async _ =>
{
    if (authStarted || finished) return;
    authStarted = true;
    if (!string.IsNullOrWhiteSpace(savedSession?.RefreshToken))
    {
        loggingOnWithSavedToken = true;
        user!.LogOn(new SteamUser.LogOnDetails
        {
            Username = savedSession.AccountName,
            AccessToken = savedSession.RefreshToken,
            ShouldRememberPassword = true,
            LoginID = helperLoginId,
            MachineName = $"{Environment.MachineName} (GamerLocker)",
        });
        return;
    }
    await AuthenticateWithCredentials();
});

manager.Subscribe<SteamUser.LoggedOnCallback>(async callback =>
{
    if (finished) return;
    if (callback.Result == EResult.TryAnotherCM && cmReconnectAttempts < 2)
    {
        // Steam may redirect this login to a different connection manager.
        // Reconnect without discarding a valid session or asking for Guard.
        cmReconnectAttempts++;
        reconnectPending = true;
        authStarted = false;
        client.Disconnect();
        return;
    }
    if (loggingOnWithSavedToken && SteamSessionPolicy.ShouldRetryCredentials(callback.Result))
    {
        if (request.SavedSessionOnly)
        {
            Finish(new Result("session_rejected", Message: "A Steam recusou a sessao salva."));
            return;
        }
        // Only authentication rejection invalidates the token, never GC/network failures.
        loggingOnWithSavedToken = false;
        savedSession = savedSession! with { RefreshToken = "" };
        if (!sessionStore.Save(request.Username, savedSession))
            sessionWarning = "Nao foi possivel atualizar a sessao Steam salva.";
        await AuthenticateWithCredentials();
        return;
    }
    if (callback.Result == EResult.AccountLogonDenied)
    {
        Finish(new Result(
            "steam_guard_required",
            Message: string.IsNullOrWhiteSpace(callback.EmailDomain)
                ? "Steam Guard por e-mail solicitado."
                : $"Steam Guard enviado para {callback.EmailDomain}.",
            GuardType: "email"));
        return;
    }

    if (callback.Result == EResult.AccountLoginDeniedNeedTwoFactor)
    {
        Finish(new Result(
            "two_factor_required",
            Message: "Informe o codigo do Steam Guard Mobile.",
            GuardType: "mobile"));
        return;
    }

    if (callback.Result != EResult.OK)
    {
        Finish(new Result("login_failed", Message: $"Login Steam recusado: {callback.Result} / {callback.ExtendedResult}."));
        return;
    }

    // Save after a successful Steam login, independently of the later GC result.
    if (pendingSession is not null && !sessionStore.Save(request.Username, pendingSession))
        sessionWarning = "Nao foi possivel salvar a sessao Steam. O Steam Guard pode ser solicitado novamente.";
    if (pendingSession is not null) savedSession = pendingSession;

    profileSteamId = client.SteamID!.ConvertToUInt64().ToString();
    friends!.RequestFriendInfo(client.SteamID,
        EClientPersonaStateFlag.PlayerName | EClientPersonaStateFlag.Presence);

    if (request.JoinGamerLockerGroup && groupJoinTask is null && savedSession is not null)
        groupJoinTask = SteamGroupMembership.EnsureMemberAsync(
            client.Authentication, client.SteamID!, savedSession.RefreshToken);

    var playGame = new ClientMsgProtobuf<CMsgClientGamesPlayed>(EMsg.ClientGamesPlayed);
    playGame.Body.games_played.Add(new CMsgClientGamesPlayed.GamePlayed
    {
        game_id = new GameID(Cs2AppId),
    });
    client.Send(playGame);

    // Give Steam a moment to publish the playing-session state, then start the
    // GC handshake. Keep retrying because ClientWelcome is not guaranteed to
    // arrive from the first hello.
    helloTimer = new Timer(_ =>
    {
        if (gcReady) return;
        SendGcHello();
    }, null, TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(3));
});

manager.Subscribe<SteamFriends.PersonaStateCallback>(callback =>
{
    if (callback.FriendID.ConvertToUInt64().ToString() != profileSteamId) return;
    profileAvatarUrl = SteamAvatar.UrlFromHash(callback.AvatarHash) ?? profileAvatarUrl;
    if (!string.IsNullOrWhiteSpace(callback.Name)) profileName = callback.Name;
});

manager.Subscribe<SteamGameCoordinator.MessageCallback>(callback =>
{
    observedGcMessages.Add(callback.EMsg);

    if (callback.EMsg == GcClientWelcome)
    {
        gcReady = true;
        helloTimer?.Dispose();
        try
        {
            // CS2 sends the authenticated account status in the welcome's
            // game_data2, even when it never sends a separate 9110 response.
            var welcome = new ClientGCMsgProtobuf<CsgoGcClientWelcome>(callback.Message).Body;
            if (GcWelcomeStatus.TryRead(welcome.GameData2, client.SteamID!.AccountID, out var account))
            {
                Finish(new Result("ok",
                    PenaltySeconds: checked((int)(account!.PenaltySeconds ?? 0)),
                    PenaltyReason: checked((int)(account.PenaltyReason ?? 0)),
                    VacBanned: account.VacBanned != 0,
                    Message: account.PenaltySeconds > 0 ? "Cooldown ativo." : "Sem cooldown ativo."));
                return;
            }
        }
        catch
        {
            // If welcome data is absent or malformed, retain the original
            // matchmaking/penalty-notification fallback rather than reporting zero.
        }

        // MatchmakingGC2ClientHello is commonly pushed shortly after the GC
        // session is established. If it isn't, request it repeatedly.
        matchmakingTimer ??= new Timer(_ => SendMatchmakingHello(), null,
            TimeSpan.FromMilliseconds(750), TimeSpan.FromSeconds(3));
        return;
    }

    if (callback.EMsg == ServerNotificationForUserPenalty)
    {
        try
        {
            var message = new ClientGCMsgProtobuf<CsgoPenaltyNotification>(callback.Message);
            var body = message.Body;
            if (body.Seconds > 0)
            {
                Finish(new Result(
                    "ok",
                    PenaltySeconds: checked((int)body.Seconds),
                    PenaltyReason: checked((int)body.Reason),
                    VacBanned: false,
                    Message: "Cooldown ativo (notificacao do GC)."));
            }
        }
        catch
        {
            // Ignore malformed/partial notification and continue waiting for 9110.
        }
        return;
    }

    if (callback.EMsg != MatchmakingGc2ClientHello)
    {
        return;
    }

    try
    {
        var message = new ClientGCMsgProtobuf<CsgoMatchmakingGcHello>(callback.Message);
        var body = message.Body;
        Finish(new Result(
            "ok",
            PenaltySeconds: checked((int)body.PenaltySeconds),
            PenaltyReason: checked((int)body.PenaltyReason),
            VacBanned: body.VacBanned != 0,
            Message: body.PenaltySeconds > 0 ? "Cooldown ativo." : "Sem cooldown ativo."));
    }
    catch (Exception ex)
    {
        Finish(new Result("error", Message: $"Falha ao interpretar resposta do GC: {ex.Message}"));
    }
});

manager.Subscribe<SteamClient.DisconnectedCallback>(_ =>
{
    if (reconnectPending && !finished)
    {
        reconnectPending = false;
        client.Connect();
        return;
    }
    if (!finished)
    {
        Finish(new Result("error", Message: "Steam desconectou antes de retornar o status do CS2."));
    }
});

client.Connect();
var deadline = DateTime.UtcNow.AddSeconds(timeoutSeconds);
while (!finished && DateTime.UtcNow < deadline)
{
    manager.RunWaitCallbacks(TimeSpan.FromMilliseconds(500));
}

if (!finished)
{
    var seen = observedGcMessages.Count == 0
        ? "nenhuma mensagem do GC"
        : $"mensagens GC recebidas: {string.Join(", ", observedGcMessages.OrderBy(x => x))}";
    Finish(new Result(
        "timeout",
        Message: $"Game Coordinator do CS2 nao retornou o status a tempo. Hello GC: {helloAttempts} tentativa(s); matchmaking: {matchmakingAttempts} tentativa(s); {seen}."));
}

// Keep the CM connection and its callbacks alive until the optional group action
// completes; receiving cooldown data must not cancel the web-token exchange.
if (groupJoinTask is not null)
{
    var groupDeadline = DateTime.UtcNow.AddSeconds(13);
    while (!groupJoinTask.IsCompleted && DateTime.UtcNow < groupDeadline)
        manager.RunWaitCallbacks(TimeSpan.FromMilliseconds(100));
    var groupResult = groupJoinTask.IsCompletedSuccessfully
        ? groupJoinTask.Result : new SteamGroupResult("failed", "Nao foi possivel confirmar a entrada no grupo GamerLocker.");
    if (result is not null) result = result with { GroupStatus = groupResult.Status, GroupMessage = groupResult.Message };
}
if (profileSteamId is not null && profileAvatarUrl is null)
{
    var profileDeadline = DateTime.UtcNow.AddSeconds(2);
    while (profileAvatarUrl is null && client.IsConnected && DateTime.UtcNow < profileDeadline)
        manager.RunWaitCallbacks(TimeSpan.FromMilliseconds(100));
}
if (result is not null) result = result with {
    SteamId64 = profileSteamId, AvatarUrl = profileAvatarUrl, PersonaName = profileName,
};
try { client.Disconnect(); } catch { }
WriteResult(result ?? new Result("error", Message: "Resultado desconhecido."));

static void WriteResult(Result result)
{
    Console.WriteLine(JsonSerializer.Serialize(result, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }));
}


sealed record Request(
    string Username = "",
    string Password = "",
    string AuthCode = "",
    string TwoFactorCode = "",
    int TimeoutSeconds = 45,
    bool SavedSessionOnly = false,
    bool JoinGamerLockerGroup = false);

sealed record Result(
    string Status,
    int PenaltySeconds = 0,
    int PenaltyReason = 0,
    bool VacBanned = false,
    string? Message = null,
    string? GuardType = null,
    string? SessionWarning = null,
    string? GroupStatus = null,
    string? GroupMessage = null,
    string? SteamId64 = null,
    string? AvatarUrl = null,
    string? PersonaName = null);

sealed class GuardCodeRequiredException : Exception
{
    public string GuardType { get; }

    public GuardCodeRequiredException(string guardType, string message) : base(message)
    {
        GuardType = guardType;
    }
}

sealed class RequestAuthenticator : IAuthenticator
{
    private readonly Request request;

    public RequestAuthenticator(Request request)
    {
        this.request = request;
    }

    public Task<string> GetDeviceCodeAsync(bool previousCodeWasIncorrect)
    {
        if (!previousCodeWasIncorrect && !string.IsNullOrWhiteSpace(request.TwoFactorCode))
        {
            return Task.FromResult(request.TwoFactorCode.Trim());
        }

        var message = previousCodeWasIncorrect
            ? "Codigo do Steam Guard Mobile incorreto. Informe um novo codigo."
            : "Informe o codigo atual do Steam Guard Mobile.";
        throw new GuardCodeRequiredException("mobile", message);
    }

    public Task<string> GetEmailCodeAsync(string email, bool previousCodeWasIncorrect)
    {
        if (!previousCodeWasIncorrect && !string.IsNullOrWhiteSpace(request.AuthCode))
        {
            return Task.FromResult(request.AuthCode.Trim());
        }

        var destination = string.IsNullOrWhiteSpace(email) ? "seu e-mail" : email;
        var message = previousCodeWasIncorrect
            ? $"Codigo do Steam Guard por e-mail incorreto. Informe o novo codigo enviado para {destination}."
            : $"Informe o codigo do Steam Guard enviado para {destination}.";
        throw new GuardCodeRequiredException("email", message);
    }

    public Task<bool> AcceptDeviceConfirmationAsync()
    {
        // For the one-shot helper we intentionally fall back to a code so the
        // Flutter UI can request it and invoke the helper again.
        return Task.FromResult(false);
    }
}

[ProtoContract]
sealed class CsgoGcClientHello : IExtensible
{
    [ProtoMember(1)] public uint Version { get; set; }
    [ProtoMember(3)] public uint ClientSessionNeed { get; set; }
    [ProtoMember(4)] public uint ClientLauncher { get; set; }
    [ProtoMember(9)] public uint SteamLauncher { get; set; }
    private IExtension? extensionObject;
    public IExtension GetExtensionObject(bool createIfMissing) =>
        Extensible.GetExtensionObject(ref extensionObject, createIfMissing);
}

[ProtoContract]
sealed class CsgoMatchmakingClientHello : IExtensible
{
    private IExtension? extensionObject;
    public IExtension GetExtensionObject(bool createIfMissing) =>
        Extensible.GetExtensionObject(ref extensionObject, createIfMissing);
}

[ProtoContract]
sealed class CsgoMatchmakingGcHello : IExtensible
{
    [ProtoMember(4)] public uint PenaltySeconds { get; set; }
    [ProtoMember(5)] public uint PenaltyReason { get; set; }
    [ProtoMember(6)] public int VacBanned { get; set; }
    private IExtension? extensionObject;
    public IExtension GetExtensionObject(bool createIfMissing) =>
        Extensible.GetExtensionObject(ref extensionObject, createIfMissing);
}

[ProtoContract]
sealed class CsgoPenaltyNotification : IExtensible
{
    [ProtoMember(1)] public uint AccountId { get; set; }
    [ProtoMember(2)] public uint Reason { get; set; }
    [ProtoMember(3)] public uint Seconds { get; set; }
    [ProtoMember(4)] public bool CommunicationCooldown { get; set; }
    [ProtoMember(5)] public uint CheatingPenaltyLevel { get; set; }
    private IExtension? extensionObject;
    public IExtension GetExtensionObject(bool createIfMissing) =>
        Extensible.GetExtensionObject(ref extensionObject, createIfMissing);
}
