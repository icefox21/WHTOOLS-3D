-- 浮动材质球 透明版 v1.0
-- 背景完全透明，仅显示已赋材质的材质球，支持左键赋材质、右键菜单

global WH_FloatAlpha_Form
global WH_FloatAlpha_BgForm
global WH_FloatAlpha_Struct
global WH_FloatAlpha_RCMenu
global WH_FloatAlpha_IsDrag  = false
global WH_FloatAlpha_DragSX  = 0
global WH_FloatAlpha_DragSY  = 0
global WH_FloatAlpha_CurIdx  = 0

-- 轻柔系统提示音（代替弹窗）
fn WH_beep = ( try((dotNetClass "System.Media.SystemSounds").Asterisk.Play())catch() )

-- ===== 锚点右键菜单（关闭 / 重建）=====
global WH_FloatAlpha_AnchorMenu
rcMenu WH_FloatAlpha_AnchorMenu (
    menuItem mi_a_settings "⚙️ 布局设置"
    menuItem mi_a_rebuild  "🔄 重建界面"
    separator sep_guide
    menuItem mi_a_guide    "📖 操作指南"
    separator sep_aa
    menuItem mi_a_close    "❌ 关闭"
    on mi_a_settings picked do (
        try(destroyDialog WH_FloatAlpha_Config_Rollout)catch()
        createDialog WH_FloatAlpha_Config_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) pos:mouse.screenpos
    )
    on mi_a_rebuild picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.buildUI() )
    on mi_a_guide picked do (
        local msg = "【浮动材质球 极速操作指南】\n\n"
        msg += "左键相关：\n"
        msg += "• [左键单击] 槽位：将该材质赋予选中的物体\n"
        msg += "• [Alt + 左键单击] 槽位：将【材质编辑器】中当前的激活材质导入到此槽位\n"
        msg += "• [Shift + 左键单击] 槽位：吸取场景中【选中物体】的材质到此槽位\n"
        msg += "• [左键拖动] 空隙/空槽/锚点：自由移动面板位置\n\n"
        msg += "右键相关：\n"
        msg += "• [右键单击] 槽位/空槽：弹出材质专属功能菜单\n"
        msg += "• [右键单击] 锚点：弹出面板设置与管理菜单\n"
        messagebox msg title:"操作指南"
    )
    on mi_a_close   picked do ( 
        if WH_FloatAlpha_Form   != undefined do try(WH_FloatAlpha_Form.Close())catch()
        if WH_FloatAlpha_BgForm != undefined do try(WH_FloatAlpha_BgForm.Close())catch()
    )
)

-- ===== 材质球右键菜单 =====
rcMenu WH_FloatAlpha_RCMenu (
    menuItem mi_pickObj     "✏️ 吸取选定物体材质"
    menuItem mi_fromMedit   "📥 从编辑器导入当前"
    separator sep1
    menuItem mi_rename      "🏷️ 重命名当前材质"
    menuItem mi_editCompact "📝 在精简编辑器中编辑"
    menuItem mi_editSlate   "🌐 在节点编辑器中编辑"
    separator sep2
    menuItem mi_applyObj    "➡️ 赋给选定物体"
    separator sep3
    menuItem mi_clear       "❌ 清空"

    on mi_pickObj     picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.pickFromObject   WH_FloatAlpha_CurIdx )
    on mi_fromMedit   picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.pickFromMedit    WH_FloatAlpha_CurIdx )
    on mi_rename      picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.renameMaterial   WH_FloatAlpha_CurIdx )
    on mi_editCompact picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.editInCompact    WH_FloatAlpha_CurIdx )
    on mi_editSlate   picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.editInSlate      WH_FloatAlpha_CurIdx )
    on mi_applyObj    picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.applyMatToObject WH_FloatAlpha_CurIdx )
    on mi_clear       picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.clearSlot        WH_FloatAlpha_CurIdx )
)

-- ===== 空槽位专用右键菜单 =====
global WH_FloatAlpha_EmptyRCMenu
rcMenu WH_FloatAlpha_EmptyRCMenu (
    menuItem mi_ep_pickObj   "✏️ 吸取选定物体材质"
    menuItem mi_ep_fromMedit "📥 从编辑器导入当前"
    on mi_ep_pickObj   picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.pickFromObject   WH_FloatAlpha_CurIdx )
    on mi_ep_fromMedit picked do ( if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.pickFromMedit    WH_FloatAlpha_CurIdx )
)

