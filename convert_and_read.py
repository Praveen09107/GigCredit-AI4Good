import os

spec_dir = r"d:\Program Files\GigCredit\specification files"
out_dir = r"d:\Program Files\GigCredit\specs_utf8"
os.makedirs(out_dir, exist_ok=True)

for fname in sorted(os.listdir(spec_dir)):
    if not fname.endswith('.txt'):
        continue
    fpath = os.path.join(spec_dir, fname)
    data = open(fpath, 'rb').read()
    
    # Try UTF-8-SIG first (BOM), then UTF-8, then cp1252
    text = None
    for enc in ['utf-8-sig', 'utf-8', 'cp1252', 'iso-8859-1']:
        try:
            t = data.decode(enc)
            # Check if readable - count actual question marks vs printable
            printable = sum(1 for c in t[:2000] if c.isprintable() or c.isspace())
            ratio = printable / min(len(t), 2000) if len(t) > 0 else 0
            if ratio > 0.85:
                text = t
                used_enc = enc
                break
        except:
            continue
    
    if text is None:
        text = data.decode('iso-8859-1')
        used_enc = 'iso-8859-1-fallback'
    
    # Clean up: replace box-drawing and special chars with ASCII equivalents
    replacements = {
        '\u2500': '-', '\u2502': '|', '\u250c': '+', '\u2510': '+',
        '\u2514': '+', '\u2518': '+', '\u251c': '+', '\u2524': '+',
        '\u252c': '+', '\u2534': '+', '\u253c': '+',
        '\u2550': '=', '\u2551': '||', '\u2554': '+', '\u2557': '+',
        '\u255a': '+', '\u255d': '+',
        '\u2588': '#', '\u2591': '.', '\u2592': ':', '\u2593': '#',
        '\u2022': '*', '\u2013': '-', '\u2014': '--', '\u2015': '--',
        '\u2018': "'", '\u2019': "'", '\u201c': '"', '\u201d': '"',
        '\u2026': '...', '\u2192': '->', '\u2190': '<-',
        '\u2713': '[Y]', '\u2717': '[N]', '\u25cf': '*',
        '\u25cb': 'o', '\u25a0': '#', '\u25a1': '[]',
        '\u00d7': 'x',  # multiplication sign
        '\u00f7': '/',  # division sign
        '\u2265': '>=', '\u2264': '<=', '\u2260': '!=',
        '\u00b1': '+/-',
        '\u0097': '-',  # control char sometimes used as dash
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    
    safe_name = fname.replace(' ', '_').replace('(', '').replace(')', '').replace(',', '')
    # Truncate long filenames
    if len(safe_name) > 80:
        safe_name = safe_name[:77] + '.txt'
    out_path = os.path.join(out_dir, safe_name)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(text)
    
    # Count actual content lines
    lines = [l for l in text.split('\n') if l.strip()]
    print(f"[{used_enc:12s}] {fname[:65]:65s} -> {len(lines):4d} lines")

print("\nAll files converted to:", out_dir)
