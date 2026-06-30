import io

src = r"H:\新软件\3D脚本\whtools\WH_Toolbox_免安装版.ms"
try:
    with io.open(src, "r", encoding="utf-8-sig") as f:
        lines = f.read().splitlines()
except UnicodeDecodeError:
    with io.open(src, "r", encoding="gbk") as f:
        lines = f.read().splitlines()

def write_block(path, start, end, prepend, append):
    content = "\n".join(prepend + lines[start-1:end] + append) + "\n"
    with io.open(path, "w", encoding="utf-8-sig") as f:
        f.write(content)

write_block(r"H:\新软件\3D脚本\车位自制\智能车位生成器_带摆放车辆.ms", 14, 398, [], ["", "try(destroyDialog ParkingGeneratorUI)catch()", "createDialog ParkingGeneratorUI style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"])

write_block(r"H:\新软件\3D脚本\片窗\片窗.ms", 401, 793, [r'global iniPathPc = getDir #plugcfg + "\PianChuangSettings.ini"'], ["", "try(destroyDialog UI_WinMakerTool)catch()", "createDialog UI_WinMakerTool style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"])

write_block(r"H:\新软件\3D脚本\偏移\偏移+.ms", 867, 1300, [], ["", "try(destroyDialog SplineOffsetRollout)catch()", "createDialog SplineOffsetRollout style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"])

write_block(r"H:\新软件\3D脚本\线条平分连接\平分连接.ms", 1311, 1532, [], ["", "try(destroyDialog splConnectDialog)catch()", "createDialog splConnectDialog style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"])

print("Sync completed successfully via Python!")