-- ===== 拖动事件（全局函数，供 dotNet.addEventHandler 使用）=====
-- 此函数已废弃，现在由底层隐形窗体统一拦截
fn WH_FloatAlpha_AnchorMove sender args = (
    if WH_FloatAlpha_IsDrag do (
        local sp = sender.PointToScreen (dotNetObject "System.Drawing.Point" args.X args.Y)
        local dx = sp.X - WH_FloatAlpha_DragSX
        local dy = sp.Y - WH_FloatAlpha_DragSY
        WH_FloatAlpha_DragSX = sp.X
        WH_FloatAlpha_DragSY = sp.Y
        if WH_FloatAlpha_Form != undefined do (
            local loc = WH_FloatAlpha_Form.Location
            local newLoc = dotNetObject "System.Drawing.Point" (loc.X + dx) (loc.Y + dy)
            WH_FloatAlpha_Form.Location = newLoc
            if WH_FloatAlpha_BgForm != undefined do WH_FloatAlpha_BgForm.Location = newLoc
        )
    )
)
fn WH_FloatAlpha_AnchorUp sender args = (
    WH_FloatAlpha_IsDrag = false
    -- 拖动结束时保存位置
    if WH_FloatAlpha_Form != undefined and WH_FloatAlpha_Struct != undefined do (
        local loc = WH_FloatAlpha_Form.Location
        setINISetting WH_FloatAlpha_Struct.iniFile "Settings" "WinPosX" (loc.X as string)
        setINISetting WH_FloatAlpha_Struct.iniFile "Settings" "WinPosY" (loc.Y as string)
    )
)
-- ===== 底层隐形窗体鼠标事件（拦截空隙和空槽）=====
fn WH_FloatAlpha_BgDown sender args = (
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        WH_FloatAlpha_IsDrag = true
        local sp = sender.PointToScreen (dotNetObject "System.Drawing.Point" args.X args.Y)
        WH_FloatAlpha_DragSX = sp.X
        WH_FloatAlpha_DragSY = sp.Y
        return ()
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        if WH_FloatAlpha_Struct != undefined do (
            local padX = 5; local padY = 4; local anchorH = 30
            local btnW = 75
            local showName = WH_FloatAlpha_Struct.loadShowName()
            local btnH = if showName then 75 else 55
            local spacing = 4
            
            local dx = args.X - padX
            local dy = args.Y - anchorH - padY
            if dx >= 0 and dy >= 0 do (
                local c = (dx / (btnW + spacing)) as integer + 1
                local r = (dy / (btnH + spacing)) as integer + 1
                local modX = mod dx (btnW + spacing)
                local modY = mod dy (btnH + spacing)
                local cfg = WH_FloatAlpha_Struct.loadConfig()
                local cols = cfg[1]
                
                if c > 0 and c <= cols and modX < btnW and modY < btnH do (
                    local idx = (r - 1) * cols + c
                    if idx > 0 and idx <= WH_FloatAlpha_Struct.matArray.count do (
                        local mat = WH_FloatAlpha_Struct.matArray[idx]
                        if not (isKindOf mat Material) do (
                            WH_FloatAlpha_CurIdx = idx
                            popupMenu WH_FloatAlpha_EmptyRCMenu
                        )
                    )
                )
            )
        )
    )
)

-- ===== 材质按钮鼠标事件 =====
fn WH_FloatAlpha_BtnDown sender args = (
    local idxStr = sender.Name  -- "s1", "s2" ...
    local idx = (substring idxStr 2 -1) as integer
    WH_FloatAlpha_CurIdx = idx
    local mat = if WH_FloatAlpha_Struct != undefined then WH_FloatAlpha_Struct.matArray[idx] else undefined
    local isEmpty = not (isKindOf mat Material)
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        if not isEmpty and WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.applyMatToObject idx
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        if isEmpty then popupMenu WH_FloatAlpha_EmptyRCMenu
        else popupMenu WH_FloatAlpha_RCMenu
    )
)

