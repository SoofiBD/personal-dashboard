import asyncio
import io
import zipfile
import unittest
import base64

import fitz
from fastapi import HTTPException
from fastapi import UploadFile

from app import HtmlExport, ZipExport, ZipImage, convert, export_html, export_zip, extract_layout_text, is_valid_table


def convert_pdf(document, annotation_mode="both", **options):
    payload = document.tobytes()
    document.close()
    upload = UploadFile(filename="report.pdf", file=io.BytesIO(payload))
    defaults = {
        "extract_images_enabled": True, "min_image_dimension": 100, "image_quality": "high", "strip_headers_footers": True,
        "bind_captions_enabled": True, "extract_annotations_enabled": True,
        "include_yaml_frontmatter": True, "fix_hyphenation_enabled": True, "detect_tables": True,
    }
    return asyncio.run(convert(upload, "", annotation_mode, **(defaults | options)))


class PdfWorkerTest(unittest.TestCase):
    def test_removes_repeated_headers_and_footers(self):
        document = fitz.open()
        for page_number in range(1, 4):
            page = document.new_page()
            page.insert_text((72, 20), "Confidential Report")
            page.insert_text((72, 100), f"Revenue for quarter {page_number}")
            page.insert_text((72, 820), f"Page {page_number} of 3")

        result = convert_pdf(document)

        self.assertNotIn("Confidential Report", result["markdown_content"])
        self.assertNotIn("Page 1 of 3", result["markdown_content"])
        self.assertEqual(6, result["stats"]["headers_stripped"])

    def test_extracts_a_grid_table_as_gfm(self):
        document = fitz.open()
        page = document.new_page()
        for x in (72, 172, 272):
            page.draw_line((x, 100), (x, 180))
        for y in (100, 140, 180):
            page.draw_line((72, y), (272, y))
        page.insert_text((82, 125), "Metric")
        page.insert_text((182, 125), "Value")
        page.insert_text((82, 165), "Revenue")
        page.insert_text((182, 165), "120")

        result = convert_pdf(document, "section")

        self.assertIn("| Metric | Value |", result["markdown_content"])
        self.assertEqual(1, result["stats"]["tables_converted"])

    def test_rejects_sparse_equation_layouts_as_tables(self):
        rows = [
            ["", "", "Γ", ""],
            ["", "E", "", ""],
            ["", "", "z⁻⁴", ""],
        ]

        self.assertFalse(is_valid_table(rows))

    def test_honors_disabled_optional_extraction_features(self):
        document = fitz.open()
        page = document.new_page()
        page.insert_text((72, 100), "A wrapped line\ncontinues here.")
        pixmap = fitz.Pixmap(fitz.csRGB, fitz.IRect(0, 0, 120, 100), False)
        pixmap.clear_with(128)
        page.insert_image(fitz.Rect(72, 130, 192, 230), stream=pixmap.tobytes("png"))

        result = convert_pdf(document, extract_images_enabled=False, include_yaml_frontmatter=False, fix_hyphenation_enabled=False)

        self.assertEqual(0, result["stats"]["images_extracted"])
        self.assertNotIn("---", result["markdown_content"])

    def test_unwraps_soft_breaks_and_heals_hyphenation(self):
        document = fitz.open()
        page = document.new_page()
        page.insert_text((72, 100), "A minimal theory of nonradia-\ntive energy transfer from a\ntwo-dimensional moire exciton.\nNext sentence starts here.")
        result = convert_pdf(document, include_yaml_frontmatter=False)
        self.assertIn("A minimal theory of nonradiative energy transfer from a two-dimensional moire exciton. Next sentence starts here.", result["markdown_content"])

    def test_orders_two_column_text_left_before_right(self):
        document = fitz.open()
        page = document.new_page(width=600, height=800)
        page.insert_text((60, 400), "Left column paragraph")
        page.insert_text((330, 350), "Right column paragraph")

        text = extract_layout_text(document)

        self.assertLess(text.index("Left column"), text.index("Right column"))

    def test_inlines_highlight_when_selected(self):
        document = fitz.open()
        page = document.new_page()
        page.insert_text((72, 100), "Revenue improved by 25 percent.")
        annotation = page.add_highlight_annot(page.search_for("improved by 25 percent")[0])
        annotation.update()

        result = convert_pdf(document, "inline")

        self.assertIn("Revenue ==improved by 25 percent.==", result["markdown_content"])
        self.assertNotIn("Extracted Highlights & Notes", result["markdown_content"])

    def test_synthesizes_heading_and_binds_image_caption(self):
        document = fitz.open()
        page = document.new_page()
        pixmap = fitz.Pixmap(fitz.csRGB, fitz.IRect(0, 0, 120, 100), False)
        pixmap.clear_with(128)
        page.insert_text((72, 60), "Financial Overview", fontsize=22, fontname="hebo")
        page.insert_text((72, 100), "Revenue improved during the quarter.", fontsize=11)
        page.insert_image(fitz.Rect(72, 130, 192, 230), stream=pixmap.tobytes("png"))
        page.insert_text((72, 250), "Figure 1: Revenue trend", fontsize=9)

        result = convert_pdf(document)

        self.assertIn("# Financial Overview", result["markdown_content"])
        self.assertIn("![Figure 1: Revenue trend](images/img_p1_1.png)", result["markdown_content"])
        self.assertEqual(1, result["stats"]["captions_bound"])

    def test_exports_markdown_and_images_as_zip(self):
        response = export_zip(ZipExport(markdown_content="# Report", source_filename="report.pdf", images=[]))

        archive = zipfile.ZipFile(io.BytesIO(response.body))
        self.assertEqual(["report.md"], archive.namelist())
        self.assertEqual(b"# Report", archive.read("report.md"))

    def test_exports_sanitized_html_with_embedded_images(self):
        payload = HtmlExport(markdown_content="# Report\n\n![Chart](images/chart.png)\n\n<script>alert(1)</script>", source_filename="report.pdf", images=[ZipImage(filename="chart.png", data_base64=base64.b64encode(b"png-data").decode("ascii"))])

        response = export_html(payload)

        body = response.body.decode()
        self.assertIn("<h1>Report</h1>", body)
        self.assertIn("data:image/png;base64,", body)
        self.assertNotIn("<script>", body)

    def test_extracts_vector_charts_and_diagrams(self):
        document = fitz.open()
        page = document.new_page(width=600, height=800)
        shape = page.new_shape()
        shape.draw_line(fitz.Point(100, 300), fitz.Point(400, 300))
        shape.draw_line(fitz.Point(100, 300), fitz.Point(100, 150))
        shape.draw_rect(fitz.Rect(130, 200, 170, 300))
        shape.draw_rect(fitz.Rect(200, 170, 240, 300))
        shape.draw_rect(fitz.Rect(270, 230, 310, 300))
        shape.finish(color=(0.2, 0.4, 0.8), fill=(0.4, 0.7, 1.0))
        shape.commit()
        page.insert_text(fitz.Point(100, 330), "Grafik 1: Gelir Analizi", fontsize=10)

        result = convert_pdf(document)

        self.assertGreaterEqual(result["stats"]["images_extracted"], 1)
        self.assertTrue(any("chart_p1_" in img["filename"] for img in result["images"]))
        self.assertIn("![Grafik 1: Gelir Analizi](images/chart_p1_1.png)", result["markdown_content"])
        self.assertIn("Grafik 1: Gelir Analizi", result["markdown_content"])

    def test_renders_vector_charts_at_the_selected_high_quality_profile(self):
        document = fitz.open()
        page = document.new_page(width=600, height=800)
        page.draw_rect(fitz.Rect(100, 150, 400, 350), color=(0.1, 0.3, 0.8), fill=(0.4, 0.7, 1.0))
        page.draw_line((100, 350), (400, 150), color=(0.0, 0.0, 0.0))

        result = convert_pdf(document, image_quality="maximum")
        chart = next(image for image in result["images"] if image["filename"].startswith("chart_p1_"))

        self.assertEqual("image/png", chart["content_type"])
        self.assertGreater(chart["width"], 1000)

    def test_rejects_pdf_over_the_page_limit(self):
        document = fitz.open()
        for _page_number in range(251):
            document.new_page()

        with self.assertRaises(HTTPException) as raised:
            convert_pdf(document)

        self.assertEqual(422, raised.exception.status_code)
