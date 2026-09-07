(() => {
  const init = () => {
    const dialog = document.querySelector('[data-image-crop-dialog]');
    if (!dialog || dialog.dataset.ready) return;
    dialog.dataset.ready = 'true';
    const source = dialog.querySelector('[data-crop-source]');
    const stage = dialog.querySelector('[data-crop-stage]');
    const selection = dialog.querySelector('[data-crop-selection]');
    const preview = dialog.querySelector('[data-crop-preview]');
    const feedback = dialog.querySelector('[data-crop-feedback]');
    const fields = Object.fromEntries([...dialog.querySelectorAll('[data-crop-field]')].map(input => [input.dataset.cropField, input]));
    const save = dialog.querySelector('[data-crop-save]');
    const restore = dialog.querySelector('[data-crop-restore]');
    const selectAll = dialog.querySelector('[data-crop-select-all]');
    const close = dialog.querySelector('[data-crop-close]');
    let url, opener, start, busy = false, loaded = false;
    const bounds = () => Object.fromEntries(Object.entries(fields).map(([key, input]) => [key, Number(input.value)]));
    const valid = (b) => loaded && Object.values(b).every(Number.isInteger) && Object.values(fields).every(input => input.value !== '') && b.left >= 0 && b.top >= 0 && b.width > 0 && b.height > 0 && b.left + b.width <= source.naturalWidth && b.top + b.height <= source.naturalHeight;
    const draw = () => {
      const b = bounds();
      save.disabled = busy || !valid(b);
      selection.hidden = !valid(b);
      if (!valid(b)) {
        preview.width = 1; preview.height = 1;
        return;
      }
      Object.assign(selection.style, {left: `${b.left / source.naturalWidth * 100}%`, top: `${b.top / source.naturalHeight * 100}%`, width: `${b.width / source.naturalWidth * 100}%`, height: `${b.height / source.naturalHeight * 100}%`});
      const scale = Math.min(1, 520 / b.width, 520 / b.height);
      preview.width = Math.max(1, Math.round(b.width * scale));
      preview.height = Math.max(1, Math.round(b.height * scale));
      preview.getContext('2d').drawImage(source, b.left, b.top, b.width, b.height, 0, 0, preview.width, preview.height);
    };
    const setBounds = (b) => { Object.entries(b).forEach(([key, value]) => { fields[key].value = value; }); draw(); };
    const setBusy = (value) => {
      busy = value;
      dialog.querySelector('[data-crop-fields]').disabled = busy || !loaded;
      restore.disabled = busy || !loaded;
      selectAll.disabled = busy || !loaded;
      close.disabled = busy;
      draw();
    };
    document.querySelectorAll('[data-crop-image]').forEach(button => button.addEventListener('click', () => {
      opener = button; url = button.dataset.assetUrl; loaded = false; start = null;
      source.removeAttribute('src');
      selection.hidden = true; preview.width = 1; preview.height = 1;
      feedback.textContent = 'Görsel yükleniyor…';
      setBusy(false);
      dialog.showModal();
      source.src = `${url}?original=1`;
    }));
    source.addEventListener('load', () => {
      loaded = true;
      fields.left.max = source.naturalWidth - 1;
      fields.top.max = source.naturalHeight - 1;
      fields.width.max = source.naturalWidth;
      fields.height.max = source.naturalHeight;
      setBounds({left: 0, top: 0, width: source.naturalWidth, height: source.naturalHeight});
      setBusy(false); feedback.textContent = 'Kırpmak istediğiniz alanı seçin.';
    });
    source.addEventListener('error', () => { loaded = false; setBusy(false); feedback.textContent = 'Görsel yüklenemedi. Kapatıp tekrar deneyin.'; });
    Object.values(fields).forEach(input => input.addEventListener('input', () => {
      draw(); feedback.textContent = valid(bounds()) ? '' : 'Alan görsel sınırları içinde olmalı; genişlik ve yükseklik en az 1 piksel olmalı.';
    }));
    const point = (event) => {
      const rect = source.getBoundingClientRect();
      return {x: Math.max(0, Math.min(source.naturalWidth, Math.round((event.clientX - rect.left) / rect.width * source.naturalWidth))), y: Math.max(0, Math.min(source.naturalHeight, Math.round((event.clientY - rect.top) / rect.height * source.naturalHeight)))};
    };
    stage.addEventListener('pointerdown', event => {
      if (!loaded || busy || event.button !== 0) return;
      start = point(event); stage.setPointerCapture(event.pointerId); event.preventDefault();
    });
    const move = event => {
      if (!start) return;
      const end = point(event);
      if (end.x === start.x || end.y === start.y) return;
      setBounds({left: Math.min(start.x, end.x), top: Math.min(start.y, end.y), width: Math.abs(end.x - start.x), height: Math.abs(end.y - start.y)});
      feedback.textContent = '';
    };
    stage.addEventListener('pointermove', move);
    stage.addEventListener('pointerup', event => { move(event); start = null; });
    stage.addEventListener('pointercancel', () => { start = null; });
    selectAll.addEventListener('click', () => setBounds({left: 0, top: 0, width: source.naturalWidth, height: source.naturalHeight}));
    const persist = async method => {
      if (busy || (method === 'PATCH' && !valid(bounds()))) return;
      setBusy(true); feedback.textContent = 'Kaydediliyor…';
      try {
        const response = await fetch(url, {method, headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''}, body: method === 'PATCH' ? JSON.stringify(bounds()) : undefined});
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Kaydedilemedi. Tekrar deneyin.');
        document.querySelectorAll('.document-gallery img, [data-markdown-preview] img').forEach(img => {
          if (new URL(img.src, location.href).pathname === url) img.src = `${url}?v=${Date.now()}`;
        });
        document.querySelector('[data-workspace-feedback]').textContent = method === 'PATCH' ? 'Görsel kırpıldı. ZIP ve HTML çıktıları güncellendi.' : 'Orijinal görsel geri yüklendi.';
        dialog.close();
      } catch (error) {
        feedback.textContent = error.message || 'Kaydedilemedi. Tekrar deneyin.';
      } finally { setBusy(false); }
    };
    save.addEventListener('click', () => persist('PATCH'));
    restore.addEventListener('click', () => persist('DELETE'));
    close.addEventListener('click', () => dialog.close());
    dialog.addEventListener('cancel', event => { if (busy) event.preventDefault(); });
    dialog.addEventListener('close', () => { start = null; opener?.focus(); });
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
  document.addEventListener('turbo:load', init);
})();
