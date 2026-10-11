using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using SteamKit2;

sealed record SteamSavedSession(string AccountName, string RefreshToken, string? GuardData);

static class SteamSessionPolicy
{
    public static bool ShouldRetryCredentials(EResult result) => result is
        EResult.InvalidPassword or EResult.Expired or EResult.Revoked or
        EResult.AccessDenied or EResult.InvalidSignature or
        EResult.AccountLogonDenied or EResult.AccountLoginDeniedNeedTwoFactor;
}

sealed class SteamSessionStore
{
    private readonly string directory;

    public SteamSessionStore(string? directory = null)
    {
        this.directory = directory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "GamerLocker", "steam_sessions");
    }

    private string SessionPath(string username)
    {
        var key = Convert.ToHexString(SHA256.HashData(
            Encoding.UTF8.GetBytes(username.Trim().ToUpperInvariant())));
        return Path.Combine(directory, key + ".bin");
    }

    public SteamSavedSession? Load(string username)
    {
        byte[]? plain = null;
        try
        {
            var path = SessionPath(username);
            if (!File.Exists(path)) return null;
            plain = WindowsSessionProtection.Unprotect(File.ReadAllBytes(path));
            var session = JsonSerializer.Deserialize<SteamSavedSession>(plain);
            return !string.IsNullOrWhiteSpace(session?.AccountName) && string.Equals(session.AccountName.Trim(),
                username.Trim(), StringComparison.OrdinalIgnoreCase) ? session : null;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or
            CryptographicException or JsonException or PlatformNotSupportedException)
        {
            // Missing, damaged or other-Windows-user sessions require authentication.
            return null;
        }
        finally
        {
            if (plain is not null) CryptographicOperations.ZeroMemory(plain);
        }
    }

    public bool Save(string username, SteamSavedSession session)
    {
        byte[]? plain = null;
        string? temporaryPath = null;
        try
        {
            if (!string.Equals(session.AccountName.Trim(), username.Trim(), StringComparison.OrdinalIgnoreCase))
                return false;
            plain = JsonSerializer.SerializeToUtf8Bytes(session);
            var protectedBytes = WindowsSessionProtection.Protect(plain);
            Directory.CreateDirectory(directory);
            var path = SessionPath(username);
            temporaryPath = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            // Atomic replacement prevents a terminated helper from corrupting a session.
            File.WriteAllBytes(temporaryPath, protectedBytes);
            File.Move(temporaryPath, path, overwrite: true);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or
            CryptographicException or PlatformNotSupportedException)
        {
            return false;
        }
        finally
        {
            if (plain is not null) CryptographicOperations.ZeroMemory(plain);
            if (temporaryPath is not null)
            {
                try { File.Delete(temporaryPath); } catch (IOException) { } catch (UnauthorizedAccessException) { }
            }
        }
    }
}

// Windows DPAPI, scoped to the current Windows user. No plaintext token files,
// no machine-wide decryption and no additional NuGet dependency.
static class WindowsSessionProtection
{
    [StructLayout(LayoutKind.Sequential)]
    private struct DataBlob
    {
        public int Length;
        public IntPtr Data;
    }

    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CryptProtectData(ref DataBlob input, string description,
        IntPtr entropy, IntPtr reserved, IntPtr prompt, uint flags, out DataBlob output);

    [DllImport("crypt32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CryptUnprotectData(ref DataBlob input, IntPtr description,
        IntPtr entropy, IntPtr reserved, IntPtr prompt, uint flags, out DataBlob output);

    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr pointer);

    public static byte[] Protect(byte[] data) => Transform(data, protect: true);
    public static byte[] Unprotect(byte[] data) => Transform(data, protect: false);

    private static byte[] Transform(byte[] data, bool protect)
    {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException();
        if (data.Length == 0) throw new CryptographicException("Empty session data.");
        var input = new DataBlob { Length = data.Length, Data = Marshal.AllocHGlobal(data.Length) };
        var output = new DataBlob();
        try
        {
            Marshal.Copy(data, 0, input.Data, data.Length);
            const uint UiForbidden = 1;
            var success = protect
                ? CryptProtectData(ref input, "GamerLocker Steam session", IntPtr.Zero,
                    IntPtr.Zero, IntPtr.Zero, UiForbidden, out output)
                : CryptUnprotectData(ref input, IntPtr.Zero, IntPtr.Zero,
                    IntPtr.Zero, IntPtr.Zero, UiForbidden, out output);
            if (!success) throw new CryptographicException(Marshal.GetLastWin32Error());
            var result = new byte[output.Length];
            Marshal.Copy(output.Data, result, 0, output.Length);
            return result;
        }
        finally
        {
            // Clear unmanaged buffers before releasing them, including decrypted tokens.
            for (var i = 0; i < input.Length; i++) Marshal.WriteByte(input.Data, i, 0);
            Marshal.FreeHGlobal(input.Data);
            if (output.Data != IntPtr.Zero)
            {
                for (var i = 0; i < output.Length; i++) Marshal.WriteByte(output.Data, i, 0);
                LocalFree(output.Data);
            }
        }
    }
}
