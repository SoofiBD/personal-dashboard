import io
import re
import time
import math
import base64
import zipfile
import html
import mimetypes
from datetime import datetime, timezone

import fitz
import bleach
import markdown
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from markitdown import MarkItDown
from pydantic import BaseModel, Field

MAX_FILE_SIZE = 25 * 1024 * 1024
MAX_PAGE_COUNT = 250
MIN_IMAGE_DIMENSION = 100
MAX_IMAGE_COUNT = 50
MAX_EXTRACTED_IMAGE_BYTES = 20 * 1024 * 1024

app = FastAPI(title="Personal Dashboard PDF Worker", docs_url=None, redoc_url=None)


class ZipImage(BaseModel):
    filename: str = Field(pattern=r"^[a-zA-Z0-9][a-zA-Z0-9._-]*$")
    data_base64: str


class ZipExport(BaseModel):
    markdown_content: str = Field(max_length=10_000_000)
    source_filename: str = Field(max_length=255)
    images: list[ZipImage] = Field(max_length=MAX_IMAGE_COUNT)


class HtmlExport(ZipExport):
    pass


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/convert")
async def convert(
    file: UploadFile = File(...), custom_notes: str = Form(default=""), annotation_mode: str = Form(default="both"),
    extract_images_enabled: bool = Form(default=True), min_image_dimension: int = Form(default=MIN_IMAGE_DIMENSION),
    strip_headers_footers: bool = Form(default=True), bind_captions_enabled: bool = Form(default=True),
    extract_annotations_enabled: bool = Form(default=True), include_yaml_frontmatter: bool = Form(default=True),
    fix_hyphenation_enabled: bool = Form(default=True), detect_tables: bool = Form(default=True),
):
    contents = await file.read(MAX_FILE_SIZE + 1)
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="PDF dosyası en fazla 25 MB olabilir.")
    if not contents.startswith(b"%PDF-"):
        raise HTTPException(status_code=422, detail="Yüklenen dosya geçerli bir PDF değil.")
    if annotation_mode not in {"section", "inline", "both"}:
        raise HTTPException(status_code=422, detail="Geçersiz anotasyon modu.")
    if not 50 <= min_image_dimension <= 500:
        raise HTTPException(status_code=422, detail="Minimum görsel boyutu 50 ile 500 piksel arasında olmalıdır.")

    started_at = time.perf_counter()
    try:
        document = fitz.open(stream=contents, filetype="pdf")
        page_count = document.page_count
        if page_count > MAX_PAGE_COUNT:
            raise HTTPException(status_code=422, detail="PDF en fazla 250 sayfa olabilir.")
        running_artifacts = find_running_artifacts(document) if strip_headers_footers else []
        heading_candidates = find_heading_candidates(document)
        annotations = extract_annotations(document) if extract_annotations_enabled else []
        images = extract_images(document, min_image_dimension) if extract_images_enabled else []
        tables = extract_tables(document) if detect_tables else []
        markdown = extract_layout_text(document)
        if not markdown:
            markdown = MarkItDown().convert_stream(io.BytesIO(contents), file_extension=".pdf").text_content.strip()
        document.close()
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=422, detail="PDF dönüştürülemedi.") from error

    markdown, headers_stripped = sanitize_markdown(markdown, running_artifacts, fix_hyphenation_enabled)
    markdown, captions_bound = bind_captions(markdown, images) if bind_captions_enabled else (markdown, 0)
    markdown, headings_synthesized = synthesize_headings(markdown, heading_candidates)
    if include_yaml_frontmatter:
        markdown = inject_frontmatter(markdown, file.filename or "document.pdf", custom_notes)
    markdown, tables_converted = append_tables(markdown, tables)
    markdown = append_images(markdown, images)
    markdown, annotations_inlined = inline_annotations(markdown, annotations) if annotation_mode in {"inline", "both"} else (markdown, 0)
    section_annotations = annotations if annotation_mode in {"section", "both"} else [annotation for annotation in annotations if annotation["type"] == "note"]
    markdown = append_annotations(markdown, section_annotations)
    return {
        "markdown_content": markdown,
        "stats": {
            "page_count": page_count,
            "headers_stripped": headers_stripped,
            "captions_bound": captions_bound,
            "headings_synthesized": headings_synthesized,
            "annotations_extracted": len(annotations),
            "annotations_inlined": annotations_inlined,
            "images_extracted": len(images),
            "tables_converted": tables_converted,
            "processing_time_ms": round((time.perf_counter() - started_at) * 1000),
        },
        "images": images,
    }