-- ===== 底层隐形窗体鼠标事件（拦截空隙和空槽）=====
fn WH_FloatAlpha_BgDown sender args = (
    local modKeys = (dotNetClass "System.Windows.Forms.Control").ModifierKeys
    local isAlt = modKeys == (dotNetClass "System.Windows.Forms.Keys").Alt
    local isShift = modKeys == (dotNetClass "System.Windows.Forms.Keys").Shift

    local padX = 5; local padY = 5
    local anchorW = 28
    local spacing = 4
    local startX = padX + anchorW + spacing
    local startY = padY

    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        if (isAlt or isShift) and args.X >= startX then (
            -- 快捷键吸收材质
            if WH_FloatAlpha_Struct != undefined do (
                local btnW = 75
                local showName = WH_FloatAlpha_Struct.loadShowName()
                local btnH = if showName then 75 else 55
                
                local dx = args.X - startX
                local dy = args.Y - startY
                if dx >= 0 and dy >= 0 do (
                    local c = (dx / (btnW + spacing)) as integer + 1
                    local r = (dy / (btnH + spacing)) as integer + 1
                    local modX = mod dx (btnW + spacing)
                    local modY = mod dy (btnH + spacing)
                    local cfg = WH_FloatAlpha_Struct.loadConfig()
                    local cols = cfg[1]
                    
                    if c > 0 and c <= cols and modX < btnW and modY < btnH do (
                        local idx = (r - 1) * cols + c
                        if idx > 0 and idx <= WH_FloatAlpha_Struct.matArray.count do (
                            if isAlt then WH_FloatAlpha_Struct.pickFromMedit idx
                            else if isShift then WH_FloatAlpha_Struct.pickFromObject idx
                        )
                    )
                )
            )
        ) else (
            -- 普通左键拖动窗口
            WH_FloatAlpha_IsDrag = true
            local sp = sender.PointToScreen (dotNetObject "System.Drawing.Point" args.X args.Y)
            WH_FloatAlpha_DragSX = sp.X
            WH_FloatAlpha_DragSY = sp.Y
        )
        return ()
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        if args.X < startX then (
            popupMenu WH_FloatAlpha_AnchorMenu
        ) else (
            if WH_FloatAlpha_Struct != undefined do (
                local btnW = 75
                local showName = WH_FloatAlpha_Struct.loadShowName()
                local btnH = if showName then 75 else 55
                
                local dx = args.X - startX
                local dy = args.Y - startY
                if dx >= 0 and dy >= 0 do (
                    local c = (dx / (btnW + spacing)) as integer + 1
                    local r = (dy / (btnH + spacing)) as integer + 1
                    local modX = mod dx (btnW + spacing)
                    local modY = mod dy (btnH + spacing)
                    local cfg = WH_FloatAlpha_Struct.loadConfig()
                    local cols = cfg[1]
                    
                    if c > 0 and c <= cols and modX < btnW and modY < btnH do (
                        local idx = (r - 1) * cols + c
                        if idx > 0 and idx <= WH_FloatAlpha_Struct.matArray.count do (
                            local mat = WH_FloatAlpha_Struct.matArray[idx]
                            if not (isKindOf mat Material) do (
                                WH_FloatAlpha_CurIdx = idx
                                popupMenu WH_FloatAlpha_EmptyRCMenu
                            )
                        )
                    )
                )
            )
        )
    )
)

