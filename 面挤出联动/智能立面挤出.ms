try(destroyDialog WH_SmartExtrude_Rollout)catch()
try(destroyDialog WH_EditPreset_Rollout)catch()

global WH_SmartExtrude_Rollout
global WH_EditPreset_Rollout

-- ==========================================
-- 1. 自定义预设子面板定义
-- ==========================================
rollout WH_EditPreset_Rollout "自定义预设" width:220 height:95
(
    label lbl_title "请输入新的预设数值：" align:#left offset:[12, 8]
    spinner spn_new_val "数值：" range:[-1000000, 1000000, 0] type:#worldunits fieldwidth:80 align:#left offset:[12, 8]
    button btn_ok "确定" width:70 height:22 align:#right offset:[-12, 12] across:2
    button btn_cancel "取消" width:70 height:22 align:#left offset:[12, 12]
    
    on WH_EditPreset_Rollout open do (
        spn_new_val.value = WH_SmartExtrude_Rollout.edit_val
    )
    
    on btn_ok pressed do (
        local val = spn_new_val.value
        WH_SmartExtrude_Rollout.edit_btn.text = (val as string)
        if WH_SmartExtrude_Rollout.edit_var == "p1_ext" do WH_SmartExtrude_Rollout.p1_val_ext = val
        if WH_SmartExtrude_Rollout.edit_var == "p2_ext" do WH_SmartExtrude_Rollout.p2_val_ext = val
        if WH_SmartExtrude_Rollout.edit_var == "p1_off" do WH_SmartExtrude_Rollout.p1_val_off = val
        if WH_SmartExtrude_Rollout.edit_var == "p2_off" do WH_SmartExtrude_Rollout.p2_val_off = val
        WH_SmartExtrude_Rollout.saveSettings()
        destroyDialog WH_EditPreset_Rollout
    )
    
    on btn_cancel pressed do (
        destroyDialog WH_EditPreset_Rollout
    )
)

