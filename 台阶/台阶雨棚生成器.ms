-- 台阶雨棚生成器 v1.0
(
    global StairCanopyGen_Rollout
    try(destroyDialog StairCanopyGen_Rollout)catch()
    
    rollout StairCanopyGen_Rollout "台阶雨棚生成器 v1.0" width:220 height:465 (
        groupBox grp1 "踏步尺寸 (单位: mm)" pos:[5,5] width:210 height:115
        spinner spn_width "宽度:" range:[1,10000,300] type:#float pos:[15,25] fieldWidth:50 tooltip:"踏步深度"
        spinner spn_height "高度:" range:[1,10000,150] type:#float pos:[115,25] fieldWidth:50 tooltip:"踏步总高含盖板"
        spinner spn_guard "护边:" range:[1,5000,100] type:#float pos:[15,50] fieldWidth:50 tooltip:"护边宽度"
        spinner spn_cap "盖板:" range:[0,500,15] type:#float pos:[115,50] fieldWidth:50 tooltip:"盖板厚度及突出"
        spinner spn_plat "平台:" range:[10,50000,1000] type:#float pos:[15,75] fieldWidth:50 tooltip:"最顶级台阶深度"
        label lbl_platW "基线长: (选线后显示)" pos:[15,98]
        
        groupBox grp2 "踏步数量" pos:[5,125] width:210 height:42
        spinner spn_count "数量:" range:[1,200,5] type:#integer pos:[15,145] fieldWidth:50
        
        groupBox grp3 "台阶类型" pos:[5,172] width:210 height:42
        radioButtons rdo_type labels:#("单向有护边", "三向无护边") default:1 pos:[15,190] columns:2
        
        groupBox grp4 "对齐位置 (基准线相对深度)" pos:[5,219] width:210 height:42
        radioButtons rdo_align labels:#("后(靠墙)", "中", "前") default:1 pos:[15,237] columns:3
        
        button btn_pick "选择路径线" pos:[5,272] width:105 height:30
        button btn_create "创建踏步" pos:[115,272] width:100 height:30
        
        button btn_canopy_only "单独创建雨棚" pos:[5,307] width:210 height:30 tooltip:"在选定路径线上只生成雨棚与中央楼板"
        
        button btn_reverse "反转方向" pos:[5,342] width:105 height:25
        button btn_clear "清除当前" pos:[115,342] width:100 height:25
        
        checkbox chk_canopy "创建踏步时同时生成雨棚" pos:[15,375] checked:false
        checkbox chk_mirror "镜像雨棚开口方向" pos:[15,395] checked:false
        
        label lbl_status "状态: 待命" pos:[5,420] width:210 height:40
        
        local pickedSpline = undefined
        local lastCreated = #()
        local lastCanopyCreated = #()
        local isReversed = false
        
        local iniFile = (getDir #temp) + "\\台阶雨棚生成器_settings.ini"
        
        fn saveSettings = (
            setINISetting iniFile "Settings" "Width" (spn_width.value as string)
            setINISetting iniFile "Settings" "Height" (spn_height.value as string)
            setINISetting iniFile "Settings" "Guard" (spn_guard.value as string)
            setINISetting iniFile "Settings" "Cap" (spn_cap.value as string)
            setINISetting iniFile "Settings" "Plat" (spn_plat.value as string)
            setINISetting iniFile "Settings" "Count" (spn_count.value as string)
            setINISetting iniFile "Settings" "Type" (rdo_type.state as string)
            setINISetting iniFile "Settings" "Align" (rdo_align.state as string)
            setINISetting iniFile "Settings" "Canopy" (if chk_canopy.checked then "1" else "0")
            setINISetting iniFile "Settings" "Mirror" (if chk_mirror.checked then "1" else "0")
        )
        
        fn loadSettings = (
            if doesFileExist iniFile do (
                local val = getINISetting iniFile "Settings" "Width"
                if val != "" do spn_width.value = val as float
                
                val = getINISetting iniFile "Settings" "Height"
                if val != "" do spn_height.value = val as float
                
                val = getINISetting iniFile "Settings" "Guard"
                if val != "" do spn_guard.value = val as float
                
                val = getINISetting iniFile "Settings" "Cap"
                if val != "" do spn_cap.value = val as float
                
                val = getINISetting iniFile "Settings" "Plat"
                if val != "" do spn_plat.value = val as float
                
                val = getINISetting iniFile "Settings" "Count"
                if val != "" do spn_count.value = val as integer
                
                val = getINISetting iniFile "Settings" "Type"
                if val != "" do rdo_type.state = val as integer
                
                val = getINISetting iniFile "Settings" "Align"
                if val != "" do rdo_align.state = val as integer
                
                val = getINISetting iniFile "Settings" "Canopy"
                if val != "" do chk_canopy.checked = (val == "1")
                
                val = getINISetting iniFile "Settings" "Mirror"
                if val != "" do chk_mirror.checked = (val == "1")
            )
        )
        
        -- 模块化雨棚子生成函数
        fn buildCanopySub toSys = (
            if pickedSpline == undefined or not isValidNode pickedSpline do return()
            
            -- 1. 创建雨棚截面 Profile (2D Spline)
            local profile = SplineShape name:"雨棚截面_Profile"
            addNewSpline profile
            
            -- X_factor 决定截面水平镜像方向。
            -- 默认情况下，使用 X_factor = -1.0。若勾选“镜像”，则使用 X_factor = 1.0。
            -- 这样使得即便在 Shape Pivot 模式下，也能极其灵敏地瞬间镜像！且槽底 X=0 绝无偏移变化！
            local X_factor = if chk_mirror.checked then 1.0 else -1.0
            
            addKnot profile 1 #corner #line ([-80.0 * X_factor, 0, 0] * toSys)
            addKnot profile 1 #corner #line ([120.0 * X_factor, 0, 0] * toSys)
            addKnot profile 1 #corner #line ([120.0 * X_factor, 360, 0] * toSys)
            addKnot profile 1 #corner #line ([-80.0 * X_factor, 360, 0] * toSys)
            addKnot profile 1 #corner #line ([-80.0 * X_factor, 280, 0] * toSys)
            addKnot profile 1 #corner #line ([0.0, 280, 0] * toSys)
            addKnot profile 1 #corner #line ([0.0, 80, 0] * toSys)
            addKnot profile 1 #corner #line ([-80.0 * X_factor, 80, 0] * toSys)
            close profile 1
            updateShape profile
            profile.visibility = false
            profile.renderable = false
            
            -- 2. 确定放样路径与闭合路径
            local isStraightPath = false
            if numSplines pickedSpline == 1 and not isClosed pickedSpline 1 do (
                if numKnots pickedSpline 1 == 2 do isStraightPath = true
            )
            
            local canopyPath = undefined
            local closedPath = undefined
            
            if isStraightPath then (
                -- 2a. 若为直线，智能且高精度地在数学上构建出与顶级平台对齐的 U 形雨棚放样路径：
                local p0 = pathInterp pickedSpline 1 0.0
                local p1 = pathInterp pickedSpline 1 1.0
                local lineDir = normalize ([p1.x-p0.x, p1.y-p0.y, 0])
                local platW = distance [p0.x,p0.y,0] [p1.x,p1.y,0]
                local fwd = normalize (cross lineDir [0,0,1])
                if isReversed do fwd = -fwd
                
                local totalDepth = (spn_count.value - 1) * (spn_width.value * toSys) + (spn_plat.value * toSys)
                local platDepth = spn_plat.value * toSys
                
                local alignOff = case rdo_align.state of (
                    1: [0,0,0]
                    2: fwd * totalDepth * (-0.5)
                    3: fwd * totalDepth * (-1.0)
                )
                local basePos = p0 + alignOff
                
                -- 四点 U 形：后左 -> 前左 -> 前右 -> 后右，严丝合缝包裹顶级平台三面
                local pt1 = basePos
                local pt2 = basePos + fwd * platDepth
                local pt3 = basePos + fwd * platDepth + lineDir * platW
                local pt4 = basePos + lineDir * platW
                
                canopyPath = SplineShape name:(pickedSpline.name + "_雨棚外框")
                addNewSpline canopyPath
                addKnot canopyPath 1 #corner #line pt1
                addKnot canopyPath 1 #corner #line pt2
                addKnot canopyPath 1 #corner #line pt3
                addKnot canopyPath 1 #corner #line pt4
                updateShape canopyPath
                
                -- 楼板路径为该 U 形路径直接闭合
                closedPath = copy canopyPath
                closedPath.name = pickedSpline.name + "_雨棚楼板"
                if not isClosed closedPath 1 do (
                    close closedPath 1
                    updateShape closedPath
                )
            ) else (
                -- 2b. 若原本就是 U 形折线，则直接采用原折线路径生成
                canopyPath = copy pickedSpline
                canopyPath.name = pickedSpline.name + "_雨棚外框"
                if isReversed do (
                    reverse canopyPath 1
                    updateShape canopyPath
                )
                
                closedPath = copy pickedSpline
                closedPath.name = pickedSpline.name + "_雨棚楼板"
                if isReversed do (
                    reverse closedPath 1
                    updateShape closedPath
                )
                if numSplines closedPath > 0 do (
                    if not isClosed closedPath 1 do (
                        close closedPath 1
                        updateShape closedPath
                    )
                )
            )
            
            -- 3. 添加 Sweep 修改器并配置自定义截面
            CenterPivot canopyPath -- 在添加修改器前，确保轴心位于模型几何中心！
            local sw = Sweep()
            addModifier canopyPath sw
            sw.customShape = 1
            sw.shapes[1] = profile
            
            -- 采用 Bottom-Left 精确对齐，关闭 Banking
            sw.PivotAlignment = 2 
            sw.Banking = false
            sw.MirrorXYPlane = false
            sw.MirrorXZPlane = false
            
            -- 去掉横向/纵向偏移，保持数值为 0.0
            sw.xOffset = 0.0
            sw.yOffset = 0.0
            
            -- 4. 为闭合楼板添加 Extrude 修改器
            CenterPivot closedPath -- 在添加修改器前，确保轴心位于模型几何中心！
            local ext = Extrude amount:(100.0 * toSys)
            addModifier closedPath ext
            
            -- 将楼板向上移动 80mm，避开底缘厚度，完美卡入凹槽内部
            move closedPath [0, 0, 80.0 * toSys]
            
            -- 保持修改器参数化，不塌陷为多边形！将临时截面隐藏在场景中作为依赖
            profile.isHidden = true
            
            -- 计算台阶顶部的 3 倍台阶总高度偏移（无论是否伴随台阶一起生成，均在此高度生成，确保高度一致，防重叠）
            local zOffset = 3.0 * (spn_count.value * spn_height.value) * toSys
            if zOffset > 0.0 do (
                move canopyPath [0, 0, zOffset]
                move closedPath [0, 0, zOffset]
            )
            
            -- 将截面也存入创建列表，以便重建时能被一并自动删除，绝不留残留！
            lastCanopyCreated = #(canopyPath, closedPath, profile)
        )
        
        -- 高速创建台阶函数
        fn buildStairs = (
            if pickedSpline == undefined or not isValidNode pickedSpline do return undefined
            
            -- 性能优化：禁用重绘，切出修改面板
            disableSceneRedraw()
            local oldPanel = getCommandPanelTaskMode()
            setCommandPanelTaskMode #create
            
            try (
                undo "创建台阶" on (
                    -- 删除旧的记录（脱离旧线）
                    for obj in lastCreated do (if isValidNode obj do delete obj)
                    lastCreated = #()
                    
                    -- 删除旧的雨棚记录
                    for obj in lastCanopyCreated do (if isValidNode obj do delete obj)
                    lastCanopyCreated = #()
                    
                    local p0 = pathInterp pickedSpline 1 0.0
                    local p1 = pathInterp pickedSpline 1 1.0
                    local lineDir = normalize ([p1.x-p0.x, p1.y-p0.y, 0])
                    local platW = distance [p0.x,p0.y,0] [p1.x,p1.y,0]
                    local fwd = normalize (cross lineDir [0,0,1])
                    if isReversed do fwd = -fwd
                    
                    local toSys = units.decodeValue "1mm"
                    local stepW = spn_width.value * toSys
                    local stepH = spn_height.value * toSys
                    local capOH = spn_cap.value * toSys
                    local capThick = capOH
                    local bodyH = stepH - capThick
                    local guardW = spn_guard.value * toSys
                    local platDepth = spn_plat.value * toSys
                    local guardUp = 50.0 * toSys   
                    local nSteps = spn_count.value
                    local stepType = rdo_type.state
                    
                    local totalDepth = (nSteps - 1) * stepW + platDepth
                    local totalHeight = nSteps * stepH
                    
                    local alignOff = case rdo_align.state of (
                        1: [0,0,0]
                        2: fwd * totalDepth * (-0.5)
                        3: fwd * totalDepth * (-1.0)
                    )
                    local basePos = p0 + alignOff
                    local boxZ = cross lineDir fwd
                    
                    local allObjs = #()
                    
                    if stepType == 1 then (
                        -- ================== A: 单向 ==================
                        local tmA = matrix3 fwd [0,0,1] (cross fwd [0,0,1]) basePos
                        local extAmt = (dot (cross fwd [0,0,1]) lineDir) * platW
                        
                        local ss = SplineShape()
                        addNewSpline ss
                        addKnot ss 1 #corner #line [0, 0, 0]
                        for i = nSteps to 1 by -1 do (
                            local x0 = if i == nSteps then 0 else (platDepth + (nSteps - 1 - i) * stepW)
                            local x1 = x0 + (if i == nSteps then platDepth else stepW)
                            local yB = (i-1) * stepH + bodyH
                            addKnot ss 1 #corner #line [x0, yB, 0]; addKnot ss 1 #corner #line [x1, yB, 0]
                        )
                        addKnot ss 1 #corner #line [totalDepth, 0, 0]
                        close ss 1; updateShape ss
                        addModifier ss (Extrude amount:extAmt)
                        ss.transform = tmA; convertToMesh ss; append allObjs ss
                        
                        for i = nSteps to 1 by -1 do (
                            local x0 = if i == nSteps then 0 else (platDepth + (nSteps - 1 - i) * stepW)
                            local x1 = x0 + (if i == nSteps then platDepth else stepW)
                            local capLen = (x1-x0) + capOH
                            local capBox = Box length:capLen width:platW wireColor:(color 120 200 180)
                            capBox.transform = matrix3 lineDir fwd boxZ (basePos + fwd*(x0 + capLen*0.5) + lineDir*(platW*0.5) + [0,0,1]*((i-1)*stepH + bodyH))
                            capBox.height = if boxZ.z > 0 then capThick else -capThick
                            convertToMesh capBox; append allObjs capBox
                        )
                        for side = 1 to 2 do (
                            local gs = SplineShape()
                            addNewSpline gs
                            addKnot gs 1 #corner #line [-guardUp, 0, 0]
                            addKnot gs 1 #corner #line [-guardUp, nSteps*stepH + guardUp, 0]
                            addKnot gs 1 #corner #line [platDepth, nSteps*stepH + guardUp, 0]
                            addKnot gs 1 #corner #line [totalDepth + guardUp, stepH + guardUp, 0]
                            addKnot gs 1 #corner #line [totalDepth + guardUp, 0, 0]
                            close gs 1; updateShape gs
                            local sPos = basePos + (if side == 1 then lineDir*platW else lineDir*(-guardW))
                            addModifier gs (Extrude amount:(dot (cross fwd [0,0,1]) (lineDir*guardW)))
                            gs.transform = matrix3 fwd [0,0,1] (cross fwd [0,0,1]) sPos
                            convertToMesh gs; append allObjs gs
                        )
                    ) else (
                        -- ================== B: 三向 ==================
                        for i = 1 to nSteps do (
                            local curH = i * stepH - capThick
                            local curW = platW + 2 * (nSteps - i) * stepW
                            local curL = platDepth + (nSteps - i) * stepW
                            local bx = Box length:curL width:curW wireColor:(color 120 200 180)
                            bx.transform = matrix3 lineDir fwd boxZ (basePos + lineDir*(platW*0.5) + fwd*(curL*0.5))
                            bx.height = if boxZ.z > 0 then curH else -curH
                            convertToMesh bx; append allObjs bx
                            
                            local cl = curL + capOH; local cw = curW + 2 * capOH
                            local cb = Box length:cl width:cw wireColor:(color 120 200 180)
                            cb.transform = matrix3 lineDir fwd boxZ (basePos + lineDir*(platW*0.5) + fwd*(cl*0.5) + [0,0,1]*curH)
                            cb.height = if boxZ.z > 0 then capThick else -capThick
                            convertToMesh cb; append allObjs cb
                        )
                    )
                    
                    -- 高速合并 (批量 Attach)
                    if allObjs.count > 1 then (
                        local main = allObjs[1]
                        for i = 2 to allObjs.count do meshop.attach main allObjs[i]
                        lastCreated = #(main)
                    ) else (lastCreated = allObjs)
                    
                    -- 将生成的台阶模型轴心也完美归中到模型几何中心！
                    for obj in lastCreated do (
                        if isValidNode obj do CenterPivot obj
                    )
                    
                    -- 检查是否开启“同时生成雨棚与中央楼板”
                    if chk_canopy.checked do (
                        buildCanopySub toSys
                    )
                    
                    local toSelect = #()
                    join toSelect lastCreated
                    join toSelect lastCanopyCreated
                    select toSelect
                )
            ) catch (
                format "Error: %\n" (getCurrentException())
            )
            
            setCommandPanelTaskMode oldPanel
            enableSceneRedraw()
            completeRedraw()
            local statusMsg = "✅ 生成完毕 (" + (nSteps as string) + "级)"
            if chk_canopy.checked do statusMsg += " + 雨棚"
            lbl_status.text = statusMsg
        )
        
        -- 单独生成雨棚入口函数
        fn buildCanopyOnly = (
            if pickedSpline == undefined or not isValidNode pickedSpline do (
                lbl_status.text = "⚠️ 请选择路径线！"
                return undefined
            )
            
            disableSceneRedraw()
            local oldPanel = getCommandPanelTaskMode()
            setCommandPanelTaskMode #create
            
            try (
                undo "单独创建雨棚" on (
                    -- 清除旧的雨棚记录
                    for obj in lastCanopyCreated do (if isValidNode obj do delete obj)
                    lastCanopyCreated = #()
                    
                    local toSys = units.decodeValue "1mm"
                    buildCanopySub toSys
                    select lastCanopyCreated
                )
            ) catch (
                format "Error: %\n" (getCurrentException())
            )
            
            setCommandPanelTaskMode oldPanel
            enableSceneRedraw()
            completeRedraw()
            lbl_status.text = "✅ 雨棚与楼板创建完毕"
        )
        
        fn autoRebuild = (
            if pickedSpline != undefined and isValidNode pickedSpline do (
                if lastCreated.count > 0 then (
                    buildStairs()
                ) else if lastCanopyCreated.count > 0 do (
                    buildCanopyOnly()
                )
            )
            saveSettings()
        )
        
        on StairCanopyGen_Rollout open do (
            loadSettings()
        )
        
        on StairCanopyGen_Rollout close do (
            saveSettings()
        )
        
        on spn_width changed v do autoRebuild(); on spn_height changed v do autoRebuild()
        on spn_guard changed v do autoRebuild(); on spn_cap changed v do autoRebuild()
        on spn_plat changed v do autoRebuild(); on spn_count changed v do autoRebuild()
        on rdo_type changed v do autoRebuild(); on rdo_align changed v do autoRebuild()
        on chk_canopy changed state do autoRebuild()
        on chk_mirror changed state do autoRebuild()
        
        on btn_pick pressed do (
            local obj = pickObject message:"点选线" filter:(fn f o = superClassOf o == Shape)
            if obj != undefined then (
                pickedSpline = obj; lastCreated = #(); lastCanopyCreated = #(); btn_create.enabled = true
                lbl_platW.text = "基线长: " + (formattedPrint ((curveLength pickedSpline 1)/(units.decodeValue "1mm")) format:".1f") + " mm"
            )
        )
        
        on btn_create pressed do (
            local sel = selection as array
            if sel.count == 1 and superClassOf sel[1] == Shape do (pickedSpline = sel[1]; lastCreated = #(); lastCanopyCreated = #())
            buildStairs()
        )
        
        on btn_canopy_only pressed do (
            local sel = selection as array
            if sel.count == 1 and superClassOf sel[1] == Shape do (pickedSpline = sel[1]; lastCanopyCreated = #())
            buildCanopyOnly()
        )
        
        on btn_reverse pressed do (isReversed = not isReversed; buildStairs())
        
        on btn_clear pressed do (
            undo "清除" on (
                for o in lastCreated do (if isValidNode o do delete o)
                for o in lastCanopyCreated do (if isValidNode o do delete o)
            )
            lastCreated = #()
            lastCanopyCreated = #()
            lbl_status.text = "已清除"
        )
    )
    createDialog StairCanopyGen_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)
