// cactus-kafe-cron — vardiya bildirim zamanlayıcısı.
// Ana worker (cactus-kafe) statik asset'li olduğu için cron trigger kabul etmiyor;
// bu minik worker aynı D1'e bağlanır ve 10 dakikada bir vardiya kontrolünü çalıştırır:
// gece özeti (05:00-05:30 İst) + geç kalma uyarısı. Bkz. wrangler-cron.toml.
import { vardiyaZamanliKontrol } from './index.js';

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(vardiyaZamanliKontrol(env).catch(function () {}));
  },
};
