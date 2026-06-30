-- 悬浮材质球 v1.0
-- 背景完全透明，仅显示已赋材质的材质球，支持左键赋材质、右键菜单

global WH_XFMat_Form
global WH_XFMat_BgForm
global WH_XFMat_Struct
global WH_XFMat_RCMenu
global WH_XFMat_IsDrag  = false
global WH_XFMat_DragSX  = 0
global WH_XFMat_DragSY  = 0
global WH_XFMat_CurIdx  = 0
global WH_XFMat_Config_Rollout

-- 轻柔系统提示音（代替弹窗）
fn WH_beep = ( try((dotNetClass "System.Media.SystemSounds").Asterisk.Play())catch() )

-- ===== 锚点右键菜单（关闭 / 重建）=====
global WH_XFMat_AnchorMenu
rcMenu WH_XFMat_AnchorMenu (
    menuItem mi_a_paint    "🖌️ 连续点击赋予模式" checked:false
    separator sep_pt
    menuItem mi_a_settings "⚙️ 布局设置"
    menuItem mi_a_rebuild  "🔄 重建界面"
    separator sep_guide
    menuItem mi_a_guide    "📖 操作指南"
    separator sep_aa
    menuItem mi_a_close    "❌ 关闭"
    
    on WH_XFMat_AnchorMenu open do (
        if WH_XFMat_Struct != undefined do (
            mi_a_paint.checked = WH_XFMat_Struct.loadPaintMode()
        )
    )
    
    on mi_a_paint picked do (
        if WH_XFMat_Struct != undefined do (
            local cur = WH_XFMat_Struct.loadPaintMode()
            WH_XFMat_Struct.savePaintMode (not cur)
            WH_XFMat_Struct.buildUI()
        )
    )
    
    on mi_a_settings picked do (
        try(destroyDialog WH_XFMat_Config_Rollout)catch()
        local posX = mouse.screenpos.x - 320
        local posY = mouse.screenpos.y - 20
        if posX < 0 do posX = 0
        if posY < 0 do posY = 0
        createDialog WH_XFMat_Config_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) pos:[posX, posY]
    )
    on mi_a_rebuild picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.buildUI() )
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
        if WH_XFMat_Form   != undefined do try(WH_XFMat_Form.Close())catch()
        if WH_XFMat_BgForm != undefined do try(WH_XFMat_BgForm.Close())catch()
    )
)

-- ===== 材质球右键菜单 =====
rcMenu WH_XFMat_RCMenu (
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

    on mi_pickObj     picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromObject   WH_XFMat_CurIdx )
    on mi_fromMedit   picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromMedit    WH_XFMat_CurIdx )
    on mi_rename      picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.renameMaterial   WH_XFMat_CurIdx )
    on mi_editCompact picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.editInCompact    WH_XFMat_CurIdx )
    on mi_editSlate   picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.editInSlate      WH_XFMat_CurIdx )
    on mi_applyObj    picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.applyMatToObject WH_XFMat_CurIdx )
    on mi_clear       picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.clearSlot        WH_XFMat_CurIdx )
)

-- ===== 空槽位专用右键菜单 =====
global WH_XFMat_EmptyRCMenu
rcMenu WH_XFMat_EmptyRCMenu (
    menuItem mi_ep_pickObj   "✏️ 吸取选定物体材质"
    menuItem mi_ep_fromMedit "📥 从编辑器导入当前"
    on mi_ep_pickObj   picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromObject   WH_XFMat_CurIdx )
    on mi_ep_fromMedit picked do ( if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromMedit    WH_XFMat_CurIdx )
)