@app.post("/export-zip")
def export_zip(payload: ZipExport):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, mode="w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(f"{safe_stem(payload.source_filename)}.md", payload.markdown_content)
        for image in payload.images:
            try:
                image_data = base64.b64decode(image.data_base64, validate=True)
            except ValueError as error:
                raise HTTPException(status_code=422, detail="Geçersiz görsel verisi.") from error
            archive.writestr(f"images/{image.filename}", image_data)
    return Response(content=buffer.getvalue(), media_type="application/zip")


@app.post("/export-html")
def export_html(payload: HtmlExport):
    image_data = {}
    for image in payload.images:
        try:
            decoded = base64.b64decode(image.data_base64, validate=True)
        except ValueError as error:
            raise HTTPException(status_code=422, detail="Geçersiz görsel verisi.") from error
        content_type = mimetypes.guess_type(image.filename)[0] or "application/octet-stream"
        image_data[image.filename] = f"data:{content_type};base64,{base64.b64encode(decoded).decode('ascii')}"

    rendered = markdown.markdown(payload.markdown_content, extensions=["tables", "fenced_code"])
    rendered = bleach.clean(
        rendered,
        tags={"a", "blockquote", "br", "code", "del", "em", "h1", "h2", "h3", "h4", "hr", "img", "li", "ol", "p", "pre", "strong", "table", "tbody", "td", "th", "thead", "tr", "u", "ul"},
        attributes={"a": ["href", "title"], "img": ["alt", "src"], "*": ["class"]},
        protocols={"http", "https", "mailto", "data"}
    )
    rendered = re.sub(r'src="images/([a-zA-Z0-9._-]+)"', lambda match: f'src="{image_data.get(match.group(1), match.group(0))}"', rendered)
    title = html.escape(safe_stem(payload.source_filename))
    document = f"<!doctype html><html lang=\"tr\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{title}</title><style>body{{color:#172033;font:16px/1.65 system-ui,sans-serif;margin:0 auto;max-width:860px;padding:2rem}}img{{height:auto;max-width:100%}}table{{border-collapse:collapse;width:100%}}td,th{{border:1px solid #cbd5e1;padding:.5rem;text-align:left}}pre{{background:#f1f5f9;overflow:auto;padding:1rem}}</style></head><body>{rendered}</body></html>"
    return Response(content=document, media_type="text/html; charset=utf-8")


def extract_annotations(document):
    annotation_types = {
        fitz.PDF_ANNOT_HIGHLIGHT: "highlight",
        fitz.PDF_ANNOT_UNDERLINE: "underline",
        fitz.PDF_ANNOT_SQUIGGLY: "squiggly underline",
        fitz.PDF_ANNOT_STRIKE_OUT: "strikeout",
        fitz.PDF_ANNOT_TEXT: "note",
        fitz.PDF_ANNOT_FREE_TEXT: "note",
    }
    annotations = []
    for page_number, page in enumerate(document, start=1):
        for annotation in page.annots() or []:
            annotation_type = annotation_types.get(annotation.type[0])
            if not annotation_type:
                continue
            info = annotation.info or {}
            text = page.get_textbox(annotation.rect).strip()
            comment = (info.get("content") or "").strip()
            if text or comment:
                annotations.append({"page": page_number, "type": annotation_type, "text": text, "comment": comment})
    return annotations


def find_heading_candidates(document):
    spans = []
    lines = []
    for page in document:
        for block in page.get_text("dict")["blocks"]:
            if block.get("type") != 0:
                continue
            for line in block.get("lines", []):
                line_spans = line.get("spans", [])
                text = normalize_plain_text("".join(span["text"] for span in line_spans))
                if not text or len(text) > 140 or len(text) < 2:
                    continue
                size = max(span["size"] for span in line_spans)
                bold = any("bold" in span["font"].lower() for span in line_spans)
                spans.extend(round(span["size"], 1) for span in line_spans if span["text"].strip())
                lines.append({"text": text, "size": size, "bold": bold})

    if not spans:
        return []
    body_size = max(set(spans), key=spans.count)
    candidates = {}
    for line in lines:
        size_ratio = line["size"] / body_size
        if size_ratio >= 1.6:
            level = 1
        elif size_ratio >= 1.3:
            level = 2
        elif size_ratio >= 1.1 and line["bold"]:
            level = 3
        else:
            continue
        candidates[line["text"]] = min(level, candidates.get(line["text"], level))
    return [{"text": text, "level": level} for text, level in candidates.items()]


