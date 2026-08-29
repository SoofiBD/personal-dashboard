# PDF to Clean Markdown & Image Extractor Web Panel
## Complete Technical Architecture, Non-AI Layout Heuristics, and Implementation Roadmap

---

## 1. Executive Summary & Problem Formulation

### 1.1 Objective
Build a modern, high-performance web dashboard that converts complex PDF documents into clean, structured Markdown (`.md`), automatically extracts all embedded figures/images into a companion `images/` directory, links those images seamlessly within the generated Markdown, and exports the bundle as a downloadable ZIP archive.

### 1.2 The Core Problem with Standard PDF-to-Markdown Converters
Standard PDF parsers (including out-of-the-box Microsoft `markitdown`, `pdfminer`, and `pypdf`) read PDF content streams sequentially without layout-coordinate awareness. This results in:
1. **Header & Footer Pollution:** Running headers, page titles, and page numbers repeatedly interrupt the middle of sentences across page boundaries.
2. **Caption & Floating Text Collision:** Figure captions (e.g., *"Figure 1: Architecture diagram"*), chart labels, and sidebar notes are inserted directly into body paragraphs, breaking readability.
3. **Hyphenation & Broken Lines:** Words split across lines with hyphens (e.g., `infor-` / `mation`) remain broken; hard line breaks from PDF line wraps destroy Markdown paragraph flow.
4. **Missing Images & Visual Context:** Standard parsers do not extract raster images or bind them spatially to their corresponding positions and captions in the Markdown output.
5. **Non-AI Constraint (Initial Phase):** The solution must achieve high fidelity **without relying on external LLM/AI APIs**, utilizing deterministic geometric heuristics, coordinate-based layout parsing, and string pattern analysis—while maintaining an extensible plug-in interface for future AI/Vision enhancements.

---

## 2. System Architecture & High-Level Flow

```mermaid
flowchart TD
    subgraph Client_Side ["Frontend Web Panel (SPA)"]
        A[User Drops PDF] --> B[Configuration Options\n- Remove Headers/Footers\n- Extract Images & Bind Captions\n- Fix Hyphenation\n- Format Tables]
        B --> C[POST /api/convert Multipart Upload]
        G[Receive Markdown + Images] --> H[Split-View Workspace]
        H --> H1[Left: Markdown Code Editor]
        H --> H2[Right: Live Rendered Preview + Images]
        H --> I[Export Options: Download ZIP / Copy MD / Export HTML]
    end

    subgraph Server_Side ["Backend Processing Pipeline (FastAPI + Python)"]
        C --> D[PDF Pre-processor & PyMuPDF / MarkItDown Engine]
        
        subgraph Deterministic_Pipeline ["Deterministic Cleaning Engine (No-AI)"]
            D --> E1[1. Page Coordinate & Margin Analyzer]
            E1 --> E2[2. Header & Footer Deduplication Engine]
            E2 --> E3[3. Image Extraction & Bounding Box Spatial Indexing]
            E3 --> E4[4. Caption Isolation & Proximity Anchor Engine]
            E4 --> E5[5. Font-Size Hierarchy & Heading Synthesizer]
            E5 --> E6[6. Table Geometry & Markdown Formatter]
            E6 --> E7[7. Line Wrap & Hyphenation Healer]
        end
        
        subgraph Future_AI_Hook ["Future AI Plug-in Hook (Optional)"]
            E7 -.->|If Enabled| F1[Vision / LLM Refinement Module]
            F1 -.-> F2[Semantic Structuring]
        end
        
        E7 --> J[Markdown Compiler & Image Linker]
        F2 -.-> J
        J --> K[ZIP Packaging Engine]
        K --> G
    end
```

---

## 3. Deep-Dive: Deterministic Layout & Text Cleaning Engine (Non-AI)

### 3.1 Margin & Running Header/Footer Elimination
* **Vertical Coordinate Thresholding:** Define dynamic top margin $Y_{top} < 0.08 \times \text{PageHeight}$ and bottom margin $Y_{bottom} > 0.92 \times \text{PageHeight}$.
* **Cross-Page N-Gram Frequency Analysis:**
  - Extract text blocks residing in the top/bottom threshold zones across all pages.
  - Calculate frequency distributions of strings across pages.
  - If a string appears in $\ge 70\%$ of pages (e.g., *"Chapter 4: Financial Overview"*, *"Page X of Y"*), it is flagged as a running artifact and removed.