-- ==========================================
-- 2. 智能立面综合工具主面板
-- ==========================================
rollout WH_SmartExtrude_Rollout "智能立面综合工具"
(
    group " 智能面推拉 (操作面) " (
        checkbox chk_new_segment " 创建新分段 (不联动)" checked:false align:#left offset:[8, 2]
        
        spinner spn_dist_ext "推拉距离：" range:[-1000000, 1000000, 0] type:#worldunits scale:1.0 fieldwidth:80 align:#left offset:[8, 6] across:2
        button btn_align_ext "对齐到点" width:70 height:20 align:#right offset:[-8, 4] tooltip:"点击在视口中拾取一个参考点对齐推拉深度"
        
        label lbl_preset_ext "常用预设 (左键执行，右键自定义)：" align:#left offset:[8, 6]
        button btn_p1_ext "120" width:70 height:20 align:#left across:3 offset:[2, 4]
        button btn_p2_ext "240" width:70 height:20 align:#center offset:[0, 4]
        button btn_last_ext "上次:0" width:85 height:20 align:#right offset:[-2, 4]
    )
    
    group " POLY线偏移 (操作线) " (
        spinner spn_dist_off "偏移距离：" range:[-1000000, 1000000, 0] type:#worldunits scale:1.0 fieldwidth:80 align:#left offset:[8, 6]
        
        label lbl_preset_off "常用预设 (左键执行，右键自定义)：" align:#left offset:[8, 6]
        button btn_p1_off "120" width:70 height:20 align:#left across:3 offset:[2, 4]
        button btn_p2_off "240" width:70 height:20 align:#center offset:[0, 4]
        button btn_last_off "上次:0" width:85 height:20 align:#right offset:[-2, 4]
    )

    -- 共享状态变量
    local targetNode = undefined
    
    -- 面推拉专属变量
    local baseFaces = #{}
    local extrudeVerts = #()
    local origVertPos = #()
    local extrudeNormal = [0,0,0]
    local isDragging_ext = false
    local ignoreChange_ext = false
    
    -- 线偏移专属变量
    local origEdgeSel = #{}
    local isDragging_off = false
    local ignoreChange_off = false
    local hasRunInDrag_off = false
    
    -- 统合的配置文件及预设值 (保存在 plugcfg 目录，保证脚本目录干净无杂物)
    local iniPath = (getDir #plugcfg) + "\\智能立面综合工具.ini"
    
    local p1_val_ext = 120.0
    local p2_val_ext = 240.0
    local last_val_ext = 0.0
    
    local p1_val_off = 120.0
    local p2_val_off = 240.0
    local last_val_off = 0.0

    -- 共享的预设编辑临时变量
    local edit_btn = undefined
    local edit_var = ""
    local edit_val = 0.0

    struct PolyData (oldFaceID, vArr, matID, sg, supportedChannels, mapFaces)

    -- ==========================================
    -- 配置管理
    -- ==========================================
    fn loadSettings = (
        if doesFileExist iniPath then (
            p1_val_ext = (getINISetting iniPath "ExtrudePresets" "Preset1") as float
            p2_val_ext = (getINISetting iniPath "ExtrudePresets" "Preset2") as float
            last_val_ext = (getINISetting iniPath "ExtrudePresets" "LastValue") as float
            
            p1_val_off = (getINISetting iniPath "OffsetPresets" "Preset1") as float
            p2_val_off = (getINISetting iniPath "OffsetPresets" "Preset2") as float
            last_val_off = (getINISetting iniPath "OffsetPresets" "LastValue") as float
            
            local ns = getINISetting iniPath "ExtrudeSettings" "NewSegment"
            if ns != "" do chk_new_segment.checked = (ns == "true")
        ) else (
            setINISetting iniPath "ExtrudePresets" "Preset1" "120.0"
            setINISetting iniPath "ExtrudePresets" "Preset2" "240.0"
            setINISetting iniPath "ExtrudePresets" "LastValue" "0.0"
            
            setINISetting iniPath "OffsetPresets" "Preset1" "120.0"
            setINISetting iniPath "OffsetPresets" "Preset2" "240.0"
            setINISetting iniPath "OffsetPresets" "LastValue" "0.0"
            
            setINISetting iniPath "ExtrudeSettings" "NewSegment" "false"
        )
    )
    
    fn saveSettings = (
        setINISetting iniPath "ExtrudePresets" "Preset1" (p1_val_ext as string)
        setINISetting iniPath "ExtrudePresets" "Preset2" (p2_val_ext as string)
        setINISetting iniPath "ExtrudePresets" "LastValue" (last_val_ext as string)
        
        setINISetting iniPath "OffsetPresets" "Preset1" (p1_val_off as string)
        setINISetting iniPath "OffsetPresets" "Preset2" (p2_val_off as string)
        setINISetting iniPath "OffsetPresets" "LastValue" (last_val_off as string)
        
        setINISetting iniPath "ExtrudeSettings" "NewSegment" (if chk_new_segment.checked then "true" else "false")
    )

    -- ==========================================
    -- 核心算法：智能面推拉 (带共面过滤及新分段模式)
    -- ==========================================
    fn prepareExtrusion = (
        targetNode = selection[1]
        if targetNode == undefined or classOf targetNode != Editable_Poly do return false
        baseFaces = polyOp.getFaceSelection targetNode
        if baseFaces.isEmpty do return false
        
        extrudeNormal = [0,0,0]
        for f in baseFaces do extrudeNormal += polyOp.getFaceNormal targetNode f
        if extrudeNormal == [0,0,0] do extrudeNormal = [0,0,1]
        extrudeNormal = normalize extrudeNormal
        
        -- 转换为世界坐标下的推拉法线，解决物体自身被旋转或 Pivot 修改导致 local 判定失效的问题
        local extrudeNormal_world = normalize (extrudeNormal * targetNode.objectTransform.rotation)
        
        format "\n--- [DEBUG] prepareExtrusion Start ---\n"
        format "Selected Node: %\n" targetNode.name
        format "Base Faces Selection: %\n" (baseFaces as string)
        format "extrudeNormal (Local): %\n" extrudeNormal
        format "extrudeNormal_world: %\n" extrudeNormal_world
        format "chk_new_segment.checked: %\n" chk_new_segment.checked
        
        local allEdges = polyOp.getEdgesUsingFace targetNode baseFaces
        local perimeterEdges = #{}
        for e in allEdges do (
            local f = polyOp.getFacesUsingEdge targetNode e
            local overlap = f * baseFaces
            if overlap.numberset == 1 do append perimeterEdges e
        )
        
        local edgesToStretchData = #()
        local openBoundaryEdges = #()
        for e in perimeterEdges do (
            local f = polyOp.getFacesUsingEdge targetNode e
            if f.numberset == 2 then (
                local shouldStretch = false
                local dotValStr = "N/A"
                local reasonStr = ""
                local n_adj_world = [0,0,0]
                local afArray = (f - baseFaces) as array
                
                -- 只有在未勾选“创建新分段”时，才进行拉伸过滤
                if not chk_new_segment.checked then (
                    local selectedFacesSharingEdge = f * baseFaces
                    local sfArray = selectedFacesSharingEdge as array
                    if sfArray.count > 0 then (
                        local baseFace = sfArray[1]
                        if afArray.count > 0 then (
                            local adjFace = afArray[1]
                            local n_adj = polyOp.getFaceNormal targetNode adjFace
                            local n_bf = polyOp.getFaceNormal targetNode baseFace
                            if n_adj != [0,0,0] and n_bf != [0,0,0] then (
                                -- 将相邻面法线转为世界坐标
                                n_adj_world = normalize (n_adj * targetNode.objectTransform.rotation)
                                -- 计算相邻面世界法线与推拉世界法线的点积
                                -- 点积绝对值 < 0.08 表示相邻面平行于世界坐标下的挤出运动方向，进行智能拉伸
                                local dotVal = abs (dot n_adj_world extrudeNormal_world)
                                dotValStr = dotVal as string
                                if dotVal < 0.08 then (
                                    shouldStretch = true
                                    reasonStr = "Adjacent face parallel to motion (Stretches)"
                                ) else (
                                    reasonStr = "Adjacent face perpendicular to motion (Blocks)"
                                )
                            ) else (
                                reasonStr = "Zero normal detected"
                            )
                        ) else (
                            reasonStr = "No adjacent face in afArray"
                        )
                    ) else (
                        reasonStr = "No base face sharing edge"
                    )
                ) else (
                    reasonStr = "NewSegment enabled (No Linkage)"
                )
                
                format "Edge %: adjFace=%, n_adj_world=%, dotVal=%, shouldStretch=%, reason=%\n" e (if afArray.count > 0 then afArray[1] else -1) n_adj_world dotValStr shouldStretch reasonStr
                
                if shouldStretch do (
                    local adjFace = afArray[1]
                    append edgesToStretchData #(adjFace, e)
                )
            ) else if f.numberset == 1 do (
                append openBoundaryEdges e
            )
        )
        
        local numFacesBefore = polyOp.getNumFaces targetNode
        polyOp.extrudeFaces targetNode baseFaces 0.0
        local numFacesAfter = polyOp.getNumFaces targetNode
        local sideFaces = #{ (numFacesBefore+1) .. numFacesAfter }
        
        -- 核心修正：在执行任何相邻面删除/重构以致面索引偏移前，立刻提取被挤出面目前的真实顶点索引
        local verts = polyOp.getVertsUsingFace targetNode baseFaces
        extrudeVerts = verts as array
        origVertPos = for v in extrudeVerts collect (polyOp.getVert targetNode v)
        
        local polygonsToCreate = #()
        local facesToDelete = #{}
        
        for data in edgesToStretchData do (
            local adjFace = data[1]
            local oldEdge = data[2]
            
            local f = polyOp.getFacesUsingEdge targetNode oldEdge
            local sf = (f * sideFaces) as array
            local sideFace = sf[1]
            
            if sideFace != undefined do (
                local sfEdges = polyOp.getEdgesUsingFace targetNode sideFace
                local adjEdges = polyOp.getEdgesUsingFace targetNode adjFace
                local sharedEdgeArr = (sfEdges * adjEdges) as array
                
                if sharedEdgeArr.count > 0 do (
                    local sharedEdge = sharedEdgeArr[1]
                    local oldVerts = polyOp.getVertsUsingEdge targetNode sharedEdge
                    local sfVerts = polyOp.getVertsUsingFace targetNode sideFace
                    local newVerts = sfVerts - oldVerts
                    
                    local v_old1 = (oldVerts as array)[1]
                    local v_old2 = (oldVerts as array)[2]
                    local v_new1 = undefined
                    local v_new2 = undefined
                    
                    for nv in newVerts do (
                        local edges_nv = polyOp.getEdgesUsingVert targetNode nv
                        local edges_v_old1 = polyOp.getEdgesUsingVert targetNode v_old1
                        if not (edges_nv * edges_v_old1).isEmpty do v_new1 = nv
                        
                        local edges_v_old2 = polyOp.getEdgesUsingVert targetNode v_old2
                        if not (edges_nv * edges_v_old2).isEmpty do v_new2 = nv
                    )
                    
                    if v_new1 != undefined and v_new2 != undefined do (
                        local existingIdx = 0
                        for i = 1 to polygonsToCreate.count do (
                            if polygonsToCreate[i].oldFaceID == adjFace do existingIdx = i
                        )
                        
                        local vArr = #()
                        if existingIdx > 0 then (
                            vArr = polygonsToCreate[existingIdx].vArr
                        ) else (
                            vArr = polyOp.getFaceVerts targetNode adjFace
                        )
                        
                        for i = 1 to vArr.count do (
                            if vArr[i] == v_old1 do vArr[i] = v_new1
                            if vArr[i] == v_old2 do vArr[i] = v_new2
                        )
                        
                        if existingIdx > 0 then (
                            polygonsToCreate[existingIdx].vArr = vArr
                        ) else (
                            local matID = polyOp.getFaceMatID targetNode adjFace
                            local sg = polyOp.getFaceSmoothGroup targetNode adjFace
                            local numMaps = polyOp.getNumMaps targetNode
                            local mapFaces = #()
                            local supportedChannels = #()
                            for c = 0 to numMaps do (
                                if polyOp.getMapSupport targetNode c do (
                                    append supportedChannels c
                                    append mapFaces (polyOp.getMapFace targetNode c adjFace)
                                )
                            )
                            append polygonsToCreate (PolyData oldFaceID:adjFace vArr:vArr matID:matID sg:sg supportedChannels:supportedChannels mapFaces:mapFaces)
                        )
                        
                        facesToDelete += #{adjFace, sideFace}
                    )
                )
            )
        )
        
        -- 只有在不创建新分段的情况下，我们才执行删除悬空边缘（使侧面不封口）
        if not chk_new_segment.checked do (
            for e in openBoundaryEdges do (
                local f = polyOp.getFacesUsingEdge targetNode e
                local sf = (f * sideFaces) as array
                if sf.count == 1 do (
                    facesToDelete += #{sf[1]}
                )
            )
        )
        
        if not facesToDelete.isEmpty do (
            polyOp.deleteFaces targetNode facesToDelete delIsoVerts:false
            for p in polygonsToCreate do (
                local newFaceID = polyOp.createPolygon targetNode p.vArr
                if newFaceID > 0 do (
                    polyOp.setFaceMatID targetNode newFaceID p.matID
                    polyOp.setFaceSmoothGroup targetNode newFaceID p.sg
                    for i = 1 to p.supportedChannels.count do (
                        polyOp.setMapFace targetNode p.supportedChannels[i] newFaceID p.mapFaces[i]
                    )
                )
            )
        )
        
        return true
    )

    -- ==========================================
    -- 智能消面开洞功能 (SketchUp 级开洞核心)
    -- ==========================================
    fn checkAndCutHoles val = (
        if val >= 0.0 do return false
        if targetNode == undefined or classOf targetNode != Editable_Poly do return false
        
        local currentPushedFaces = polyOp.getFaceSelection targetNode
        if currentPushedFaces.isEmpty do return false
        
        local newExtrudedFacesToDelete = #{}
        local backFacesToDelete = #{}
        
        for pf in currentPushedFaces do (
            local C = polyOp.getFaceCenter targetNode pf
            local N = polyOp.getFaceNormal targetNode pf
            
            local foundBackFace = undefined
            local minDist = 1e9
            local numFaces = polyOp.getNumFaces targetNode
            
            for f = 1 to numFaces do (
                if pf == f do continue
                local N_f = polyOp.getFaceNormal targetNode f
                -- 背面的法线必须与挤出方向相反
                if dot N N_f < -0.95 do (
                    local fVerts = polyOp.getFaceVerts targetNode f
                    if fVerts.count > 0 do (
                        local P_f = polyOp.getVert targetNode fVerts[1]
                        local dist = abs (dot (C - P_f) N)
                        if dist < minDist do (
                            minDist = dist
                            foundBackFace = f
                        )
                    )
                )
            )
            
            -- 如果推拉面中心和背面在同一个平面上（间距极小）
            if foundBackFace != undefined and minDist < 0.2 do (
                local area_pf = polyOp.getFaceArea targetNode pf
                local area_bf = polyOp.getFaceArea targetNode foundBackFace
                -- 面积对比防线：确保背面不是超大墙体（防整面墙误删）
                if area_bf <= area_pf * 1.3 do (
                    append newExtrudedFacesToDelete pf
                    append backFacesToDelete foundBackFace
                )
            )
        )
        
        if not backFacesToDelete.isEmpty then (
            -- 收集将被删除的面的顶点集
            local vertsPushed = #{}
            for pf in newExtrudedFacesToDelete do vertsPushed += polyOp.getVertsUsingFace targetNode #{pf}
            local vertsBack = #{}
            for bf in backFacesToDelete do vertsBack += polyOp.getVertsUsingFace targetNode #{bf}
            
            -- 删除面
            local allToDelete = newExtrudedFacesToDelete + backFacesToDelete
            polyOp.deleteFaces targetNode allToDelete delIsoVerts:false
            
            -- 焊接接缝顶点
            local vertsToWeld = vertsPushed + vertsBack
            targetNode.weldThreshold = 0.2
            polyOp.weldVertsByThreshold targetNode vertsToWeld
            
            -- 局部清理孤立顶点
            local isoVerts = #{}
            for v in vertsToWeld do (
                if (polyOp.getFacesUsingVert targetNode v).isEmpty do append isoVerts v
            )
            if not isoVerts.isEmpty do polyOp.deleteVerts targetNode isoVerts
            
            return true
        )
        return false
    )

    fn executePushPull val = (
        if val != 0.0 do (
            undo "智能立面推拉" on (
                local success = false
                try (
                    success = prepareExtrusion()
                ) catch (
                    format "Error in prepareExtrusion: %\n" (getCurrentException())
                    success = false
                )
                if success do (
                    for i = 1 to extrudeVerts.count do (
                        polyOp.setVert targetNode extrudeVerts[i] (origVertPos[i] + extrudeNormal * val)
                    )
                    -- 检查开洞
                    checkAndCutHoles val
                    update targetNode
                    
                    last_val_ext = val
                    btn_last_ext.text = "上次:" + (last_val_ext as string)
                    saveSettings()
                )
            )
        )
    )

    -- ==========================================
    -- 核心算法：POLY线偏移
    -- ==========================================
    fn isPositiveDirection P = (
        if abs P.z > 0.001 then (
            P.z > 0
        ) else if abs P.y > 0.001 then (
            P.y > 0
        ) else (
            P.x > 0
        )
    )
    
    fn doOffset val = (
        if val == 0.0 do return false
        
        targetNode = selection[1]
        if targetNode == undefined or classOf targetNode != Editable_Poly do (
            messageBox "请选择一个 Editable Poly 对象！" title:"提示"
            return false
        )
        
        local edgeSel = polyOp.getEdgeSelection targetNode
        if edgeSel.isEmpty do (
            messageBox "请先选择需要偏移的边线！" title:"提示"
            return false
        )
        
        local edgeArr = edgeSel as array
        local newEdges = #{}
        
        for e in edgeArr do (
            local eVerts = polyOp.getEdgeVerts targetNode e
            local v1 = polyOp.getVert targetNode eVerts[1]
            local v2 = polyOp.getVert targetNode eVerts[2]
            local D = normalize (v2 - v1)
            local M = (v1 + v2) / 2.0
            
            local adjFaces = (polyOp.getFacesUsingEdge targetNode #{e}) as array
            if adjFaces.count == 0 do continue
            
            if adjFaces.count == 1 then (
                local f = adjFaces[1]
                local N = polyOp.getFaceNormal targetNode f
                local fVerts = polyOp.getFaceVerts targetNode f
                local C = [0,0,0]
                for v in fVerts do C += polyOp.getVert targetNode v
                C = C / fVerts.count
                local V_MC = C - M
                local P = cross D N
                if (dot P V_MC) < 0 do P = -P
                P = normalize P
                
                local P_offset = M + P * (abs val)
                
                local numEdgesBefore = polyOp.getNumEdges targetNode
                local numVertsBefore = polyOp.getNumVerts targetNode
                polyOp.slice targetNode #{f} (ray P_offset P)
                local numEdgesAfter = polyOp.getNumEdges targetNode
                local numVertsAfter = polyOp.getNumVerts targetNode
                
                if numEdgesAfter > numEdgesBefore do (
                    for ne = (numEdgesBefore + 1) to numEdgesAfter do (
                        local neVerts = polyOp.getEdgeVerts targetNode ne
                        if neVerts[1] > numVertsBefore and neVerts[2] > numVertsBefore do (
                            newEdges += #{ne}
                        )
                    )
                )
            ) else if adjFaces.count >= 2 then (
                local f1 = adjFaces[1]
                local f2 = adjFaces[2]
                
                local N1 = polyOp.getFaceNormal targetNode f1
                local f1Verts = polyOp.getFaceVerts targetNode f1
                local C1 = [0,0,0]
                for v in f1Verts do C1 += polyOp.getVert targetNode v
                C1 = C1 / f1Verts.count
                local V_MC1 = C1 - M
                local P1 = cross D N1
                if (dot P1 V_MC1) < 0 do P1 = -P1
                P1 = normalize P1
                
                local f1_is_pos = isPositiveDirection P1
                
                local f = if val >= 0 then (
                    if f1_is_pos then f1 else f2
                ) else (
                    if not f1_is_pos then f1 else f2
                )
                
                local N = polyOp.getFaceNormal targetNode f
                local fVerts = polyOp.getFaceVerts targetNode f
                local C = [0,0,0]
                for v in fVerts do C += polyOp.getVert targetNode v
                C = C / fVerts.count
                local V_MC = C - M
                local P = cross D N
                if (dot P V_MC) < 0 do P = -P
                P = normalize P
                
                local P_offset = M + P * (abs val)
                
                local numEdgesBefore = polyOp.getNumEdges targetNode
                local numVertsBefore = polyOp.getNumVerts targetNode
                polyOp.slice targetNode #{f} (ray P_offset P)
                local numEdgesAfter = polyOp.getNumEdges targetNode
                local numVertsAfter = polyOp.getNumVerts targetNode
                
                if numEdgesAfter > numEdgesBefore do (
                    for ne = (numEdgesBefore + 1) to numEdgesAfter do (
                        local neVerts = polyOp.getEdgeVerts targetNode ne
                        if neVerts[1] > numVertsBefore and neVerts[2] > numVertsBefore do (
                            newEdges += #{ne}
                        )
                    )
                )
            )
        )
        
        if not newEdges.isEmpty do (
            polyOp.setEdgeSelection targetNode newEdges
        )
        update targetNode
        return true
    )
    
    fn executeOffset val = (
        if val != 0.0 do (
            undo "POLY线偏移" on (
                local success = doOffset val
                if success do (
                    last_val_off = val
                    btn_last_off.text = "上次:" + (last_val_off as string)
                    saveSettings()
                )
            )
        )
    )

    -- ==========================================
    -- 面板生命周期及事件处理
    -- ==========================================
    on WH_SmartExtrude_Rollout open do (
        loadSettings()
        -- 填充面推拉 UI
        btn_p1_ext.text = p1_val_ext as string
        btn_p2_ext.text = p2_val_ext as string
        btn_last_ext.text = "上次:" + (last_val_ext as string)
        -- 填充线偏移 UI
        btn_p1_off.text = p1_val_off as string
        btn_p2_off.text = p2_val_off as string
        btn_last_off.text = "上次:" + (last_val_off as string)
    )

    on chk_new_segment changed state do saveSettings()

    -- ------------------------------------------
    -- 智能面推拉拖动事件组
    -- ------------------------------------------
    on spn_dist_ext buttondown do (
        theHold.SuperBegin()
        local success = false
        undo "智能立面推拉" on (
            try (
                success = prepareExtrusion()
            ) catch (
                format "Error in prepareExtrusion: %\n" (getCurrentException())
                success = false
            )
        )
        if success then (
            isDragging_ext = true
        ) else (
            theHold.SuperCancel()
            isDragging_ext = false
        )
    )

    on spn_dist_ext changed val do (
        if ignoreChange_ext do return ()
        if isDragging_ext and extrudeVerts.count > 0 and targetNode != undefined do (
            try (
                undo "智能立面推拉" on (
                    for i = 1 to extrudeVerts.count do (
                        polyOp.setVert targetNode extrudeVerts[i] (origVertPos[i] + extrudeNormal * val)
                    )
                    update targetNode
                )
            ) catch (
                format "Error in spn_dist_ext changed: %\n" (getCurrentException())
                theHold.SuperCancel()
                isDragging_ext = false
            )
        )
    )

    on spn_dist_ext buttonup do (
        if isDragging_ext do (
            local finalVal = spn_dist_ext.value
            if finalVal != 0.0 then (
                try (
                    undo "智能立面推拉" on (
                        -- 写入最终位置
                        for i = 1 to extrudeVerts.count do (
                            polyOp.setVert targetNode extrudeVerts[i] (origVertPos[i] + extrudeNormal * finalVal)
                        )
                        -- 检查开洞
                        checkAndCutHoles finalVal
                        update targetNode
                    )
                    theHold.SuperAccept "智能立面推拉"
                    
                    last_val_ext = finalVal
                    btn_last_ext.text = "上次:" + (last_val_ext as string)
                    saveSettings()
                ) catch (
                    format "Error in spn_dist_ext buttonup: %\n" (getCurrentException())
                    theHold.SuperCancel()
                )
            ) else (
                theHold.SuperCancel()
            )
            isDragging_ext = false
            ignoreChange_ext = true; spn_dist_ext.value = 0; ignoreChange_ext = false
        )
    )
    
    on spn_dist_ext entered inSpin inCancel do (
        if not inSpin and not inCancel and not ignoreChange_ext do (
            local val = spn_dist_ext.value
            if val != 0 do (
                try (
                    undo "智能立面推拉" on (
                        local success = false
                        try (
                            success = prepareExtrusion()
                        ) catch (
                            format "Error in prepareExtrusion: %\n" (getCurrentException())
                            success = false
                        )
                        if success do (
                            for i = 1 to extrudeVerts.count do (
                                polyOp.setVert targetNode extrudeVerts[i] (origVertPos[i] + extrudeNormal * val)
                            )
                            -- 检查开洞
                            checkAndCutHoles val
                            update targetNode
                            
                            last_val_ext = val
                            btn_last_ext.text = "上次:" + (last_val_ext as string)
                            saveSettings()
                        )
                    )
                ) catch (
                    format "Error in spn_dist_ext entered: %\n" (getCurrentException())
                )
                ignoreChange_ext = true; spn_dist_ext.value = 0; ignoreChange_ext = false
            )
        )
    )

    -- ------------------------------------------
    -- 对齐到点按钮逻辑
    -- ------------------------------------------
    on btn_align_ext pressed do (
        targetNode = selection[1]
        if targetNode == undefined or classOf targetNode != Editable_Poly do (
            messageBox "请先选择一个 Editable Poly 对象！" title:"提示"
            return ()
        )
        local baseFacesSel = polyOp.getFaceSelection targetNode
        if baseFacesSel.isEmpty do (
            messageBox "请在多边形的面子层级下选择要推拉的面！" title:"提示"
            return ()
        )
        
        -- 调用 Max 拾取点
        local p = pickPoint snap:#3D message:"请在视口中点击一个参考点以对齐推拉距离..."
        if classOf p == Point3 do (
            -- 1. 获取选中的面中心（显式指定 node 参数以获取世界坐标）
            local C_world = [0,0,0]
            for f in baseFacesSel do C_world += polyOp.getFaceCenter targetNode f node:targetNode
            C_world = C_world / baseFacesSel.numberset
            
            -- 2. 获取法线（从 baseObject 获取以保证为局部法线）并转为世界方向
            local localNormal = [0,0,0]
            for f in baseFacesSel do localNormal += polyOp.getFaceNormal targetNode.baseObject f
            localNormal = normalize localNormal
            local worldNormal = normalize (localNormal * targetNode.objectTransform.rotation)
            
            -- 3. 计算世界空间下的精准投影位移距离
            local val_world = dot (p - C_world) worldNormal
            
            -- 4. 解决缩放/对齐偏差：计算局部法线长度 1.0 在世界空间变换后的实际长度比例 factor
            local p0_world = [0,0,0] * targetNode.objectTransform
            local p1_world = localNormal * targetNode.objectTransform
            local factor = distance p0_world p1_world
            
            if factor > 0.0001 then (
                local val = val_world / factor
                executePushPull val
            ) else (
                executePushPull val_world
            )
        )
    )

    -- ------------------------------------------
    -- POLY线偏移拖动事件组
    -- ------------------------------------------
    on spn_dist_off buttondown do (
        theHold.SuperBegin()
        targetNode = selection[1]
        if targetNode != undefined and classOf targetNode == Editable_Poly then (
            origEdgeSel = polyOp.getEdgeSelection targetNode
            isDragging_off = true
            hasRunInDrag_off = false
        ) else (
            theHold.SuperCancel()
            isDragging_off = false
        )
    )
    
    on spn_dist_off changed val do (
        if ignoreChange_off do return ()
        if isDragging_off and not origEdgeSel.isEmpty and targetNode != undefined do (
            try (
                if hasRunInDrag_off do (
                    theHold.SuperCancel()
                    theHold.SuperBegin()
                )
                undo "POLY线偏移" on (
                    polyOp.setEdgeSelection targetNode origEdgeSel
                    local success = doOffset val
                    if success then (
                        hasRunInDrag_off = true
                    ) else (
                        theHold.SuperCancel()
                        hasRunInDrag_off = false
                        isDragging_off = false
                    )
                )
            ) catch (
                format "Error in spn_dist_off changed: %\n" (getCurrentException())
                theHold.SuperCancel()
                isDragging_off = false
                hasRunInDrag_off = false
            )
        )
    )
    
    on spn_dist_off buttonup inCancel do (
        if isDragging_off do (
            try (
                if inCancel then (
                    if hasRunInDrag_off do theHold.SuperCancel()
                ) else (
                    if hasRunInDrag_off then (
                        theHold.SuperAccept "POLY线偏移"
                        local finalVal = spn_dist_off.value
                        if finalVal != 0.0 do (
                            last_val_off = finalVal
                            btn_last_off.text = "上次:" + (last_val_off as string)
                            saveSettings()
                        )
                    ) else (
                        theHold.SuperCancel()
                    )
                )
            ) catch (
                format "Error in spn_dist_off buttonup: %\n" (getCurrentException())
                theHold.SuperCancel()
            )
            isDragging_off = false
            hasRunInDrag_off = false
            ignoreChange_off = true; spn_dist_off.value = 0; ignoreChange_off = false
        )
    )
    
    on spn_dist_off entered inSpin inCancel do (
        if not inSpin and not inCancel and not ignoreChange_off do (
            local val = spn_dist_off.value
            if val != 0 do (
                executeOffset val
                ignoreChange_off = true; spn_dist_off.value = 0; ignoreChange_off = false
            )
        )
    )

    on btn_p1_ext pressed do executePushPull p1_val_ext
    on btn_p1_ext rightclick do (
        edit_btn = btn_p1_ext
        edit_var = "p1_ext"
        edit_val = p1_val_ext
        createDialog WH_EditPreset_Rollout modal:true
    )

    on btn_p2_ext pressed do executePushPull p2_val_ext
    on btn_p2_ext rightclick do (
        edit_btn = btn_p2_ext
        edit_var = "p2_ext"
        edit_val = p2_val_ext
        createDialog WH_EditPreset_Rollout modal:true
    )

    on btn_last_ext pressed do executePushPull last_val_ext

    on btn_p1_off pressed do executeOffset p1_val_off
    on btn_p1_off rightclick do (
        edit_btn = btn_p1_off
        edit_var = "p1_off"
        edit_val = p1_val_off
        createDialog WH_EditPreset_Rollout modal:true
    )

    on btn_p2_off pressed do executeOffset p2_val_off
    on btn_p2_off rightclick do (
        edit_btn = btn_p2_off
        edit_var = "p2_off"
        edit_val = p2_val_off
        createDialog WH_EditPreset_Rollout modal:true
    )

    on btn_last_off pressed do executeOffset last_val_off

    -- ------------------------------------------
    -- 按钮及事件定义在最后，以避免占用自动布局行
    -- ------------------------------------------
    button btn_help "?" width:16 height:16 pos:[256, 5] tooltip:"使用说明"

    on btn_help pressed do (
        local helpText = "【智能面推拉】\n" \
                       + "1. 在面层级下，选择需要推拉的墙体或窗洞面。\n" \
                       + "2. 【特色 - 智能开洞】：向内推至墙体背面深度（背面有相匹配多边形），释放鼠标会自动删面并缝合焊接，实现穿透开洞！\n" \
                       + "3. 【特色 - 共面过滤】：平直大墙面上推拉局部面时，周围共面墙体不会变形拉伸，自动生成新边分段，与 SU 体验一致。\n" \
                       + "4. 【特色 - 创建新分段】：勾选后推拉相当于 SU 的 Ctrl 键，始终进行独立段挤出。\n" \
                       + "5. 【特色 - 对齐到点】：点击后在视口中捕捉任意物体顶点，可将推拉高度完美对齐该点。\n\n" \
                       + "【POLY线偏移】\n" \
                       + "- 在边层级选择边线，拖动偏移或一键应用常用预设，只保留单向智能偏移。\n\n" \
                       + "【公共操作】\n" \
                       + "- 预设按钮：左键直接运行，右键自定义数值并保存。\n" \
                       + "- 撤销支持：支持 Ctrl+Z 撤销（开洞及焊接会被作为单步历史撤销恢复）。"
        messageBox helpText title:"使用说明"
    )
)

createDialog WH_SmartExtrude_Rollout width:280 height:230