def find_running_artifacts(document):
    candidates = {}
    for page in document:
        page_candidates = set()
        top_boundary = page.rect.height * 0.08
        bottom_boundary = page.rect.height * 0.92
        for block in page.get_text("blocks", sort=True):
            x0, y0, _x1, y1, text, *_rest = block
            if y1 > top_boundary and y0 < bottom_boundary:
                continue
            value = normalize_block_text(text)
            if value:
                page_candidates.add(value)
        for candidate in page_candidates:
            candidates[candidate] = candidates.get(candidate, 0) + 1

    threshold = max(2, math.ceil(document.page_count * 0.7))
    return [candidate for candidate, count in candidates.items() if count >= threshold]


def normalize_block_text(value):
    return re.sub(r"\d+", "#", normalize_plain_text(value))


def normalize_plain_text(value):
    return re.sub(r"\s+", " ", value).strip()


def extract_layout_text(document):
    """Build a predictable reading order for common single- and two-column PDFs."""
    pages = []
    for page in document:
        page_width, page_height = page.rect.width, page.rect.height
        blocks = []
        for block in page.get_text("blocks", sort=False):
            x0, y0, x1, y1, text, *_rest = block
            if not text.strip():
                continue
            cleaned = re.sub(r"[ \t]+", " ", text).strip()
            if not cleaned:
                continue
            blocks.append({"x0": x0, "x1": x1, "y0": y0, "text": cleaned})

        # Titles, authors, affiliations and abstracts generally span the page width.
        early = sorted((block for block in blocks if block["y0"] < page_height * 0.38), key=lambda block: block["y0"])
        body = [block for block in blocks if block["y0"] >= page_height * 0.38]
        left = sorted((block for block in body if block["x0"] < page_width * 0.5), key=lambda block: block["y0"])
        right = sorted((block for block in body if block["x0"] >= page_width * 0.5), key=lambda block: block["y0"])
        pages.append("\n\n".join(block["text"] for block in [*early, *left, *right]))
    return "\n\n".join(page for page in pages if page).strip()


def sanitize_markdown(markdown, running_artifacts, fix_hyphenation_enabled=True):
    cleaned = markdown
    removed_count = 0
    for artifact in running_artifacts:
        tokens = artifact.split()
        if not tokens:
            continue
        token_patterns = [r"\d+" if token == "#" else re.escape(token) for token in tokens]
        pattern = r"(?im)^\s*" + r"\s+".join(token_patterns) + r"\s*$\n?"
        cleaned, replacements = re.subn(pattern, "", cleaned)
        removed_count += replacements
    if fix_hyphenation_enabled:
        cleaned = heal_hyphenation(cleaned)
        cleaned = unwrap_soft_breaks(cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned).strip()
    return cleaned, removed_count


def heal_hyphenation(markdown):
    # Heal hyphenated words broken across lines (e.g. "nonradia-\ntive" -> "nonradiative")
    return re.sub(r"(?<=\w)-\n[ \t]*(?=[a-zA-ZğüşıöçĞÜŞİÖÇ])", "", markdown)


def unwrap_soft_breaks(markdown):
    # Split document by two or more newlines (paragraph boundaries)
    raw_blocks = re.split(r"\n\s*\n", markdown)
    cleaned_blocks = []
    for raw_block in raw_blocks:
        block = raw_block.strip()
        if not block:
            continue
        # Preserve code blocks, tables, and YAML frontmatter verbatim
        if block.startswith("```") or block.startswith("|") or block.startswith("---"):
            cleaned_blocks.append(block)
            continue

        lines = block.splitlines()
        # Check if this block is a list or contains list items
        has_list_items = any(re.match(r"^\s*([-*+]|\d+\.)\s+", line) for line in lines)
        if has_list_items:
            item_lines = []
            for line in lines:
                stripped = line.strip()
                if re.match(r"^([-*+]|\d+\.)\s+", stripped):
                    item_lines.append(stripped)
                elif item_lines:
                    item_lines[-1] += " " + stripped
                else:
                    item_lines.append(stripped)
            cleaned_blocks.append("\n".join(item_lines))
            continue

        # Check for blockquotes
        has_blockquotes = all(line.strip().startswith(">") for line in lines if line.strip())
        if has_blockquotes:
            quote_text = " ".join(re.sub(r"^>\s*", "", line.strip()) for line in lines if line.strip())
            cleaned_blocks.append(f"> {quote_text}")
            continue

        # Regular text block / paragraph: merge soft breaks into a smooth continuous paragraph
        paragraph_parts = []
        for line in lines:
            stripped = line.strip()
            if not stripped:
                continue
            if re.match(r"^#{1,6}\s+", stripped):
                if paragraph_parts:
                    cleaned_blocks.append(" ".join(paragraph_parts))
                    paragraph_parts = []
                cleaned_blocks.append(stripped)
            else:
                paragraph_parts.append(stripped)

        if paragraph_parts:
            cleaned_blocks.append(" ".join(paragraph_parts))

    return "\n\n".join(cleaned_blocks)


