using SteamKit2;
using SteamKit2.Internal;

sealed record SteamSecuritySnapshot(bool? SteamGuard, bool? TwoFactor, bool? EmailVerified,
    bool? PhoneVerified, long CheckedAt);

static class SteamSecurity
{
    // Read-only authenticated RPC. Do not retrieve recovery codes or auth secrets.
    public static async Task<SteamSecuritySnapshot> FetchAsync(SteamClient client)
    {
        bool? guard = null, twoFactor = null, email = null, phone = null;
        var unified = client.GetHandler<SteamUnifiedMessages>()!;
        unified.CreateService<Credentials>();
        unified.CreateService<TwoFactor>();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(7));
        await Task.WhenAll(ReadGuard(), ReadEmail());
        return new(guard, twoFactor, email, phone, DateTimeOffset.UtcNow.ToUnixTimeSeconds());

        async Task ReadGuard()
        {
            try
            {
                var response = await unified.SendMessage<CCredentials_GetSteamGuardDetails_Request,
                    CCredentials_GetSteamGuardDetails_Response>("Credentials.GetSteamGuardDetails#1", new())
                    .ToTask().WaitAsync(timeout.Token);
                if (response.Result != EResult.OK) return;
                // Successful protobuf responses use false as the default for these
                // booleans. Only RPC rejection/timeout is an unknown result.
                guard = response.Body.is_steamguard_enabled;
                twoFactor = response.Body.is_twofactor_enabled;
                phone = response.Body.is_phone_verified;
            }
            catch { /* Unavailable is distinct from disabled. */ }
        }
        async Task ReadEmail()
        {
            try
            {
                var response = await unified.SendMessage<CTwoFactor_Status_Request, CTwoFactor_Status_Response>(
                    "TwoFactor.QueryStatus#1", new() { steamid = client.SteamID!.ConvertToUInt64() })
                    .ToTask().WaitAsync(timeout.Token);
                if (response.Result == EResult.OK)
                    email = response.Body.email_validated;
            }
            catch { }
        }
    }
}
