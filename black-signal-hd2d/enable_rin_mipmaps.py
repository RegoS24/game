"""Enable lossless import+mips after Godot generated valid import metadata.
Godot 4.5 writes the source/CTEX mapping in the first editor-import pass.
"""
from pathlib import Path
import re
root=Path(__file__).parent/"assets/rin90"
files=sorted(root.glob("*.webp"))
assert files,len(files)
for source in files:
 path=Path(str(source)+".import")
 if not path.is_file():
  raise RuntimeError(f"missing Godot import metadata: {path}")
 text=path.read_text()
 assert "mipmaps/generate=" in text and "compress/mode=" in text,path
 text=re.sub(r"mipmaps/generate=(false|true)","mipmaps/generate=true",text)
 text=re.sub(r"compress/mode=\d+","compress/mode=0",text)
 text=re.sub(r"process/fix_alpha_border=(false|true)","process/fix_alpha_border=true",text)
 path.write_text(text)
print("RIN_MIPMAPS_ENABLED",len(files),flush=True)
