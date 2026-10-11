import { handleRequest } from './index.ts';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

Deno.test('authentication and invitations fail closed before contacting GitHub', async () => {
  Deno.env.set('SUPABASE_URL', 'https://example.supabase.co');
  Deno.env.set('SUPABASE_ANON_KEY', 'test-public-key');
  const originalFetch = globalThis.fetch;
  let calls = 0;
  try {
    globalThis.fetch = (() => { calls++; return Promise.resolve(Response.json({ error: 'invalid' }, { status: 401 })); }) as typeof fetch;
    assert((await handleRequest(new Request('https://example.supabase.co/functions/v1/private-updates'))).status === 401, 'Missing login accepted');
    assert(calls === 0, 'Anonymous request contacted upstream');
    const request = () => new Request('https://example.supabase.co/functions/v1/private-updates?asset=7', { headers: { Authorization: 'Bearer test-session' } });
    assert((await handleRequest(request())).status === 401, 'Invalid session accepted');
    calls = 0;
    globalThis.fetch = (() => Promise.resolve(Response.json(++calls === 1 ? { id: 'user' } : []))) as typeof fetch;
    assert((await handleRequest(request())).status === 403, 'Uninvited user accepted');
    assert(calls === 2, 'Denied request contacted GitHub');
  } finally { globalThis.fetch = originalFetch; }
});

Deno.test('invited user gets proxy metadata and downloads only published installer assets', async () => {
  Deno.env.set('SUPABASE_URL', 'https://example.supabase.co');
  Deno.env.set('SUPABASE_ANON_KEY', 'test-public-key');
  Deno.env.set('GITHUB_RELEASES_TOKEN', 'server-only-test-token');
  const originalFetch = globalThis.fetch;
  const release = { tag_name: 'v0.1.13', assets: [{ id: 7, name: 'GamerLocker-Setup-v0.1.13-windows-x64.exe', size: 3, digest: 'sha256:' + 'a'.repeat(64) }] };
  try {
    globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      if (url.endsWith('/auth/v1/user')) return Promise.resolve(Response.json({ id: 'user' }));
      if (url.includes('/rest/v1/')) return Promise.resolve(Response.json([{ user_id: 'user' }]));
      if (url.includes('/releases?')) return Promise.resolve(Response.json([release, { ...release, draft: true }, { ...release, prerelease: true }]));
      if (url.endsWith('/assets/7')) return Promise.resolve(new Response(null, { status: 302, headers: { Location: 'https://release-assets.githubusercontent.com/file' } }));
      if (url === 'https://release-assets.githubusercontent.com/file') {
        assert(!init?.headers, 'GitHub token leaked to asset host');
        return Promise.resolve(new Response(new Uint8Array([77, 90, 0])));
      }
      throw new Error('Unexpected upstream');
    }) as typeof fetch;
    const request = (suffix = '') => new Request('https://example.supabase.co/functions/v1/private-updates' + suffix, { headers: { Authorization: 'Bearer test-session' } });
    const metadata = await (await handleRequest(request())).text();
    assert(!metadata.includes('server-only-test-token'), 'Token exposed to client');
    assert(JSON.parse(metadata).length === 1, 'Draft or prerelease exposed');
    assert(metadata.includes('private-updates?asset=7'), 'Download bypasses authorization');
    assert((await handleRequest(request('?asset=999'))).status === 404, 'Foreign asset accepted');
    const download = await handleRequest(request('?asset=7'));
    assert(download.status === 200 && (await download.arrayBuffer()).byteLength === 3, 'Proxy download failed');
  } finally { globalThis.fetch = originalFetch; Deno.env.delete('GITHUB_RELEASES_TOKEN'); }
});
