-- whtools_manager_beta.ms
-- 免安装脚本管理器 (横版/自定义行列/支持外部拖拽绑定)
(
    global WH_ScriptManager_Rollout
    try(destroyDialog WH_ScriptManager_Rollout)catch()
    
    global KGL_ManagerINI = (getDir #userscripts) + "\\whtools_manager_config.ini"
    global KGL_clr_empty = (dotNetClass "System.Drawing.Color").FromArgb 70 70 70
    global KGL_clr_filled = (dotNetClass "System.Drawing.Color").FromArgb 70 130 180
    global KGL_clr_font = (dotNetClass "System.Drawing.Color").White
    
    rollout WH_ScriptManager_Rollout "whtools 管理器 v1.8" (
        -- 拖动手柄 (供方案A左键拖动)
        dotnetcontrol lbl_drag "System.Windows.Forms.Label" pos:[1,1] width:10 height:22 tooltip:"拖动手柄 (左键按住拖动面板)"
        
        -- 极简控制区
        button btn_cfg "≡" pos:[12,1] width:18 height:22 tooltip:"布局与设置 (面板左键拖动手柄，中键按住任何格子也可拖动)"
        
        -- 底层承载面板
        dotnetcontrol pnl_grid "System.Windows.Forms.FlowLayoutPanel" pos:[34,0] width:10 height:10
        
        timer tmr_run interval:10 active:false
        local pendingScriptPath = ""
        
        -- 智能解析并开关脚本
        fn toggleScript path = (
            local rName = ""
            try (
                local f = openFile path
                if f != undefined do (
                    while not eof f do (
                        local l = readline f
                        local tokens = filterString l " \t\r\n()=\"',"
                        local foundIndex = 0
                        for i=1 to tokens.count do (
                            if (toLower tokens[i]) == "rollout" do (
                                foundIndex = i; exit
                            )
                        )
                        if foundIndex > 0 and (foundIndex + 1) <= tokens.count then (
                            rName = tokens[foundIndex + 1]
                            exit
                        )
                    )
                    close f
                )
            ) catch()
            
            local didClose = false
            if rName != "" then (
                local isOpen = execute ("try(" + rName + ".open == true)catch(false)")
                if isOpen == true then (
                    execute ("try(destroyDialog " + rName + ")catch()")
                    didClose = true
                )
            )
            
            if not didClose then (
                try(fileIn path)catch(messagebox ("脚本执行报错：\n" + (getCurrentException())) title:"whtools管理器")
            )
        )
        
        on tmr_run tick do (
            tmr_run.active = false
            if pendingScriptPath != "" and doesFileExist pendingScriptPath do (
                toggleScript pendingScriptPath
            )
        )
        
        global KGL_IsDragging = false
        global KGL_DragPosOffsetX = 0
        global KGL_DragPosOffsetY = 0
        
        -- 防止 .NET 控件的 MAXScript 包装层被垃圾回收 (GC) 导致事件失效！
        local GC_PreventArray = #()
        
        fn StartDrag sender e = (
            if e.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left or e.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Middle then (
                KGL_IsDragging = true
                local dlgPos = GetDialogPos WH_ScriptManager_Rollout
                KGL_DragPosOffsetX = mouse.screenpos.x - dlgPos.x
                KGL_DragPosOffsetY = mouse.screenpos.y - dlgPos.y
            )
        )
        
        fn DoDrag sender e = (
            if KGL_IsDragging then (
                SetDialogPos WH_ScriptManager_Rollout [mouse.screenpos.x - KGL_DragPosOffsetX, mouse.screenpos.y - KGL_DragPosOffsetY]
            )
        )
        
        fn EndDrag sender e = (
            if KGL_IsDragging then (
                KGL_IsDragging = false
                local dlgPos = GetDialogPos WH_ScriptManager_Rollout
                setINISetting KGL_ManagerINI "Settings" "PosX" ((dlgPos.x as integer) as string)
                setINISetting KGL_ManagerINI "Settings" "PosY" ((dlgPos.y as integer) as string)
            )
        )
        
        on btn_cfg pressed do (
            try(destroyDialog RO_Manager_Config)catch()
            rollout RO_Manager_Config "设置 / 说明" width:240 height:178 (
                groupBox grp1 "网格布局 (行列)" pos:[10,5] width:220 height:50
                spinner spn_cols "列排:" range:[1,30,5] type:#integer pos:[25,25] fieldWidth:40
                spinner spn_rows "行排:" range:[1,20,1] type:#integer pos:[130,25] fieldWidth:40
                label lbl1 "操作: 把脚本拖进格子绑定\n左键: 运行脚本 | 右键: 重命名/清空\n拖动: 按住左侧边缘把手 或 中键按住网格拖动" pos:[10,60]
                
                button btn_uninstall "🗑️  完全卸载管理器" pos:[10,105] width:220 height:28 \
                    tooltip:"删除所有配置和文件，从动作列表注销"
                
                button btn_close "❌  收隐该面板" pos:[10,140] width:220 height:28 \
                    tooltip:"隐藏面板。稍后可通过系统工具栏的宏按钮再次开启。"
                
                on btn_close pressed do (
                    destroyDialog RO_Manager_Config
                    try(destroyDialog WH_ScriptManager_Rollout)catch()
                )
                
                on RO_Manager_Config open do (
                    local c = getINISetting KGL_ManagerINI "Settings" "Cols"
                    local r = getINISetting KGL_ManagerINI "Settings" "Rows"
                    if c != "" do spn_cols.value = c as integer
                    if r != "" do spn_rows.value = r as integer
                )
                on spn_cols changed val do (
                    setINISetting KGL_ManagerINI "Settings" "Cols" (val as string)
                    WH_ScriptManager_Rollout.BuildGrid val spn_rows.value
                )
                on spn_rows changed val do (
                    setINISetting KGL_ManagerINI "Settings" "Rows" (val as string)
                    WH_ScriptManager_Rollout.BuildGrid spn_cols.value val
                )
                
                on btn_uninstall pressed do (
                    if queryBox "确定要完全卸载并删除 whtools 管理器吗？\n这将彻底清除：\n• 面板界面\n• 配置文件 (config.ini)\n• 安装的脚本文件\n\n卸载后需要时可再次拖入 MZP 重新安装。" title:"完全卸载" do (
                        destroyDialog RO_Manager_Config
                        try(destroyDialog WH_ScriptManager_Rollout)catch()
                        local iniFile = (getDir #userscripts) + "\\whtools_manager_config.ini"
                        try(deleteFile iniFile)catch()
                        local scriptFile = (getDir #userscripts) + "\\whtools\\whtools_manager.ms"
                        try(deleteFile scriptFile)catch()
                        try(deleteDir ((getDir #userscripts) + "\\whtools"))catch()
                        try(macros.unregister "whtool" "WH_Manager")catch()
                        local mcrDir = getDir #userMacros
                        local mcrFile1 = mcrDir + "\\whtool-WH_Manager.mcr"
                        local mcrFile2 = mcrDir + "\\whtool_WH_Manager.mcr"
                        try(deleteFile mcrFile1)catch()
                        try(deleteFile mcrFile2)catch()
                        local allMcr = getFiles (mcrDir + "\\whtool*.mcr")
                        for f in allMcr do try(deleteFile f)catch()
                        messageBox "✅ whtools 已完全卸载，一干二净！\n动作列表里的条目已删除。\n\n工具栏如果还有图标，关闭并重开【自定义用户界面】窗口即可刷新。" title:"卸载完成"
                    )
                )
            )
            createDialog RO_Manager_Config style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
        )
        
        global KGL_RenameBtn
        global KGL_RenameTag

        fn onMenuRename s e = (
            local btn = s.Tag
            KGL_RenameBtn = btn
            KGL_RenameTag = btn.Tag
            
            try(destroyDialog RO_ScriptManager_Rename)catch()
            rollout RO_ScriptManager_Rename "自定义名称" width:200 height:70 (
                edittext txt_name "" pos:[10,10] width:180
                button btn_ok "确定" pos:[30,40] width:60 height:22
                button btn_cancel "取消" pos:[110,40] width:60 height:22
                
                on btn_ok pressed do (
                    if txt_name.text != "" then (
                        setINISetting KGL_ManagerINI "Slots" ("Slot_"+(KGL_RenameTag as string)+"_Name") txt_name.text
                        KGL_RenameBtn.Text = txt_name.text
                    )
                    destroyDialog RO_ScriptManager_Rename
                )
                on btn_cancel pressed do destroyDialog RO_ScriptManager_Rename
            )
            createDialog RO_ScriptManager_Rename modal:true
            RO_ScriptManager_Rename.txt_name.text = KGL_RenameBtn.Text
        )

        fn onMenuDelete s e = (
            local btn = s.Tag
            local btnTag = btn.Tag
            if queryBox ("确定要清空格子的绑定吗？") title:"解绑确认" do (
                delINISetting KGL_ManagerINI "Slots" ("Slot_"+(btnTag as string)+"_Name")
                delINISetting KGL_ManagerINI "Slots" ("Slot_"+(btnTag as string)+"_Path")
                btn.Text = "空"
                btn.BackColor = KGL_clr_empty
            )
        )
        
        -- Drag & Drop 核心事件处理
        fn onBtnDragEnter s e = (
            if e.Data.GetDataPresent (dotNetClass "System.Windows.Forms.DataFormats").FileDrop then
                e.Effect = (dotNetClass "System.Windows.Forms.DragDropEffects").Copy
            else
                e.Effect = (dotNetClass "System.Windows.Forms.DragDropEffects").None
        )

        fn onBtnDragDrop s e = (
            local files = e.Data.GetData (dotNetClass "System.Windows.Forms.DataFormats").FileDrop
            if files != undefined and files.count > 0 do (
                local fPath = files[1]
                local ext = toLower (getFilenameType fPath)
                if ext == ".ms" or ext == ".mse" or ext == ".mcr" or ext == ".mzp" then (
                    local bName = getFilenameFile fPath
                    local btnTag = s.Tag
                    -- 持久化存储
                    setINISetting KGL_ManagerINI "Slots" ("Slot_"+(btnTag as string)+"_Name") bName
                    setINISetting KGL_ManagerINI "Slots" ("Slot_"+(btnTag as string)+"_Path") fPath
                    
                    s.Text = bName
                    s.BackColor = KGL_clr_filled
                ) else (
                    messagebox "不支持的文件类型！仅支持拖入 3ds Max 的脚本文件 (.ms, .mse, .mcp, .mzp)。"
                )
            )
        )

        fn onBtnMouseUp s e = (
            EndDrag s e -- 整合拖拽释放逻辑，避免重复绑定 MouseUp 事件
            
            local btnTag = s.Tag
            local path = getINISetting KGL_ManagerINI "Slots" ("Slot_"+(btnTag as string)+"_Path")
            
            if e.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left then (
                if path != "" and doesFileExist path then (
                    pendingScriptPath = path
                    tmr_run.active = true
                ) else if path != "" then (
                    messagebox "错误：原脚本文件不存在。\n可能已被移动或删除！"
                ) else (
                    -- 空格子支持点击弹出选择框
                    local pickedFile = getOpenFileName caption:"请选择要绑定到此格子的脚本" types:"3ds Max 脚本 (*.ms;*.mse;*.mcr;*.mzp)|*.ms;*.mse;*.mcr;*.mzp|All Files (*.*)|*.*"
                    if pickedFile != undefined do (
                        local bName = getFilenameFile pickedFile
                        setINISetting KGL_ManagerINI "Slots" ("Slot_"+(btnTag as string)+"_Name") bName
                        setINISetting KGL_ManagerINI "Slots" ("Slot_"+(btnTag as string)+"_Path") pickedFile
                        s.Text = bName
                        s.BackColor = KGL_clr_filled
                    )
                )
            ) else if e.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then (
                -- 右键弹出菜单
                if path != "" do (
                    local ctxMenu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
                    
                    local iRename = ctxMenu.Items.Add "自定义名称"
                    iRename.Tag = s
                    dotnet.addEventHandler iRename "Click" onMenuRename
                    
                    local iDel = ctxMenu.Items.Add "删除解绑"
                    iDel.Tag = s
                    dotnet.addEventHandler iDel "Click" onMenuDelete
                    
                    local pt = dotNetObject "System.Drawing.Point" e.X e.Y
                    ctxMenu.Show s pt
                )
            )
        )
        
        -- 生成网格的核心函数
        fn BuildGrid c r = (
            -- 基础尺寸设定
            local btnWidth = 85
            local btnHeight = 22
            local pad = 1 -- 极限单行边距 (横纵各加2)
            
            pnl_grid.SuspendLayout()
            
            -- ★ 关键修复：将 Controls 集合引用缓存到本地变量，
            -- 防止 MAXScript .NET 包装层每次访问 pnl_grid.Controls 时
            -- 重复向内部类型字典注册 ControlCollection 导致 "Key already added" 崩溃
            local gridControls = pnl_grid.Controls
            
            -- 安全释放旧控件：先收集到纯 MAXScript 数组，再一次性 Clear，最后逐个销毁
            local oldCount = gridControls.Count
            local ctls = for i = 0 to (oldCount - 1) collect gridControls.Item[i]
            gridControls.Clear()
            for ctl in ctls do (
                if ctl != undefined do (
                    dotnet.removeAllEventHandlers ctl
                    ctl.Dispose()
                )
            )
            GC_PreventArray = #()
            pnl_grid.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 68 68 68
            
            -- FlowLayoutPanel 设置，精确计算包含 Margin 的总长宽
            pnl_grid.Width = c * (btnWidth + pad * 2)
            pnl_grid.Height = r * (btnHeight + pad * 2)
            pnl_grid.WrapContents = true
            pnl_grid.Margin = dotNetObject "System.Windows.Forms.Padding" 0
            
            local totalSlots = c * r
            
            -- 创建纯 .NET 数组收集按钮
            local ctlArray = dotNetObject "System.Windows.Forms.Control[]" totalSlots
            
            for i = 1 to totalSlots do (
                local btn = dotNetObject "System.Windows.Forms.Button"
                btn.Width = btnWidth
                btn.Height = btnHeight
                btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                btn.FlatAppearance.BorderSize = 0
                btn.Margin = dotNetObject "System.Windows.Forms.Padding" pad
                btn.Font = dotNetObject "System.Drawing.Font" "微软雅黑" 8
                btn.ForeColor = KGL_clr_font
                btn.Cursor = (dotNetClass "System.Windows.Forms.Cursors").Hand
                btn.AllowDrop = true
                btn.Tag = i
                
                -- 读取历史配置
                local sName = getINISetting KGL_ManagerINI "Slots" ("Slot_"+(i as string)+"_Name")
                if sName != "" then (
                    btn.Text = sName
                    btn.BackColor = KGL_clr_filled
                ) else (
                    btn.Text = "空"
                    btn.BackColor = KGL_clr_empty
                )
                
                -- 绑定 .NET 事件
                dotnet.addEventHandler btn "MouseDown" StartDrag
                dotnet.addEventHandler btn "MouseMove" DoDrag
                
                dotnet.addEventHandler btn "DragEnter" onBtnDragEnter
                dotnet.addEventHandler btn "DragDrop" onBtnDragDrop
                dotnet.addEventHandler btn "MouseUp" onBtnMouseUp
                
                append GC_PreventArray btn
                ctlArray.SetValue btn (i - 1)
            )
            
            -- 通过已缓存的引用一次性推入，绝不再次访问 pnl_grid.Controls
            gridControls.AddRange ctlArray
            
            pnl_grid.ResumeLayout()
            
            WH_ScriptManager_Rollout.width = pnl_grid.Width + 34
            WH_ScriptManager_Rollout.height = pnl_grid.Height + 2
        )
        
        on WH_ScriptManager_Rollout open do (
            -- 初始化拖动手柄外观
            lbl_drag.Text = "||"
            try(lbl_drag.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter)catch()
            lbl_drag.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 50 50 50
            lbl_drag.ForeColor = (dotNetClass "System.Drawing.Color").Gray
            lbl_drag.Cursor = (dotNetClass "System.Windows.Forms.Cursors").SizeAll
            
            -- 读取行列保存数据，赋初始值
            local savedCols = getINISetting KGL_ManagerINI "Settings" "Cols"
            local savedRows = getINISetting KGL_ManagerINI "Settings" "Rows"
            
            local c = if savedCols != "" then savedCols as integer else 7
            local r = if savedRows != "" then savedRows as integer else 1
            
            -- 构建网格
            BuildGrid c r
        )
        
        -- rollout 级别事件绑定 (dotnetcontrol 必须用此语法)
        on lbl_drag MouseDown sender args do StartDrag sender args
        on lbl_drag MouseMove sender args do DoDrag sender args
        on lbl_drag MouseUp sender args do EndDrag sender args
        
        on pnl_grid MouseDown sender args do StartDrag sender args
        on pnl_grid MouseMove sender args do DoDrag sender args
        on pnl_grid MouseUp sender args do EndDrag sender args
    )
    
    local init_c = 7
    local init_r = 1
    local str_c = getINISetting KGL_ManagerINI "Settings" "Cols"
    local str_r = getINISetting KGL_ManagerINI "Settings" "Rows"
    if str_c != "" do init_c = str_c as integer
    if str_r != "" do init_r = str_r as integer
    
    local initialWidth = (init_c * 87) + 34
    local initialHeight = (init_r * 24) + 2
    
    -- 获取保存的坐标
    local str_x = getINISetting KGL_ManagerINI "Settings" "PosX"
    local str_y = getINISetting KGL_ManagerINI "Settings" "PosY"
    local init_pos = [-1, -1]
    
    if str_x != "" and str_y != "" then (
        init_pos = [str_x as integer, str_y as integer]
    ) else (
        -- 默认位置：屏幕中上部
        init_pos = [300, 100]
    )
    
    -- 完全无边框极简模式 style:#()
    createDialog WH_ScriptManager_Rollout width:initialWidth height:initialHeight pos:init_pos style:#()
)