-- ===== 材质按钮鼠标事件 =====
fn WH_FloatAlpha_BtnDown sender args = (
    local idxStr = sender.Name  -- "s1", "s2" ...
    local idx = (substring idxStr 2 -1) as integer
    WH_FloatAlpha_CurIdx = idx

    local modKeys = (dotNetClass "System.Windows.Forms.Control").ModifierKeys
    local isAlt = modKeys == (dotNetClass "System.Windows.Forms.Keys").Alt
    local isShift = modKeys == (dotNetClass "System.Windows.Forms.Keys").Shift

    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        if isAlt then (
            if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.pickFromMedit idx
        ) else if isShift then (
            if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.pickFromObject idx
        ) else (
            if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.applyMatToObject idx
        )
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        popupMenu WH_FloatAlpha_RCMenu
    )
)
struct WH_FloatAlpha_Core (
    iniFile = (getDir #userscripts) + "\\whtools_floatmat_config.ini",
    matArray = #(),

    -- ---------- 共用工具函数 ----------
    fn getDefaultMat = (
        local m = undefined
        try(m = VRayMtl())catch()
        if m == undefined do try(m = PhysicalMaterial())catch()
        if m == undefined do try(m = StandardMaterial())catch()
        m
    ),

    fn getSceneMatLibPath = (
        if maxFilePath == "" then
            (getDir #userscripts) + "\\WH_FloatMats_Untitled.mat"
        else
            maxFilePath + "WH_FloatMats_" + (getFilenameFile maxFileName) + ".mat"
    ),

    fn saveSceneMats = (
        local libPath = getSceneMatLibPath()
        local lib = materialLibrary()
        for i = 1 to matArray.count do (
            if isKindOf matArray[i] Material then (
                append lib matArray[i]
            ) else (
                local d = StandardMaterial name:"WH_EMPTY_SLOT"
                append lib d
            )
        )
        try(saveTempMaterialLibrary lib libPath)catch()
    ),

    fn loadSceneMats totalSlots = (
        local libPath = getSceneMatLibPath()
        local arr = #()
        if doesFileExist libPath then (
            local lib = undefined
            try(lib = loadTempMaterialLibrary libPath)catch()
            if lib != undefined then (
                for i = 1 to totalSlots do (
                    local isEmpty = true
                    if i <= lib.count and isKindOf lib[i] Material do (
                        local n = ""; try(n = lib[i].name as string)catch()
                        if n != "WH_EMPTY_SLOT" and n != "VRayMtl" do isEmpty = false
                    )
                    append arr (if isEmpty then undefined else lib[i])
                )
            ) else (
                for i = 1 to totalSlots do append arr undefined
            )
        ) else (
            for i = 1 to totalSlots do append arr undefined
        )
        matArray = arr
    ),

    fn loadConfig = (
        local c = getINISetting iniFile "Settings" "Cols"
        local rv = getINISetting iniFile "Settings" "Rows"
        if c == "" do c = "4"
        if rv == "" do rv = "3"
        #(c as integer, rv as integer)
    ),

    fn loadShowName = (
        local v = getINISetting iniFile "Settings" "ShowName"
        v != "0"  -- 默认显示
    ),

    fn saveConfig c rv = (
        setINISetting iniFile "Settings" "Cols" (c as string)
        setINISetting iniFile "Settings" "Rows" (rv as string)
    ),

    fn saveShowName val = (
        setINISetting iniFile "Settings" "ShowName" (if val then "1" else "0")
    ),

    -- ---------- 材质操作（与原版相同）----------
    fn getCurrentMeditMat = (
        if MatEditor.mode == #basic then (
            meditMaterials[activeMeditSlot]
        ) else (
            local m = undefined
            try(m = sme.GetMtlInParamEditor())catch()
            if m != undefined and isKindOf m Material then m else meditMaterials[activeMeditSlot]
        )
    ),

    fn applyMatToObject idx = (
        if selection.count > 0 then (
            local m = matArray[idx]
            if isKindOf m Material do
                for obj in selection do obj.material = m
        ) else (
            WH_beep()
        )
    ),

    fn pickFromObject idx = (
        if selection.count > 0 then (
            local m = selection[1].material
            if m != undefined then (
                matArray[idx] = m
                saveSceneMats()
                if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.refreshBtn idx
            ) else (
                WH_beep()
            )
        ) else (
            WH_beep()
        )
    ),

    fn pickFromMedit idx = (
        local m = getCurrentMeditMat()
        if isKindOf m Material then (
            matArray[idx] = m
            saveSceneMats()
            if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.refreshBtn idx
        ) else (
            WH_beep()
        )
    ),

    fn editInCompact idx = (
        local m = matArray[idx]
        if isKindOf m Material do (
            MatEditor.mode = #basic
            if not MatEditor.isOpen() do MatEditor.Open()
            meditMaterials[activeMeditSlot] = m
        )
    ),

    fn editInSlate idx = (
        local m = matArray[idx]
        if isKindOf m Material do (
            MatEditor.mode = #advanced
            if not MatEditor.isOpen() do MatEditor.Open()
            try(local v = sme.GetView(sme.activeView); if v != undefined do v.CreateNode m [0,0])catch()
        )
    ),

    fn renameMaterial idx = (
        local m = matArray[idx]
        if isKindOf m Material then (
            global WH_FloatMat_RenameMat = m
            global WH_FloatMat_RenameIdx = idx
            try(destroyDialog WH_FloatAlpha_Rename_Rollout)catch()
            rollout WH_FloatAlpha_Rename_Rollout "重命名材质" width:220 height:80 (
                edittext edt "" text:"" pos:[10,15] width:195
                button btn_ok "确定" pos:[50,45] width:60 height:25
                button btn_cancel "取消" pos:[115,45] width:60 height:25
                on WH_FloatAlpha_Rename_Rollout open do (
                    if WH_FloatMat_RenameMat != undefined do edt.text = WH_FloatMat_RenameMat.name as string
                    setFocus edt
                )
                on btn_ok pressed do (
                    if edt.text != "" and WH_FloatMat_RenameMat != undefined do (
                        WH_FloatMat_RenameMat.name = edt.text
                        if WH_FloatAlpha_Struct != undefined do (
                            WH_FloatAlpha_Struct.saveSceneMats()
                            WH_FloatAlpha_Struct.refreshBtn WH_FloatMat_RenameIdx
                        )
                    )
                    destroyDialog WH_FloatAlpha_Rename_Rollout
                )
                on btn_cancel pressed do destroyDialog WH_FloatAlpha_Rename_Rollout
            )
            createDialog WH_FloatAlpha_Rename_Rollout style:#(#style_titlebar, #style_toolwindow) pos:mouse.screenpos
        )
    ),

    fn clearSlot idx = (
        matArray[idx] = undefined
        saveSceneMats()
        if WH_FloatAlpha_Struct != undefined do WH_FloatAlpha_Struct.buildUI()
    ),

    -- ---------- 球体位图渲染 ----------
    fn getMatColor mat = (
        local c = color 120 120 120
        try (
            if isProperty mat "diffuse"       then c = mat.diffuse
            else if isProperty mat "diffuse_color" then c = mat.diffuse_color
            else if isProperty mat "base_color"    then c = mat.base_color
            if classOf c != Color do c = color 120 120 120
        ) catch()
        c
    ),

    fn drawSphereBitmap mat bw bh = (
        local bmp = dotNetObject "System.Drawing.Bitmap" bw bh
        local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        try(g.SmoothingMode = (dotNetClass "System.Drawing.Drawing2D.SmoothingMode").AntiAlias)catch()

        -- 透明背景（使用和窗口相同的 TransparencyKey 颜色）
        try (
            local bgBrush = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 3 3 3)
            g.FillRectangle bgBrush 0 0 bw bh
            bgBrush.Dispose()
        ) catch()

        local c = getMatColor mat
        local rr = c.r as integer; local gg = c.g as integer; local bb = c.b as integer
        if rr < 0 do rr = 0; if rr > 255 do rr = 255
        if gg < 0 do gg = 0; if gg > 255 do gg = 255
        if bb < 0 do bb = 0; if bb > 255 do bb = 255

        local d = 46
        local cx = ((bw - d) / 2) as integer
        local cy = 4

        -- 阴影
        try (
            local sh = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 100 0 0 0)
            g.FillEllipse sh (cx+3) (cy+4) d d
            sh.Dispose()
        ) catch()

        -- 剪切区
        local path = undefined
        try (
            path = dotNetObject "System.Drawing.Drawing2D.GraphicsPath"
            path.AddEllipse cx cy d d
            g.SetClip path
        ) catch()

        -- 玻璃材质判断
        local isGlass = false
        try (
            if classOf mat == VRayMtl then (
                if isProperty mat "refraction" do (
                    if (classOf mat.refraction == Color and mat.refraction.v > 30) do isGlass = true
                )
            ) else if classOf mat == PhysicalMaterial then (
                if isProperty mat "transparency" and mat.transparency > 0.2 do isGlass = true
            ) else if classOf mat == StandardMaterial then (
                if isProperty mat "opacity" and mat.opacity < 85 do isGlass = true
            )
        ) catch()

        -- 填色
        try (
            if isGlass then (
                local tRect = dotNetObject "System.Drawing.Rectangle" cx cy d (d/2 as integer)
                local bRect = dotNetObject "System.Drawing.Rectangle" cx (cy + d/2 as integer) d (d/2 as integer)
                local tC1 = (dotNetClass "System.Drawing.Color").FromArgb 220 230 240
                local tC2 = (dotNetClass "System.Drawing.Color").FromArgb 100 110 120
                local bC1 = (dotNetClass "System.Drawing.Color").FromArgb 20 25 30
                local bC2 = (dotNetClass "System.Drawing.Color").FromArgb 5 10 15
                local tBr = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" tRect tC1 tC2 (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").Vertical
                local bBr = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" bRect bC1 bC2 (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").Vertical
                g.FillRectangle tBr tRect; g.FillRectangle bBr bRect
                tBr.Dispose(); bBr.Dispose()
                local cRect = dotNetObject "System.Drawing.Rectangle" cx (cy + (d*0.3) as integer) d ((d*0.7) as integer)
                local cBr = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" cRect ((dotNetClass "System.Drawing.Color").FromArgb 0 255 255 255) ((dotNetClass "System.Drawing.Color").FromArgb 160 255 255 255) (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").Vertical
                g.FillRectangle cBr cRect; cBr.Dispose()
            ) else (
                local base = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb rr gg bb)
                g.FillEllipse base cx cy d d
                base.Dispose()
            )
        ) catch()

        -- 光影
        try (
            local shRect = dotNetObject "System.Drawing.Rectangle" (cx - (d*0.2) as integer) (cy - (d*0.2) as integer) ((d*1.4) as integer) ((d*1.4) as integer)
            local shBr = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" shRect ((dotNetClass "System.Drawing.Color").FromArgb 0 0 0 0) ((dotNetClass "System.Drawing.Color").FromArgb 160 0 0 0) (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").ForwardDiagonal
            g.FillEllipse shBr cx cy d d; shBr.Dispose()
            local rimBr = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" (dotNetObject "System.Drawing.Rectangle" cx cy d d) ((dotNetClass "System.Drawing.Color").FromArgb 40 255 255 255) ((dotNetClass "System.Drawing.Color").FromArgb 0 255 255 255) (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").ForwardDiagonal
            g.FillEllipse rimBr cx cy d d; rimBr.Dispose()
            local hx = cx + (d * 0.1) as integer
            local hy = cy + (d * 0.1) as integer
            local hlMax = (d * 0.45) as float
            for i = 6 to 1 by -1 do (
                local sz = (hlMax * i / 6) as integer
                if sz > 0 do (
                    local hlOff = ((hlMax - sz) / 2) as integer
                    local hlBr = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 30 255 255 255)
                    g.FillEllipse hlBr (dotNetObject "System.Drawing.Rectangle" (hx+hlOff) (hy+hlOff) sz sz)
                    hlBr.Dispose()
                )
            )
        ) catch()

        try(g.ResetClip(); if path != undefined do path.Dispose())catch()

        try (
            local outPen = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 60 0 0 0) (1.0 as float)
            g.DrawEllipse outPen cx cy d d; outPen.Dispose()
        ) catch()

        try(g.Dispose())catch()
        bmp
    ),

    -- ---------- 刷新单个按钮图像 ----------
    fn refreshBtn idx = (
        if WH_FloatAlpha_Form == undefined do return()
        local btnName = "s" + (idx as string)
        local btn = undefined
        local arr = WH_FloatAlpha_Form.Controls.Find btnName false
        if arr.count > 0 do btn = arr[1]
        
        if btn == undefined do return()
        local mat = matArray[idx]
        if isKindOf mat Material then (
            local bmp = drawSphereBitmap mat btn.Width btn.Height
            btn.Image = bmp
            local showName = loadShowName()
            if showName then (
                local mName = ""; try(mName = mat.name as string)catch()
                if mName == "" do mName = "未命名"
                btn.Text = mName
                btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                btn.ForeColor = (dotNetClass "System.Drawing.Color").White
                btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
            ) else (
                btn.Text = ""
                btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
            )
        ) else (
            btn.Image = undefined
            btn.Text = ""
        )
    ),

    -- ---------- 构建/重建 UI ----------
    fn buildUI = (
        try (
            local cfg = loadConfig()
            local cols = cfg[1]; local rows = cfg[2]
            local totalSlots = cols * rows
            loadSceneMats totalSlots

            local btnW = 75
            local showName = loadShowName()
            local btnH = if showName then 75 else 55  -- 显示名称时加高
            local spacing = 4
            local padX = 5; local padY = 5
            local anchorW = 28
            local startX = padX + anchorW + spacing
            local startY = padY
            
            local formW = startX + cols * (btnW + spacing) + padX
            local formH = startY + rows * (btnH + spacing) + padY

            local transC = (dotNetClass "System.Drawing.Color").FromArgb 3 3 3

            -- 关闭旧窗口
            if WH_FloatAlpha_Form != undefined do try(WH_FloatAlpha_Form.Close())catch()
            if WH_FloatAlpha_BgForm != undefined do try(WH_FloatAlpha_BgForm.Close())catch()

            local sx = getINISetting iniFile "Settings" "WinPosX"
            local sy = getINISetting iniFile "Settings" "WinPosY"
            local cx_, cy_
            if sx != "" and sy != "" then (
                cx_ = sx as integer
                cy_ = sy as integer
            ) else (
                cx_ = (sysInfo.desktopSize.x - formW - 200) as integer
                cy_ = 62
            )
            local ptLoc = dotNetObject "System.Drawing.Point" cx_ cy_
            local sz = dotNetObject "System.Drawing.Size" formW formH

            -- 创建底层隐形盾牌 Form (捕获空隙和空槽的点击)
            WH_FloatAlpha_BgForm = dotNetObject "System.Windows.Forms.Form"
            WH_FloatAlpha_BgForm.FormBorderStyle = (dotNetClass "System.Windows.Forms.FormBorderStyle").None
            WH_FloatAlpha_BgForm.ShowInTaskbar = false
            WH_FloatAlpha_BgForm.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
            WH_FloatAlpha_BgForm.Size = sz
            WH_FloatAlpha_BgForm.Location = ptLoc
            WH_FloatAlpha_BgForm.BackColor = (dotNetClass "System.Drawing.Color").Black
            WH_FloatAlpha_BgForm.Opacity = 0.01  -- 1% 不透明度，肉眼绝对看不出变化，但能完美拦截鼠标
            
            dotNet.addEventHandler WH_FloatAlpha_BgForm "MouseDown" WH_FloatAlpha_BgDown
            dotNet.addEventHandler WH_FloatAlpha_BgForm "MouseMove" WH_FloatAlpha_AnchorMove
            dotNet.addEventHandler WH_FloatAlpha_BgForm "MouseUp" WH_FloatAlpha_AnchorUp

            -- 创建表层完全透明 Form
            WH_FloatAlpha_Form = dotNetObject "System.Windows.Forms.Form"
            WH_FloatAlpha_Form.FormBorderStyle = (dotNetClass "System.Windows.Forms.FormBorderStyle").None
            WH_FloatAlpha_Form.TopMost = false
            WH_FloatAlpha_Form.BackColor = transC
            WH_FloatAlpha_Form.TransparencyKey = transC
            WH_FloatAlpha_Form.ShowInTaskbar = false
            WH_FloatAlpha_Form.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
            WH_FloatAlpha_Form.Size = sz
            WH_FloatAlpha_Form.Location = ptLoc

            -- 将底层挂靠到 3ds Max，表层挂靠到底层
            try (
                local maxHwnd = windows.getMaxHWND()
                local hwndPtr = dotNetObject "System.IntPtr" (maxHwnd as integer)
                local nativeWin = dotNetObject "System.Windows.Forms.NativeWindow"
                nativeWin.AssignHandle hwndPtr
                WH_FloatAlpha_BgForm.Show nativeWin
                WH_FloatAlpha_Form.Show WH_FloatAlpha_BgForm
            ) catch (
                WH_FloatAlpha_BgForm.Show()
                WH_FloatAlpha_Form.Show WH_FloatAlpha_BgForm
            )

            -- ≡ 锚点图标 (纯视觉元素，点击穿透至底层)
            local anchor = dotNetObject "System.Windows.Forms.Label"
            anchor.Name = "anchor"
            anchor.Text = "≡"
            anchor.Size = dotNetObject "System.Drawing.Size" anchorW 30
            anchor.Location = dotNetObject "System.Drawing.Point" padX (padY + 6)
            anchor.BackColor = transC
            anchor.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 160 160 160
            anchor.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 20
            anchor.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
            WH_FloatAlpha_Form.Controls.Add anchor

            -- 红X已移除，关闭请右键点击锚点

            -- 材质球按钮（全部槽位，空槽隐藏）
            for i = 1 to totalSlots do (
                local r = ((i - 1) / cols) as integer + 1
                local c = (mod (i-1) cols) + 1
                local bx = startX + (c - 1) * (btnW + spacing)
                local btnY = startY + (r - 1) * (btnH + spacing)

                local btn = dotNetObject "System.Windows.Forms.Button"
                btn.Name = "s" + (i as string)
                btn.Size = dotNetObject "System.Drawing.Size" btnW btnH
                btn.Location = dotNetObject "System.Drawing.Point" bx btnY
                btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                btn.FlatAppearance.BorderSize = 0
                -- 背景色与 TransparencyKey 相同 → 视觉透明，LWA_COLORKEY 不影响命中区域，仍接收右键
                btn.BackColor = transC
                btn.FlatAppearance.MouseOverBackColor = transC
                btn.FlatAppearance.MouseDownBackColor = transC
                btn.FlatAppearance.BorderColor = transC
                btn.Text = ""
                btn.Cursor = (dotNetClass "System.Windows.Forms.Cursors").Hand

                local mat = matArray[i]
                if isKindOf mat Material then (
                    local bmp = drawSphereBitmap mat btnW btnH
                    btn.Image = bmp
                    local showName = loadShowName()
                    if showName then (
                        local mName = ""; try(mName = mat.name as string)catch()
                        if mName == "" do mName = "未命名"
                        btn.Text = mName
                        btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                        btn.ForeColor = (dotNetClass "System.Drawing.Color").White
                        btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                        btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                        btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
                    ) else (
                        btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                    )
                )
                -- 空槽时 btn 已是 transC，视觉透明，右键仍有效

                dotNet.addEventHandler btn "MouseDown" WH_FloatAlpha_BtnDown
                WH_FloatAlpha_Form.Controls.Add btn
            )

            -- Show 已在 Owner 设置块中调用，此处无需重复
        ) catch (
            messagebox ("透明版界面生成失败：\n" + getCurrentException()) title:"错误"
        )
    )
)

