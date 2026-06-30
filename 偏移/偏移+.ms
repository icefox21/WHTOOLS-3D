rollout SplineOffsetRollout "样条线偏移工具" width:260 height:280
(
    spinner spn_distance "偏移距离:" type:#float range:[-1e9,1e9,200.0] fieldwidth:80 pos:[20,10]
    spinner spn_samples "曲线插值数:" type:#integer range:[1,100,16] fieldwidth:80 pos:[20,40]
    
    label lbl_line1 "----------------------------------------" pos:[20,65]

    checkbox chk_preview "🌟开启实时预览 (所见即所得)" checked:false pos:[20,80]
    checkbox chk_reverseDir "🔁方向反转(结果左右互换)" checked:false pos:[20,105]
    
    label lbl_line2 "----------------------------------------" pos:[20,130]

    checkbox chk_deleteOriginal "偏移后删除原样条线" checked:true pos:[20,145]
    checkbox chk_selectNew "执行后选中新偏移线" checked:false pos:[20,165]
    
    button btn_run "确认生成 (执行偏移)" width:220 height:32 pos:[20,190] tooltip:"如果在预览模式下，会将当前预览转正。否则直接执行。"

    label lbl_tip "使用说明: 勾选'实时预览'后可拖动距离或\n方向反转实时观察。调整满意后点击确认。" pos:[20,230] width:220 height:50

    -- [全局状态] 存放临时生成的预览样条线
    local previewShapes = #()

    local iniFile = getDir #plugcfg + "\\SplineOffsetPlus_Settings.ini"

    fn loadSettings =
    (
        local v
        v = getINISetting iniFile "Settings" "Distance"
        if v != "" do spn_distance.value = v as float
        v = getINISetting iniFile "Settings" "Samples"
        if v != "" do spn_samples.value = v as integer
        v = getINISetting iniFile "Settings" "Preview"
        if v != "" do chk_preview.checked = (v == "true")
        v = getINISetting iniFile "Settings" "ReverseDir"
        if v != "" do chk_reverseDir.checked = (v == "true")
        v = getINISetting iniFile "Settings" "DeleteOriginal"
        if v != "" do chk_deleteOriginal.checked = (v == "true")
        v = getINISetting iniFile "Settings" "SelectNew"
        if v != "" do chk_selectNew.checked = (v == "true")
    )

    fn saveSettings =
    (
        setINISetting iniFile "Settings" "Distance" (spn_distance.value as string)
        setINISetting iniFile "Settings" "Samples" (spn_samples.value as string)
        setINISetting iniFile "Settings" "Preview" (chk_preview.checked as string)
        setINISetting iniFile "Settings" "ReverseDir" (chk_reverseDir.checked as string)
        setINISetting iniFile "Settings" "DeleteOriginal" (chk_deleteOriginal.checked as string)
        setINISetting iniFile "Settings" "SelectNew" (chk_selectNew.checked as string)
    )

    -- 清理内存和场景中的临时预览模型
    fn clearPreview = (
        undo off (
            for s in previewShapes where isValidNode s do delete s
            previewShapes = #()
        )
        forceCompleteRedraw()
    )

    -- 将一条Spline按段展开计算为点序列(Polyline)
    fn getSplinePolyline shp s samples_per_curve =
    (
        local pts = #()
        local numSegs = numSegments shp s
        local numK = numKnots shp s
        
        if numK == 0 do return #()

        append pts (getKnotPoint shp s 1)
        
        for i = 1 to numSegs do
        (
            local segType = getSegmentType shp s i
            local k1 = i
            local k2 = i + 1
            if k2 > numK do k2 = 1 
            
            local pos0 = getKnotPoint shp s k1
            local out1 = getOutVec shp s k1
            local in2  = getInVec shp s k2
            local pos3 = getKnotPoint shp s k2
            
            -- 判断是否几何上完全是直线（避免因贝塞尔手柄引发杂点）
            local isStraight = false
            if segType == #line then isStraight = true
            else
            (
                local segVec = pos3 - pos0
                local segLength = length segVec
                if segLength < 1e-5 then isStraight = true
                else
                (
                    local lineDir = segVec / segLength
                    local d1 = length ((out1 - pos0) - (dot (out1 - pos0) lineDir) * lineDir)
                    local d2 = length ((in2 - pos3) - (dot (in2 - pos3) lineDir) * lineDir)
                    
                    if d1 < 1e-3 and d2 < 1e-3 do
                    (
                        local proj1 = dot (out1 - pos0) lineDir
                        local proj2 = dot (in2 - pos0) lineDir
                        if proj1 >= -1e-3 and proj1 <= (segLength + 1e-3) and \
                           proj2 >= -1e-3 and proj2 <= (segLength + 1e-3) do
                        (
                            isStraight = true
                        )
                    )
                )
            )
            
            if isStraight then
            (
                append pts pos3
            )
            else
            (
                for j = 1 to samples_per_curve do
                (
                    local t = (j as float) / samples_per_curve
                    local t_inv = 1.0 - t
                    local p = t_inv^3 * pos0 + 3 * t_inv^2 * t * out1 + 3 * t_inv * t^2 * in2 + t^3 * pos3
                    append pts p
                )
            )
        )
        pts
    )

    -- 简化共线冗余点（重要：去除非必要的顶点，保证法线纯净且直线只有两端点）
    fn simplifyCollinearPts pts tol:1e-3 =
    (
        if pts.count <= 2 do return pts
        local res = #()
        append res pts[1]
        
        for i = 2 to pts.count - 1 do
        (
            local p_prev = res[res.count]
            local p_curr = pts[i]
            local p_next = pts[i+1]
            
            local dir = p_next - p_prev
            local len = length dir
            if len < 1e-5 then
            (
                append res p_curr
            )
            else
            (
                dir = dir / len
                local v = p_curr - p_prev
                local proj = dot v dir
                local perp = v - proj * dir
                
                if (length perp) > tol then
                (
                    append res p_curr
                )
                else
                (
                    -- 点是共线的，但只有当它恰好位于前点和后点之间时才剔除
                    if proj < -1e-4 or proj > (len + 1e-4) do
                    (
                        append res p_curr
                    )
                )
            )
        )
        append res pts[pts.count]
        res
    )

    -- 清理重复点和共线点
    fn cleanDuplicates pts isCls =
    (
        local cleaned = #()
        if pts.count == 0 do return #()
        append cleaned pts[1]
        for i = 2 to pts.count do
        (
            if (length (pts[i] - cleaned[cleaned.count])) > 1e-5 do
            (
                append cleaned pts[i]
            )
        )
        if isCls and cleaned.count > 1 do
        (
            if (length (cleaned[cleaned.count] - cleaned[1])) < 1e-5 do deleteItem cleaned cleaned.count
        )
        simplifyCollinearPts cleaned tol:1e-3
    )

    -- 核心偏移函数：使用角平分线相交算法（完美保持硬直角）
    fn offsetPolyline pts dist isCls reverseDir =
    (
        local processPts = cleanDuplicates pts isCls
        local M = processPts.count
        if M < 2 do return #()
        
        local offsetPts = #()
        
        for i = 1 to M do
        (
            local P = processPts[i]
            local prevIdx = if i == 1 then M else i - 1
            local nextIdx = if i == M then 1 else i + 1
            
            local P_prev = processPts[prevIdx]
            local P_next = processPts[nextIdx]
            
            local T_in = [0,0,0]
            local T_out = [0,0,0]
            
            if i == 1 and not isCls then
            (
                T_out = normalize (P_next - P)
                T_in = T_out 
            )
            else if i == M and not isCls then
            (
                T_in = normalize (P - P_prev)
                T_out = T_in 
            )
            else
            (
                T_in = normalize (P - P_prev)
                T_out = normalize (P_next - P)
            )
            
            local N_in = normalize [-T_in.y, T_in.x, 0]
            local N_out = normalize [-T_out.y, T_out.x, 0]
            
            if reverseDir do
            (
                N_in = -N_in
                N_out = -N_out
            )
            
            local N_sum = N_in + N_out
            local N_bisect = if length N_sum < 1e-5 then N_in else normalize N_sum
            
            local dot_val = dot N_bisect N_in
            if dot_val < 0.1 do dot_val = 0.1 
            
            local offset_dist = dist / dot_val
            local Q = P + N_bisect * offset_dist
            
            append offsetPts Q
        )
        offsetPts
    )

    -- 统一执行：控制是“生成临时预览”还是“直接出最后成品”
    fn doOffset isPreview:false =
    (
        clearPreview() -- 不论正式还是预览，先清理上一次垃圾

        local selArray = selection as array
        if selArray.count == 0 then
        (
            if not isPreview do messageBox "请先选择一个或多个样条线(Shape/Line/Editable Spline)对象。" title:"提示"
            return ()
        )

        local dist = spn_distance.value
        local samples = spn_samples.value
        local rev = chk_reverseDir.checked
        local pickSelectNew = chk_selectNew.checked
        local deleteOriginal = chk_deleteOriginal.checked

        local hasShape = false
        for obj in selArray where (isKindOf obj Shape or classOf obj == Line) do hasShape = true
        
        if not hasShape do 
        (
            if not isPreview do messageBox "所选对象内没有可用的样条线。" title:"提示"
            return ()
        )

        local newShapesArray = #()

        with redraw off 
        (
            if isPreview then
            (
                undo off
                (
                    for obj in selArray do
                    (
                        if (isKindOf obj Shape) or (isKindOf obj SplineShape) or (classOf obj == Line) then
                        (
                            local tmpObj = copy obj
                            try(convertToSplineShape tmpObj)catch()

                            local ns = numSplines tmpObj
                            if ns > 0 do
                            (
                                local baseName = "_临时预览_"
                                local newSh = line name:(uniqueName baseName)
                                newSh.wirecolor = (color 255 128 0)
                                newSh.renderable = false
                                
                                for s = 1 to ns do
                                (
                                    local isCls = isClosed tmpObj s
                                    local rawPts = getSplinePolyline tmpObj s samples
                                    local offsetPts = offsetPolyline rawPts dist isCls rev
                                    if offsetPts.count > 1 do
                                    (
                                        local spIdx = addNewSpline newSh
                                        for p in offsetPts do addKnot newSh spIdx #corner #line p
                                        if isCls do try(setClosed newSh spIdx true)catch()
                                    )
                                )
                                updateShape newSh
                                append previewShapes newSh
                            )
                            delete tmpObj 
                        )
                    )
                )
            )
            else
            (
                undo "Spline Offset Realtime" on
                (
                    for obj in selArray do
                    (
                        if (isKindOf obj Shape) or (isKindOf obj SplineShape) or (classOf obj == Line) then
                        (
                            local tmpObj = copy obj
                            try(convertToSplineShape tmpObj)catch()

                            local ns = numSplines tmpObj
                            if ns > 0 do
                            (
                                local baseName = obj.name + "_Offset"
                                local newSh = line name:(uniqueName baseName)
                                newSh.wirecolor = (color 90 200 255)
                                newSh.renderable = false
                                
                                for s = 1 to ns do
                                (
                                    local isCls = isClosed tmpObj s
                                    local rawPts = getSplinePolyline tmpObj s samples
                                    local offsetPts = offsetPolyline rawPts dist isCls rev
                                    if offsetPts.count > 1 do
                                    (
                                        local spIdx = addNewSpline newSh
                                        for p in offsetPts do addKnot newSh spIdx #corner #line p
                                        if isCls do try(setClosed newSh spIdx true)catch()
                                    )
                                )
                                updateShape newSh
                                append newShapesArray newSh
                            )
                            delete tmpObj 

                            if deleteOriginal do delete obj
                        )
                    )

                    if pickSelectNew then
                    (
                        if not deleteOriginal do clearSelection()
                        for nSh in newShapesArray do selectMore nSh
                    )
                )
            )
        )
        if isPreview do forceCompleteRedraw()
    )


    -- === 面板实时交互防灾绑定 ===

    -- UI 控制联动
    on chk_preview changed state do 
    (
        if state then doOffset isPreview:true
        else clearPreview()
    )

    on spn_distance changed val do 
    (
        if chk_preview.checked do doOffset isPreview:true
    )

    on chk_reverseDir changed state do 
    (
        if chk_preview.checked do doOffset isPreview:true
    )

    -- 切换不同物体时，防止预览线挂在半空
    fn resetOnSelectionChange = (
        if chk_preview.checked do (
            clearPreview()
            doOffset isPreview:true
        )
    )

    -- 主执行按钮
    on btn_run pressed do
    (
        -- 保存原有参数（防止执行动作改变状态丢失勾选意图）
        saveSettings()

        -- 不论是否有预览模式，按下执行时：
        -- 1. 取消预览状态（它会同时执行清空废品节点）
        chk_preview.checked = false 
        clearPreview()
        
        -- 2. 真正下发生产指令
        doOffset isPreview:false
    )

    -- 面板生命周期
    on SplineOffsetRollout open do
    (
        loadSettings()
        if chk_preview.checked do doOffset isPreview:true

        callbacks.removeScripts id:#SplineOffset_SelChange
        callbacks.addScript #selectionSetChanged "SplineOffsetRollout.resetOnSelectionChange()" id:#SplineOffset_SelChange
    )

    on SplineOffsetRollout close do
    (
        saveSettings()
        callbacks.removeScripts id:#SplineOffset_SelChange
        chk_preview.checked = false
        clearPreview()
    )
)

try(destroyDialog SplineOffsetRollout)catch()
createDialog SplineOffsetRollout style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)
