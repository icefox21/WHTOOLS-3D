rollout splConnectDialog "线条平分连接" width:190 height:170 (
    spinner spnNum "分段数/板数:" range:[1,100,2] type:#integer pos:[15, 15] width:150
    checkbox chkThick "生成实体板(双连线)" checked:true pos:[15, 45]
    spinner spnThick "板厚参数:" range:[0.001, 10000, 1000.0] type:#float pos:[15, 70] width:150
    checkbox chkEnds "包含首尾两端" checked:false pos:[15, 100]
    button btnConnect "连 接" width:155 height:35 pos:[15, 125]
    
    local iniFile = getDir #plugcfg + "\\SplineConnect_Settings.ini"
    
    fn saveSettings = (
        try (
            setINISetting iniFile "Settings" "Segments" (spnNum.value as string)
            setINISetting iniFile "Settings" "ThickEnabled" (if chkThick.checked then "true" else "false")
            setINISetting iniFile "Settings" "Thickness" (spnThick.value as string)
            setINISetting iniFile "Settings" "Ends" (if chkEnds.checked then "true" else "false")
        ) catch()
    )
    
    fn loadSettings = (
        try (
            if doesFileExist iniFile do (
                local v = getINISetting iniFile "Settings" "Segments"
                if v != "" do spnNum.value = v as integer
                
                v = getINISetting iniFile "Settings" "ThickEnabled"
                if v != "" do (
                    chkThick.checked = (v == "true")
                )
                
                v = getINISetting iniFile "Settings" "Thickness"
                if v != "" do spnThick.value = v as float
                
                v = getINISetting iniFile "Settings" "Ends"
                if v != "" do chkEnds.checked = (v == "true")
            )
        ) catch()
    )

    on chkThick changed state do spnThick.enabled = state
    on splConnectDialog open do (
        loadSettings()
        spnThick.enabled = chkThick.checked
    )
    on splConnectDialog close do saveSettings()
    
    on btnConnect pressed do (
        undo "线条平分连接" on (
            if selection.count != 1 do (
                messagebox "请选择一个且仅选择一个样条线(Spline)对象！" title:"提示"
                return ()
            )
            
            local shp = selection[1]
            if superclassof shp != shape do (
                messagebox "所选对象不是形状(Shape)类型！" title:"提示"
                return ()
            )
            
            local targetMod = undefined
            local mObj = modPanel.getCurrentObject()
            if mObj != undefined and classof mObj == Edit_Spline do (
                targetMod = mObj
            )
            
            local selSegs = #()
            local selSpls = #()
            
            local ns = 0
            if targetMod != undefined then try(ns = numSplines targetMod)catch()
            else try(ns = numSplines shp)catch()
            
            if targetMod != undefined then try(selSpls = (getSplineSelection targetMod) as array)catch()
            else try(selSpls = (getSplineSelection shp) as array)catch()
            
            if ns > 0 do (
                for s = 1 to ns do (
                    local segSel = #()
                    if targetMod != undefined then try(segSel = (getSegSelection targetMod s) as array)catch()
                    else try(segSel = (getSegSelection shp s) as array)catch()
                    for seg in segSel do append selSegs #(s, seg)
                )
            )
            
            local soLevel = 0
            try(soLevel = subObjectLevel)catch()
            
            local useType = 0
            if soLevel == 3 and selSpls.count == 2 then useType = 2
            else if soLevel == 2 and selSegs.count == 2 then useType = 1
            else if selSegs.count == 2 then useType = 1
            else if selSpls.count == 2 then useType = 2
            
            if useType == 0 do (
                messagebox ("请明确选择刚好 2 条“线段(Segment)”或 2 条“样条线(Spline)”！\n\n当前选中段数: " + selSegs.count as string + "\n当前选中样条线数: " + (if selSpls != undefined then selSpls.count else 0) as string) title:"提示"
                return ()
            )
            
            local num = spnNum.value
            local incEnds = chkEnds.checked
            local chkThk = chkThick.checked
            local thkVal = spnThick.value
            
            convertToSplineShape shp
            
            fn getSegLength sRef sp sg = (
                local len = 0.0
                local steps = 20
                local pPrev = interpBezier3D sRef sp sg 0.0
                for i = 1 to steps do (
                    local pNext = interpBezier3D sRef sp sg (i as float / steps)
                    len += distance pPrev pNext
                    pPrev = pNext
                )
                return len
            )
            
            fn calcUValues L nBoards T incE chkT = (
                local list = #()
                local TotalT = nBoards * T
                if chkT then (
                    if TotalT >= L do (
                        TotalT = L * 0.99
                        T = TotalT / nBoards
                    )
                    local S = 0.0
                    if incE then (
                        if nBoards == 1 then (
                            append list (((L - T)/2.0) / L)
                            append list (((L + T)/2.0) / L)
                        ) else (
                            S = (L - TotalT) / (nBoards - 1)
                            for i = 1 to nBoards do (
                                append list (((i - 1) * S + (i - 1) * T) / L)
                                append list (((i - 1) * S + i * T) / L)
                            )
                        )
                    ) else (
                        S = (L - TotalT) / (nBoards + 1)
                        for i = 1 to nBoards do (
                            append list ((i * S + (i - 1) * T) / L)
                            append list ((i * S + i * T) / L)
                        )
                    )
                ) else (
                    if incE then (
                        if nBoards == 1 then (
                            append list 0.5
                        ) else (
                            for i = 1 to nBoards do append list ((i - 1) as float / (nBoards - 1))
                        )
                    ) else (
                        for i = 1 to nBoards do append list (i as float / (nBoards + 1))
                    )
                )
                return list
            )
            
            fn refineSegmentWithUValues shapeRef spl seg u_list = (
                local valid_u = #()
                for u in u_list do (
                    if u > 0.0001 and u < 0.9999 do append valid_u u
                )
                sort valid_u
                local unique_u = #()
                if valid_u.count > 0 do (
                    append unique_u valid_u[1]
                    for i = 2 to valid_u.count do (
                        if abs(valid_u[i] - valid_u[i-1]) > 0.0001 do append unique_u valid_u[i]
                    )
                )
                local backward_u = #()
                if unique_u.count > 0 do (
                    for i = unique_u.count to 1 by -1 do (
                        if i == unique_u.count then append backward_u unique_u[i]
                        else append backward_u (unique_u[i] / unique_u[i+1])
                    )
                )
                for rel_u in backward_u do refineSegment shapeRef spl seg rel_u
            )
            
            local connectLines = #()
            
            if useType == 1 then (
                local splA = selSegs[1][1]; local segA = selSegs[1][2]
                local splB = selSegs[2][1]; local segB = selSegs[2][2]
                
                local L_A = getSegLength shp splA segA
                local L_B = getSegLength shp splB segB
                
                local uA_list = calcUValues L_A num thkVal incEnds chkThk
                local uB_list = calcUValues L_B num thkVal incEnds chkThk
                
                local ptsA = #()
                for u in uA_list do append ptsA (interpBezier3D shp splA segA u)
                local ptsB = #()
                for u in uB_list do append ptsB (interpBezier3D shp splB segB u)
                
                local d1 = distance ptsA[1] ptsB[1] + distance ptsA[ptsA.count] ptsB[ptsB.count]
                local d2 = distance ptsA[1] ptsB[ptsB.count] + distance ptsA[ptsA.count] ptsB[1]
                local flipB = d2 < d1
                if flipB do (
                    local revPtsB = #()
                    for i = ptsB.count to 1 by -1 do append revPtsB ptsB[i]
                    ptsB = revPtsB
                )
                
                local actions = #()
                append actions #(splA, segA, uA_list)
                append actions #(splB, segB, uB_list)
                
                -- 判断哪一个分段更靠后，靠后的优先级高（反向打断不会改变靠前线段的索引）
                if actions[1][1] < actions[2][1] or (actions[1][1] == actions[2][1] and actions[1][2] < actions[2][2]) do (
                    local tmp = actions[1]
                    actions[1] = actions[2]
                    actions[2] = tmp
                )
                
                for act in actions do refineSegmentWithUValues shp act[1] act[2] act[3]
                
                for i = 1 to ptsA.count do append connectLines #(ptsA[i], ptsB[i])
            ) else (
                local splA = selSpls[1]; local splB = selSpls[2]
                local L_A = curveLength shp splA
                local L_B = curveLength shp splB
                
                local uA_list = calcUValues L_A num thkVal incEnds chkThk
                local uB_list = calcUValues L_B num thkVal incEnds chkThk
                
                local ptsA = #()
                for u in uA_list do append ptsA (interpCurve3D shp splA u)
                local ptsB = #()
                for u in uB_list do append ptsB (interpCurve3D shp splB u)
                
                local d1 = distance ptsA[1] ptsB[1] + distance ptsA[ptsA.count] ptsB[ptsB.count]
                local d2 = distance ptsA[1] ptsB[ptsB.count] + distance ptsA[ptsA.count] ptsB[1]
                local flipB = d2 < d1
                if flipB do (
                    local revPtsB = #()
                    for i = ptsB.count to 1 by -1 do append revPtsB ptsB[i]
                    ptsB = revPtsB
                )
                
                for i = 1 to ptsA.count do append connectLines #(ptsA[i], ptsB[i])
            )
            
            for pts in connectLines do (
                local newSpl = addNewSpline shp
                addKnot shp newSpl #corner #line pts[1]
                addKnot shp newSpl #corner #line pts[2]
            )
            
            updateShape shp
            redrawViews()
            print "线条连接已完成。"
        )
    )
)

try(destroyDialog splConnectDialog)catch()
createDialog splConnectDialog style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)