def extract_images(document, min_image_dimension=MIN_IMAGE_DIMENSION):
    images = []
    extracted_bytes = 0
    allowed_types = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp"}
    for page_number, page in enumerate(document, start=1):
        page_raster_rects = []
        # 1. Extract embedded raster images
        for image_index, image_info in enumerate(page.get_images(full=True), start=1):
            xref = image_info[0]
            image = document.extract_image(xref)
            width, height = image["width"], image["height"]
            extension = image.get("ext", "png").lower()
            content_type = allowed_types.get(extension)
            if width < min_image_dimension or height < min_image_dimension or not content_type:
                continue
            image_data = image["image"]
            if len(images) >= MAX_IMAGE_COUNT or extracted_bytes + len(image_data) > MAX_EXTRACTED_IMAGE_BYTES:
                return images

            for r in page.get_image_rects(xref):
                page_raster_rects.append(fitz.Rect(r))

            images.append({
                "filename": f"img_p{page_number}_{image_index}.{extension}",
                "page": page_number,
                "width": width,
                "height": height,
                "content_type": content_type,
                "caption": find_caption(page, xref),
                "data_base64": base64.b64encode(image_data).decode("ascii"),
            })
            extracted_bytes += len(image_data)

        # 2. Extract vector graphics, charts, plots and diagrams
        charts = extract_vector_charts(page, page_number, page_raster_rects, min_image_dimension)
        for chart in charts:
            chart_data = chart["data"]
            if len(images) >= MAX_IMAGE_COUNT or extracted_bytes + len(chart_data) > MAX_EXTRACTED_IMAGE_BYTES:
                return images
            images.append({
                "filename": chart["filename"],
                "page": page_number,
                "width": chart["width"],
                "height": chart["height"],
                "content_type": "image/png",
                "caption": chart["caption"],
                "data_base64": base64.b64encode(chart_data).decode("ascii"),
            })
            extracted_bytes += len(chart_data)

    return images


