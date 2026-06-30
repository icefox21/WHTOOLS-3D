$sourceFile = "H:\新软件\3D脚本\whtools\WH_Toolbox_免安装版.ms"
$lines = [System.IO.File]::ReadAllLines($sourceFile, [System.Text.Encoding]::UTF8)

# 1. 车位自制
$parkingLines = $lines[13..397]
$parkingAppend = @(
"",
"try(destroyDialog ParkingGeneratorUI)catch()",
"createDialog ParkingGeneratorUI style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"
)
[System.IO.File]::WriteAllLines("H:\新软件\3D脚本\车位自制\智能车位生成器_带摆放车辆.ms", $parkingLines + $parkingAppend, [System.Text.Encoding]::UTF8)

# 2. 片窗
$pcLines = @("global iniPathPc = getDir #plugcfg + `"\PianChuangSettings.ini`"") + $lines[400..792]
$pcAppend = @(
"",
"try(destroyDialog UI_WinMakerTool)catch()",
"createDialog UI_WinMakerTool style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"
)
[System.IO.File]::WriteAllLines("H:\新软件\3D脚本\片窗\片窗.ms", $pcLines + $pcAppend, [System.Text.Encoding]::UTF8)

# 3. 偏移
$offsetLines = $lines[866..1299]
$offsetAppend = @(
"",
"try(destroyDialog SplineOffsetRollout)catch()",
"createDialog SplineOffsetRollout style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"
)
[System.IO.File]::WriteAllLines("H:\新软件\3D脚本\偏移\偏移+.ms", $offsetLines + $offsetAppend, [System.Text.Encoding]::UTF8)

# 4. 线条平分连接
$connectLines = $lines[1310..1531]
$connectAppend = @(
"",
"try(destroyDialog splConnectDialog)catch()",
"createDialog splConnectDialog style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)"
)
[System.IO.File]::WriteAllLines("H:\新软件\3D脚本\线条平分连接\平分连接.ms", $connectLines + $connectAppend, [System.Text.Encoding]::UTF8)

Write-Host "Sync Complete!"