-- ===== 连续赋予底层追踪工具 =====
global WH_XFMat_PaintMtl = undefined
tool WH_XFMat_PaintTool numPoints:100000 (
    on start do (
        setSysCur #select
        pushPrompt "【涂抹模式】点击场景物体赋予材质 (右键 或 ESC 退出)..."
    )
    on stop do (
        popPrompt()
        if WH_XFMat_BgForm != undefined do try(WH_XFMat_BgForm.Show())catch()
        if WH_XFMat_Form != undefined do try(WH_XFMat_Form.Show WH_XFMat_BgForm)catch()
    )
    on mousePoint clickno do (
        local targetObj = undefined
        
        -- 方法1：射线投射（精准命中多边形几何体，自动穿透剔除）
        local r = mapScreenToWorldRay mouse.pos
        if r != undefined do (
            local hits = intersectRayScene r
            if hits != undefined and hits.count > 0 do (
                local minDist = 1e9
                for h in hits do (
                    local d = distance r.pos h[2].pos
                    if d < minDist do (
                        minDist = d
                        targetObj = h[1]
                    )
                )
            )
        )
        
        -- 方法2：像素框选降级（用于命中二维线段、灯光等无体积对象）
        if targetObj == undefined do (
            local rect = box2 ((mouse.pos.x as integer) - 2) ((mouse.pos.y as integer) - 2) 4 4
            local bhits = boxPickNode rect crossing:true
            if bhits != undefined and bhits.count > 0 do targetObj = bhits[1]
        )
        
        -- 核心：显式调用全局变量，彻底解决 Struct 局部作用域丢失导致 Mtl 为空的恶性 BUG
        if isValidNode targetObj and ::WH_XFMat_PaintMtl != undefined do (
            undo "赋予材质" on ( targetObj.material = ::WH_XFMat_PaintMtl )
        )
    )
    on mouseAbort clickno do (
        -- 右键或ESC会自动触发 stop
    )
)

-- ===== 拖动事件（全局函数，供 dotNet.addEventHandler 使用）=====
fn WH_XFMat_AnchorDown sender args = (
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        WH_XFMat_IsDrag = true
        local sp = sender.PointToScreen (dotNetObject "System.Drawing.Point" args.X args.Y)
        WH_XFMat_DragSX = sp.X
        WH_XFMat_DragSY = sp.Y
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        popupMenu WH_XFMat_AnchorMenu
    )
)
fn WH_XFMat_AnchorMove sender args = (
    if WH_XFMat_IsDrag do (
        local sp = sender.PointToScreen (dotNetObject "System.Drawing.Point" args.X args.Y)
        local dx = sp.X - WH_XFMat_DragSX
        local dy = sp.Y - WH_XFMat_DragSY
        WH_XFMat_DragSX = sp.X
        WH_XFMat_DragSY = sp.Y
        if WH_XFMat_Form != undefined do (
            local loc = WH_XFMat_Form.Location
            local newLoc = dotNetObject "System.Drawing.Point" (loc.X + dx) (loc.Y + dy)
            WH_XFMat_Form.Location = newLoc
            if WH_XFMat_BgForm != undefined do WH_XFMat_BgForm.Location = newLoc
        )
    )
)
fn WH_XFMat_AnchorUp sender args = (
    WH_XFMat_IsDrag = false
    -- 拖动结束时保存位置
    if WH_XFMat_Form != undefined and WH_XFMat_Struct != undefined do (
        local loc = WH_XFMat_Form.Location
        setINISetting WH_XFMat_Struct.iniFile "Settings" "WinPosX" (loc.X as string)
        setINISetting WH_XFMat_Struct.iniFile "Settings" "WinPosY" (loc.Y as string)
    )
)
-- ===== 底层隐形窗体鼠标事件（拦截空隙和空槽）=====
fn WH_XFMat_BgDown sender args = (
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        WH_XFMat_IsDrag = true
        local sp = sender.PointToScreen (dotNetObject "System.Drawing.Point" args.X args.Y)
        WH_XFMat_DragSX = sp.X
        WH_XFMat_DragSY = sp.Y
        return ()
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        if WH_XFMat_Struct != undefined do (
            local padX = 5; local padY = 4; local anchorH = 30
            local btnW = 75
            local showName = WH_XFMat_Struct.loadShowName()
            local btnH = if showName then 75 else 55
            local spacing = 4
            
            local dx = args.X - padX
            local dy = args.Y - anchorH - padY
            if dx >= 0 and dy >= 0 do (
                local c = (dx / (btnW + spacing)) as integer + 1
                local r = (dy / (btnH + spacing)) as integer + 1
                local modX = mod dx (btnW + spacing)
                local modY = mod dy (btnH + spacing)
                local cfg = WH_XFMat_Struct.loadConfig()
                local cols = cfg[1]
                
                if c > 0 and c <= cols and modX < btnW and modY < btnH do (
                    local idx = (r - 1) * cols + c
                    if idx > 0 and idx <= WH_XFMat_Struct.matArray.count do (
                        local mat = WH_XFMat_Struct.matArray[idx]
                        if not (isKindOf mat Material) do (
                            WH_XFMat_CurIdx = idx
                            popupMenu WH_XFMat_EmptyRCMenu
                        )
                    )
                )
            )
        )
    )
)

