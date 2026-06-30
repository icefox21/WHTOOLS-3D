-- 台阶生成器 v1.7
(
    global StairGen_Rollout
    try(destroyDialog StairGen_Rollout)catch()
    
    rollout StairGen_Rollout "台阶生成器 v1.7" width:220 height:390 (
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
        button btn_reverse "反转方向" pos:[5,307] width:105 height:25
        button btn_clear "清除当前" pos:[115,307] width:100 height:25
        label lbl_status "状态: 待命" pos:[5,340] width:210 height:40
        
        local pickedSpline = undefined
        local lastCreated = #()
        local isReversed = false
        
        -- 高速创建函数
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
                    select lastCreated
                )
            ) catch (
                format "Error: %\n" (getCurrentException())
            )
            
            setCommandPanelTaskMode oldPanel
            enableSceneRedraw()
            completeRedraw()
            lbl_status.text = "✅ 生成完毕 (" + (nSteps as string) + "级)"
        )
        
        fn autoRebuild = (if pickedSpline != undefined and isValidNode pickedSpline and lastCreated.count > 0 do buildStairs())
        on spn_width changed v do autoRebuild(); on spn_height changed v do autoRebuild()
        on spn_guard changed v do autoRebuild(); on spn_cap changed v do autoRebuild()
        on spn_plat changed v do autoRebuild(); on spn_count changed v do autoRebuild()
        on rdo_type changed v do autoRebuild(); on rdo_align changed v do autoRebuild()
        
        on btn_pick pressed do (
            local obj = pickObject message:"点选线" filter:(fn f o = superClassOf o == Shape)
            if obj != undefined then (
                pickedSpline = obj; lastCreated = #(); btn_create.enabled = true
                lbl_platW.text = "基线长: " + (formattedPrint ((curveLength pickedSpline 1)/(units.decodeValue "1mm")) format:".1f") + " mm"
            )
        )
        on btn_create pressed do (
            local sel = selection as array
            if sel.count == 1 and superClassOf sel[1] == Shape do (pickedSpline = sel[1]; lastCreated = #())
            buildStairs()
        )
        on btn_reverse pressed do (isReversed = not isReversed; buildStairs())
        on btn_clear pressed do (undo "清除" on (for o in lastCreated do (if isValidNode o do delete o)); lastCreated = #(); lbl_status.text = "已清除")
    )
    createDialog StairGen_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)
