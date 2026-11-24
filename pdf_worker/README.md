# pdf_worker

Internal FastAPI service that turns PDFs into Markdown and builds exports.
Only Rails (`app/services/pdf_conversion_client.rb`) calls it, over the
internal `pdf` Docker network. It has no public port.

## Auth

Every endpoint except `/health` needs `Authorization: Bearer <key>`.
The key (32+ chars) comes from `PDF_WORKER_API_KEY`, or from the file named
by `PDF_WORKER_API_KEY_FILE` (the Docker secret in production). The service
refuses to start without it.

## Endpoints

| Method | Path | Request | Response |
|---|---|---|---|
| GET | `/health` | – | `{"status": "ok"}` |
| POST | `/convert` | multipart, see below | JSON, see below |
| POST | `/export-zip` | JSON export body | `application/zip`: `<stem>.md` + `images/<file>` |
| POST | `/export-html` | JSON export body | `text/html`: sanitized HTML, images inlined as data URIs |
| POST | `/crop-image` | multipart: `file`, `left`, `top`, `width`, `height` (px) | cropped image, same format |

### `/convert`

Multipart fields:

- `file` (required): the PDF. Max 25 MB, max 250 pages, must start with `%PDF-`.
- `custom_notes`: text added to the YAML front matter as `user_notes`.
- `annotation_mode`: `both` (default), `section` or `inline`.
- `image_quality`: `balanced` (200 DPI WebP), `high` (default, 240 DPI PNG), `maximum` (300 DPI PNG).
- Booleans, all default `true`: `extract_images_enabled`, `strip_headers_footers`,
  `bind_captions_enabled`, `extract_annotations_enabled`, `include_yaml_frontmatter`,
  `fix_hyphenation_enabled`, `detect_tables`.

Response:

```json
{
  "markdown_content": "...",
  "stats": {"page_count": 1, "parser": "pymupdf", "images_extracted": 0, "tables_converted": 0, "...": 0},
  "images": [{"filename": "figure_p1_1.png", "page": 1, "width": 800, "height": 600,
              "content_type": "image/png", "caption": "Figure 1: ...", "data_base64": "..."}]
}
```

Images are captioned page regions rendered as screenshots (max 50 images,
20 MB in total). Markdown references them as `images/<filename>`.
Text comes from PyMuPDF; MarkItDown is the fallback when PyMuPDF finds none.

### Export body

```json
{"markdown_content": "...", "source_filename": "report.pdf",
 "images": [{"filename": "figure_p1_1.png", "data_base64": "..."}]}
```

Markdown max 10 MB, max 50 images, filenames `[a-zA-Z0-9][a-zA-Z0-9._-]*`.

## Errors

`413`/`422` carry `{"detail": "<Turkish message>"}`; Rails shows that text to
the user. `401` means a missing or wrong key. Rails maps anything else to a
generic "service unavailable" message.

## Limits and resources

- All work happens in memory. Uploads larger than 1 MB are spooled by
  python-multipart to `/tmp` (a tmpfs in compose) and closed after the request.
- Conversion runs on the event loop, so one conversion runs at a time.
  Rails waits up to 180 s (`read_timeout`) per request.
- Compose limits: 1.5 GB RAM, 1 CPU.

## Tests

```bash
cd pdf_worker && python -m unittest discover -s tests -v
```
