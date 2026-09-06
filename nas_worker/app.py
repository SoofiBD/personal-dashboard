"""Private SMB adapter. Only Rails knows the service credential."""
import hmac
import os
import tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from time import monotonic

from flask import Flask, jsonify, request, send_file
from smb.SMBConnection import SMBConnection
from werkzeug.exceptions import HTTPException

app = Flask(__name__)
LIMIT = 256 * 1024 * 1024
app.config.update(MAX_CONTENT_LENGTH=LIMIT + 1024 * 1024, MAX_FORM_MEMORY_SIZE=64 * 1024)


def safe_path(value, root=True):
    if not isinstance(value, str) or len(value.encode()) > 2048:
        raise ValueError('Geçersiz dosya yolu.')
    if any(ord(c) < 32 for c in value) or any(c in value for c in '\\:*?"<>|'):
        raise ValueError('Geçersiz dosya yolu.')
    parts = value.strip('/').split('/') if value.strip('/') else []
    if any(p in ('', '.', '..') or len(p.encode()) > 255 or p.endswith((' ', '.')) for p in parts):
        raise ValueError('Geçersiz dosya yolu.')
    if not parts and not root:
        raise ValueError('Dosya seçin.')
    return '/' + '/'.join(parts)


def child_path(parent, name):
    if not isinstance(name, str) or '/' in name or not name:
        raise ValueError('Geçersiz ad.')
    safe_path(name, root=False)
    return safe_path(parent).rstrip('/') + '/' + name


@app.before_request
def authenticate():
    if request.path == '/health':
        return
    token = os.environ.get('NAS_API_TOKEN', '')
    if len(token) < 32 or not hmac.compare_digest(request.headers.get('Authorization', ''), 'Bearer ' + token):
        return jsonify(error='Yetkisiz erişim.'), 401


@app.after_request
def private_response(response):
    response.headers['Cache-Control'] = 'no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    return response


@app.errorhandler(Exception)
def error(exc):
    if isinstance(exc, ValueError):
        return jsonify(error=str(exc)), 400
    if isinstance(exc, HTTPException):
        return jsonify(error='İstek işlenemedi.'), exc.code
    # SMB exceptions can contain authentication and private network details.
    app.logger.warning('NAS operation failed (%s)', type(exc).__name__)
    return jsonify(error='NAS işlemi tamamlanamadı. Bağlantıyı ve paylaşım izinlerini kontrol edin.'), 503


@contextmanager
def connection():
    required = ('NAS_HOST', 'NAS_USER', 'NAS_PASSWORD', 'NAS_SHARE')
    if not all(os.environ.get(k) for k in required):
        raise RuntimeError('Not configured')
    conn = SMBConnection(os.environ['NAS_USER'], os.environ['NAS_PASSWORD'], 'dashboard',
                         os.environ['NAS_HOST'], domain=os.environ.get('NAS_DOMAIN', ''),
                         use_ntlm_v2=True, is_direct_tcp=True)
    try:
        if not conn.connect(os.environ['NAS_HOST'], 445, timeout=8):
            raise ConnectionError('Unavailable')
        if not conn.isUsingSMB2:
            raise ConnectionError('SMB2 required')
        yield conn, os.environ['NAS_SHARE']
    finally:
        conn.close()


@app.get('/health')
def health():
    return jsonify(status='ok')


@app.get('/browse')
def browse():
    path = safe_path(request.args.get('path', '/'))
    query = request.args.get('q', '')[:100].casefold()
    sort = request.args.get('sort', 'name')
    page = max(1, min(int(request.args.get('page', 1)), 10000))
    started = monotonic()
    with connection() as (conn, share):
        entries = conn.listPath(share, path, timeout=10)
    files = []
    for entry in entries:
        if entry.filename in ('.', '..'):
            continue
        try:
            full_path = child_path(path, entry.filename)
        except ValueError:
            continue
        files.append(dict(name=entry.filename, path=full_path, is_dir=entry.isDirectory,
                          size=entry.file_size if not entry.isDirectory else 0,
                          modified=entry.last_write_time))
    summary = dict(files=sum(not f['is_dir'] for f in files), folders=sum(f['is_dir'] for f in files),
                   bytes=sum(f['size'] for f in files))
    filtered = [f for f in files if query in f['name'].casefold()]
    key = {'name': lambda f: f['name'].casefold(), 'size': lambda f: -f['size'],
           'modified': lambda f: -f['modified']}.get(sort, lambda f: f['name'].casefold())
    filtered.sort(key=lambda f: (not f['is_dir'], key(f), f['name'].casefold()))
    return jsonify(path=path, files=filtered[(page-1)*100:page*100], total=len(filtered), page=page,
                   summary=summary, checked_at=datetime.now(timezone.utc).isoformat(),
                   latency_ms=round((monotonic()-started)*1000), max_file_bytes=LIMIT)


class LimitedFile:
    def __init__(self, file):
        self.file = file
        self.size = 0

    def write(self, chunk):
        self.size += len(chunk)
        if self.size > LIMIT:
            raise ValueError('Dosya 256 MiB sınırını aşıyor.')
        return self.file.write(chunk)


@app.get('/download')
def download():
    path = safe_path(request.args.get('path', ''), root=False)
    buffer = tempfile.TemporaryFile()
    try:
        with connection() as (conn, share):
            attrs = conn.getAttributes(share, path, timeout=10)
            if attrs.isDirectory or attrs.file_size > LIMIT:
                raise ValueError('Bir dosya seçin (en fazla 256 MiB).')
            conn.retrieveFile(share, path, LimitedFile(buffer), timeout=60)
        buffer.seek(0)
        response = send_file(buffer, as_attachment=True, download_name=path.rsplit('/', 1)[-1],
                             mimetype='application/octet-stream', conditional=False)
        response.call_on_close(buffer.close)
        return response
    except Exception:
        buffer.close()
        raise


@app.post('/upload')
def upload():
    file = request.files.get('file')
    if not file:
        raise ValueError('Dosya seçin.')
    path = child_path(request.form.get('path', '/'), file.filename)
    file.stream.seek(0, 2)
    if file.stream.tell() > LIMIT:
        raise ValueError('Dosya 256 MiB sınırını aşıyor.')
    file.stream.seek(0)
    with connection() as (conn, share):
        # Explicit overwrite consent; no hidden replacement of existing backups.
        existing = conn.listPath(share, path.rsplit('/', 1)[0] or '/', timeout=10)
        if any(e.filename.casefold() == file.filename.casefold() for e in existing):
            return jsonify(error='Bu ad zaten var. Dosyayı yeniden adlandırın.'), 409
        conn.storeFile(share, path, file.stream, timeout=60)
    return jsonify(success=True)


@app.post('/folder')
def folder():
    data = request.get_json()
    path = child_path(data.get('path', '/'), data.get('name', ''))
    with connection() as (conn, share):
        conn.createDirectory(share, path, timeout=10)
    return jsonify(success=True)


@app.post('/delete')
def delete():
    data = request.get_json()
    path = safe_path(data.get('path', ''), root=False)
    if data.get('confirmation') != path.rsplit('/', 1)[-1]:
        raise ValueError('Silmek için dosya adını aynen yazın.')
    with connection() as (conn, share):
        attrs = conn.getAttributes(share, path, timeout=10)
        if attrs.isDirectory:
            conn.deleteDirectory(share, path, timeout=10)  # Only empty directories.
        else:
            conn.deleteFiles(share, path, timeout=10)
    return jsonify(success=True)