* **Regex Pattern Matching:** Detect isolated digit lines, Roman numerals (`i`, `ii`, `iii`), and typical pagination signatures (`Page \d+`, `\d+ / \d+`).

### 3.2 High-Resolution Image Extraction & Spatial Indexing
* **Raster Extraction via PyMuPDF (`fitz`):**
  - Iterate through PDF XObjects (`page.get_images()`).
  - Extract raw image bytes, color spaces (RGB/CMYK to sRGB conversion), and dimensions.
  - Apply filtering: Exclude tiny decorative artifacts, vertical line dividers, and icons ($\text{Width} < 80\text{px}$ or $\text{Height} < 80\text{px}$ or $\text{Area} < 10,000\text{px}^2$).
  - Save valid images to `/workspace_session/images/img_p{page_num}_{img_index}.png`.
* **Spatial Bounding Box Tracking:**
  - Record the exact $(x_0, y_0, x_1, y_1)$ bounding box of each image on the page coordinate grid.

### 3.3 Caption Isolation & Semantic Binding
* **Proximity Scan:**
  - Scan text blocks immediately below ($y \in [y_1, y_1 + 45\text{pt}]$) or above ($y \in [y_0 - 30\text{pt}, y_0]$) the image bounding box.
* **Caption Pattern Matchers:**
  - Detect linguistic prefixes: `^(Figure|Fig\.|Şekil|Resim|Görsel|Table|Tablo|Chart|Grafik)\s*\d+[\.:\s\-]?.*$` (case-insensitive).
  - Detect styling anomalies: Blocks with italic font styles or font sizes smaller than body paragraph text ($size < size_{body}$).
* **Transformation:**
  - Remove the caption text block from the general body text stream.
  - Inject the image Markdown link with the normalized caption directly underneath:
    ```markdown
    ![Figure 1: System Flow Diagram](images/img_p2_1.png)
    *Figure 1: System Flow Diagram*
    ```

### 3.4 Font-Size Hierarchy & Markdown Headings
* Calculate the statistical mode of font sizes across the document to establish $Size_{body}$.
* Heuristic Heading Mapping:
  - $Size \ge 1.6 \times Size_{body} \implies \text{`# Heading 1`}$
  - $1.3 \times Size_{body} \le Size < 1.6 \times Size_{body} \implies \text{`## Heading 2`}$
  - $1.1 \times Size_{body} \le Size < 1.3 \times Size_{body} \text{ with Bold} \implies \text{`### Heading 3`}$
* Remove duplicate trailing colons, normalize spacing, and ensure clean line breaks.

### 3.5 Line-Wrap & Hyphenation Healing
* **Hyphen Stitching:** Match words ending with trailing hyphens at line endings followed by lowercase starting letters on the next line:
  - Regex: `(\b\w+)-\n([a-zğüşıöç\w]+)` $\longrightarrow$ `$1$2`
* **Soft Break vs. Paragraph Break:**
  - If a line does not end with sentence-terminating punctuation (`.`, `!`, `?`, `:`, `"`), concatenate it with a single space instead of a double newline.
  - Preserve double newlines exclusively for distinct paragraph blocks based on vertical spacing ($gap > 1.4 \times \text{LineHeight}$).

### 3.6 Structural Table Extraction
* Utilize `pdfplumber` / PyMuPDF table finder (`page.find_tables()`).
* Detect grid boundaries, extract cell texts, and generate valid GFM (GitHub Flavored Markdown) table syntax:
  ```markdown
  | Metric | Q1 2026 | Q2 2026 | Change (%) |
  | :--- | :--- | :--- | :--- |
  | Revenue | $1.2M | $1.5M | +25% |
  | Operating Margin | 32% | 36% | +4% |
  ```

---

## 4. Web Panel User Interface & UX Design

