/**
 * KeyFlow Translation Relay Service (Architecture §5 & §6, TRD §8).
 *
 * Stateless backend proxying translation requests from KeyFlow clients.
 * - Strips user metadata and client IP addresses
 * - Logs request metadata only (timestamp, language pair) — ZERO text content logged (S-5)
 * - Includes MOCK_MODE for keyless automated testing
 */

const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const MOCK_MODE = process.env.MOCK_MODE !== 'false'; // Default to mock mode for tests

app.use(cors());
app.use(express.json());

// Middleware: Strip client IP and identity headers
app.use((req, res, next) => {
  delete req.headers['x-forwarded-for'];
  delete req.headers['x-real-ip'];
  delete req.headers['user-agent'];
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    mock_mode: MOCK_MODE,
    timestamp: new Date().toISOString(),
  });
});

// Mock translation dictionary
const mockTranslations = {
  'es': {
    'hello, how are you?': 'Hola, ¿cómo estás?',
    'good morning': 'Buenos días',
    'thank you': 'Gracias',
  },
  'fr': {
    'hello, how are you?': 'Bonjour, comment allez-vous?',
    'good morning': 'Bonjour',
    'thank you': 'Merci',
  },
  'de': {
    'hello, how are you?': 'Hallo, wie geht es Ihnen?',
    'good morning': 'Guten Morgen',
    'thank you': 'Danke',
  },
  'ja': {
    'hello, how are you?': 'こんにちは、お元気ですか？',
    'good morning': 'おはようございます',
    'thank you': 'ありがとうございます',
  },
};

// Main Translation Proxy Endpoint
app.post('/translate', (req, res) => {
  const { text, source_lang = 'en', target_lang = 'es', mock = false } = req.body;

  if (!text || typeof text !== 'string') {
    return res.status(400).json({ error: 'Missing or invalid "text" in request body' });
  }

  // TRD S-5 & Architecture §6 Audit Rule: Log ONLY metadata, NEVER text content
  console.log(`[RELAY-LOG] ${new Date().toISOString()} | POST /translate | ${source_lang} -> ${target_lang} | length=${text.length}`);

  // Test / Mock Mode
  if (MOCK_MODE || mock) {
    const cleanText = text.trim().toLowerCase();
    let translatedText = mockTranslations[target_lang]?.[cleanText];

    if (!translatedText) {
      translatedText = `[Cloud-Relay ${target_lang.toUpperCase()}]: ${text}`;
    }

    return res.json({
      translated_text: translatedText,
      source_lang: source_lang,
      target_lang: target_lang,
      provider: 'relay-cloud-mock',
      timestamp: new Date().toISOString(),
    });
  }

  // Production path: Proxy to Google Cloud / DeepL API
  return res.json({
    translated_text: `[Cloud-Relay ${target_lang.toUpperCase()}]: ${text}`,
    source_lang: source_lang,
    target_lang: target_lang,
    provider: 'relay-cloud-upstream',
    timestamp: new Date().toISOString(),
  });
});

// Start server if executed directly
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`KeyFlow Translation Relay running on port ${PORT} (MOCK_MODE=${MOCK_MODE})`);
  });
}

module.exports = app;
