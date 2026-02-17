const express = require('express');
const router = express.Router();

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const CACHE_DIR = path.join(__dirname, '../cache');
if (!fs.existsSync(CACHE_DIR)) {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
}

// GET /api/proxy/image?url=ENCODED_URL
router.get('/image', async (req, res) => {
    try {
        const imageUrl = req.query.url;
        if (!imageUrl) {
            console.log('[Proxy] Missing URL param');
            return res.status(400).send('Missing url parameter');
        }

        // 1. Generate filename from URL hash
        const hash = crypto.createHash('md5').update(imageUrl).digest('hex');
        const cachePath = path.join(CACHE_DIR, hash);

        // 2. Check cache
        if (fs.existsSync(cachePath)) {
            // console.log(`[Proxy] Cache HIT: ${imageUrl.substring(0, 30)}...`);
            return res.sendFile(cachePath);
        }

        console.log(`[Proxy] Cache MISS. Fetching: ${imageUrl.substring(0, 50)}...`);

        // Use native fetch (Node 18+)
        const response = await fetch(imageUrl, {
            headers: {
                'Referer': 'http://localhost:3000', // Simulate a allowed referrer
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
            }
        });

        console.log(`[Proxy] Upstream status: ${response.status}`);

        if (!response.ok) {
            console.error(`[Proxy] Failed: ${response.status} ${response.statusText}`);

            // 1. Try serving local placeholder.png
            const placeholderPath = path.join(__dirname, '../placeholder.png');
            if (fs.existsSync(placeholderPath)) {
                console.log('[Proxy] Serving placeholder.png due to upstream error');
                return res.sendFile(placeholderPath);
            }

            // 2. Fallback: Serve 1x1 Gray PNG placeholder (base64)
            const placeholderBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
            const imgBuffer = Buffer.from(placeholderBase64, 'base64');

            console.log('[Proxy] Serving placeholder PNG (fallback) due to upstream error');
            res.setHeader('Content-Type', 'image/png');
            return res.send(imgBuffer);
        }

        // Forward Content-Type
        const contentType = response.headers.get('content-type');
        if (contentType) {
            res.setHeader('Content-Type', contentType);
        }

        // Stream the image data to the client AND save to cache
        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        // Write to cache
        try {
            fs.writeFileSync(cachePath, buffer);
            console.log(`[Proxy] Saved to cache: ${hash}`);
        } catch (filesErr) {
            console.error('[Proxy] Failed to write cache:', filesErr);
        }

        res.send(buffer);

    } catch (err) {
        console.error('[Proxy] Error:', err);
        res.status(500).send('Proxy error');
    }
});

module.exports = router;