### 4.1 Visual Aesthetic & Theme
* **Modern Dark Glassmorphism:** Deep indigo-slate background (`#0b0f19`), translucent frosted glass containers (`backdrop-filter: blur(16px)`), subtle neon cyan/indigo accents (`#38bdf8`, `#6366f1`), and refined typography (Inter / JetBrains Mono).
* **Responsive Layout:** Dynamic split-screen workspace with collapsible sidebars and draggable resize handles.

### 4.2 Workspace Panels
1. **Top Navigation Bar:**
   - App branding, active document name, page count badge, processing latency indicator.
   - Quick action buttons: `Upload New`, `Re-process`, `Copy Markdown`, `Download ZIP`.
2. **Left Control & Settings Sidebar:**
   - **Toggles:**
     - `[✓] Extract Images` (Slider: Min pixel threshold 50px - 500px).
     - `[✓] Strip Headers & Footers` (Slider: Top/Bottom margin exclusion %).
     - `[✓] Auto-bind Captions`.
     - `[✓] Fix Hyphenation & Broken Lines`.
     - `[✓] Detect & Format Tables`.
     - `[ ] Enable Future AI Vision Refiner (Experimental)`.
3. **Central Split-View Area:**
   - **Editor Pane (Left):** Full-featured raw Markdown code editor with line numbers, syntax highlighting, and search/replace.
   - **Preview Pane (Right):** Live HTML rendered document with styled tables, embedded images served from the session media route, and copyable code blocks.
4. **Bottom Status & Asset Gallery Bar:**
   - Horizontal thumbnail strip of all extracted images with click-to-insert tags into the editor.

---

## 5. Technical Stack & Repository Directory Structure

### 5.1 Technology Selection
* **Backend Framework:** Python 3.10+ with **FastAPI** (Async, high-throughput, auto-generating OpenAPI docs).
* **PDF Processing Engine:** **PyMuPDF (`fitz`)**, **pdfplumber**, and **Microsoft MarkItDown (`markitdown`)**.
* **Packaging & Utilities:** `aiofiles`, `zipfile`, `python-multipart`, `Pillow`.
* **Frontend:** Vanilla HTML5 / Modern ES6+ / Vanilla CSS (Zero heavy build dependencies for blazing-fast startup and complete customization) with `marked.js` (markdown rendering), `highlight.js` (code syntax highlight), and `lucide` icons.

### 5.2 Proposed Directory Tree

```
markitdown-pdf-panel/
├── backend/
│   ├── app.py                         # FastAPI application entrypoint & routing
│   ├── config.py                      # Server settings, upload size limits, temp paths
│   ├── services/
│   │   ├── __init__.py
│   │   ├── pdf_pipeline.py            # Master orchestration pipeline
│   │   ├── layout_analyzer.py         # Coordinate, header/footer, and heading analyzer
│   │   ├── image_extractor.py         # PyMuPDF raster image extraction & bounding box logic
│   │   ├── caption_matcher.py         # Proximity & regex caption detection
│   │   ├── table_extractor.py         # Grid/line table extraction to Markdown tables
│   │   ├── text_sanitizer.py          # Hyphenation, line un-wrapping, whitespace normalization
│   │   └── zip_bundler.py             # Compresses .md + images/ into downloadable archive
│   ├── plugins/
│   │   ├── __init__.py
│   │   └── ai_refiner_stub.py         # Abstract base class for future LLM/Vision integration
│   └── requirements.txt               # Backend dependencies
├── frontend/
│   ├── index.html                     # Main Single Page Application interface
│   ├── css/
│   │   ├── styles.css                 # Core design system, variables & glassmorphism
│   │   └── editor.css                 # Split-view, code editor & preview styles
│   └── js/
│       ├── api.js                     # REST API client
│       ├── editor.js                  # Markdown editor & live preview sync
│       ├── ui.js                      # Drag-and-drop, notifications, modal handlers
│       └── app.js                     # Application bootstrap & state management
├── tests/
│   ├── test_pipeline.py               # Unit tests for text cleaning and image extraction
│   └── sample_docs/                   # Sample complex PDFs with images and tables
├── run.py                             # Single-command launcher (Starts server & opens browser)
└── README.md                          # Quickstart guide & documentation
```

---

## 6. REST API Endpoint Specification