-- ===== 材质按钮鼠标事件 =====
fn WH_XFMat_BtnDown sender args = (
    local idxStr = sender.Name  -- "s1", "s2" ...
    local idx = (substring idxStr 2 -1) as integer
    WH_XFMat_CurIdx = idx
    local mat = if WH_XFMat_Struct != undefined then WH_XFMat_Struct.matArray[idx] else undefined
    local isEmpty = not (isKindOf mat Material)
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        if not isEmpty and WH_XFMat_Struct != undefined do WH_XFMat_Struct.applyMatToObject idx
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        if isEmpty then popupMenu WH_XFMat_EmptyRCMenu
        else popupMenu WH_XFMat_RCMenu
    )
)

-- ===== 底层隐形窗体鼠标事件（拦截空隙和空槽）=====
fn WH_XFMat_BgDown sender args = (
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
            if WH_XFMat_Struct != undefined do (
                local btnW = 75
                local showName = WH_XFMat_Struct.loadShowName()
                local btnH = if showName then 75 else 55
                
                local dx = args.X - startX
                local dy = args.Y - startY
                if dx >= 0 and dy >= 0 do (
                    local c = (dx / (btnW + spacing)) as integer + 1
                    local r = (dy / (btnH + spacing)) as integer + 1
                    local modX = mod dx (btnW + spacing)
                    local modY = mod dy (btnH + spacing)
                    local cfg = WH_XFMat_Struct.loadConfig()
                    local cols = cfg[1]
                    
                    if c > 0 and c <= cols and modX < btnW and modY < btnH do (
                        local idx = (r - 1) * cols + c
                        if idx > 0 and idx <= WH_XFMat_Struct.matArray.count do (
                            if isAlt then WH_XFMat_Struct.pickFromMedit idx
                            else if isShift then WH_XFMat_Struct.pickFromObject idx
                        )
                    )
                )
            )
        ) else (
            -- 普通左键拖动窗口
            WH_XFMat_IsDrag = true
            local sp = sender.PointToScreen (dotNetObject "System.Drawing.Point" args.X args.Y)
            WH_XFMat_DragSX = sp.X
            WH_XFMat_DragSY = sp.Y
        )
        return ()
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        if args.X < startX then (
            popupMenu WH_XFMat_AnchorMenu
        ) else (
            if WH_XFMat_Struct != undefined do (
                local btnW = 75
                local showName = WH_XFMat_Struct.loadShowName()
                local btnH = if showName then 75 else 55
                
                local dx = args.X - startX
                local dy = args.Y - startY
                if dx >= 0 and dy >= 0 do (
                    local c = (dx / (btnW + spacing)) as integer + 1
                    local r = (dy / (btnH + spacing)) as integer + 1
                    local modX = mod dx (btnW + spacing)
                    local modY = mod dy (btnH + spacing)
                    local cfg = WH_XFMat_Struct.loadConfig()
                    local cols = cfg[1]
                    
                    if c > 0 and c <= cols and modX < btnW and modY < btnH do (
                        local idx = (r - 1) * cols + c
                        if idx > 0 and idx <= WH_XFMat_Struct.matArray.count do (
                            local mat = WH_XFMat_Struct.matArray[idx]
                            if not (isKindOf mat Material) do (
                                WH_XFMat_CurIdx = idx
                                popupMenu WH_XFMat_EmptyRCMenu
                            )
                        )
                    )
                )
            )
        )
    )
)

