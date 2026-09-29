#!/usr/bin/env python3
"""提取 PDF 文本，用换页符（\\f）分隔页面。优先 pymupdf，其次 pypdf。"""
import sys


def extract(path: str) -> str:
    try:
        import pymupdf  # type: ignore

        doc = pymupdf.open(path)
        return "\f".join(page.get_text("text") for page in doc)
    except ImportError:
        pass

    try:
        from pypdf import PdfReader  # type: ignore

        reader = PdfReader(path)
        return "\f".join((page.extract_text() or "") for page in reader.pages)
    except ImportError:
        sys.exit("缺少 PDF 提取库：请在 nvim-devkit venv 中安装 pymupdf（或 pypdf）")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: pdf_extract.py FILE.pdf")
    sys.stdout.write(extract(sys.argv[1]))


if __name__ == "__main__":
    main()
