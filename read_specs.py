import os
import chardet

spec_dir = r"d:\Program Files\GigCredit\specification files"
out_dir = r"d:\Program Files\GigCredit\specs_readable"
os.makedirs(out_dir, exist_ok=True)

for fname in sorted(os.listdir(spec_dir)):
    if not fname.endswith('.txt'):
        continue
    fpath = os.path.join(spec_dir, fname)
    with open(fpath, 'rb') as f:
        raw = f.read()
    detected = chardet.detect(raw)
    enc = detected.get('encoding', 'utf-8') or 'utf-8'
    print(f"File: {fname}")
    print(f"  Detected encoding: {enc} (confidence: {detected.get('confidence', 'N/A')})")
    print(f"  Size: {len(raw)} bytes")
    
    # Try detected encoding, fallback to several
    text = None
    for try_enc in [enc, 'utf-8', 'utf-16', 'utf-16-le', 'utf-16-be', 'cp1252', 'latin-1']:
        try:
            text = raw.decode(try_enc, errors='replace')
            # Check quality - count replacement chars
            replacements = text.count('\ufffd')
            if replacements < len(text) * 0.05:  # Less than 5% replacement
                print(f"  Successfully decoded with: {try_enc} ({replacements} replacements)")
                break
            else:
                text = None
        except:
            continue
    
    if text is None:
        text = raw.decode('latin-1', errors='replace')
        print(f"  Fallback to latin-1")
    
    # Write readable version
    out_name = fname.replace(' ', '_').replace('(', '').replace(')', '')
    out_path = os.path.join(out_dir, out_name)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"  Written to: {out_name}")
    print()
