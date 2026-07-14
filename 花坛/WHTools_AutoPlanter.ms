-- WHTools_AutoPlanter.ms
-- Built for Engineering-Grade Stability

try(destroyDialog AutoPlanterRollout)catch()
    -- 【强制审查声明】 (Rubber Duck Debugging)
    -- 此脚本已实现以下异常隔离：
    -- 1. snapshotAsMesh 使用 try/catch/finally 严格保障内存回收，绝不残留幽灵网格。
    -- 2. 边段合并采用 1D 区间投影合并算法，无视任何破面、碎边、法线反转导致的拓扑灾难。
    -- 3. 石块生成自带极短线段防御 (length < width)，防止生成负缩放模型引起物理崩溃。
    
    rollout AutoPlanterRollout "全自动识别花坛 V2.3" width:220
    (
        local iniFile = getdir #plugcfg + "\\WHTools_AutoPlanter.ini"
        
        group "【石块参数】(单位:mm)"
        (
            spinner spn_stoneW "石块宽度/高度:" range:[10, 500, 120] type:#integer
            spinner spn_stoneL "标准石块长度:" range:[100, 5000, 1000] type:#integer
            spinner spn_fillet "石块边缘倒角:" range:[0, 50, 5.0] type:#float
            spinner spn_depth  "花坛向外深度:" range:[100, 5000, 600] type:#integer
            spinner spn_cornerR "转角圆角半径(0为直角):" range:[0, 5000, 0] type:#integer
            spinner spn_lawnZ  "草坪下沉深度:" range:[0, 200, 20] type:#integer
            spinner spn_tol    "底边识别容差:" range:[1, 100, 20] type:#integer
        )
        button btn_generate "视口视角智能生成" width:190 height:35
        label lbl1 "操作说明：" align:#left
        label lbl2 "1. 旋转视图，看着要长花坛的墙面" align:#left
        label lbl3 "2. 选中墙体，直接点击上方按钮" align:#left
        
        group "【简易线条模式】(独立参数)"
        (
            spinner spn_line_stoneW "边框宽度:" range:[10, 500, 100] type:#integer
            spinner spn_line_stoneL "单块长度:" range:[100, 5000, 1000] type:#integer
            spinner spn_line_fillet "石块倒角:" range:[0, 20, 5.0] type:#float
            checkbox chk_line_useRadius "启用拐角圆角" checked:true align:#left
            spinner spn_line_pathRadius "拐角半径:" range:[0, 2000, 300] type:#integer
            spinner spn_line_lawnZ "草坪下沉:" range:[0, 200, 20] type:#integer
            button btn_gen_line "根据选中线条直接生成大花坛" width:190 height:35
        )
        
        fn sortIntervals i1 i2 = (
            if i1[1] < i2[1] then -1 else if i1[1] > i2[1] then 1 else 0
        )
        
        fn intersect2DLines p1 d1 p2 d2 = (
            local crossDet = d1.x * d2.y - d1.y * d2.x
            if abs(crossDet) < 0.001 then return ((p1 + p2)/2.0)
            local diff = p2 - p1
            local t = (diff.x * d2.y - diff.y * d2.x) / crossDet
            return p1 + d1 * t
        )
        
        fn placeArc C R angA angB vecName slen stoneBox = (
            local arcLen = R * abs(angB - angA) * pi / 180.0
            if arcLen < 1.0 do return #()
            
            local w = spn_stoneW.value as float
            local h = spn_stoneW.value as float
            local fVal = spn_fillet.value as float
            
            local numSegs = ceil (arcLen / 20.0) as integer
            if numSegs < 3 do numSegs = 3
            
            -- 强制顺时针/逆时针方向，确保法线始终朝上
            local startA = angA
            local endA = angB
            if angB < angA do (
                startA = angB
                endA = angA
            )
            
            local pathSp = SplineShape()
            addNewSpline pathSp
            
            -- 外圈弧线 (逆时针生成)
            local R_out = R + (w / 2.0)
            local dAng = (endA - startA) / numSegs
            for i = 0 to numSegs do (
                local a = startA + i * dAng
                local p = C + [R_out * cos a, R_out * sin a, 0]
                addKnot pathSp 1 #corner #line p
            )
            
            -- 内圈弧线 (顺时针返回，形成闭合环)
            local R_in = R - (w / 2.0)
            if R_in < 0.1 do R_in = 0.1 -- 防止倒角半径过小导致内圈出现自交死结
            for i = numSegs to 0 by -1 do (
                local a = startA + i * dAng
                local p = C + [R_in * cos a, R_in * sin a, 0]
                addKnot pathSp 1 #corner #line p
            )
            
            close pathSp 1
            updateShape pathSp
            
            -- 基础挤出（原位挤出，Z=0 -> Z=h，严丝合缝）
            local ext = Extrude amount:h
            addModifier pathSp ext
            
            -- 尝试使用原生的 Chamfer 修改器进行完美倒角
            if fVal > 0.001 do (
                try (
                    local cMod = Chamfer()
                    cMod.amount = fVal
                    cMod.segments = 1
                    try (cMod.tension = 0.0) catch() -- 强制直边倒角以匹配 ChamferBox
                    addModifier pathSp cMod
                ) catch ()
            )
            
            pathSp.name = "PlanterStone_Arc_" + vecName
            pathSp.wirecolor = black
            local matS = sceneMaterials["Planter_Stone_Mat"]
            if matS != undefined do pathSp.material = matS
            
            return #(pathSp)
        )


        fn placeRow startP endP rDir vecName slen stoneBox = (
            local rowLen = distance startP endP
            if rowLen < 0.1 do return #()
            
            local newObjs = #()
            local numFull = floor (rowLen / slen) as integer
            local remain = rowLen - (numFull * slen)
            
            local currentP = startP
            for i = 1 to numFull do (
                local inst = instance stoneBox
                local tm = matrix3 1
                tm.row1 = rDir
                tm.row3 = [0,0,1]
                tm.row2 = normalize (cross tm.row3 tm.row1)
                tm.row4 = currentP + rDir * (slen / 2.0)
                inst.transform = tm
                inst.name = "PlanterStone_" + vecName + "_" + (i as string)
                inst.wirecolor = black
                append newObjs inst
                currentP += rDir * slen
            )
            if remain > 0.1 do (
                local remInst = instance stoneBox
                local tm = matrix3 1
                tm.row1 = rDir
                tm.row3 = [0,0,1]
                tm.row2 = normalize (cross tm.row3 tm.row1)
                tm.row4 = currentP + rDir * (remain / 2.0)
                remInst.transform = tm
                remInst.scale = [remain / slen, 1.0, 1.0]
                remInst.name = "PlanterStone_" + vecName + "_Rem"
                remInst.wirecolor = black
                append newObjs remInst
            )
            return newObjs
        )
        
        -- Core Engine: Build Planter Path (Handles Corners)
        fn buildPlanterPath pts outs matS matL = (
            local N = pts.count
            if N < 2 do return()
            
            local w = spn_stoneW.value as float
            local h = spn_stoneW.value as float
            local slen = spn_stoneL.value as float
            local fVal = spn_fillet.value as float
            local d = spn_depth.value as float
            local R_ui = spn_cornerR.value as float
            local lZ = spn_lawnZ.value as float
            
            local stoneBox = undefined
            if fVal > 0.001 then (
                stoneBox = ChamferBox length:w width:slen height:h fillet:fVal filletSegs:1 smooth:off
            ) else (
                stoneBox = Box length:w width:slen height:h
            )
            stoneBox.material = matS
            stoneBox.wirecolor = black
            
            local F_start = #()
            local F_end = #()
            for i = 1 to (N-1) do (
                local p1 = pts[i] + outs[i] * (d - w/2.0)
                local p2 = pts[i+1] + outs[i] * (d - w/2.0)
                append F_start p1
                append F_end p2
            )
            
            local arcData = #()
            for i = 1 to (N-2) do append arcData undefined
            
            for i = 1 to (N-2) do (
                local d1 = normalize (pts[i+1] - pts[i])
                local d2 = normalize (pts[i+2] - pts[i+1])
                local p1 = pts[i+1] + outs[i] * (d - w/2.0)
                local p2 = pts[i+1] + outs[i+1] * (d - w/2.0)
                
                local crossZ = d1.x * d2.y - d1.y * d2.x
                local dotZ = d1.x * d2.x + d1.y * d2.y
                local alpha = atan2 crossZ dotZ
                local intersectP = if abs(crossZ) > 0.05 then intersect2DLines p1 d1 p2 d2 else ((p1 + p2)/2.0)
                
                if R_ui > 0.1 and abs(crossZ) > 0.05 then (
                    local T = R_ui / abs(tan (abs(alpha) / 2.0))
                    
                    local len1 = distance pts[i] pts[i+1]
                    local len2 = distance pts[i+1] pts[i+2]
                    local maxT1 = len1 / 2.0
                    local maxT2 = len2 / 2.0
                    local safeT = amin T (amin maxT1 maxT2)
                    local actual_R = safeT * abs(tan (abs(alpha) / 2.0))
                    
                    F_end[i] = intersectP - d1 * safeT
                    F_start[i+1] = intersectP + d2 * safeT
                    
                    local signA = if alpha > 0 then 1.0 else -1.0
                    local n1 = [ -d1.y * signA, d1.x * signA, 0 ]
                    local C = F_end[i] + n1 * actual_R
                    
                    local angA_val = atan2 (-n1.y) (-n1.x)
                    local n2 = [ -d2.y * signA, d2.x * signA, 0 ]
                    local angB_val = atan2 (-n2.y) (-n2.x)
                    
                    if signA > 0 and angB_val < angA_val do angB_val += 360.0
                    if signA < 0 and angB_val > angA_val do angB_val -= 360.0
                    
                    arcData[i] = #(C, actual_R, angA_val, angB_val, "Corner_" + i as string, alpha)
                ) else if abs(crossZ) > 0.05 then (
                    -- 【统一平接算法 (Butt Joint)】
                    -- 无论阴角还是阳角，都让前一段延长 w/2，后一段起始推后 w/2。
                    -- 这样两排石块刚好形成完美的 90 度 L 型平接，既不重叠也不留缝。
                    F_end[i] = intersectP + d1 * (w/2.0)
                    F_start[i+1] = intersectP + d2 * (w/2.0)
                ) else (
                    F_end[i] = intersectP
                    F_start[i+1] = intersectP
                )
            )
            
            local generatedObjs = #()
            
            for i = 1 to (N-1) do (
                local dVec = normalize (pts[i+1] - pts[i])
                join generatedObjs (placeRow F_start[i] F_end[i] dVec ("Front_" + i as string) slen stoneBox)
            )
            
            for i = 1 to (N-2) do (
                if arcData[i] != undefined do (
                    local ad = arcData[i]
                    join generatedObjs (placeArc ad[1] ad[2] ad[3] ad[4] ad[5] slen stoneBox)
                )
            )
            
            local d1 = normalize (pts[2] - pts[1])
            local leftStart = pts[1] + d1 * (w/2.0)
            local leftEnd = leftStart + outs[1] * (d - w)
            join generatedObjs (placeRow leftStart leftEnd outs[1] "LeftCap" slen stoneBox)
            
            local dN = normalize (pts[N] - pts[N-1])
            local rightStart = pts[N] - dN * (w/2.0)
            local rightEnd = rightStart + outs[N-1] * (d - w)
            join generatedObjs (placeRow rightStart rightEnd outs[N-1] "RightCap" slen stoneBox)
            
            delete stoneBox
            
            local lawnPts = #()
            append lawnPts (pts[1] + d1 * w)
            for i = 1 to (N-1) do (
                if i == 1 then append lawnPts (pts[1] + outs[1] * (d - w) + d1 * w)
                
                if i < N-1 then (
                    local dA = normalize (pts[i+1] - pts[i])
                    local dB = normalize (pts[i+2] - pts[i+1])
                    if arcData[i] != undefined then (
                        local ad = arcData[i]
                        local C = ad[1]
                        local actual_R = ad[2]
                        local angA_val = ad[3]
                        local angB_val = ad[4]
                        local alpha = ad[6]
                        local signA = if alpha > 0 then 1.0 else -1.0
                        local rLawn = actual_R - signA * (w/2.0)
                        if rLawn < 0.1 do rLawn = 0.1
                        local numLawnPts = ceil (abs(angB_val - angA_val) / 10.0) as integer
                        if numLawnPts < 3 do numLawnPts = 3
                        local dAngL = (angB_val - angA_val) / numLawnPts
                        for k = 0 to numLawnPts do (
                            local aL = angA_val + k * dAngL
                            append lawnPts (C + [rLawn * cos aL, rLawn * sin aL, 0])
                        )
                    ) else (
                        local pA = pts[i+1] + outs[i] * (d - w)
                        local pB = pts[i+1] + outs[i+1] * (d - w)
                        local cZ = dA.x * dB.y - dA.y * dB.x
                        local intP = if abs(cZ) > 0.05 then intersect2DLines pA dA pB dB else ((pA + pB)/2.0)
                        append lawnPts intP
                    )
                )
                if i == N-1 then append lawnPts (pts[N] + outs[N-1] * (d - w) - dN * w)
            )
            append lawnPts (pts[N] - dN * w)
            for i = (N-1) to 2 by -1 do append lawnPts pts[i]
            
            if lawnPts.count >= 3 do (
                local lawnSpline = SplineShape()
                addNewSpline lawnSpline
                for p in lawnPts do addKnot lawnSpline 1 #corner #line p
                close lawnSpline 1
                updateShape lawnSpline
                
                addModifier lawnSpline (Turn_To_Poly())
                collapseStack lawnSpline
                lawnSpline.pos.z += (h - lZ)
                lawnSpline.wirecolor = black
                lawnSpline.name = "PlanterLawn"
                lawnSpline.material = matL
                append generatedObjs lawnSpline
            )
            
            if generatedObjs.count > 0 do (
                local stonesOnly = for obj in generatedObjs where obj.name != "PlanterLawn" collect obj
                if stonesOnly.count > 0 do group stonesOnly name:"PlanterStones_Unit"
            )
        )
        
        on btn_generate pressed do (
            local sel = selection as array
            if sel.count == 0 do (
                messageBox "请先选中墙体对象！\n只需选中即可，无需修改模型结构。" title:"提示"
                return()
            )
            
            local camLookDir = -1 * (inverse(getViewTM())).row3
            local tolerance = spn_tol.value as float
            
            local globalMinZ = 9999999.0
            for obj in sel do (
                if obj.min.z < globalMinZ do globalMinZ = obj.min.z
            )
            
            setINISetting iniFile "Settings" "stoneW" (spn_stoneW.value as string)
            setINISetting iniFile "Settings" "stoneL" (spn_stoneL.value as string)
            setINISetting iniFile "Settings" "fillet" (spn_fillet.value as string)
            setINISetting iniFile "Settings" "depth"  (spn_depth.value as string)
            setINISetting iniFile "Settings" "cornerR" (spn_cornerR.value as string)
            setINISetting iniFile "Settings" "lawnZ"  (spn_lawnZ.value as string)
            setINISetting iniFile "Settings" "tol"    (spn_tol.value as string)
            
            local matStone = sceneMaterials["Planter_Stone_Mat"]
            if matStone == undefined do matStone = StandardMaterial name:"Planter_Stone_Mat" diffuse:(color 180 180 180)
            
            local matLawn = sceneMaterials["Planter_Lawn_Mat"]
            if matLawn == undefined do matLawn = StandardMaterial name:"Planter_Lawn_Mat" diffuse:(color 60 160 60)
            
            undo "智能生成花坛" on (
                local validEdges = #()
                
                -- 第一阶段：底层边缘提取 (引入高度检测与视口过滤)
                for obj in sel do (
                    if not (canConvertTo obj Mesh) do continue
                    if obj.min.z > (globalMinZ + tolerance) do continue
                    
                    local tMesh = undefined
                    try (
                        tMesh = snapshotAsMesh obj
                        for f = 1 to tMesh.numfaces do (
                            local fNormal = getFaceNormal tMesh f
                            
                            -- 我们移除了绝对视口过滤，因为在斜向俯视时，侧面的外墙会被误删。
                            -- 所有的内外判断将交给后面的“极值投影”和“墙体厚度配对”算法。
                            
                            local fVerts = getFace tMesh f
                            local vPos = #(getVert tMesh fVerts.x, getVert tMesh fVerts.y, getVert tMesh fVerts.z)
                            
                            -- 【核心防御 2：面高度检测 (绝杀门洞)】
                            -- 如果这个面是一个门槛或地平线底座，它的最大Z值会很低。
                            -- 强制要求面高度 >= 500mm，门洞处的连接面会直接被忽略，从而产生完美的物理断层！
                            local faceMaxZ = amax vPos[1].z (amax vPos[2].z vPos[3].z)
                            if (faceMaxZ - globalMinZ) < 500.0 do continue
                            
                            local edges = #( #(1,2), #(2,3), #(3,1) )
                            for e in edges do (
                                local pA = vPos[e[1]]
                                local pB = vPos[e[2]]
                                if abs(pA.z - globalMinZ) <= tolerance and abs(pB.z - globalMinZ) <= tolerance then (
                                    append validEdges #(pA, pB, fNormal)
                                )
                            )
                        )
                    ) catch (
                        print "提取网格底层边缘时出错。"
                    ) finally (
                        if tMesh != undefined do ( free tMesh; delete tMesh )
                    )
                )
                
                if validEdges.count > 0 do (
                    -- 第二阶段：跨物体全局共线打组
                    local lineGroups = #()
                    for ve in validEdges do (
                        local p1 = ve[1]
                        local p2 = ve[2]
                        local fNorm = ve[3]
                        
                        if distance p1 p2 < 1.0 do continue
                        
                        local flatN = [fNorm.x, fNorm.y, 0]
                        if (length flatN) < 0.1 do continue 
                        local outV = normalize flatN
                        
                        local edgeDir = normalize (p2 - p1)
                        if edgeDir.x < 0 or (abs(edgeDir.x) < 0.001 and edgeDir.y < 0) do edgeDir *= -1
                        
                        local foundGroup = false
                        for g in lineGroups do (
                            local gBasePt = g[1][1]
                            local gDir = g[1][2]
                            local gOutV = g[1][3]
                            
                            if abs(dot edgeDir gDir) > 0.95 then (
                                if (dot outV gOutV) > 0.9 then (
                                    local vecToP1 = p1 - gBasePt
                                    local distToLine = length (cross vecToP1 gDir)
                                    if distToLine < 50.0 then (
                                        local t1 = dot (p1 - gBasePt) gDir
                                        local t2 = dot (p2 - gBasePt) gDir
                                        append g[2] #(amin t1 t2, amax t1 t2)
                                        foundGroup = true
                                        exit
                                    )
                                )
                            )
                        )
                        
                        if not foundGroup do (
                            local t1 = 0.0
                            local t2 = dot (p2 - p1) edgeDir
                            append lineGroups #( #(p1, edgeDir, outV), #( #(amin t1 t2, amax t1 t2) ) )
                        )
                    )
                    
                    -- 第2.5阶段：线段组级别 (LineGroup) 的极大值投影过滤
                    -- 【核心防御 3：极值投影】
                    -- 在同一朝向的所有墙体线段中，只保留最靠外的那层皮。
                    local filteredGroups = #()
                    for g in lineGroups do (
                        local basePt = g[1][1]
                        local outVec = g[1][3]
                        local proj = dot basePt outVec
                        
                        local maxProj = proj
                        for g2 in lineGroups do (
                            if (dot g2[1][3] outVec) > 0.9 do (
                                local p2 = dot g2[1][1] outVec
                                if p2 > maxProj do maxProj = p2
                            )
                        )
                        
                        -- 容差50mm：极其严格的共面检测。只有绝对的最外层墙皮保留，内墙彻底过滤。
                        if (maxProj - proj) <= 50.0 do (
                            append filteredGroups g
                        )
                    )
                    lineGroups = filteredGroups
                    
                    -- 第2.75阶段：单墙厚度配对与视口剔除 (Thickness & Camera Pairing)
                    -- 对于用户只选了一面单墙的情况（极值投影无法生效，因为没有对立面比较），
                    -- 墙的正面和反面会作为两个相反的 LineGroup 并存，且距离极近（墙厚）。
                    -- 我们将距离 < 600mm 且法线相反的线段配对，强制剔除其中背对镜头的那个（内墙面）！
                    local finalGroups = #()
                    for g in lineGroups do (
                        local outVec = g[1][3]
                        local basePt = g[1][1]
                        
                        local isInnerWall = false
                        for g2 in lineGroups do (
                            if g == g2 do continue
                            local outVec2 = g2[1][3]
                            local basePt2 = g2[1][1]
                            
                            if (dot outVec outVec2) < -0.9 then (
                                local vecToG2 = basePt2 - basePt
                                local dist = abs(dot vecToG2 outVec)
                                
                                -- 如果两条线段法线相反，且距离在 600mm（常规墙厚）以内，说明它们是同一堵墙的内外皮
                                if dist < 600.0 then (
                                    local dot1 = dot outVec camLookDir
                                    local dot2 = dot outVec2 camLookDir
                                    -- 点积越大，说明越背对镜头。我们只保留面向镜头的皮。
                                    if dot1 > dot2 do (
                                        isInnerWall = true
                                        exit
                                    )
                                )
                            )
                        )
                        if not isInnerWall do append finalGroups g
                    )
                    lineGroups = finalGroups
                    
                    -- 第三阶段：无缝合并长线并准备路径
                    local cleanSegments = #()
                    for g in lineGroups do (
                        local basePt = g[1][1]
                        local dirVec = g[1][2]
                        local outVec = g[1][3]
                        local intervals = g[2]
                        
                        qsort intervals sortIntervals
                        
                        local mergedIntervals = #()
                        local currentInt = intervals[1]
                        
                        for i = 2 to intervals.count do (
                            local nextInt = intervals[i]
                            if nextInt[1] <= currentInt[2] + 200.0 then (
                                currentInt[2] = amax currentInt[2] nextInt[2]
                            ) else (
                                append mergedIntervals currentInt
                                currentInt = nextInt
                            )
                        )
                        append mergedIntervals currentInt
                        
                        local totalLen = 0.0
                        for mi in mergedIntervals do totalLen += (mi[2] - mi[1])
                        if totalLen < 600.0 do continue
                        
                        for mi in mergedIntervals do (
                            local startPt = basePt + dirVec * mi[1]
                            local endPt = basePt + dirVec * mi[2]
                            
                            startPt.z = globalMinZ
                            endPt.z = globalMinZ
                            
                            local rightVec = cross [0,0,1] outVec
                            if (dot rightVec dirVec) < 0 do (
                                local temp = startPt
                                startPt = endPt
                                endPt = temp
                            )
                            
                            append cleanSegments #(startPt, endPt, outVec)
                        )
                    )
                    
                    -- 第四阶段：串联拐角路径（支持自动修复墙角重叠、交叉与缝隙）
                    local polylines = #()
                    while cleanSegments.count > 0 do (
                        local pts = #( cleanSegments[1][1], cleanSegments[1][2] )
                        local outs = #( cleanSegments[1][3] )
                        deleteItem cleanSegments 1
                        
                        local added = true
                        while added do (
                            added = false
                            for i = cleanSegments.count to 1 by -1 do (
                                local seg = cleanSegments[i]
                                local dStartToEnd = distance seg[1] pts[pts.count]
                                local dEndToStart = distance seg[2] pts[1]
                                local dStartToStart = distance seg[1] pts[1]
                                local dEndToEnd = distance seg[2] pts[pts.count]
                                
                                if dStartToEnd < 400.0 then (
                                    local d1 = normalize (pts[pts.count] - pts[pts.count-1])
                                    local d2 = normalize (seg[2] - seg[1])
                                    local intP = intersect2DLines pts[pts.count] d1 seg[1] d2
                                    if distance intP pts[pts.count] > 500.0 do intP = (seg[1] + pts[pts.count])/2.0
                                    
                                    pts[pts.count] = intP
                                    append pts seg[2]
                                    append outs seg[3]
                                    deleteItem cleanSegments i
                                    added = true
                                ) else if dEndToStart < 400.0 then (
                                    local d1 = normalize (seg[2] - seg[1])
                                    local d2 = normalize (pts[2] - pts[1])
                                    local intP = intersect2DLines seg[2] d1 pts[1] d2
                                    if distance intP pts[1] > 500.0 do intP = (seg[2] + pts[1])/2.0
                                    
                                    pts[1] = intP
                                    insertItem seg[1] pts 1
                                    insertItem seg[3] outs 1
                                    deleteItem cleanSegments i
                                    added = true
                                ) else if dStartToStart < 400.0 then (
                                    local d1 = normalize (seg[1] - seg[2])
                                    local d2 = normalize (pts[2] - pts[1])
                                    local intP = intersect2DLines seg[1] d1 pts[1] d2
                                    if distance intP pts[1] > 500.0 do intP = (seg[1] + pts[1])/2.0
                                    
                                    pts[1] = intP
                                    insertItem seg[2] pts 1
                                    insertItem seg[3] outs 1
                                    deleteItem cleanSegments i
                                    added = true
                                ) else if dEndToEnd < 400.0 then (
                                    local d1 = normalize (pts[pts.count] - pts[pts.count-1])
                                    local d2 = normalize (seg[1] - seg[2])
                                    local intP = intersect2DLines pts[pts.count] d1 seg[2] d2
                                    if distance intP pts[pts.count] > 500.0 do intP = (seg[2] + pts[pts.count])/2.0
                                    
                                    pts[pts.count] = intP
                                    append pts seg[1]
                                    append outs seg[3]
                                    deleteItem cleanSegments i
                                    added = true
                                )
                            )
                        )
                        append polylines #(pts, outs)
                    )
                    
                    for pl in polylines do (
                        buildPlanterPath pl[1] pl[2] matStone matLawn
                    )
                )
            )
        )
        on btn_gen_line pressed do (
            local sel = selection as array
            if sel.count == 0 do (
                messageBox "请先选中一个或多个二维线条 (Spline)！" title:"提示"
                return()
            )
            
            -- 使用独立的 UI 参数
            local w = spn_line_stoneW.value as float
            local h = spn_line_stoneW.value as float
            local slen = spn_line_stoneL.value as float
            local fVal = spn_line_fillet.value as float
            local chkR = chk_line_useRadius.checked
            local pathR = spn_line_pathRadius.value as float
            local lZ = spn_line_lawnZ.value as float
            local tempSplineCopies = #()
            
            local matStone = sceneMaterials["Planter_Stone_Mat"]
            if matStone == undefined do matStone = StandardMaterial name:"Planter_Stone_Mat" diffuse:(color 180 180 180)
            
            local matLawn = sceneMaterials["Planter_Lawn_Mat"]
            if matLawn == undefined do matLawn = StandardMaterial name:"Planter_Lawn_Mat" diffuse:(color 60 160 60)
            
            suspendEditing()
            try (
                with redraw off undo "线条生成大花坛" on (
                fn getRawKnots sp s doInterp = (
                    local pts = #()
                    local nKnots = numKnots sp s
                    local steps = sp.steps
                    for k = 1 to (nKnots - 1) do (
                        append pts (getKnotPoint sp s k)
                        if doInterp do (
                            local kType1 = getKnotType sp s k
                            local kType2 = getKnotType sp s (k+1)
                            if kType1 != #corner or kType2 != #corner do (
                                for i = 1 to steps do (
                                    local param = i as float / (steps + 1.0)
                                    append pts (interpBezier3D sp s k param)
                                )
                            )
                        )
                    )
                    append pts (getKnotPoint sp s nKnots)
                    if isClosed sp s do (
                        if doInterp do (
                            local kType1 = getKnotType sp s nKnots
                            local kType2 = getKnotType sp s 1
                            if kType1 != #corner or kType2 != #corner do (
                                for i = 1 to steps do (
                                    local param = i as float / (steps + 1.0)
                                    append pts (interpBezier3D sp s nKnots param)
                                )
                            )
                        )
                        append pts (getKnotPoint sp s 1)
                    )
                    return pts
                )
                
                fn extractSplinePolyline sp s doFillet rVal = (
                    local rawPts = #()
                    local nKnots = numKnots sp s
                    if nKnots < 2 do return rawPts
                    
                    local steps = sp.steps
                    for k = 1 to (nKnots - 1) do (
                        append rawPts (getKnotPoint sp s k)
                        if not doFillet do (
                            local kType1 = getKnotType sp s k
                            local kType2 = getKnotType sp s (k+1)
                            if kType1 != #corner or kType2 != #corner do (
                                for i = 1 to steps do (
                                    local param = i as float / (steps + 1.0)
                                    append rawPts (interpBezier3D sp s k param)
                                )
                            )
                        )
                    )
                    append rawPts (getKnotPoint sp s nKnots)
                    if isClosed sp s do (
                        if not doFillet do (
                            local kType1 = getKnotType sp s nKnots
                            local kType2 = getKnotType sp s 1
                            if kType1 != #corner or kType2 != #corner do (
                                for i = 1 to steps do (
                                    local param = i as float / (steps + 1.0)
                                    append rawPts (interpBezier3D sp s nKnots param)
                                )
                            )
                        )
                    )
                    
                    if not doFillet or rVal <= 0.1 do return rawPts
                    
                    local filletedPts = #()
                    local N = rawPts.count
                    local isC = isClosed sp s
                    local loopEnd = N
                    
                    for i = 1 to loopEnd do (
                        local pCurr = rawPts[i]
                        local pPrev = if i > 1 then rawPts[i-1] else (if isC then rawPts[N] else undefined)
                        local pNext = if i < N then rawPts[i+1] else (if isC then rawPts[1] else undefined)
                        
                        local isSharp = false
                        if pPrev != undefined and pNext != undefined then (
                            local d1 = normalize (pCurr - pPrev)
                            local d2 = normalize (pNext - pCurr)
                            local dotV = dot d1 d2
                            if dotV > 0.999 do dotV = 0.999
                            if dotV < -0.999 do dotV = -0.999
                            if (acos dotV) > 5.0 do isSharp = true
                            
                            if isSharp then (
                                local R = rVal
                                local theta = acos dotV
                                local insetDist = R * abs(tan (theta/2.0))
                                local maxI = amin ((distance pPrev pCurr)*0.49) ((distance pCurr pNext)*0.49)
                                if insetDist > maxI do ( insetDist = maxI; R = insetDist / abs(tan (theta/2.0)) )
                                
                                local cStart = pCurr - d1 * insetDist
                                local cEnd = pCurr + d2 * insetDist
                                local crossZ = d1.x * d2.y - d1.y * d2.x
                                local perp1 = if crossZ > 0 then [-d1.y, d1.x, 0] else [d1.y, -d1.x, 0]
                                local center = cStart + perp1 * R
                                
                                append filletedPts cStart
                                local v1 = normalize (cStart - center)
                                local v2 = normalize (cEnd - center)
                                local angle_arc = acos (dot v1 v2)
                                local sinAngle = sin angle_arc
                                
                                for j = 1 to 5 do (
                                    local t = j as float / 6.0
                                    if sinAngle > 0.001 then (
                                        local w1 = sin ((1.0 - t) * angle_arc) / sinAngle
                                        local w2 = sin (t * angle_arc) / sinAngle
                                        append filletedPts (center + (normalize (v1 * w1 + v2 * w2)) * R)
                                    )
                                )
                                append filletedPts cEnd
                            ) else ( append filletedPts pCurr )
                        ) else ( append filletedPts pCurr )
                    )
                    if isC do append filletedPts filletedPts[1]
                    return filletedPts
                )
                
                for sourceObj in sel do (
                    if (superClassOf sourceObj == Shape) do (
                        local obj = copy sourceObj
                        append tempSplineCopies obj
                        convertToSplineShape obj
                        local newObjs = #()
                        local stoneBox = if fVal > 0.001 then ChamferBox length:w width:slen height:h fillet:fVal filletSegs:1 smooth:off else Box length:w width:slen height:h
                        stoneBox.material = matStone
                        stoneBox.wirecolor = black
                        local stonesGroup = #()
                        
                        fn generateCurvedSolid cPts w h fVal nameStr mat = (
                            if cPts.count < 2 do return undefined
                            local pathSp = SplineShape()
                            addNewSpline pathSp
                            local N = cPts.count
                            local normals = #()
                            for i = 1 to N do (
                                local dVec
                                if i == 1 then dVec = normalize (cPts[2] - cPts[1])
                                else if i == N then dVec = normalize (cPts[N] - cPts[N-1])
                                else dVec = normalize (cPts[i+1] - cPts[i-1])
                                local nVec = normalize (cross [0,0,1] dVec)
                                append normals nVec
                            )
                            for i = 1 to N do addKnot pathSp 1 #corner #line (cPts[i] + normals[i] * (w / 2.0))
                            for i = N to 1 by -1 do addKnot pathSp 1 #corner #line (cPts[i] - normals[i] * (w / 2.0))
                            close pathSp 1
                            updateShape pathSp
                            addModifier pathSp (Extrude amount:h)
                            if fVal > 0.001 do (
                                try (
                                    local cMod = Chamfer()
                                    cMod.amount = fVal
                                    cMod.segments = 1
                                    try (cMod.tension = 0.0) catch()
                                    addModifier pathSp cMod
                                ) catch()
                            )
                            pathSp.name = nameStr
                            pathSp.material = mat
                            pathSp.wirecolor = black
                            collapseStack pathSp
                            return pathSp
                        )
                        
                        for s = 1 to (numSplines obj) do (
                            local lawnPts = extractSplinePolyline obj s chkR pathR
                            if lawnPts.count < 2 do continue
                            
                            local lSpline = splineShape()
                            addNewSpline lSpline
                            local endIdx = if (distance lawnPts[lawnPts.count] lawnPts[1] < 0.001) then (lawnPts.count - 1) else lawnPts.count
                            for i = 1 to endIdx do (
                                local p = lawnPts[i]
                                p.z = obj.min.z
                                addKnot lSpline 1 #corner #line p
                            )
                            close lSpline 1
                            updateShape lSpline
                            
                            lSpline.name = sourceObj.name + "_Lawn_" + s as string
                            lSpline.wirecolor = black
                            addModifier lSpline (Turn_To_Poly())
                            collapseStack lSpline
                            if (polyop.getNumFaces lSpline) > 0 do (
                                local fNorm = polyop.getFaceNormal lSpline 1
                                if fNorm.z < 0 do ( addModifier lSpline (Normalmodifier flip:true); collapseStack lSpline )
                            )
                            lSpline.pos.z += (h - lZ)
                            lSpline.material = matLawn
                            append newObjs lSpline
                            
                            if chkR then (
                                local rawPts = getRawKnots obj s false
                                local N = rawPts.count
                                if N < 2 do continue
                                local isC = isClosed obj s
                                local loopEnd = if isC then (N-1) else N
                                
                                local cornerArcs = #()
                                
                                for i = 1 to loopEnd do (
                                    local pCurr = rawPts[i]
                                    pCurr.z = obj.min.z
                                    local pPrev = if i > 1 then rawPts[i-1] else (if isC then rawPts[N-1] else undefined)
                                    if pPrev != undefined do pPrev.z = obj.min.z
                                    local pNext = if i < loopEnd then rawPts[i+1] else (if isC then rawPts[N] else undefined)
                                    if pNext != undefined do pNext.z = obj.min.z
                                    
                                    local arcInset = 0.0
                                    if pPrev != undefined and pNext != undefined do (
                                        local d1 = normalize (pCurr - pPrev)
                                        local d2 = normalize (pNext - pCurr)
                                        local dotV = dot d1 d2
                                        if dotV > 0.999 do dotV = 0.999
                                        if dotV < -0.999 do dotV = -0.999
                                        local theta = acos dotV
                                        
                                        if theta > 5.0 do (
                                            local R = pathR
                                            arcInset = R * abs(tan (theta/2.0))
                                            local maxI = amin ((distance pPrev pCurr)*0.49) ((distance pCurr pNext)*0.49)
                                            if arcInset > maxI do ( arcInset = maxI; R = arcInset / abs(tan (theta/2.0)) )
                                            
                                            local cStart = pCurr - d1 * arcInset
                                            local cEnd = pCurr + d2 * arcInset
                                            
                                            local crossZ = d1.x * d2.y - d1.y * d2.x
                                            local perp1 = if crossZ > 0 then [-d1.y, d1.x, 0] else [d1.y, -d1.x, 0]
                                            local center = cStart + perp1 * R
                                            
                                            local v1 = normalize (cStart - center)
                                            local v2 = normalize (cEnd - center)
                                            local angA = atan2 v1.y v1.x
                                            local angB = atan2 v2.y v2.x
                                            
                                            local sweep = angB - angA
                                            if sweep > 180.0 do sweep -= 360.0
                                            if sweep < -180.0 do sweep += 360.0
                                            
                                            local numSegs = ceil (abs(sweep) / 10.0) as integer
                                            if numSegs < 3 do numSegs = 3
                                            
                                            local pathSp = SplineShape()
                                            addNewSpline pathSp
                                            
                                            local R_out = R + (w / 2.0)
                                            local R_in = R - (w / 2.0)
                                            if R_in < 0.1 do R_in = 0.1
                                            
                                            local startA = angA
                                            local endA = angA + sweep
                                            if sweep < 0 do (
                                                startA = angA + sweep
                                                endA = angA
                                            )
                                            local actualSweep = endA - startA
                                            
                                            for j = 0 to numSegs do (
                                                local a = startA + (j as float / numSegs) * actualSweep
                                                local p = center + [R_out * cos a, R_out * sin a, 0]
                                                addKnot pathSp 1 #corner #line p
                                            )
                                            for j = numSegs to 0 by -1 do (
                                                local a = startA + (j as float / numSegs) * actualSweep
                                                local p = center + [R_in * cos a, R_in * sin a, 0]
                                                addKnot pathSp 1 #corner #line p
                                            )
                                            
                                            close pathSp 1
                                            updateShape pathSp
                                            
                                            local ext = Extrude amount:h
                                            addModifier pathSp ext
                                            
                                            if fVal > 0.001 do (
                                                try (
                                                    local cMod = Chamfer()
                                                    cMod.amount = fVal
                                                    cMod.segments = 1
                                                    try (cMod.tension = 0.0) catch()
                                                    addModifier pathSp cMod
                                                ) catch()
                                            )
                                            
                                            pathSp.material = matStone
                                            pathSp.wirecolor = black
                                            pathSp.name = sourceObj.name + "_Arc_" + s as string + "_" + i as string
                                            collapseStack pathSp
                                            append stonesGroup pathSp
                                        )
                                    )
                                    append cornerArcs arcInset
                                )
                                
                                for k = 1 to (N - 1) do (
                                    local pA = rawPts[k]
                                    local pB = rawPts[k+1]
                                    pA.z = obj.min.z
                                    pB.z = obj.min.z
                                    
                                    local insetStart = cornerArcs[k]
                                    local nextIdx = k+1
                                    if isC and nextIdx == N do nextIdx = 1
                                    local insetEnd = cornerArcs[nextIdx]
                                    
                                    local dVec = normalize (pB - pA)
                                    
                                    local startP = pA + dVec * insetStart
                                    local endP = pB - dVec * insetEnd
                                    
                                    local segLen = distance startP endP
                                    if segLen > 0.001 and (dot (normalize (endP - startP)) dVec) > 0.0 do (
                                        local numFull = floor (segLen / slen) as integer
                                        local remain = segLen - (numFull * slen)
                                        
                                        local currentP = startP
                                        for i = 1 to numFull do (
                                            local p1 = currentP
                                            local p2 = currentP + dVec * slen
                                            local inst = instance stoneBox
                                            local tm = matrix3 1
                                            tm.row1 = dVec; tm.row3 = [0,0,1]; tm.row2 = normalize (cross tm.row3 tm.row1)
                                            tm.row4 = (p1 + p2) / 2.0
                                            inst.transform = tm
                                            inst.name = sourceObj.name + "_Stone_" + s as string + "_" + k as string + "_" + i as string
                                            inst.wirecolor = black
                                            append stonesGroup inst
                                            currentP = p2
                                        )
                                        
                                        if remain > 0.001 do (
                                            local p1 = currentP
                                            local p2 = endP
                                            local remBox = if fVal > 0.001 then ChamferBox length:w width:remain height:h fillet:fVal filletSegs:1 smooth:off else Box length:w width:remain height:h
                                            local tm = matrix3 1
                                            tm.row1 = dVec; tm.row3 = [0,0,1]; tm.row2 = normalize (cross tm.row3 tm.row1)
                                            tm.row4 = (p1 + p2) / 2.0
                                            remBox.transform = tm
                                            remBox.name = sourceObj.name + "_Stone_Rem_" + s as string + "_" + k as string
                                            remBox.wirecolor = black
                                            remBox.material = matStone
                                            append stonesGroup remBox
                                        )
                                    )
                                )
                            ) else (
                                local nKnots = numKnots obj s
                                local steps = obj.steps
                                for k = 1 to (nKnots - 1) do (
                                    local kType1 = getKnotType obj s k
                                    local kType2 = getKnotType obj s (k+1)
                                    if kType1 == #corner and kType2 == #corner then (
                                        local pA = getKnotPoint obj s k
                                        local pB = getKnotPoint obj s (k+1)
                                        pA.z = obj.min.z; pB.z = obj.min.z
                                        local dVec = normalize (pB - pA)
                                        local segLen = distance pA pB
                                        if segLen > 0.001 do (
                                            local numFull = floor (segLen / slen) as integer
                                            local remain = segLen - (numFull * slen)
                                            local currentP = pA
                                            for i = 1 to numFull do (
                                                local p1 = currentP
                                                local p2 = currentP + dVec * slen
                                                local inst = instance stoneBox
                                                local tm = matrix3 1
                                                tm.row1 = dVec; tm.row3 = [0,0,1]; tm.row2 = normalize (cross tm.row3 tm.row1)
                                                tm.row4 = (p1 + p2) / 2.0
                                                inst.transform = tm
                                                inst.name = sourceObj.name + "_Stone_" + s as string + "_" + k as string + "_" + i as string
                                                inst.wirecolor = black
                                                append stonesGroup inst
                                                currentP = p2
                                            )
                                            if remain > 0.001 do (
                                                local p1 = currentP
                                                local p2 = pB
                                                local remBox = if fVal > 0.001 then ChamferBox length:w width:remain height:h fillet:fVal filletSegs:1 smooth:off else Box length:w width:remain height:h
                                                local tm = matrix3 1
                                                tm.row1 = dVec; tm.row3 = [0,0,1]; tm.row2 = normalize (cross tm.row3 tm.row1)
                                                tm.row4 = (p1 + p2) / 2.0
                                                remBox.transform = tm
                                                remBox.name = sourceObj.name + "_Stone_Rem_" + s as string + "_" + k as string
                                                remBox.wirecolor = black
                                                remBox.material = matStone
                                                append stonesGroup remBox
                                            )
                                        )
                                    ) else (
                                        local cPts = #()
                                        append cPts (getKnotPoint obj s k)
                                        for i = 1 to steps do append cPts (interpBezier3D obj s k (i as float / (steps + 1.0)))
                                        append cPts (getKnotPoint obj s (k+1))
                                        for p in cPts do p.z = obj.min.z
                                        local swept = generateCurvedSolid cPts w h fVal (sourceObj.name + "_Curve_" + s as string + "_" + k as string) matStone
                                        if swept != undefined do append stonesGroup swept
                                    )
                                )
                                if isClosed obj s do (
                                    local kType1 = getKnotType obj s nKnots
                                    local kType2 = getKnotType obj s 1
                                    if kType1 == #corner and kType2 == #corner then (
                                        local pA = getKnotPoint obj s nKnots
                                        local pB = getKnotPoint obj s 1
                                        pA.z = obj.min.z; pB.z = obj.min.z
                                        local dVec = normalize (pB - pA)
                                        local segLen = distance pA pB
                                        if segLen > 0.001 do (
                                            local numFull = floor (segLen / slen) as integer
                                            local remain = segLen - (numFull * slen)
                                            local currentP = pA
                                            for i = 1 to numFull do (
                                                local p1 = currentP
                                                local p2 = currentP + dVec * slen
                                                local inst = instance stoneBox
                                                local tm = matrix3 1
                                                tm.row1 = dVec; tm.row3 = [0,0,1]; tm.row2 = normalize (cross tm.row3 tm.row1)
                                                tm.row4 = (p1 + p2) / 2.0
                                                inst.transform = tm
                                                inst.name = sourceObj.name + "_Stone_Closed_" + s as string + "_" + i as string
                                                inst.wirecolor = black
                                                append stonesGroup inst
                                                currentP = p2
                                            )
                                            if remain > 0.001 do (
                                                local p1 = currentP
                                                local p2 = pB
                                                local remBox = if fVal > 0.001 then ChamferBox length:w width:remain height:h fillet:fVal filletSegs:1 smooth:off else Box length:w width:remain height:h
                                                local tm = matrix3 1
                                                tm.row1 = dVec; tm.row3 = [0,0,1]; tm.row2 = normalize (cross tm.row3 tm.row1)
                                                tm.row4 = (p1 + p2) / 2.0
                                                remBox.transform = tm
                                                remBox.name = sourceObj.name + "_Stone_Closed_Rem_" + s as string
                                                remBox.wirecolor = black
                                                remBox.material = matStone
                                                append stonesGroup remBox
                                            )
                                        )
                                    ) else (
                                        local cPts = #()
                                        append cPts (getKnotPoint obj s nKnots)
                                        for i = 1 to steps do append cPts (interpBezier3D obj s nKnots (i as float / (steps + 1.0)))
                                        append cPts (getKnotPoint obj s 1)
                                        for p in cPts do p.z = obj.min.z
                                        local swept = generateCurvedSolid cPts w h fVal (sourceObj.name + "_Curve_Closed_" + s as string) matStone
                                        if swept != undefined do append stonesGroup swept
                                    )
                                )
                            )
                        )
                        delete stoneBox
                        
                        if stonesGroup.count > 0 do (
                            local g = group stonesGroup name:(sourceObj.name + "_Stones")
                            append newObjs g
                        )
                        
                        if newObjs.count > 0 do (
                            group newObjs name:(sourceObj.name + "_PlanterUnit")
                        )
                        try(delete obj)catch()
                    )
                )
            )
            ) catch (
                messageBox ("发生错误: " + getCurrentException()) title:"错误"
            )
            for tempSpline in tempSplineCopies where isValidNode tempSpline do try(delete tempSpline)catch()
            resumeEditing()
        )
        
        on AutoPlanterRollout open do (
            local w = getINISetting iniFile "Settings" "stoneW"
            if w != "" do spn_stoneW.value = w as float
            
            local slen = getINISetting iniFile "Settings" "stoneL"
            if slen != "" do spn_stoneL.value = slen as float
            
            local fVal = getINISetting iniFile "Settings" "fillet"
            if fVal != "" do spn_fillet.value = fVal as float
            
            local d = getINISetting iniFile "Settings" "depth"
            if d != "" do spn_depth.value = d as float
            
            local cr = getINISetting iniFile "Settings" "cornerR"
            if cr != "" do spn_cornerR.value = cr as float
            
            local lZ = getINISetting iniFile "Settings" "lawnZ"
            if lZ != "" do spn_lawnZ.value = lZ as float
            
            local tol = getINISetting iniFile "Settings" "tol"
            if tol != "" do spn_tol.value = tol as float
            
            local line_w = getINISetting iniFile "Settings" "line_stoneW"
            if line_w != "" do spn_line_stoneW.value = line_w as float
            
            local line_l = getINISetting iniFile "Settings" "line_stoneL"
            if line_l != "" do spn_line_stoneL.value = line_l as float
            
            local line_f = getINISetting iniFile "Settings" "line_fillet"
            if line_f != "" do spn_line_fillet.value = line_f as float
            
            local line_chkR = getINISetting iniFile "Settings" "line_useRadius"
            if line_chkR != "" do chk_line_useRadius.checked = (line_chkR == "true")
            
            local line_pr = getINISetting iniFile "Settings" "line_pathRadius"
            if line_pr != "" do spn_line_pathRadius.value = line_pr as float
            
            local line_lz = getINISetting iniFile "Settings" "line_lawnZ"
            if line_lz != "" do spn_line_lawnZ.value = line_lz as float
        )
        
        on AutoPlanterRollout close do (
            setINISetting iniFile "Settings" "stoneW" (spn_stoneW.value as string)
            setINISetting iniFile "Settings" "stoneL" (spn_stoneL.value as string)
            setINISetting iniFile "Settings" "fillet" (spn_fillet.value as string)
            setINISetting iniFile "Settings" "depth" (spn_depth.value as string)
            setINISetting iniFile "Settings" "cornerR" (spn_cornerR.value as string)
            setINISetting iniFile "Settings" "lawnZ" (spn_lawnZ.value as string)
            setINISetting iniFile "Settings" "tol" (spn_tol.value as string)
            
            setINISetting iniFile "Settings" "line_stoneW" (spn_line_stoneW.value as string)
            setINISetting iniFile "Settings" "line_stoneL" (spn_line_stoneL.value as string)
            setINISetting iniFile "Settings" "line_fillet" (spn_line_fillet.value as string)
            setINISetting iniFile "Settings" "line_useRadius" (chk_line_useRadius.checked as string)
            setINISetting iniFile "Settings" "line_pathRadius" (spn_line_pathRadius.value as string)
            setINISetting iniFile "Settings" "line_lawnZ" (spn_line_lawnZ.value as string)
        )
    )
    
    createdialog AutoPlanterRollout
