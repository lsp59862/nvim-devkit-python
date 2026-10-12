#!/usr/bin/env python3
"""输出 PDF 页数（供查看器显示“第 n/N 页”）。优先 pymupdf，其次 pypdf。"""
import sys


def pages(path: str) -> int:
    try:
        import pymupdf  # type: ignore

        return pymupdf.open(path).page_count
    except ImportError:
        pass

    from pypdf import PdfReader  # type: ignore

    return len(PdfReader(path).pages)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: pdf_pages.py FILE.pdf")
    try:
        print(pages(sys.argv[1]))
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"无法读取页数: {exc}")


if __name__ == "__main__":
    main()
