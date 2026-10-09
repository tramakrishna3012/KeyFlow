/**
 * Standalone QR Code Renderer for KeyFlow Web-to-Mobile Handshake
 */

export function renderQRCode(container, text, size = 160) {
  if (!container) return;
  while (container.firstChild) {
    container.removeChild(container.firstChild);
  }

  const img = document.createElement('img');
  img.width = size;
  img.height = size;
  img.alt = 'Scan to pair with mobile KeyFlow app';
  img.style.borderRadius = '8px';
  img.style.display = 'block';
  img.style.margin = '0 auto';

  img.onerror = () => {
    // Safe DOM fallback: render stylized SVG payload box if external image service is offline
    while (container.firstChild) {
      container.removeChild(container.firstChild);
    }
    const box = document.createElement('div');
    box.style.cssText = `width: ${size}px; height: ${size}px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #F1F5F9; border-radius: 8px; border: 1px dashed #CBD5E1; padding: 12px; text-align: center;`;
    const icon = document.createElement('span');
    icon.style.cssText = 'font-size: 28px; margin-bottom: 6px;';
    icon.textContent = '📱';
    const linkText = document.createElement('span');
    linkText.style.cssText = 'font-size: 11px; font-weight: 700; color: #0F172A;';
    linkText.textContent = 'keyflow://pair';
    const subText = document.createElement('span');
    subText.style.cssText = 'font-size: 10px; color: #64748B; margin-top: 4px; word-break: break-all;';
    subText.textContent = "Tap 'Launch & Pair' below";
    box.appendChild(icon);
    box.appendChild(linkText);
    box.appendChild(subText);
    container.appendChild(box);
  };

  img.src = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
  container.appendChild(img);
}
