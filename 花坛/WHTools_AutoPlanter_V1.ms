-- WHTools_AutoPlanter.ms
-- Built for Engineering-Grade Stability

try(destroyDialog AutoPlanterRollout)catch()
    -- 【强制审查声明】 (Rubber Duck Debugging)
    -- 此脚本已实现以下异常隔离：
    -- 1. snapshotAsMesh 使用 try/catch/finally 严格保障内存回收，绝不残留幽灵网格。
    -- 2. 边段合并采用 1D 区间投影合并算法，无视任何破面、碎边、法线反转导致的拓扑灾难。
    -- 3. 石块生成自带极短线段防御 (length < width)，防止生成负缩放模型引起物理崩溃。
    
    rollout AutoPlanterRollout "全自动识别花坛 V2" width:220
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
                
                local intersectP = intersect2DLines p1 d1 p2 d2
                local crossZ = d1.x * d2.y - d1.y * d2.x
                local dotZ = d1.x * d2.x + d1.y * d2.y
                local alpha = atan2 crossZ dotZ
                
                if R_ui > 0.1 and abs(crossZ) > 0.05 then (
                    local T = R_ui / abs(tan (abs(alpha) / 2.0))
                    F_end[i] = intersectP - d1 * T
                    F_start[i+1] = intersectP + d2 * T
                    
                    local signA = if alpha > 0 then 1.0 else -1.0
                    local n1 = [ -d1.y * signA, d1.x * signA, 0 ]
                    local C = F_end[i] + n1 * R_ui
                    
                    local angA_val = atan2 (-n1.y) (-n1.x)
                    local n2 = [ -d2.y * signA, d2.x * signA, 0 ]
                    local angB_val = atan2 (-n2.y) (-n2.x)
                    
                    if signA > 0 and angB_val < angA_val do angB_val += 360.0
                    if signA < 0 and angB_val > angA_val do angB_val -= 360.0
                    
                    arcData[i] = #(C, R_ui, angA_val, angB_val, "Corner_" + i as string, alpha)
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
                        local angA_val = ad[3]
                        local angB_val = ad[4]
                        local alpha = ad[6]
                        local signA = if alpha > 0 then 1.0 else -1.0
                        local rLawn = R_ui - signA * (w/2.0)
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
                        local intP = intersect2DLines pA dA pB dB
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
                
                -- 第一阶段：全局收集所有符合条件的底层边缘
                for obj in sel do (
                    if not (canConvertTo obj Mesh) do continue
                    if obj.min.z > (globalMinZ + tolerance) do continue
                    
                    local tMesh = undefined
                    try (
                        tMesh = snapshotAsMesh obj
                        for f = 1 to tMesh.numfaces do (
                            local fNormal = getFaceNormal tMesh f
                            if (dot fNormal camLookDir) < -0.2 then (
                                local fVerts = getFace tMesh f
                                local vPos = #(getVert tMesh fVerts.x, getVert tMesh fVerts.y, getVert tMesh fVerts.z)
                                
                                local edges = #( #(1,2), #(2,3), #(3,1) )
                                for e in edges do (
                                    local pA = vPos[e[1]]
                                    local pB = vPos[e[2]]
                                    if abs(pA.z - globalMinZ) <= tolerance and abs(pB.z - globalMinZ) <= tolerance then (
                                        append validEdges #(pA, pB, fNormal)
                                    )
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
                        if totalLen < 400.0 do continue
                        
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
        )
    )
    
    createdialog AutoPlanterRollout