-- ===== 材质按钮鼠标事件 =====
fn WH_XFMat_BtnDown sender args = (
    local idxStr = sender.Name  -- "s1", "s2" ...
    local idx = (substring idxStr 2 -1) as integer
    WH_XFMat_CurIdx = idx

    local modKeys = (dotNetClass "System.Windows.Forms.Control").ModifierKeys
    local isAlt = modKeys == (dotNetClass "System.Windows.Forms.Keys").Alt
    local isShift = modKeys == (dotNetClass "System.Windows.Forms.Keys").Shift

    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        if isAlt then (
            if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromMedit idx
        ) else if isShift then (
            if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromObject idx
        ) else (
            if WH_XFMat_Struct != undefined do (
                local paintMode = WH_XFMat_Struct.loadPaintMode()
                if paintMode then (
                    WH_XFMat_Struct.paintMatToObject idx
                ) else (
                    WH_XFMat_Struct.applyMatToObject idx
                )
            )
        )
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        popupMenu WH_XFMat_RCMenu
    )
)
struct WH_XFMat_Core (
    iniFile = (getDir #userscripts) + "\\whtools_xfmat_config.ini",
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
            (getDir #userscripts) + "\\WH_XFMats_Untitled.mat"
        else
            maxFilePath + "WH_XFMats_" + (getFilenameFile maxFileName) + ".mat"
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

    fn loadPaintMode = (
        local v = getINISetting iniFile "Settings" "PaintMode"
        v == "1"  -- 默认不开启
    ),

    fn saveConfig c rv = (
        setINISetting iniFile "Settings" "Cols" (c as string)
        setINISetting iniFile "Settings" "Rows" (rv as string)
    ),

    fn saveShowName val = (
        setINISetting iniFile "Settings" "ShowName" (if val then "1" else "0")
    ),

    fn savePaintMode val = (
        setINISetting iniFile "Settings" "PaintMode" (if val then "1" else "0")
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

    fn paintMatToObject idx = (
        local m = matArray[idx]
        if not (isKindOf m Material) do return WH_beep()
        
        -- 显式指定赋值到全局变量空间
        ::WH_XFMat_PaintMtl = m
        
        -- 启动原生Tool工具。startTool是异步非阻塞的，会立刻结束当前的.NET点击事件，从而完美规避右键失灵问题
        if WH_XFMat_Form != undefined do WH_XFMat_Form.Hide()
        if WH_XFMat_BgForm != undefined do WH_XFMat_BgForm.Hide()
        (dotNetClass "System.Windows.Forms.Application").DoEvents()
        
        startTool WH_XFMat_PaintTool
    ),

    fn pickFromObject idx = (
        if selection.count > 0 then (
            local m = selection[1].material
            if m != undefined then (
                matArray[idx] = m
                saveSceneMats()
                if WH_XFMat_Struct != undefined do WH_XFMat_Struct.refreshBtn idx
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
            if WH_XFMat_Struct != undefined do WH_XFMat_Struct.refreshBtn idx
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
            try(destroyDialog WH_XFMat_Rename_Rollout)catch()
            rollout WH_XFMat_Rename_Rollout "重命名材质" width:220 height:80 (
                edittext edt "" text:"" pos:[10,15] width:195
                button btn_ok "确定" pos:[50,45] width:60 height:25
                button btn_cancel "取消" pos:[115,45] width:60 height:25
                on WH_XFMat_Rename_Rollout open do (
                    if WH_FloatMat_RenameMat != undefined do edt.text = WH_FloatMat_RenameMat.name as string
                    setFocus edt
                )
                on btn_ok pressed do (
                    if edt.text != "" and WH_FloatMat_RenameMat != undefined do (
                        WH_FloatMat_RenameMat.name = edt.text
                        if WH_XFMat_Struct != undefined do (
                            WH_XFMat_Struct.saveSceneMats()
                            WH_XFMat_Struct.refreshBtn WH_FloatMat_RenameIdx
                        )
                    )
                    destroyDialog WH_XFMat_Rename_Rollout
                )
                on btn_cancel pressed do destroyDialog WH_XFMat_Rename_Rollout
            )
            createDialog WH_XFMat_Rename_Rollout style:#(#style_titlebar, #style_toolwindow) pos:mouse.screenpos
        )
    ),

    fn clearSlot idx = (
        matArray[idx] = undefined
        saveSceneMats()
        if WH_XFMat_Struct != undefined do WH_XFMat_Struct.buildUI()
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

    -- ---------- 球体位图渲染 ----------
    fn drawEmptyPlaceholder bw bh = (
        local bmp = dotNetObject "System.Drawing.Bitmap" bw bh
        local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        try(g.SmoothingMode = (dotNetClass "System.Drawing.Drawing2D.SmoothingMode").AntiAlias)catch()
        
        try (
            local bgBrush = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 3 3 3)
            g.FillRectangle bgBrush 0 0 bw bh
            bgBrush.Dispose()
        ) catch()
        
        try (
            local pen = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 100 100 100) 1.0
            pen.DashStyle = (dotNetClass "System.Drawing.Drawing2D.DashStyle").Dash
            local d = 46
            local cx = ((bw - d) / 2) as integer
            local cy = 4
            g.DrawEllipse pen cx cy d d
            pen.Dispose()
        ) catch()
        
        try(g.Dispose())catch()
        bmp
    ),

    -- ---------- 刷新单个按钮图像 ----------
    fn refreshBtn idx = (
        if WH_XFMat_Form == undefined do return()
        local btnName = "s" + (idx as string)
        local btn = undefined
        local arr = WH_XFMat_Form.Controls.Find btnName false
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
            local hasAnyMat = false
            for m in matArray do if isKindOf m Material do (hasAnyMat = true; exit)
            
            if idx == 1 and not hasAnyMat then (
                btn.Image = drawEmptyPlaceholder btn.Width btn.Height
                btn.Text = "右键添加"
                btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                btn.ForeColor = (dotNetClass "System.Drawing.Color").Gray
                btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
            ) else (
                btn.Image = undefined
                btn.Text = ""
            )
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
            if WH_XFMat_Form != undefined do try(WH_XFMat_Form.Close())catch()
            if WH_XFMat_BgForm != undefined do try(WH_XFMat_BgForm.Close())catch()

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
            WH_XFMat_BgForm = dotNetObject "System.Windows.Forms.Form"
            WH_XFMat_BgForm.FormBorderStyle = (dotNetClass "System.Windows.Forms.FormBorderStyle").None
            WH_XFMat_BgForm.ShowInTaskbar = false
            WH_XFMat_BgForm.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
            WH_XFMat_BgForm.Size = sz
            WH_XFMat_BgForm.Location = ptLoc
            WH_XFMat_BgForm.BackColor = (dotNetClass "System.Drawing.Color").Black
            WH_XFMat_BgForm.Opacity = 0.01  -- 1% 不透明度，肉眼绝对看不出变化，但能完美拦截鼠标
            
            dotNet.addEventHandler WH_XFMat_BgForm "MouseDown" WH_XFMat_BgDown
            dotNet.addEventHandler WH_XFMat_BgForm "MouseMove" WH_XFMat_AnchorMove
            dotNet.addEventHandler WH_XFMat_BgForm "MouseUp" WH_XFMat_AnchorUp

            -- 创建表层完全透明 Form
            WH_XFMat_Form = dotNetObject "System.Windows.Forms.Form"
            WH_XFMat_Form.FormBorderStyle = (dotNetClass "System.Windows.Forms.FormBorderStyle").None
            WH_XFMat_Form.TopMost = false
            WH_XFMat_Form.BackColor = transC
            WH_XFMat_Form.TransparencyKey = transC
            WH_XFMat_Form.ShowInTaskbar = false
            WH_XFMat_Form.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
            WH_XFMat_Form.Size = sz
            WH_XFMat_Form.Location = ptLoc

            -- 将底层挂靠到 3ds Max，表层挂靠到底层
            try (
                local maxHwnd = windows.getMaxHWND()
                local hwndPtr = dotNetObject "System.IntPtr" (maxHwnd as integer)
                local nativeWin = dotNetObject "System.Windows.Forms.NativeWindow"
                nativeWin.AssignHandle hwndPtr
                WH_XFMat_BgForm.Show nativeWin
                WH_XFMat_Form.Show WH_XFMat_BgForm
            ) catch (
                WH_XFMat_BgForm.Show()
                WH_XFMat_Form.Show WH_XFMat_BgForm
            )

            local paintMode = loadPaintMode()
            
            -- 锚点图标
            local anchor = dotNetObject "System.Windows.Forms.Label"
            anchor.Name = "anchor"
            anchor.Size = dotNetObject "System.Drawing.Size" anchorW 30
            anchor.BackColor = transC
            anchor.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
            
            if paintMode then (
                anchor.Text = "≡"
                anchor.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 255 150 50
                anchor.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 20
                anchor.Location = dotNetObject "System.Drawing.Point" padX (padY + 6)
            ) else (
                anchor.Text = "≡"
                anchor.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 160 160 160
                anchor.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 20
                anchor.Location = dotNetObject "System.Drawing.Point" padX (padY + 6)
            )
            
            dotNet.addEventHandler anchor "MouseDown" WH_XFMat_AnchorDown
            dotNet.addEventHandler anchor "MouseMove" WH_XFMat_AnchorMove
            dotNet.addEventHandler anchor "MouseUp" WH_XFMat_AnchorUp
            WH_XFMat_Form.Controls.Add anchor

            -- 材质球按钮（全部槽位，空槽隐藏）
            local hasAnyMat = false
            for m in matArray do if isKindOf m Material do (hasAnyMat = true; exit)
            
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
                btn.BackColor = transC
                btn.FlatAppearance.MouseOverBackColor = transC
                btn.FlatAppearance.MouseDownBackColor = transC
                btn.FlatAppearance.BorderColor = transC
                btn.Text = ""
                btn.Cursor = if paintMode then (dotNetClass "System.Windows.Forms.Cursors").Cross else (dotNetClass "System.Windows.Forms.Cursors").Hand

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
                ) else (
                    if i == 1 and not hasAnyMat then (
                        btn.Image = drawEmptyPlaceholder btnW btnH
                        btn.Text = "右键添加"
                        btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                        btn.ForeColor = (dotNetClass "System.Drawing.Color").Gray
                        btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                        btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                        btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
                    )
                )

                dotNet.addEventHandler btn "MouseDown" WH_XFMat_BtnDown
                WH_XFMat_Form.Controls.Add btn
            )

            -- Show 已在 Owner 设置块中调用，此处无需重复
        ) catch (
            messagebox ("透明版界面生成失败：\n" + getCurrentException()) title:"错误"
        )
    )
)

