require('dotenv').config();
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const { AccessToken } = require('livekit-server-sdk');

const app = express();
app.use(cors());
app.use(express.json());

const waiting = [];

app.get('/health', (_req, res) => res.json({ ok: true }));

async function makeParticipantToken(roomName) {
  const identity = crypto.randomUUID();
  const token = new AccessToken(
    process.env.LIVEKIT_API_KEY,
    process.env.LIVEKIT_API_SECRET,
    { identity, ttl: '10m' }
  );
  token.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true
  });
  return await token.toJwt();
}

app.post('/match', async (req, res) => {
  if (!process.env.LIVEKIT_URL || !process.env.LIVEKIT_API_KEY || !process.env.LIVEKIT_API_SECRET) {
    return res.status(503).json({ error: 'LiveKit server configuration is missing' });
  }

  const language = String(req.body.language || 'همه زبان‌ها').slice(0, 40);
  const region = String(req.body.region || 'همه مناطق').slice(0, 40);
  const now = Date.now();

  // حذف درخواست‌های منقضی‌شده از صف
  for (let i = waiting.length - 1; i >= 0; i--) {
    if (now - waiting[i].createdAt > 30000) {
      const expired = waiting.splice(i, 1)[0];
      expired.res.status(408).json({ matched: false, error: 'Match request expired' });
    }
  }

  const index = waiting.findIndex(
    item => item.language === language && item.region === region
  );

  if (index === -1) {
    // درخواست اول تا زمان پیدا شدن نفر دوم باز می‌ماند.
    const entry = {
      language, region, createdAt: now, res,
      timer: setTimeout(() => {
        const i = waiting.indexOf(entry);
        if (i !== -1) waiting.splice(i, 1);
        if (!res.headersSent) res.status(408).json({ matched: false, error: 'No match yet' });
      }, 25000)
    };
    waiting.push(entry);
    return;
  }

  const first = waiting.splice(index, 1)[0];
  clearTimeout(first.timer);

  try {
    const roomName = `rv-${crypto.randomUUID()}`;
    const [firstToken, secondToken] = await Promise.all([
      makeParticipantToken(roomName),
      makeParticipantToken(roomName)
    ]);

    first.res.json({
      matched: true,
      url: process.env.LIVEKIT_URL,
      token: firstToken,
      roomName
    });

    res.json({
      matched: true,
      url: process.env.LIVEKIT_URL,
      token: secondToken,
      roomName
    });
  } catch (error) {
    console.error(error);
    if (!first.res.headersSent) first.res.status(500).json({ error: 'Could not create room tokens' });
    if (!res.headersSent) res.status(500).json({ error: 'Could not create room tokens' });
  }
});

app.listen(process.env.PORT || 3000, () => {
  console.log(`Random Voice backend listening on ${process.env.PORT || 3000}`);
});
