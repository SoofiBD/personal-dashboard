import io
import os
import unittest
from unittest.mock import patch, MagicMock
from contextlib import contextmanager
from types import SimpleNamespace

os.environ['NAS_API_TOKEN'] = 'test-' * 10
from app import app, safe_path, child_path, LimitedFile, LIMIT


class NasTest(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()
        self.headers = {'Authorization': 'Bearer ' + os.environ['NAS_API_TOKEN']}
        self.conn = MagicMock()
        @contextmanager
        def fake():
            yield self.conn, 'test-share'
        self.patcher = patch('app.connection', fake)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def test_private_routes_require_token(self):
        for path in ('/browse', '/download'):
            self.assertEqual(self.client.get(path).status_code, 401)
        self.assertEqual(self.client.get('/health').status_code, 200)

    def test_traversal_wildcards_and_root_protected(self):
        for path in ('../x', '/a/../b', '/a\\b', '/*', '/a?', '/a:b', '/a\x00', '/a//b', '/a./b'):
            with self.assertRaises(ValueError):
                safe_path(path)
        with self.assertRaises(ValueError):
            safe_path('/', root=False)
        for name in ('..', 'a/b', 'a\\b', '*', ''):
            with self.assertRaises(ValueError):
                child_path('/', name)
        self.assertEqual(safe_path('/Türkçe yedek/a..txt'), '/Türkçe yedek/a..txt')

    def test_listing_summary_search_sort_pagination(self):
        self.conn.listPath.return_value = [SimpleNamespace(filename=f'file-{n:03}', isDirectory=False, file_size=n, last_write_time=n) for n in range(205)]
        response = self.client.get('/browse?sort=size&page=2', headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json['files']), 100)
        self.assertEqual(response.json['files'][0]['size'], 104)
        self.assertEqual(response.json['summary']['files'], 205)
        self.assertEqual(self.client.get('/browse?q=file-204', headers=self.headers).json['total'], 1)

    def test_no_recursive_scan(self):
        self.conn.listPath.return_value = [SimpleNamespace(filename='folder', isDirectory=True, file_size=0, last_write_time=0)]
        self.client.get('/browse', headers=self.headers)
        self.assertEqual(self.conn.listPath.call_count, 1)

    def test_delete_requires_exact_name_and_rejects_wildcard(self):
        for data in ({'path': '/*', 'confirmation': '*'}, {'path': '/file', 'confirmation': 'wrong'}, {'path': '/', 'confirmation': ''}):
            self.assertEqual(self.client.post('/delete', json=data, headers=self.headers).status_code, 400)
        self.conn.deleteFiles.assert_not_called()
        self.conn.getAttributes.return_value.isDirectory = True
        self.assertEqual(self.client.post('/delete', json={'path': '/empty', 'confirmation': 'empty'}, headers=self.headers).status_code, 200)
        self.conn.deleteDirectory.assert_called_once()

    def test_upload_does_not_replace_existing(self):
        self.conn.listPath.return_value = [SimpleNamespace(filename='backup.txt')]
        response = self.client.post('/upload', data={'path': '/', 'file': (io.BytesIO(b'x'), 'BACKUP.txt')}, headers=self.headers)
        self.assertEqual(response.status_code, 409)
        self.conn.storeFile.assert_not_called()

    def test_download_and_size_limit(self):
        self.conn.getAttributes.return_value = SimpleNamespace(isDirectory=False, file_size=3)
        self.conn.retrieveFile.side_effect = lambda share, path, file, **kw: file.write(b'abc')
        response = self.client.get('/download?path=/file.txt', headers=self.headers)
        self.assertEqual(response.data, b'abc')
        self.assertIn('attachment', response.headers['Content-Disposition'])
        response.close()
        self.conn.getAttributes.return_value.file_size = LIMIT + 1
        self.assertEqual(self.client.get('/download?path=/large', headers=self.headers).status_code, 400)
        bounded = LimitedFile(io.BytesIO())
        bounded.size = LIMIT
        with self.assertRaises(ValueError):
            bounded.write(b'x')

    def test_errors_do_not_leak_network_secrets(self):
        self.conn.listPath.side_effect = RuntimeError('sensitive-password-host')
        response = self.client.get('/browse', headers=self.headers)
        self.assertEqual(response.status_code, 503)
        self.assertNotIn(b'sensitive-password-host', response.data)
        self.assertEqual(response.headers['Cache-Control'], 'no-store')


if __name__ == '__main__':
    unittest.main()