-- ===== 宏脚本入口 =====
-- ===== 布局设置面板 =====
rollout WH_XFMat_Config_Rollout "布局设置" width:210 height:130 (
    spinner spn_cols "列数 (左右):" range:[1,20,4] type:#integer pos:[20,20] fieldWidth:40
    spinner spn_rows "行数 (上下):" range:[1,20,3] type:#integer pos:[20,50] fieldWidth:40
    checkbox chk_name "显示材质名称" pos:[20,78] checked:true
    button btn_guide "📖 操作指南" pos:[10,102] width:190 height:22
    
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

    on WH_XFMat_Config_Rollout open do (
        if WH_XFMat_Struct != undefined do (
            local cfg = WH_XFMat_Struct.loadConfig()
            spn_cols.value = cfg[1]
            spn_rows.value = cfg[2]
            chk_name.checked = WH_XFMat_Struct.loadShowName()
        )
    )
    on chk_name changed val do (
        if WH_XFMat_Struct != undefined do (
            WH_XFMat_Struct.saveShowName val
            WH_XFMat_Struct.buildUI()
        )
    )
    on spn_cols changed val do (
        if WH_XFMat_Struct != undefined do (
            WH_XFMat_Struct.saveConfig val spn_rows.value
            WH_XFMat_Struct.buildUI()
        )
    )
    on spn_rows changed val do (
        if WH_XFMat_Struct != undefined do (
            WH_XFMat_Struct.saveConfig spn_cols.value val
            WH_XFMat_Struct.buildUI()
        )
    )
)

macroScript WhFloatMatAlpha
category:"whtool"
toolTip:"悬浮材质球"
buttonText:"材质球透明版"
(
    on execute do (
        WH_XFMat_Struct = WH_XFMat_Core()
        WH_XFMat_Struct.buildUI()
    )
)

-- ===== 直接执行 =====
(
    WH_XFMat_Struct = WH_XFMat_Core()
    WH_XFMat_Struct.buildUI()
)