def extract_vector_charts(page, page_number, raster_rects, min_image_dimension=MIN_IMAGE_DIMENSION):
    drawings = page.get_drawings()
    if not drawings:
        return []

    page_rect = page.rect
    table_rects = []
    try:
        for table in page.find_tables().tables:
            table_rects.append(fitz.Rect(table.bbox))
    except Exception:
        pass

    candidate_rects = []
    for d in drawings:
        r = fitz.Rect(d["rect"])
        # Ignore full-page background boxes
        if r.width >= page_rect.width * 0.92 and r.height >= page_rect.height * 0.92:
            continue
        # Ignore thin header/footer line separators
        if (r.height <= 2.5 and r.width >= page_rect.width * 0.4) or (r.width <= 2.5 and r.height >= page_rect.height * 0.4):
            continue
        # Ignore drawings strictly inside table borders
        if any(r in t_rect for t_rect in table_rects):
            continue
        candidate_rects.append(r)

    if not candidate_rects:
        return []

    # Cluster nearby drawing rectangles (threshold 25pt)
    clusters = []
    for r in candidate_rects:
        merged = False
        margin = 25
        for i, cluster in enumerate(clusters):
            expanded_cluster = fitz.Rect(cluster.x0 - margin, cluster.y0 - margin, cluster.x1 + margin, cluster.y1 + margin)
            if expanded_cluster.intersects(r):
                clusters[i] = cluster | r
                merged = True
                break
        if not merged:
            clusters.append(fitz.Rect(r))

    merged_clusters = []
    while clusters:
        current = clusters.pop(0)
        merged = False
        margin = 20
        for i, other in enumerate(merged_clusters):
            expanded = fitz.Rect(other.x0 - margin, other.y0 - margin, other.x1 + margin, other.y1 + margin)
            if expanded.intersects(current):
                merged_clusters[i] = other | current
                merged = True
                break
        if not merged:
            merged_clusters.append(current)

    charts = []
    chart_index = 1
    for cluster_rect in merged_clusters:
        min_pt = max(45, min_image_dimension * 72 / 150)
        if cluster_rect.width < min_pt or cluster_rect.height < min_pt:
            continue
        if cluster_rect.width * cluster_rect.height < 3000:
            continue

        # Skip if covered by raster image
        if any(
            (cluster_rect.intersect(r_rect).get_area() / max(1, cluster_rect.get_area())) > 0.5
            for r_rect in raster_rects
        ):
            continue

        # Skip if predominantly a table
        if any(
            (cluster_rect.intersect(t_rect).get_area() / max(1, cluster_rect.get_area())) > 0.6
            for t_rect in table_rects
        ):
            continue

        # Check drawing density
        drawings_in_cluster = [d for d in drawings if fitz.Rect(d["rect"]).intersects(cluster_rect)]
        if len(drawings_in_cluster) < 2 and not any(d.get("fill") for d in drawings_in_cluster):
            continue

        # Expand to include axis labels or text blocks located inside/adjacent
        clip_rect = fitz.Rect(cluster_rect)
        for block in page.get_text("blocks", sort=True):
            bx0, by0, bx1, by1, btext, *_ = block
            b_rect = fitz.Rect(bx0, by0, bx1, by1)
            if b_rect.intersects(cluster_rect) or (
                abs(b_rect.y0 - cluster_rect.y1) <= 12 and (b_rect.x0 >= cluster_rect.x0 - 20 and b_rect.x1 <= cluster_rect.x1 + 20)
            ):
                if len(btext.strip()) <= 80:
                    clip_rect |= b_rect

        padded_rect = fitz.Rect(
            max(0, clip_rect.x0 - 4),
            max(0, clip_rect.y0 - 4),
            min(page_rect.width, clip_rect.x1 + 4),
            min(page_rect.height, clip_rect.y1 + 4)
        )

        pix = page.get_pixmap(clip=padded_rect, dpi=150)
        if pix.width < min_image_dimension or pix.height < min_image_dimension:
            continue

        caption = find_caption(page, padded_rect)
        chart_bytes = pix.tobytes("png")

        charts.append({
            "filename": f"chart_p{page_number}_{chart_index}.png",
            "width": pix.width,
            "height": pix.height,
            "caption": caption,
            "data": chart_bytes,
        })
        chart_index += 1

    return charts


def extract_tables(document):
    tables = []
    for page_number, page in enumerate(document, start=1):
        try:
            found_tables = page.find_tables().tables
        except Exception:
            continue
        for table in found_tables:
            rows = normalize_table_rows(table.extract())
            if is_valid_table(rows):
                tables.append({"page": page_number, "rows": rows})
    return tables


def normalize_table_rows(rows):
    normalized = []
    for row in rows:
        normalized.append([normalize_plain_text(cell or "") for cell in row])
    return normalized


def is_valid_table(rows):
    if len(rows) < 2 or max((len(row) for row in rows), default=0) < 2:
        return False
    non_empty_cells = [cell for row in rows for cell in row if cell]
    if len(non_empty_cells) < 4:
        return False
    total_cells = sum(len(row) for row in rows)
    if len(non_empty_cells) / total_cells < 0.6:
        return False
    return sum(len(cell) > 120 for cell in non_empty_cells) / len(non_empty_cells) <= 0.3


def find_caption(page, target):
    caption_pattern = re.compile(r"^(figure|fig\.|şekil|resim|görsel|table|tablo|chart|grafik|diagram|çizelge)\s*\d*[:.\s-].*", re.IGNORECASE)
    if isinstance(target, fitz.Rect):
        image_rects = [target]
    elif isinstance(target, int):
        image_rects = page.get_image_rects(target)
    else:
        image_rects = [fitz.Rect(target)]

    candidates = []
    for block in page.get_text("blocks", sort=True):
        _x0, y0, _x1, y1, text, *_rest = block
        value = normalize_plain_text(text)
        if not caption_pattern.match(value):
            continue
        for image_rect in image_rects:
            below_gap = y0 - image_rect.y1
            above_gap = image_rect.y0 - y1
            if 0 <= below_gap <= 45 or 0 <= above_gap <= 30:
                candidates.append((min(abs(below_gap), abs(above_gap)), value))
    return min(candidates, default=(0, ""))[1]


