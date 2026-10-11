const repository = 'GamerLocker/gamerlockerpro-releases';
const headers = { 'Cache-Control': 'no-store' };
const json = (data: unknown, status = 200) => Response.json(data, { status, headers });
const installerName = /^GamerLocker-Setup-v\d+\.\d+\.\d+-windows-x64\.exe$/i;

export async function handleRequest(request: Request): Promise<Response> {
  if (request.method !== 'GET') return json({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('Authorization') ?? '';
  if (!/^Bearer \S+$/i.test(authorization)) return json({ error: 'Sign in required' }, 401);
  const base = Deno.env.get('SUPABASE_URL')!;
  const apikey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const authHeaders = { Authorization: authorization, apikey };
  try {
    // Validate with Auth; never trust an unverified JWT payload or client plan.
    const auth = await fetch(`${base}/auth/v1/user`, { headers: authHeaders,
      signal: AbortSignal.timeout(10000) });
    if (!auth.ok) return json({ error: 'Invalid session' }, 401);
    const user = await auth.json();
    const access = await fetch(`${base}/rest/v1/private_update_access?user_id=eq.${encodeURIComponent(user.id)}&select=user_id`,
      { headers: authHeaders, signal: AbortSignal.timeout(10000) });
    if (!access.ok) return json({ error: 'Authorization unavailable' }, 503);
    const allowed = await access.json();
    if (!Array.isArray(allowed) || allowed.length !== 1) return json({ error: 'Invitation required' }, 403);
    const token = Deno.env.get('GITHUB_RELEASES_TOKEN');
    if (!token) return json({ error: 'Updates not configured' }, 503);
    const ghHeaders = { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'GamerLocker-Private-Updates' };
    const releasesResponse = await fetch(`https://api.github.com/repos/${repository}/releases?per_page=30`,
      { headers: ghHeaders, signal: AbortSignal.timeout(10000) });
    if (!releasesResponse.ok) return json({ error: 'Releases unavailable' }, 502);
    const releases = (await releasesResponse.json()).filter((r: any) => !r.draft && !r.prerelease);
    const url = new URL(request.url);
    const assetId = url.searchParams.get('asset');
    const assets = releases.flatMap((r: any) => r.assets ?? []).filter((a: any) => installerName.test(a.name));
    if (assetId !== null) {
      // IDs must belong to an installer on a published release of this fixed repository.
      const asset = assets.find((a: any) => String(a.id) === assetId);
      if (!asset) return json({ error: 'Installer not found' }, 404);
      let download = await fetch(`https://api.github.com/repos/${repository}/releases/assets/${asset.id}`,
        { headers: { ...ghHeaders, Accept: 'application/octet-stream' }, redirect: 'manual',
          signal: AbortSignal.timeout(20000) });
      if (download.status === 302) {
        const target = new URL(download.headers.get('Location')!);
        if (target.protocol !== 'https:' || target.hostname !== 'release-assets.githubusercontent.com') {
          return json({ error: 'Invalid download destination' }, 502);
        }
        // Never forward the GitHub token to the download host or the client.
        download = await fetch(target, { redirect: 'error', signal: AbortSignal.timeout(60000) });
      }
      if (!download.ok || !download.body) return json({ error: 'Download unavailable' }, 502);
      return new Response(download.body, { headers: { ...headers,
        'Content-Type': 'application/octet-stream', 'Content-Length': String(asset.size) } });
    }
    return json(releases.map((r: any) => ({ tag_name: r.tag_name, name: r.name,
      assets: (r.assets ?? []).filter((a: any) => installerName.test(a.name)).map((a: any) => ({
        name: a.name, browser_download_url: `${base}/functions/v1/private-updates?asset=${a.id}`,
        digest: a.digest,
      })) })));
  } catch {
    return json({ error: 'Updates temporarily unavailable' }, 503);
  }
}

if (import.meta.main) Deno.serve(handleRequest);
