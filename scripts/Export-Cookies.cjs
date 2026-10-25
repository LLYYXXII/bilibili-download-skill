const fs = require('node:fs');
const pwModule = process.env.BILI_PW_MODULE;
if (!pwModule) { console.error('BILI_PW_MODULE missing'); process.exit(1); }
const { chromium } = require(pwModule);
const profileDir = process.argv[2];
const outPath = process.argv[3];
if (!profileDir || !outPath) { console.error('usage: node Export-Cookies.cjs <profileDir> <cookiesOut>'); process.exit(1); }
(async () => {
  const ctx = await chromium.launchPersistentContext(profileDir, {
    channel: 'msedge', headless: true,
    args: ['--disable-blink-features=AutomationControlled'], timeout: 60000,
  });
  try {
    const headers = { Referer: 'https://www.bilibili.com/', Origin: 'https://www.bilibili.com', 'User-Agent': 'Mozilla/5.0' };
    const res = await ctx.request.get('https://api.bilibili.com/x/web-interface/nav', { headers, timeout: 30000 });
    const nav = await res.json();
    if (nav.code !== 0 || !nav.data || nav.data.isLogin !== true) {
      console.error('AUTH_REQUIRED: the isolated Edge session is not logged in.');
      process.exit(20);
    }
    const cookies = await ctx.cookies();
    const lines = ['# Netscape HTTP Cookie File'];
    let count = 0;
    for (const c of cookies) {
      if (!String(c.domain).includes('bilibili')) continue;
      const expiry = c.expires && c.expires > 0 ? Math.floor(c.expires) : 0;
      lines.push([c.domain, c.domain.startsWith('.') ? 'TRUE' : 'FALSE', c.path, c.secure ? 'TRUE' : 'FALSE', expiry, c.name, c.value].join('\t'));
      count++;
    }
    fs.writeFileSync(outPath, lines.join('\n') + '\n');
    console.log('COOKIES_OK ' + count);
  } finally {
    await ctx.close();
  }
})().catch(e => { console.error('COOKIE_EXPORT_FAILED: ' + e.message); process.exitCode = 1; });