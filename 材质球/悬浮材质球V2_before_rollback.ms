-- 悬浮材质球 v1.0
-- 背景完全透明，仅显示已赋材质的材质球，支持左键赋材质、右键菜单

global WH_XFMat_Form
global WH_XFMat_BgForm
global WH_XFMat_Struct
global WH_XFMat_RCMenu
global WH_XFMat_IsDrag  = false
global WH_XFMat_DragSX  = 0
global WH_XFMat_DragSY  = 0
global WH_XFMat_WinX = 0
global WH_XFMat_WinY = 0
global WH_XFMat_CurIdx  = 0
global WH_XFMat_Config_Rollout
global WH_XFMat_V2_ActiveMtl = undefined
global WH_XFMat_V2_ActiveIdx = 0
global WH_XFMat_V2_UIControls = #()
global WH_XFMat_V2_VisibilityTimer = undefined
global WH_XFMat_V2_HiddenByMaxMinimize = false

-- ===== 调试日志系统 =====
fn WH_XFMat_LogDebug msg = (
    try (
        local logPath = (getDir #temp) + "wh_xfmat_run_log.txt"
        local f = openFile logPath mode:"a"
        if f == undefined do f = createFile logPath
        if f != undefined do (
            format "[%] %\n" (localTime) msg to:f
            close f
        )
    ) catch()
)

-- ===== 终极防线：纯反射包装器（规避 mxsdotNet 字典污染及 .NET Core 平台兼容问题） =====
struct WH_XFMat_ReflectHelper (
    fn addControl parent child = (
        if parent == undefined or child == undefined do return ()
        try (
            local pt = parent.GetType()
            local p = pt.GetProperty "Controls"
            local cObj = p.GetValue parent undefined
            local ct = cObj.GetType()
            local m = ct.GetMethod "Add"
            local args = dotNetObject "System.Object[]" 1
            args.SetValue child 0
            m.Invoke cObj args
        ) catch (
            try(parent.Controls.Add child)catch()
        )
    ),
    fn clearControls parent = (
        if parent == undefined do return ()
        try (
            local pt = parent.GetType()
            local p = pt.GetProperty "Controls"
            local cObj = p.GetValue parent undefined
            local ct = cObj.GetType()
            local m = ct.GetMethod "Clear"
            m.Invoke cObj undefined
        ) catch (
            try(parent.Controls.Clear())catch()
        )
    ),
    fn showForm f = (
        if f == undefined do return ()
        try (
            local ft = f.GetType()
            local m = ft.GetMethod "Show" (dotNetClass "System.Type").EmptyTypes
            m.Invoke f undefined
        ) catch (
            try(f.Show())catch()
        )
    ),
    fn closeForm f = (
        if f == undefined do return ()
        try (
            local ft = f.GetType()
            local m = ft.GetMethod "Close" (dotNetClass "System.Type").EmptyTypes
            m.Invoke f undefined
        ) catch (
            try(f.Close())catch()
        )
    ),
    fn setProp obj propName val = (
        if obj == undefined do return ()
        try (
            setProperty obj propName val
        ) catch (
            try (
                local pt = obj.GetType()
                local p = pt.GetProperty propName
                p.SetValue obj val undefined
            ) catch ()
        )
    )
)
global WH_XFMat_ReflectHelper_Obj = WH_XFMat_ReflectHelper()


-- ===== 延迟重绘机制 (规避快捷键焦点阻塞) =====
global WH_XFMat_V2_RedrawTimer = undefined

fn WH_XFMat_V2_RedrawTimerTick sender args = (
    try (
        sender.Stop()
        dotNet.removeAllEventHandlers sender
        sender.Dispose()
    ) catch()
    
    -- 强制刷新视图
    try (
        forceCompleteRedraw()
        redrawViews()
    ) catch()
)

fn WH_XFMat_V2_TriggerRedraw = (
    if ::WH_XFMat_V2_RedrawTimer != undefined do (
        try (
            ::WH_XFMat_V2_RedrawTimer.Stop()
            dotNet.removeAllEventHandlers ::WH_XFMat_V2_RedrawTimer
            ::WH_XFMat_V2_RedrawTimer.Dispose()
        ) catch()
    )
    ::WH_XFMat_V2_RedrawTimer = dotNetObject "System.Windows.Forms.Timer"
    ::WH_XFMat_V2_RedrawTimer.Interval = 30
    dotNet.addEventHandler ::WH_XFMat_V2_RedrawTimer "Tick" ::WH_XFMat_V2_RedrawTimerTick
    ::WH_XFMat_V2_RedrawTimer.Start()
)

fn WH_XFMat_V2_IsMaxMinimized = (
    try (
        local maxHwnd = windows.getMaxHWND()
        if maxHwnd == undefined or maxHwnd == 0 do return false

        local r = windows.getWindowPos maxHwnd
        if r == undefined do return false

        local x = 0
        local y = 0
        try (
            x = r.x
            y = r.y
        ) catch (
            try (
                x = r.pos.x
                y = r.pos.y
            ) catch()
        )

        (x < -10000 or y < -10000)
    ) catch (
        false
    )
)

fn WH_XFMat_ShowFloatingForms = (
    try (
        if WH_XFMat_BgForm != undefined do WH_XFMat_BgForm.Show()
        if WH_XFMat_Form != undefined do WH_XFMat_Form.Show()
        if WH_XFMat_Form != undefined do WH_XFMat_Form.BringToFront()
    ) catch (
        try (
            if WH_XFMat_BgForm != undefined do WH_XFMat_BgForm.Show()
        ) catch()
        try (
            if WH_XFMat_Form != undefined do WH_XFMat_Form.Show()
        ) catch()
    )
)

fn WH_XFMat_V2_VisibilityTimerTick sender args = (
    try (
        local maxMin = WH_XFMat_V2_IsMaxMinimized()
        if maxMin then (
            if not ::WH_XFMat_V2_HiddenByMaxMinimize do (
                try(if WH_XFMat_Form != undefined do WH_XFMat_Form.Hide())catch()
                try(if WH_XFMat_BgForm != undefined do WH_XFMat_BgForm.Hide())catch()
                ::WH_XFMat_V2_HiddenByMaxMinimize = true
            )
        ) else (
            if ::WH_XFMat_V2_HiddenByMaxMinimize do (
                ::WH_XFMat_V2_HiddenByMaxMinimize = false
                WH_XFMat_ShowFloatingForms()
            )
        )
    ) catch()
)

fn WH_XFMat_V2_StartVisibilityTimer = (
    if ::WH_XFMat_V2_VisibilityTimer != undefined do (
        try (
            ::WH_XFMat_V2_VisibilityTimer.Stop()
            dotNet.removeAllEventHandlers ::WH_XFMat_V2_VisibilityTimer
            ::WH_XFMat_V2_VisibilityTimer.Dispose()
        ) catch()
    )
    ::WH_XFMat_V2_HiddenByMaxMinimize = false
    ::WH_XFMat_V2_VisibilityTimer = dotNetObject "System.Windows.Forms.Timer"
    ::WH_XFMat_V2_VisibilityTimer.Interval = 300
    dotNet.addEventHandler ::WH_XFMat_V2_VisibilityTimer "Tick" ::WH_XFMat_V2_VisibilityTimerTick
    ::WH_XFMat_V2_VisibilityTimer.Start()
)

fn WH_XFMat_V2_StopVisibilityTimer = (
    if ::WH_XFMat_V2_VisibilityTimer != undefined do (
        try (
            ::WH_XFMat_V2_VisibilityTimer.Stop()
            dotNet.removeAllEventHandlers ::WH_XFMat_V2_VisibilityTimer
            ::WH_XFMat_V2_VisibilityTimer.Dispose()
        ) catch()
    )
    ::WH_XFMat_V2_VisibilityTimer = undefined
    ::WH_XFMat_V2_HiddenByMaxMinimize = false
)

-- 极度防御性：黑线框状态检测与设置函数
fn WH_XFMat_IsBlackBorder = (
    local ini = (getDir #userscripts) + "\\whtools_xfmat_config.ini"
    if WH_XFMat_Struct != undefined then (
        WH_XFMat_Struct.loadBlackBorder()
    ) else (
        (getINISetting ini "Settings" "BlackBorder") == "1"
    )
)

fn WH_XFMat_ApplyBlackBorder target = (
    if WH_XFMat_IsBlackBorder() do (
        if target != undefined do (
            if isProperty target "count" then (
                for i = 1 to target.count do (
                    local obj = target[i]
                    if isValidNode obj do obj.wirecolor = color 0 0 0
                )
            ) else (
                if isValidNode target do target.wirecolor = color 0 0 0
            )
        )
    )
)

fn WH_XFMat_ApplyAutoUvwMap target mat = (
    if WH_XFMat_Struct != undefined and WH_XFMat_Struct.loadAutoUvwMap() do (
        if WH_XFMat_Struct.hasDiffuseMap mat do (
            local sz = WH_XFMat_Struct.loadUvwMapSize()
            local uvw = Uvwmap maptype:4 length:sz width:sz height:sz realWorldMapSize:false
            
            fn processNode obj sz refUvw = (
                if isValidNode obj and superclassof obj == GeometryClass do (
                    local existingUvw = undefined
                    local modsToDelete = #()
                    
                    -- 倒序遍历收集多余的 Uvwmap 修改器，防止正向删除导致越界
                    for j = obj.modifiers.count to 1 by -1 do (
                        local m = obj.modifiers[j]
                        if isKindOf m Uvwmap do (
                            if existingUvw == undefined then (
                                existingUvw = m
                            ) else (
                                append modsToDelete m
                            )
                        )
                    )
                    
                    if existingUvw != undefined then (
                        existingUvw.maptype = 4
                        existingUvw.length = sz
                        existingUvw.width = sz
                        existingUvw.height = sz
                        existingUvw.realWorldMapSize = false
                        existingUvw.utile = 1.0
                        existingUvw.vtile = 1.0
                        existingUvw.wtile = 1.0
                        existingUvw.mapChannel = 1
                    ) else (
                        addModifier obj (copy refUvw)
                    )
                    
                    for m in modsToDelete do deleteModifier obj m
                )
            )

            if target != undefined do (
                if isProperty target "count" then (
                    for i = 1 to target.count do processNode target[i] sz uvw
                ) else (
                    processNode target sz uvw
                )
            )
        )
    )
)

-- 轻柔系统提示音（代替弹窗）
fn WH_beep = ( try((dotNetClass "System.Media.SystemSounds").Asterisk.Play())catch() )

-- ===== 锚点右键菜单（关闭 / 重建）=====
global WH_XFMat_AnchorMenu
rcMenu WH_XFMat_AnchorMenu (
    menuItem mi_m1 "🖱️ 模式1: 直接单击赋予 (当前)" checked:true
    menuItem mi_m2 "🖌️ 模式2: 连续点击涂抹" checked:false
    menuItem mi_m3 "⚡ 模式3: 激活 + 快捷键" checked:false
    separator sep_bb
    menuItem mi_blackBorder "🖤 赋予材质自动变黑线框" checked:false
    menuItem mi_autoUvwMap "📦 有贴图自动加UVW" checked:false
    separator sep_proj
    menuItem mi_proj "🌟 设为项目公共材质库"
    separator sep_pt
    menuItem mi_a_settings "⚙️ 布局设置"
    menuItem mi_a_rebuild  "🔄 重建界面"
    separator sep_guide
    menuItem mi_a_guide    "📖 操作指南"
    separator sep_aa
    menuItem mi_a_close    "❌ 关闭"
    
    on WH_XFMat_AnchorMenu open do (
        if WH_XFMat_Struct != undefined do (
            local m = WH_XFMat_Struct.loadAssignMode()
            mi_m1.checked = (m == 1)
            mi_m2.checked = (m == 2)
            mi_m3.checked = (m == 3)
            mi_m1.text = if m==1 then "🖱️ 模式1: 直接单击赋予 (当前)" else "🖱️ 模式1: 直接单击赋予"
            mi_m2.text = if m==2 then "🖌️ 模式2: 连续点击涂抹 (当前)" else "🖌️ 模式2: 连续点击涂抹"
            mi_m3.text = if m==3 then "⚡ 模式3: 激活 + 快捷键 (当前)" else "⚡ 模式3: 激活 + 快捷键"
            
            -- 读取黑边框开关并设置勾选状态
            local bb = getINISetting WH_XFMat_Struct.iniFile "Settings" "BlackBorder"
            mi_blackBorder.checked = (bb == "1")
            
            local au = getINISetting WH_XFMat_Struct.iniFile "Settings" "AutoUvwMap"
            mi_autoUvwMap.checked = (au == "1")
            
            local sz = WH_XFMat_Struct.loadUvwMapSize()
            mi_autoUvwMap.text = "📦 有贴图自动加UVW (" + (sz as string) + " Box)"
        )
    )
    
    on mi_m1 picked do ( if WH_XFMat_Struct != undefined do ( WH_XFMat_Struct.saveAssignMode 1; WH_XFMat_Struct.buildUI() ) )
    on mi_m2 picked do ( if WH_XFMat_Struct != undefined do ( WH_XFMat_Struct.saveAssignMode 2; WH_XFMat_Struct.buildUI() ) )
    on mi_m3 picked do ( if WH_XFMat_Struct != undefined do ( WH_XFMat_Struct.saveAssignMode 3; WH_XFMat_Struct.buildUI() ) )
    
    on mi_blackBorder picked do (
        if WH_XFMat_Struct != undefined do (
            local val = if mi_blackBorder.checked then "0" else "1"
            setINISetting WH_XFMat_Struct.iniFile "Settings" "BlackBorder" val
            mi_blackBorder.checked = (val == "1")
        )
    )
    
    on mi_autoUvwMap picked do (
        if WH_XFMat_Struct != undefined do (
            local val = if mi_autoUvwMap.checked then "0" else "1"
            setINISetting WH_XFMat_Struct.iniFile "Settings" "AutoUvwMap" val
            mi_autoUvwMap.checked = (val == "1")
        )
    )
    
    on mi_proj picked do (
        if maxFilePath != "" then (
            if queryBox ("确定要将当前材质作为公共库，保存在以下目录吗？\n" + maxFilePath + "\n\n(该目录及向上最多3级内的场景都会共享此材质库)") title:"设为项目公共材质库" do (
                if WH_XFMat_Struct != undefined do (
                    local projPath = maxFilePath + "WH_XFMats_Project.mat"
                    local lib = materialLibrary()
                    for i = 1 to WH_XFMat_Struct.matArray.count do (
                        if isKindOf WH_XFMat_Struct.matArray[i] Material then (
                            append lib WH_XFMat_Struct.matArray[i]
                        ) else (
                            local d = StandardMaterial name:"WH_EMPTY_SLOT"
                            append lib d
                        )
                    )
                    try(saveTempMaterialLibrary lib projPath)catch()
                    messageBox ("已成功生成项目公共库！\n" + projPath) title:"成功"
                )
            )
        ) else (
            messageBox "请先保存当前 3ds Max 场景文件！" title:"警告"
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
        local msg = "【浮动材质球V2 操作指南】\n\n"
        msg += "三种赋予模式（右键锚点切换）：\n"
        msg += "1. 直接单击：点击材质球立即赋予。\n"
        msg += "2. 涂抹模式：点击后进入涂抹，点选物体赋予。\n"
        msg += "3. 激活模式：点击材质球变为激活态(并同步到材质编辑器)，按自定快捷键赋予。\n\n"
        msg += "项目级共享：\n"
        msg += "右键锚点 -> 设为项目公共库。当前文件夹及向下所有子文件夹的场景将共享一套材质。\n"
        messagebox msg title:"操作指南"
    )
    on mi_a_close   picked do ( 
        WH_XFMat_V2_StopVisibilityTimer()
        if ::WH_XFMat_V2_UIControls != undefined do (
            for c in ::WH_XFMat_V2_UIControls where c != undefined do try(dotNet.removeAllEventHandlers c)catch()
        )
        ::WH_XFMat_V2_UIControls = #()
        if WH_XFMat_Form != undefined do try(dotNet.removeAllEventHandlers WH_XFMat_Form)catch()
        if WH_XFMat_BgForm != undefined do try(dotNet.removeAllEventHandlers WH_XFMat_BgForm)catch()

        local helperClass = ::WH_XFMat_ReflectHelper_Obj
        if helperClass != undefined then (
            if WH_XFMat_Form != undefined do (
                helperClass.clearControls WH_XFMat_Form
                helperClass.closeForm WH_XFMat_Form
            )
            if WH_XFMat_BgForm != undefined do (
                helperClass.closeForm WH_XFMat_BgForm
            )
        ) else (
            if WH_XFMat_Form   != undefined do try(WH_XFMat_Form.Close())catch()
            if WH_XFMat_BgForm != undefined do try(WH_XFMat_BgForm.Close())catch()
        )
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
        WH_XFMat_ShowFloatingForms()
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
            undo "赋予材质" on ( 
                targetObj.material = ::WH_XFMat_PaintMtl
                ::WH_XFMat_ApplyBlackBorder targetObj
                ::WH_XFMat_ApplyAutoUvwMap targetObj ::WH_XFMat_PaintMtl
            )
            ::WH_XFMat_V2_TriggerRedraw()
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
            ::WH_XFMat_WinX += dx
            ::WH_XFMat_WinY += dy
            local newLoc = dotNetObject "System.Drawing.Point" ::WH_XFMat_WinX ::WH_XFMat_WinY
            local helperClass = ::WH_XFMat_ReflectHelper_Obj
            if helperClass != undefined then (
                helperClass.setProp WH_XFMat_Form "Location" newLoc
                if WH_XFMat_BgForm != undefined do helperClass.setProp WH_XFMat_BgForm "Location" newLoc
            ) else (
                try(WH_XFMat_Form.Location = newLoc)catch()
                try(if WH_XFMat_BgForm != undefined do WH_XFMat_BgForm.Location = newLoc)catch()
            )
        )
    )
)
fn WH_XFMat_AnchorUp sender args = (
    WH_XFMat_IsDrag = false
    -- 拖动结束时保存位置
    if WH_XFMat_Struct != undefined do (
        setINISetting WH_XFMat_Struct.iniFile "Settings" "WinPosX" (::WH_XFMat_WinX as string)
        setINISetting WH_XFMat_Struct.iniFile "Settings" "WinPosY" (::WH_XFMat_WinY as string)
    )
)
-- ===== 底层隐形窗体鼠标事件（拦截空隙和空槽）=====
fn WH_XFMat_BgDown sender args = (
    try (
        if WH_XFMat_Form != undefined do WH_XFMat_Form.BringToFront()
    ) catch()

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
    local mat = undefined
    if WH_XFMat_Struct != undefined do (
        if idx > 0 and idx <= WH_XFMat_Struct.matArray.count do mat = WH_XFMat_Struct.matArray[idx]
    )
    local isEmpty = not (isKindOf mat Material)

    local modKeys = (dotNetClass "System.Windows.Forms.Control").ModifierKeys
    local isAlt = modKeys == (dotNetClass "System.Windows.Forms.Keys").Alt
    local isShift = modKeys == (dotNetClass "System.Windows.Forms.Keys").Shift

    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do (
        if isAlt then (
            if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromMedit idx
        ) else if isShift then (
            if WH_XFMat_Struct != undefined do WH_XFMat_Struct.pickFromObject idx
        ) else (
            if WH_XFMat_Struct != undefined and not isEmpty do (
                local assignMode = WH_XFMat_Struct.loadAssignMode()
                if assignMode == 1 then (
                    WH_XFMat_Struct.applyMatToObject idx
                ) else if assignMode == 2 then (
                    WH_XFMat_Struct.paintMatToObject idx
                ) else if assignMode == 3 then (
                    WH_XFMat_Struct.activateMtl idx
                )
            )
        )
    )
    if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do (
        if isEmpty then popupMenu WH_XFMat_EmptyRCMenu
        else popupMenu WH_XFMat_RCMenu
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

    fn getParentPath p = (
        local parent = ""
        try (
            local cleanPath = trimRight p "\\/"
            local di = dotNetObject "System.IO.DirectoryInfo" cleanPath
            if di.Parent != undefined do parent = di.Parent.FullName + "\\"
        ) catch()
        parent
    ),

    fn findProjectMatLibPath = (
        if maxFilePath == "" do return undefined
        local curPath = maxFilePath
        local level = 0
        while (level <= 3 and curPath != "") do (
            local projectPath = curPath + "WH_XFMats_Project.mat"
            if doesFileExist projectPath do return projectPath
            curPath = getParentPath curPath
            level += 1
        )
        undefined
    ),

    fn getSceneMatLibPath = (
        if maxFilePath == "" then (
            (getDir #userscripts) + "\\WH_XFMats_Untitled.mat"
        ) else (
            local projectPath = findProjectMatLibPath()
            if projectPath != undefined then projectPath else maxFilePath + "WH_XFMats_" + (getFilenameFile maxFileName) + ".mat"
        )
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
                    local matToLoad = undefined
                    if i <= lib.count and isKindOf lib[i] Material do (
                        local n = ""; try(n = lib[i].name as string)catch()
                        if n != "WH_EMPTY_SLOT" and n != "VRayMtl" do (
                            isEmpty = false
                            matToLoad = lib[i]
                            
                            -- 核心防御：跨会话/重启后的场景材质重连机制
                            -- 防止同一个材质球在下次打开文件时变成独立的副本
                            for sm in sceneMaterials do (
                                if sm.name == matToLoad.name and classOf sm == classOf matToLoad do (
                                    matToLoad = sm  -- 用场景里的真实材质实例替换掉脱机库材质
                                    exit
                                )
                            )
                        )
                    )
                    append arr (if isEmpty then undefined else matToLoad)
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

    fn loadAssignMode = (
        local v = getINISetting iniFile "Settings" "AssignMode"
        if v == "1" then 1 else if v == "2" then 2 else if v == "3" then 3 else 1
    ),

    fn loadBlackBorder = (
        local v = getINISetting iniFile "Settings" "BlackBorder"
        v == "1"
    ),

    fn saveConfig c rv = (
        setINISetting iniFile "Settings" "Cols" (c as string)
        setINISetting iniFile "Settings" "Rows" (rv as string)
    ),

    fn saveShowName val = (
        setINISetting iniFile "Settings" "ShowName" (if val then "1" else "0")
    ),

    fn saveAssignMode val = (
        setINISetting iniFile "Settings" "AssignMode" (val as string)
    ),

    fn saveBlackBorder val = (
        setINISetting iniFile "Settings" "BlackBorder" (if val then "1" else "0")
    ),

    fn loadAutoUvwMap = (
        local v = getINISetting iniFile "Settings" "AutoUvwMap"
        v == "1"
    ),

    fn saveAutoUvwMap val = (
        setINISetting iniFile "Settings" "AutoUvwMap" (if val then "1" else "0")
    ),

    fn loadUvwMapSize = (
        local v = getINISetting iniFile "Settings" "UvwMapSize"
        if v == "" then 800.0 else v as float
    ),

    fn saveUvwMapSize val = (
        setINISetting iniFile "Settings" "UvwMapSize" (val as string)
    ),

    fn hasDiffuseMap mat = (
        if not isKindOf mat Material do return false
        local hasMap = false
        try (
            if isProperty mat "diffuseMap" and mat.diffuseMap != undefined then hasMap = true
            else if isProperty mat "texmap_diffuse" and mat.texmap_diffuse != undefined then hasMap = true
            else if isProperty mat "base_color_map" and mat.base_color_map != undefined then hasMap = true
            else if isProperty mat "colorTexmap" and mat.colorTexmap != undefined then hasMap = true
        ) catch()
        hasMap
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

    fn activateMtl idx = (
        local m = matArray[idx]
        if not (isKindOf m Material) do return WH_beep()
        
        local oldIdx = ::WH_XFMat_V2_ActiveIdx
        
        -- 更新全局激活变量
        ::WH_XFMat_V2_ActiveMtl = m
        ::WH_XFMat_V2_ActiveIdx = idx
        
        -- 同步到材质编辑器
        local foundInMedit = false
        for i=1 to 24 do (
            if meditMaterials[i] == m do (
                activeMeditSlot = i
                foundInMedit = true
                exit
            )
        )
        if not foundInMedit do (
            meditMaterials[activeMeditSlot] = m
        )
        
        -- 动态刷新 UI 高亮 (绘制红点)
        if WH_XFMat_Struct != undefined do (
            if oldIdx > 0 and oldIdx != idx do WH_XFMat_Struct.refreshBtn oldIdx
            WH_XFMat_Struct.refreshBtn idx
        )
    ),

    fn applyMatToObject idx = (
        if selection.count > 0 then (
            local m = matArray[idx]
            if isKindOf m Material do (
                undo "赋予材质" on (
                    for obj in selection do obj.material = m
                    ::WH_XFMat_ApplyBlackBorder selection
                    ::WH_XFMat_ApplyAutoUvwMap selection m
                )
                ::WH_XFMat_V2_TriggerRedraw()
            )
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
                dotNetControl edt "System.Windows.Forms.TextBox" pos:[10,15] width:195 height:22
                button btn_ok "确定" pos:[50,45] width:60 height:25
                button btn_cancel "取消" pos:[115,45] width:60 height:25
                
                fn applyRename = (
                    if edt.text != "" and WH_FloatMat_RenameMat != undefined do (
                        WH_FloatMat_RenameMat.name = edt.text
                        if WH_XFMat_Struct != undefined do (
                            WH_XFMat_Struct.saveSceneMats()
                            WH_XFMat_Struct.refreshBtn WH_FloatMat_RenameIdx
                        )
                    )
                    destroyDialog WH_XFMat_Rename_Rollout
                )
                
                on edt KeyUp args do (
                    if args.KeyCode == (dotNetClass "System.Windows.Forms.Keys").Enter do applyRename()
                    if args.KeyCode == (dotNetClass "System.Windows.Forms.Keys").Escape do destroyDialog WH_XFMat_Rename_Rollout
                )
                
                on WH_XFMat_Rename_Rollout open do (
                    if WH_FloatMat_RenameMat != undefined do edt.text = WH_FloatMat_RenameMat.name as string
                    edt.Focus()
                    edt.SelectAll()
                )
                
                on btn_ok pressed do applyRename()
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

    fn drawSphereBitmap mat bw bh isActive:false = (
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

        if isActive do (
            try (
                local dotD = 8
                local dotX = cx + d + 1
                local dotY = cy
                local dotBr = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").OrangeRed)
                g.FillEllipse dotBr dotX dotY dotD dotD
                dotBr.Dispose()
                
                local dotPen = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").Black) (1.0 as float)
                g.DrawEllipse dotPen dotX dotY dotD dotD
                dotPen.Dispose()
            ) catch()
        )

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
        local controlIdx = idx + 1 -- UIControls[1] is the anchor; material buttons start at 2.
        local btn = if ::WH_XFMat_V2_UIControls != undefined and ::WH_XFMat_V2_UIControls.count >= controlIdx then ::WH_XFMat_V2_UIControls[controlIdx] else undefined
        if btn == undefined do return()
        local mat = matArray[idx]
        if isKindOf mat Material then (
            local assignMode = loadAssignMode()
            local isActiveSlot = (assignMode == 3 and idx == ::WH_XFMat_V2_ActiveIdx)
            local bmp = drawSphereBitmap mat btn.Width btn.Height isActive:isActiveSlot
            local oldImg = btn.Image
            local helperClass = ::WH_XFMat_ReflectHelper_Obj
            if helperClass != undefined then (
                helperClass.setProp btn "Image" bmp
                if oldImg != undefined do try(oldImg.Dispose())catch()
                local showName = loadShowName()
                if showName then (
                    local mName = ""; try(mName = mat.name as string)catch()
                    if mName == "" do mName = "未命名"
                    helperClass.setProp btn "Text" mName
                    helperClass.setProp btn "Font" (dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5)
                    helperClass.setProp btn "ForeColor" (dotNetClass "System.Drawing.Color").White
                    helperClass.setProp btn "TextAlign" (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                    helperClass.setProp btn "TextImageRelation" (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                    helperClass.setProp btn "ImageAlign" (dotNetClass "System.Drawing.ContentAlignment").TopCenter
                ) else (
                    helperClass.setProp btn "Text" ""
                    helperClass.setProp btn "ImageAlign" (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                )
            ) else (
                btn.Image = bmp
                if oldImg != undefined do try(oldImg.Dispose())catch()
                local showName = loadShowName()
                if showName then (
                    local mName = ""; try(mName = mat.name as string)catch()
                    if mName == "" do mName = "未命名"
                    btn.Text = mName
                    btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                    btn.ForeColor = (dotNetClass "System.Drawing.Color").White
                    try(btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter)catch()
                    try(btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText)catch()
                    try(btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter)catch()
                ) else (
                    btn.Text = ""
                    try(btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter)catch()
                )
            )
        ) else (
            local hasAnyMat = false
            for m in matArray do if isKindOf m Material do (hasAnyMat = true; exit)
            if idx == 1 and not hasAnyMat then (
                local oldImg = btn.Image
                local helperClass = ::WH_XFMat_ReflectHelper_Obj
                if helperClass != undefined then (
                    helperClass.setProp btn "Image" (drawEmptyPlaceholder btn.Width btn.Height)
                    if oldImg != undefined do try(oldImg.Dispose())catch()
                    helperClass.setProp btn "Text" "右键添加"
                    helperClass.setProp btn "Font" (dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5)
                    helperClass.setProp btn "ForeColor" (dotNetClass "System.Drawing.Color").Gray
                    helperClass.setProp btn "TextAlign" (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                    helperClass.setProp btn "TextImageRelation" (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                    helperClass.setProp btn "ImageAlign" (dotNetClass "System.Drawing.ContentAlignment").TopCenter
                ) else (
                    btn.Image = drawEmptyPlaceholder btn.Width btn.Height
                    if oldImg != undefined do try(oldImg.Dispose())catch()
                    btn.Text = "右键添加"
                    btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                    btn.ForeColor = (dotNetClass "System.Drawing.Color").Gray
                    try(btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter)catch()
                    try(btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText)catch()
                    try(btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter)catch()
                )
            ) else (
                local oldImg = btn.Image
                local helperClass = ::WH_XFMat_ReflectHelper_Obj
                if helperClass != undefined then (
                    helperClass.setProp btn "Image" undefined
                    if oldImg != undefined do try(oldImg.Dispose())catch()
                    helperClass.setProp btn "Text" ""
                ) else (
                    if btn.Image != undefined do try(btn.Image.Dispose())catch()
                    btn.Image = undefined
                    btn.Text = ""
                )
            )
        )
    ),

    -- ---------- 构建/重建 UI ----------
    fn buildUI = (
        WH_XFMat_V2_StopVisibilityTimer()
        -- 彻底销毁前解绑所有事件，防止垃圾回收期间指针访问异常 (ACCESS_VIOLATION)
        if ::WH_XFMat_V2_UIControls != undefined do (
            for c in ::WH_XFMat_V2_UIControls where c != undefined do try(dotNet.removeAllEventHandlers c)catch()
        )
        ::WH_XFMat_V2_UIControls = #()

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

            -- 关闭与清理旧窗口前解绑事件
            if WH_XFMat_Form != undefined do try(dotNet.removeAllEventHandlers WH_XFMat_Form)catch()
            if WH_XFMat_BgForm != undefined do try(dotNet.removeAllEventHandlers WH_XFMat_BgForm)catch()

            -- 关闭与清理旧窗口 (采用纯反射机制)
            local helperClass = ::WH_XFMat_ReflectHelper_Obj
            if helperClass != undefined then (
                if WH_XFMat_Form != undefined do (
                    helperClass.clearControls WH_XFMat_Form
                    helperClass.closeForm WH_XFMat_Form
                )
                if WH_XFMat_BgForm != undefined do (
                    helperClass.closeForm WH_XFMat_BgForm
                )
            ) else (
                if WH_XFMat_Form != undefined do (
                    try(WH_XFMat_Form.Controls.Clear())catch()
                    try(WH_XFMat_Form.Close())catch()
                )
                if WH_XFMat_BgForm != undefined do try(WH_XFMat_BgForm.Close())catch()
            )

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
            ::WH_XFMat_WinX = cx_
            ::WH_XFMat_WinY = cy_
            local ptLoc = dotNetObject "System.Drawing.Point" cx_ cy_
            local sz = dotNetObject "System.Drawing.Size" formW formH

            -- 创建底层隐形盾牌 Form (捕获空隙和空槽的点击)
            WH_XFMat_BgForm = dotNetObject "System.Windows.Forms.Form"
            if WH_XFMat_BgForm != undefined do (
                dotNet.setLifetimeControl WH_XFMat_BgForm #dotnet
                if helperClass != undefined then (
                    helperClass.setProp WH_XFMat_BgForm "FormBorderStyle" (dotNetClass "System.Windows.Forms.FormBorderStyle").None
                    helperClass.setProp WH_XFMat_BgForm "TopMost" true
                    helperClass.setProp WH_XFMat_BgForm "ShowInTaskbar" false
                    helperClass.setProp WH_XFMat_BgForm "StartPosition" (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
                    helperClass.setProp WH_XFMat_BgForm "Size" sz
                    helperClass.setProp WH_XFMat_BgForm "Location" ptLoc
                    helperClass.setProp WH_XFMat_BgForm "BackColor" (dotNetClass "System.Drawing.Color").Black
                    helperClass.setProp WH_XFMat_BgForm "Opacity" 0.01
                ) else (
                    WH_XFMat_BgForm.FormBorderStyle = (dotNetClass "System.Windows.Forms.FormBorderStyle").None
                    WH_XFMat_BgForm.TopMost = true
                    WH_XFMat_BgForm.ShowInTaskbar = false
                    WH_XFMat_BgForm.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
                    WH_XFMat_BgForm.Size = sz
                    WH_XFMat_BgForm.Location = ptLoc
                    WH_XFMat_BgForm.BackColor = (dotNetClass "System.Drawing.Color").Black
                    WH_XFMat_BgForm.Opacity = 0.01
                )
                
                dotNet.addEventHandler WH_XFMat_BgForm "MouseDown" WH_XFMat_BgDown
                dotNet.addEventHandler WH_XFMat_BgForm "MouseMove" WH_XFMat_AnchorMove
                dotNet.addEventHandler WH_XFMat_BgForm "MouseUp" WH_XFMat_AnchorUp
            )

            -- 创建表层完全透明 Form
            WH_XFMat_Form = dotNetObject "System.Windows.Forms.Form"
            if WH_XFMat_Form != undefined do (
                dotNet.setLifetimeControl WH_XFMat_Form #dotnet
                if helperClass != undefined then (
                    helperClass.setProp WH_XFMat_Form "FormBorderStyle" (dotNetClass "System.Windows.Forms.FormBorderStyle").None
                    helperClass.setProp WH_XFMat_Form "TopMost" true
                    helperClass.setProp WH_XFMat_Form "BackColor" transC
                    helperClass.setProp WH_XFMat_Form "TransparencyKey" transC
                    helperClass.setProp WH_XFMat_Form "ShowInTaskbar" false
                    helperClass.setProp WH_XFMat_Form "StartPosition" (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
                    helperClass.setProp WH_XFMat_Form "Size" sz
                    helperClass.setProp WH_XFMat_Form "Location" ptLoc
                ) else (
                    WH_XFMat_Form.FormBorderStyle = (dotNetClass "System.Windows.Forms.FormBorderStyle").None
                    WH_XFMat_Form.TopMost = true
                    WH_XFMat_Form.BackColor = transC
                    WH_XFMat_Form.TransparencyKey = transC
                    WH_XFMat_Form.ShowInTaskbar = false
                    WH_XFMat_Form.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").Manual
                    WH_XFMat_Form.Size = sz
                    WH_XFMat_Form.Location = ptLoc
                )
            )

            local assignMode = loadAssignMode()
            
            -- 锚点使用小号文本按钮，避免 Bitmap/Image 首帧漏绘和独立窗体同步错误。
            local aColor = (dotNetClass "System.Drawing.Color").FromArgb 160 160 160
            if assignMode == 2 then (
                aColor = (dotNetClass "System.Drawing.Color").FromArgb 255 150 50
            ) else if assignMode == 3 then (
                aColor = (dotNetClass "System.Drawing.Color").OrangeRed
            )

            local anchor = dotNetObject "System.Windows.Forms.Button"
            dotNet.setLifetimeControl anchor #dotnet
            if helperClass != undefined then (
                helperClass.setProp anchor "Name" "anchor"
                helperClass.setProp anchor "Size" (dotNetObject "System.Drawing.Size" anchorW 30)
                helperClass.setProp anchor "Location" (dotNetObject "System.Drawing.Point" padX (padY + 6))
                helperClass.setProp anchor "FlatStyle" (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                try(anchor.FlatAppearance.BorderSize = 0)catch()
                try(anchor.FlatAppearance.BorderColor = transC)catch()
                try(anchor.FlatAppearance.MouseOverBackColor = transC)catch()
                try(anchor.FlatAppearance.MouseDownBackColor = transC)catch()
                helperClass.setProp anchor "BackColor" transC
                helperClass.setProp anchor "ForeColor" aColor
                helperClass.setProp anchor "Font" (dotNetObject "System.Drawing.Font" "Segoe UI" 14.0)
                helperClass.setProp anchor "Text" "≡"
                helperClass.setProp anchor "TextAlign" (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                helperClass.setProp anchor "Cursor" (dotNetClass "System.Windows.Forms.Cursors").Hand
            ) else (
                anchor.Name = "anchor"
                anchor.Size = dotNetObject "System.Drawing.Size" anchorW 30
                anchor.Location = dotNetObject "System.Drawing.Point" padX (padY + 6)
                anchor.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                try(anchor.FlatAppearance.BorderSize = 0)catch()
                try(anchor.FlatAppearance.BorderColor = transC)catch()
                try(anchor.FlatAppearance.MouseOverBackColor = transC)catch()
                try(anchor.FlatAppearance.MouseDownBackColor = transC)catch()
                anchor.BackColor = transC
                anchor.ForeColor = aColor
                anchor.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0
                anchor.Text = "≡"
                try(anchor.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter)catch()
                anchor.Cursor = (dotNetClass "System.Windows.Forms.Cursors").Hand
            )
            dotNet.addEventHandler anchor "MouseDown" WH_XFMat_AnchorDown
            dotNet.addEventHandler anchor "MouseMove" WH_XFMat_AnchorMove
            dotNet.addEventHandler anchor "MouseUp" WH_XFMat_AnchorUp
            append ::WH_XFMat_V2_UIControls anchor
            if helperClass != undefined then (
                helperClass.addControl WH_XFMat_Form anchor
            ) else (
                WH_XFMat_Form.Controls.Add anchor
            )

            -- 材质球按钮（全部槽位，空槽隐藏）
            local hasAnyMat = false
            for m in matArray do if isKindOf m Material do (hasAnyMat = true; exit)
            
            for i = 1 to totalSlots do (
                local r = ((i - 1) / cols) as integer + 1
                local c = (mod (i-1) cols) + 1
                local bx = startX + (c - 1) * (btnW + spacing)
                local btnY = startY + (r - 1) * (btnH + spacing)

                local btn = dotNetObject "System.Windows.Forms.Button"
                dotNet.setLifetimeControl btn #dotnet
                
                local curType = if assignMode == 2 then (dotNetClass "System.Windows.Forms.Cursors").Cross else (dotNetClass "System.Windows.Forms.Cursors").Hand
                
                if helperClass != undefined then (
                    helperClass.setProp btn "Name" ("s" + (i as string))
                    helperClass.setProp btn "Size" (dotNetObject "System.Drawing.Size" btnW btnH)
                    helperClass.setProp btn "Location" (dotNetObject "System.Drawing.Point" bx btnY)
                    helperClass.setProp btn "FlatStyle" (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                    try(btn.FlatAppearance.BorderSize = 0)catch()
                    try(btn.FlatAppearance.BorderColor = transC)catch()
                    helperClass.setProp btn "BackColor" transC
                    try(btn.FlatAppearance.MouseOverBackColor = transC)catch()
                    try(btn.FlatAppearance.MouseDownBackColor = transC)catch()
                    helperClass.setProp btn "Text" ""
                    helperClass.setProp btn "Cursor" curType
                ) else (
                    btn.Name = "s" + (i as string)
                    btn.Size = dotNetObject "System.Drawing.Size" btnW btnH
                    btn.Location = dotNetObject "System.Drawing.Point" bx btnY
                    btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                    try(btn.FlatAppearance.BorderSize = 0)catch()
                    try(btn.FlatAppearance.BorderColor = transC)catch()
                    btn.BackColor = transC
                    try(btn.FlatAppearance.MouseOverBackColor = transC)catch()
                    try(btn.FlatAppearance.MouseDownBackColor = transC)catch()
                    btn.Text = ""
                    btn.Cursor = curType
                )

                local mat = matArray[i]
                if isKindOf mat Material then (
                    local isActiveSlot = (assignMode == 3 and i == ::WH_XFMat_V2_ActiveIdx)
                    local bmp = drawSphereBitmap mat btnW btnH isActive:isActiveSlot
                    
                    if helperClass != undefined then (
                        helperClass.setProp btn "Image" bmp
                        local showName = loadShowName()
                        if showName then (
                            local mName = ""; try(mName = mat.name as string)catch()
                            if mName == "" do mName = "未命名"
                            helperClass.setProp btn "Text" mName
                            helperClass.setProp btn "Font" (dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5)
                            helperClass.setProp btn "ForeColor" (dotNetClass "System.Drawing.Color").White
                            helperClass.setProp btn "TextAlign" (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                            helperClass.setProp btn "TextImageRelation" (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                            helperClass.setProp btn "ImageAlign" (dotNetClass "System.Drawing.ContentAlignment").TopCenter
                        ) else (
                            helperClass.setProp btn "ImageAlign" (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                        )
                    ) else (
                        btn.Image = bmp
                        local showName = loadShowName()
                        if showName then (
                            local mName = ""; try(mName = mat.name as string)catch()
                            if mName == "" do mName = "未命名"
                            btn.Text = mName
                            btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                            btn.ForeColor = (dotNetClass "System.Drawing.Color").White
                            try(btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter)catch()
                            try(btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText)catch()
                            try(btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter)catch()
                        ) else (
                            try(btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter)catch()
                        )
                    )
                ) else (
                    if i == 1 and not hasAnyMat then (
                        if helperClass != undefined then (
                            helperClass.setProp btn "Image" (drawEmptyPlaceholder btnW btnH)
                            helperClass.setProp btn "Text" "右键添加"
                            helperClass.setProp btn "Font" (dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5)
                            helperClass.setProp btn "ForeColor" (dotNetClass "System.Drawing.Color").Gray
                            helperClass.setProp btn "TextAlign" (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                            helperClass.setProp btn "TextImageRelation" (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
                            helperClass.setProp btn "ImageAlign" (dotNetClass "System.Drawing.ContentAlignment").TopCenter
                        ) else (
                            btn.Image = drawEmptyPlaceholder btnW btnH
                            btn.Text = "右键添加"
                            btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                            btn.ForeColor = (dotNetClass "System.Drawing.Color").Gray
                            try(btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter)catch()
                            try(btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText)catch()
                            try(btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter)catch()
                        )
                    )
                )

                dotNet.addEventHandler btn "MouseDown" WH_XFMat_BtnDown
                append ::WH_XFMat_V2_UIControls btn
                if helperClass != undefined then (
                    helperClass.addControl WH_XFMat_Form btn
                ) else (
                    WH_XFMat_Form.Controls.Add btn
                )
            )

            -- 控件全部加入后再显示，避免透明窗体首次显示时漏绘锚点图标
            WH_XFMat_ShowFloatingForms()
            WH_XFMat_V2_StartVisibilityTimer()

            try (
                WH_XFMat_Form.Invalidate()
                WH_XFMat_Form.Update()
                WH_XFMat_BgForm.Invalidate()
            ) catch()
        ) catch (
            messagebox ("透明版界面生成失败：\n" + getCurrentException()) title:"错误"
        )
    )
)

-- ===== 宏脚本入口 =====
-- ===== 布局设置面板 =====
rollout WH_XFMat_Config_Rollout "布局设置" width:220 height:160 (
    spinner spn_cols "列数 (左右):" range:[1,20,4] type:#integer pos:[20,20] fieldWidth:40
    spinner spn_rows "行数 (上下):" range:[1,20,3] type:#integer pos:[20,50] fieldWidth:40
    spinner spn_uvw "UVW 尺寸(mm):" range:[1,100000,800] type:#float pos:[20,80] fieldWidth:60
    checkbox chk_name "显示材质名称" pos:[20,108] checked:true
    button btn_guide "📖 操作指南" pos:[10,132] width:200 height:22
    
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
            spn_uvw.value = WH_XFMat_Struct.loadUvwMapSize()
        )
    )
    
    on spn_uvw changed val do (
        if WH_XFMat_Struct != undefined do (
            WH_XFMat_Struct.saveUvwMapSize val
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

macroScript WhFloatMatAlphaV2
category:"whtool"
toolTip:"悬浮材质球V2"
buttonText:"材质球透明版V2"
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


macroScript WhFloatMatV2Assign
category:"whtool"
toolTip:"悬浮材质球V2_快捷赋予"
buttonText:"V2_快捷赋予"
(
    on execute do (
        if ::WH_XFMat_V2_ActiveMtl != undefined then (
            if selection.count > 0 then (
                undo "快捷赋予材质" on (
                    selection.material = ::WH_XFMat_V2_ActiveMtl
                    ::WH_XFMat_ApplyBlackBorder selection
                    ::WH_XFMat_ApplyAutoUvwMap selection ::WH_XFMat_V2_ActiveMtl
                )
                ::WH_XFMat_V2_TriggerRedraw()
            ) else (
                try((dotNetClass "System.Media.SystemSounds").Asterisk.Play())catch()
            )
        ) else (
            try((dotNetClass "System.Media.SystemSounds").Asterisk.Play())catch()
        )
    )
)
