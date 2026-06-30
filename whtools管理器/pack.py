import zipfile, os
files = ["whtools_manager.ms", "install.ms", "mzp.run"]
src = r"H:\新软件\3D脚本\whtools管理器"
with zipfile.ZipFile(src + r"\whtools_manager.mzp", 'w') as z:
    for f in files:
        fp = os.path.join(src, f)
        if os.path.exists(fp): z.write(fp, f); print("Added", f)
        else: print("MISSING", f)
