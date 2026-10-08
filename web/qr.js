/**
 * Standalone QR Code Renderer for KeyFlow Web-to-Mobile Handshake
 */

export function renderQRCode(container, text, size = 160) {
  if (!container) return;
  container.innerHTML = '';

  const img = document.createElement('img');
  img.width = size;
  img.height = size;
  img.alt = 'Scan to pair with mobile KeyFlow app';
  img.style.borderRadius = '8px';
  img.style.display = 'block';
  img.style.margin = '0 auto';

  img.onerror = () => {
    // Fallback: render stylized SVG payload box if external image service is offline
    container.innerHTML = `
      <div style="width: ${size}px; height: ${size}px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #F1F5F9; border-radius: 8px; border: 1px dashed #CBD5E1; padding: 12px; text-align: center;">
        <span style="font-size: 28px; margin-bottom: 6px;">📱</span>
        <span style="font-size: 11px; font-weight: 700; color: #0F172A;">keyflow://pair</span>
        <span style="font-size: 10px; color: #64748B; margin-top: 4px; word-break: break-all;">Tap 'Launch & Pair' below</span>
      </div>
    `;
  };

  img.src = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
  container.appendChild(img);
}