def inject_frontmatter(markdown, filename, custom_notes):
    escaped_filename = filename.replace('"', "'")
    lines = ["---", f'title: "{escaped_filename.rsplit(".", 1)[0]}"', f'source_file: "{escaped_filename}"', f'converted_at: "{datetime.now(timezone.utc).isoformat()}"']
    if custom_notes.strip():
        lines.extend(["user_notes: |", *[f"  {line}" for line in custom_notes.strip().splitlines()]])
    return "\n".join(lines) + "\n---\n\n" + markdown


def bind_captions(markdown, images):
    cleaned = markdown
    bound_count = 0
    for image in images:
        caption = image.get("caption", "")
        if not caption:
            continue
        pattern = r"(?im)^\s*" + r"\s+".join(re.escape(token) for token in caption.split()) + r"\s*$\n?"
        cleaned, replacements = re.subn(pattern, "", cleaned, count=1)
        bound_count += replacements
    return cleaned, bound_count


def synthesize_headings(markdown, candidates):
    cleaned = markdown
    synthesized_count = 0
    for candidate in candidates:
        text = candidate["text"]
        pattern = r"(?m)^(?!#)\s*" + r"\s+".join(re.escape(token) for token in text.split()) + r"\s*$"
        replacement = "#" * candidate["level"] + " " + text
        cleaned, replacements = re.subn(pattern, replacement, cleaned, count=1)
        synthesized_count += replacements
    return cleaned, synthesized_count


def append_annotations(markdown, annotations):
    if not annotations:
        return markdown
    items = ["## Extracted Highlights & Notes"]
    for annotation in annotations:
        text = re.sub(r"\s+", " ", annotation["text"])
        item = f'- **[p. {annotation["page"]} | {annotation["type"]}]**'
        if text:
            item += f': *"{text}"*'
        if annotation["comment"]:
            item += f' — Note: {annotation["comment"]}'
        items.append(item)
    return markdown.rstrip() + "\n\n" + "\n".join(items) + "\n"


def inline_annotations(markdown, annotations):
    cleaned = markdown
    applied = 0
    wrappers = {
        "highlight": ("==", "=="),
        "underline": ("<u>", "</u>"),
        "squiggly underline": ("<u>", "</u>"),
        "strikeout": ("~~", "~~"),
    }
    for annotation in annotations:
        opening, closing = wrappers.get(annotation["type"], (None, None))
        text = normalize_plain_text(annotation["text"])
        if not opening or not text:
            continue
        tokens = text.split()
        if len(tokens) > 1 and len(tokens[0]) == 1:
            tokens = tokens[1:]
            text = " ".join(tokens)
        pattern = r"(?<![\w>])" + r"\s+".join(re.escape(token) for token in tokens) + r"(?![\w<])"
        cleaned, replacements = re.subn(pattern, opening + text + closing, cleaned, count=1)
        applied += replacements
    return cleaned, applied


def append_images(markdown, images):
    if not images:
        return markdown
    items = ["## Extracted Images"]
    for image in images:
        caption = image.get("caption") or f'Extracted image from page {image["page"]}'
        items.append(f'![{caption}](images/{image["filename"]})')
        if image.get("caption"):
            items.append(f'*{image["caption"]}*')
    return markdown.rstrip() + "\n\n" + "\n\n".join(items) + "\n"


def append_tables(markdown, tables):
    converted = []
    for table in tables:
        gfm = table_to_markdown(table["rows"])
        if gfm and gfm not in markdown:
            converted.append(f"### Table from page {table['page']}\n\n{gfm}")
    if not converted:
        return markdown, 0
    return markdown.rstrip() + "\n\n## Extracted Tables\n\n" + "\n\n".join(converted) + "\n", len(converted)


def table_to_markdown(rows):
    column_count = max(len(row) for row in rows)
    padded_rows = [row + [""] * (column_count - len(row)) for row in rows]
    header = [cell or f"Column {index + 1}" for index, cell in enumerate(padded_rows[0])]
    lines = [markdown_table_row(header), markdown_table_row(["---"] * column_count)]
    lines.extend(markdown_table_row(row) for row in padded_rows[1:])
    return "\n".join(lines)


def markdown_table_row(row):
    return "| " + " | ".join(cell.replace("|", "\\|").replace("\n", "<br>") for cell in row) + " |"


def safe_stem(filename):
    stem = re.sub(r"[^a-zA-Z0-9._-]+", "-", filename.rsplit(".", 1)[0]).strip(".-")
    return stem or "converted-document"