-- ===== 宏脚本入口 =====
-- ===== 布局设置面板 =====
rollout WH_FloatAlpha_Config_Rollout "布局设置" width:210 height:130 (
    spinner spn_cols "列数 (左右):" range:[1,20,4] type:#integer pos:[20,20] fieldWidth:40
    spinner spn_rows "行数 (上下):" range:[1,20,3] type:#integer pos:[20,50] fieldWidth:40
    checkbox chk_name "显示材质名称" pos:[20,78] checked:true
    button btn_guide "📖 操作指南" pos:[10,103] width:190 height:22
    
    on btn_guide pressed do (
        local msg = "【浮动材质球 极速操作指南】\n\n"
        msg += "左键相关：\n"
        msg += "• [左键单击] 槽位：将该材质赋予选中的物体\n"
        msg += "• [Alt + 左键单击] 槽位：将【材质编辑器】中当前的激活材质导入到此槽位\n"
        msg += "• [Shift + 左键单击] 槽位：吸取场景中【选中物体】的材质到此槽位\n"
        msg += "• [左键拖动] 空隙/空槽/锚点：自由移动面板位置\n\n"
        msg += "右键相关：\n"
        msg += "• [右键单击] 槽位/空槽：弹出材质专属功能菜单\n"
        msg += "• [右键单击] 锚点：弹出面板设置与管理菜单\n"
        messagebox msg title:"操作指南"
    )

    on WH_FloatAlpha_Config_Rollout open do (
        if WH_FloatAlpha_Struct != undefined do (
            local cfg = WH_FloatAlpha_Struct.loadConfig()
            spn_cols.value = cfg[1]
            spn_rows.value = cfg[2]
            chk_name.checked = WH_FloatAlpha_Struct.loadShowName()
        )
    )
    on chk_name changed val do (
        if WH_FloatAlpha_Struct != undefined do (
            WH_FloatAlpha_Struct.saveShowName val
            WH_FloatAlpha_Struct.buildUI()
        )
    )
    on spn_cols changed val do (
        if WH_FloatAlpha_Struct != undefined do (
            WH_FloatAlpha_Struct.saveConfig val spn_rows.value
            WH_FloatAlpha_Struct.buildUI()
        )
    )
    on spn_rows changed val do (
        if WH_FloatAlpha_Struct != undefined do (
            WH_FloatAlpha_Struct.saveConfig spn_cols.value val
            WH_FloatAlpha_Struct.buildUI()
        )
    )
)

macroScript WhFloatMatAlpha
category:"whtool"
toolTip:"浮动材质球 透明版"
buttonText:"材质球透明版"
(
    on execute do (
        WH_FloatAlpha_Struct = WH_FloatAlpha_Core()
        WH_FloatAlpha_Struct.buildUI()
    )
)

-- ===== 直接执行 =====
(
    WH_FloatAlpha_Struct = WH_FloatAlpha_Core()
    WH_FloatAlpha_Struct.buildUI()
)
