#!/usr/bin/env python3
"""Generate a white vector flower while preserving paths and transparency."""
from pathlib import Path
from pypdf import PdfWriter
from pypdf.generic import ContentStream, FloatObject

root = Path(__file__).resolve().parent.parent
writer = PdfWriter(clone_from=root / '_assets/images/flower.pdf')
visited = set()


def recolor(stream):
    for operands, operator in stream.operations:
        if operator in (b'rg', b'RG', b'g', b'G'):
            operands[:] = [FloatObject(1) for _ in operands]
        elif operator in (b'k', b'K'):
            operands[:] = [FloatObject(0) for _ in operands]


def recolor_forms(resources):
    for reference in resources.get('/XObject', {}).values():
        form = reference.get_object()
        if id(form) in visited or form.get('/Subtype') != '/Form':
            continue
        visited.add(id(form))
        stream = ContentStream(form, writer)
        recolor(stream)
        form.set_data(stream.get_data())
        recolor_forms(form.get('/Resources', {}))


for page in writer.pages:
    stream = ContentStream(page.get_contents(), writer)
    recolor(stream)
    page.replace_contents(stream)
    recolor_forms(page['/Resources'])
writer.write(root / '_assets/images/flower-white.pdf')
