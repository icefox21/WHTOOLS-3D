-- 隔离独立空间工具 (免安装便携版)
-- 完美支持脱离启动文件夹单独运行，整合了最底层核心逻辑架构
(
    global customIsolateMgr
    global rCustomIsolate
    
    struct CustomIsolateManager (
        stack = #(),
        fn isAncestorOfSelection node selArray = (
            local found = false
            for s in selArray do (
                if isValidNode s do (
                    local p = s.parent
                    while p != undefined do (
                        if p == node do ( found = true; exit )
                        p = p.parent
                    )
                )
                if found do exit
            )
            found
        ),
        fn saveToScene = (
            local str = with printAllElements true (stack as string)
            if rootNode != undefined do setAppData rootNode 45678 str
        ),
        fn loadFromScene = (
            if rootNode != undefined do (
                local str = getAppData rootNode 45678
                if str != undefined and str != "" then (
                    try ( stack = execute str ) catch ( stack = #() )
                ) else ( stack = #() )
            )
        ),
        fn popLevel = (
            if stack.count == 0 do return false
            local nodes_list = stack[stack.count]
            if IsolateSelection != undefined and isProperty IsolateSelection "ExitIsolateSelectionMode" do (
                try ( IsolateSelection.ExitIsolateSelectionMode() ) catch()
            )
            for item in nodes_list do (
                local h = item[1]
                local origName = item[2]
                local n = maxOps.getNodeByHandle h
                if n != undefined and not (isDeleted n) do (
                    local origLayer = LayerManager.getLayerFromName origName
                    if origLayer != undefined do origLayer.addNode n
                )
            )
            with redraw off (
                for item in nodes_list do (
                    local n = maxOps.getNodeByHandle item[1]
                    if n != undefined and not (isDeleted n) do n.isHidden = true
                )
                for item in nodes_list do (
                    local n = maxOps.getNodeByHandle item[1]
                    if n != undefined and not (isDeleted n) do n.isHidden = false
                )
            )
            deleteItem stack stack.count
            saveToScene()
            forceCompleteRedraw()
            true
        )
    )

    if customIsolateMgr == undefined do customIsolateMgr = CustomIsolateManager()
    customIsolateMgr.loadFromScene()

    try ( destroyDialog rCustomIsolate ) catch()

    rollout rCustomIsolate "Isolate Space Tool" width:180 height:275 (
        group "隔离空间 (多层)" (
            button btn_isolate   "隔离选择" width:160 height:40 tooltip:"隔离选中物体，防 Unhide All"
            button btn_endIsolate "取消隔离" width:160 height:40 tooltip:"回退一层隔离空间"
            label lbl_info "当前隔离层: 0" align:#center
        )
        
        group "视图孤立 (Alt+Q)" (
            button btn_nativeIso "孤立选择" width:160 height:30 tooltip:"执行 3ds Max 原生孤立 (Alt+Q)"
            button btn_hfiUnhide "取消隔离" width:160 height:30 tooltip:"执行 HFI 安全显示所有 (不打断隔离空间)"
        )

        fn updateInfo = (
            if customIsolateMgr != undefined do
                lbl_info.text = "当前隔离层: " + (customIsolateMgr.stack.count as string)
        )

        on btn_isolate pressed do (
            local sel = selection as array
            if sel.count == 0 do (
                messageBox "请先选择需要隔离的物体。" title:"提示"
                return false
            )

            local toHide = #()
            for o in objects do (
                if isValidNode o and not o.isHidden and findItem sel o == 0 do (
                    if not (customIsolateMgr.isAncestorOfSelection o sel) do
                        append toHide o
                )
            )

            if toHide.count > 0 then (
                local tempLayer = LayerManager.getLayerFromName "_隔离临时层_"
                if tempLayer == undefined do tempLayer = LayerManager.newLayerFromName "_隔离临时层_"
                tempLayer.on = false

                local nodes_lvl = #()
                with redraw off (
                    for o in toHide do (
                        if o.layer != undefined do (
                            append nodes_lvl #(o.inode.handle, o.layer.name)
                            tempLayer.addNode o
                            o.isHidden = true 
                        )
                    )
                )

                append customIsolateMgr.stack nodes_lvl 
                updateInfo()
                if customIsolateMgr != undefined do customIsolateMgr.saveToScene()
                forceCompleteRedraw()
            ) else (
                messageBox "没有多余可见物体可供隔离。" title:"提示"
            )
        )

        on btn_endIsolate pressed do (
            if customIsolateMgr != undefined and customIsolateMgr.stack.count > 0 then (
                customIsolateMgr.popLevel()
                updateInfo()
            ) else (
                messageBox "当前没有处于隔离状态的空间。" title:"提示"
            )
        )
        
        on btn_hfiUnhide pressed do (
            undo "WH_SafeUnhide" on (
                local isoLayer = LayerManager.getLayerFromName "_隔离临时层_"
                if isoLayer != undefined do isoLayer.on = false
                
                for o in objects where (o.isHidden and (o.layer == undefined or o.layer.name != "_隔离临时层_")) do o.isHidden = false
                forceCompleteRedraw()
            )
        )
        
        on btn_nativeIso pressed do (
            if IsolateSelection != undefined then (
                try ( IsolateSelection.EnterIsolateSelectionMode() ) catch ( actionMan.executeAction 0 40194 )
            ) else (
                actionMan.executeAction 0 40194
            )
        )

        on rCustomIsolate open do (
            rCustomIsolate.title = "隔离空间工具"
            if customIsolateMgr != undefined do customIsolateMgr.loadFromScene()
            updateInfo()
        )
    )
        
    createDialog rCustomIsolate style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)
)