### `POST /api/convert`
* **Description:** Uploads a PDF, runs the deterministic cleaning pipeline, extracts images, and returns structured Markdown with image metadata.
* **Content-Type:** `multipart/form-data`
* **Parameters:**
  - `file`: PDF binary file.
  - `extract_images`: boolean (default: `true`).
  - `min_image_dimension`: integer (default: `100`).
  - `strip_headers_footers`: boolean (default: `true`).
  - `fix_hyphens`: boolean (default: `true`).
* **Response Body (JSON):**
  ```json
  {
    "session_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "filename": "annual_report.pdf",
    "page_count": 24,
    "markdown_content": "# Annual Report 2026\n\n![Figure 1](api/media/9b1deb.../img_p1_1.png)\n...",
    "images": [
      {
        "id": "img_p1_1.png",
        "page": 1,
        "width": 1024,
        "height": 768,
        "url": "/api/media/9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d/img_p1_1.png",
        "detected_caption": "Figure 1: Revenue breakdown"
      }
    ],
    "stats": {
      "headers_stripped": 23,
      "images_extracted": 8,
      "tables_converted": 3,
      "processing_time_ms": 340
    }
  }
  ```

### `GET /api/media/{session_id}/{image_name}`
* **Description:** Serves extracted images directly to the live frontend preview.

### `POST /api/export-zip`
* **Description:** Accepts the (optionally user-edited) Markdown content and packages it along with the session's extracted images into a ZIP archive.
* **Response:** Binary stream `application/zip` (Attachment: `converted_document.zip`).

---

## 7. Extensibility: Future AI / Vision LLM Integration

When you are ready to incorporate AI, the modular architecture allows enabling AI with zero breaking changes via the `AIRefinerPlugin` interface:

```python
class BaseRefinerPlugin(ABC):
    @abstractmethod
    async def refine(self, raw_markdown: str, extracted_images: list[ImageMeta]) -> str:
        """Takes rule-cleaned markdown and refines complex sections."""
        pass

class OpenAIVisionRefiner(BaseRefinerPlugin):
    async def refine(self, raw_markdown: str, extracted_images: list[ImageMeta]) -> str:
        # 1. Send ambiguous charts/diagrams to VLM for detailed Markdown description
        # 2. Re-check complex nested mathematical equations
        # 3. Return enriched Markdown
        return refined_markdown
```

---

## 8. Implementation Roadmap (Phases)

| Phase | Title | Key Deliverables |
| :--- | :--- | :--- |
| **Phase 1** | **Backend Core Pipeline** | Implement `PyMuPDF` + `MarkItDown` extractor, image slicer, and coordinate indexer. |
| **Phase 2** | **Heuristic Cleaning Rules** | Build header/footer stripper, caption proximity matcher, and hyphenation healer. |
| **Phase 3** | **FastAPI Server & ZIP Exporter** | Develop REST endpoints (`/convert`, `/media`, `/export-zip`) and session manager. |
| **Phase 4** | **Frontend UI & Split Workspace** | Create glassmorphic Dark UI, drag-and-drop zone, syntax editor, and live renderer. |
| **Phase 5** | **Live Preview & Asset Gallery** | Connect live markdown editor with image thumbnails and instant sync. |
| **Phase 6** | **Benchmarking & Validation** | Validate with real-world complex PDFs (multi-column papers, financial reports, technical manuals). |

---

## 9. Verification & Quality Assurance Plan

1. **Text Cleanliness Check:**
   - Verify that page numbers, header titles, and footer legal notices do not appear inside paragraphs.
   - Verify that hyphenated line breaks are seamlessly joined without lost spaces.
2. **Image Integrity & Path Resolution:**
   - Verify that all raster images are extracted without color distortion (sRGB standard).
   - Ensure image links in the Markdown (`![...](images/...)`) match the relative directory structure inside the exported ZIP.
3. **ZIP Extraction Test:**
   - Download the generated ZIP file, extract it locally, and open the `.md` file in Obsidian / VS Code to verify that all images render immediately without broken links.
4. **Edge Case Handling:**
   - Multi-column PDFs (2-column IEEE papers).
   - PDFs with zero images (text-only).
   - PDFs with low-resolution icons (filtered out correctly by minimum threshold).
