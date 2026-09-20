-- WHTools_AutoPlanter.ms
-- V3.3 几何外法向第一性原理 (Geometric Outward Normal & Production-Grade Mirror Immunity)

try(destroyDialog AutoPlanterRollout)catch()

rollout AutoPlanterRollout "全自动识别花坛 V3.3" width:220
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
        spinner spn_minWallH "最低识别墙高:" range:[0, 5000, 500] type:#integer
    )
    button btn_generate "智能生成外沿花坛" width:190 height:35
    label lbl_status "状态: 待命" align:#left
    label lbl1 "操作说明：" align:#left
    label lbl2 "1. 选中要生长花坛的墙体模型" align:#left
    label lbl3 "2. 点击上方按钮，侦听器输出诊断日志" align:#left
    
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
    
    -- 辅助数学函数：1D区间排序
    fn sortIntervals i1 i2 = (
        if i1[1] < i2[1] then -1 else if i1[1] > i2[1] then 1 else 0
    )
    
    -- 辅助数学函数：2D射线求交点
    fn intersect2DLines p1 d1 p2 d2 = (
        local crossDet = d1.x * d2.y - d1.y * d2.x
        if abs(crossDet) < 0.001 then return ((p1 + p2) * 0.5)
        local diff = p2 - p1
        local t = (diff.x * d2.y - diff.y * d2.x) / crossDet
        return p1 + d1 * t
    )
    
    -- 圆弧角石生成
    fn placeArc C R angA angB vecName slen stoneBox matStone = (
        local arcLen = R * abs(angB - angA) * pi / 180.0
        if arcLen < 1.0 do return #()
        
        local w = spn_stoneW.value as float
        local h = spn_stoneW.value as float
        local fVal = spn_fillet.value as float
        
        local numSegs = ceil (arcLen / 20.0) as integer
        if numSegs < 3 do numSegs = 3
        
        local startA = angA
        local endA = angB
        if abs(endA - startA) < 0.001 do return #()
        
        local pathSp = SplineShape()
        addNewSpline pathSp
        
        -- 外圈弧线
        local R_out = R + (w / 2.0)
        local dAng = (endA - startA) / (numSegs as float)
        for i = 0 to numSegs do (
            local a = startA + i * dAng
            local p = C + [R_out * cos a, R_out * sin a, 0]
            addKnot pathSp 1 #corner #line p
        )
        
        -- 内圈弧线 (顺时针返回闭合)
        local R_in = R - (w / 2.0)
        if R_in < 0.1 do R_in = 0.1
        for i = numSegs to 0 by -1 do (
            local a = startA + i * dAng
            local p = C + [R_in * cos a, R_in * sin a, 0]
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
            ) catch ()
        )
        
        pathSp.name = "PlanterStone_Arc_" + vecName
        pathSp.wirecolor = black
        if matStone != undefined do pathSp.material = matStone
        try (collapseStack pathSp) catch()
        return #(pathSp)
    )

    -- 直线段石块铺设（规避非均匀缩放压扁倒角）
    fn placeRow startP endP rDir vecName slen stoneBox matStone = (
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
            if matStone != undefined do inst.material = matStone
            append newObjs inst
            currentP += rDir * slen
        )
        if remain > 0.1 do (
            local w0 = spn_stoneW.value as float
            local h0 = spn_stoneW.value as float
            local f0 = spn_fillet.value as float
            local remInst = undefined
            if f0 > 0.001 then (
                remInst = ChamferBox length:w0 width:remain height:h0 fillet:f0 filletSegs:1 smooth:off
            ) else (
                remInst = Box length:w0 width:remain height:h0
            )
            if matStone != undefined do remInst.material = matStone
            local tm = matrix3 1
            tm.row1 = rDir
            tm.row3 = [0,0,1]
            tm.row2 = normalize (cross tm.row3 tm.row1)
            tm.row4 = currentP + rDir * (remain / 2.0)
            remInst.transform = tm
            remInst.name = "PlanterStone_" + vecName + "_Rem"
            remInst.wirecolor = black
            append newObjs remInst
        )
        return newObjs
    )
    
    -- 核心几何生成管线：根据折线构建花坛实体
    fn buildPlanterPath pts outs matS matL = (
        local N = pts.count
        if N < 2 do return #()
        
        local w = spn_stoneW.value as float
        local h = spn_stoneW.value as float
        local slen = spn_stoneL.value as float
        local fVal = spn_fillet.value as float
        local d = spn_depth.value as float
        local R_ui = spn_cornerR.value as float
        local lZ = spn_lawnZ.value as float
        
        local isClosedLoop = (N >= 4 and (distance pts[1] pts[N]) < 5.0)
        
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
                local safeT = amin T (amin (len1 * 0.49) (len2 * 0.49))
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
                local angDeg = abs(alpha) * 180.0 / pi
                if angDeg > 75.0 and angDeg < 105.0 then (
                    F_end[i] = intersectP + d1 * (w/2.0)
                    F_start[i+1] = intersectP + d2 * (w/2.0)
                ) else (
                    F_end[i] = intersectP
                    F_start[i+1] = intersectP
                )
            ) else (
                F_end[i] = intersectP
                F_start[i+1] = intersectP
            )
        )
        
        local generatedObjs = #()
        
        -- 生成外沿主石排
        for i = 1 to (N-1) do (
            local dVec = normalize (pts[i+1] - pts[i])
            join generatedObjs (placeRow F_start[i] F_end[i] dVec ("Front_" + i as string) slen stoneBox matS)
        )
        
        -- 生成圆弧角石
        for i = 1 to (N-2) do (
            if arcData[i] != undefined do (
                local ad = arcData[i]
                join generatedObjs (placeArc ad[1] ad[2] ad[3] ad[4] ad[5] slen stoneBox matS)
            )
        )
        
        -- 生成侧边端头封口石（闭合路径不生成多余封口）
        if not isClosedLoop do (
            local d1 = normalize (pts[2] - pts[1])
            local leftStart = pts[1] + d1 * (w/2.0)
            local leftEnd = leftStart + outs[1] * (d - w)
            join generatedObjs (placeRow leftStart leftEnd outs[1] "LeftCap" slen stoneBox matS)
            
            local dN = normalize (pts[N] - pts[N-1])
            local rightStart = pts[N] - dN * (w/2.0)
            local rightEnd = rightStart + outs[N-1] * (d - w)
            join generatedObjs (placeRow rightStart rightEnd outs[N-1] "RightCap" slen stoneBox matS)
        )
        
        try (delete stoneBox) catch()
        
        -- 生成草坪多边形
        local lawnPts = #()
        local d1 = normalize (pts[2] - pts[1])
        local dN = normalize (pts[N] - pts[N-1])
        
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
                    local dAngL = (angB_val - angA_val) / (numLawnPts as float)
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
            try (
                local lawnSpline = SplineShape()
                addNewSpline lawnSpline
                for p in lawnPts do addKnot lawnSpline 1 #corner #line p
                close lawnSpline 1
                updateShape lawnSpline
                
                addModifier lawnSpline (Turn_To_Poly())
                collapseStack lawnSpline
                if (polyop.getNumFaces lawnSpline) > 0 do (
                    local fNorm = polyop.getFaceNormal lawnSpline 1
                    if fNorm.z < 0 do (
                        addModifier lawnSpline (Normalmodifier flip:true)
                        collapseStack lawnSpline
                    )
                )
                lawnSpline.pos.z += (h - lZ)
                lawnSpline.wirecolor = black
                lawnSpline.name = "PlanterLawn"
                lawnSpline.material = matL
                append generatedObjs lawnSpline
            ) catch (
                format "AutoPlanter: 草坪多边形生成异常跳过: %\n" (getCurrentException())
            )
        )
        
        local resultObjs = #()
        if generatedObjs.count > 0 do (
            local stonesOnly = for obj in generatedObjs where (obj != undefined and isValidNode obj and (findString obj.name "PlanterLawn") == undefined) collect obj
            if stonesOnly.count > 0 then (
                try (
                    local g = group stonesOnly name:"PlanterStones_Unit"
                    if g != undefined do append resultObjs g
                ) catch (
                    for obj in stonesOnly do append resultObjs obj
                )
            )
            for obj in generatedObjs where (obj != undefined and isValidNode obj and (findString obj.name "PlanterLawn") != undefined) do (
                appendIfUnique resultObjs obj
            )
        )
        resultObjs
    )
    
    on btn_generate pressed do (
        local sel = for o in selection where (isValidNode o and canConvertTo o Mesh) collect o
        if sel.count == 0 do (
            messageBox "请先选中墙体对象！\n只需选中即可，无需修改模型结构。" title:"提示"
            return()
        )
        
        local tolerance = spn_tol.value as float
        local minWallH = spn_minWallH.value as float
        local dVal = spn_depth.value as float
        local wVal = spn_stoneW.value as float
        local lVal = spn_stoneL.value as float
        
        setINISetting iniFile "Settings" "stoneW" (spn_stoneW.value as string)
        setINISetting iniFile "Settings" "stoneL" (spn_stoneL.value as string)
        setINISetting iniFile "Settings" "fillet" (spn_fillet.value as string)
        setINISetting iniFile "Settings" "depth"  (spn_depth.value as string)
        setINISetting iniFile "Settings" "cornerR" (spn_cornerR.value as string)
        setINISetting iniFile "Settings" "lawnZ"  (spn_lawnZ.value as string)
        setINISetting iniFile "Settings" "tol"    (spn_tol.value as string)
        setINISetting iniFile "Settings" "minWallH" (spn_minWallH.value as string)
        
        local matStone = sceneMaterials["Planter_Stone_Mat"]
        if matStone == undefined do matStone = StandardMaterial name:"Planter_Stone_Mat" diffuse:(color 180 180 180)
        
        local matLawn = sceneMaterials["Planter_Lawn_Mat"]
        if matLawn == undefined do matLawn = StandardMaterial name:"Planter_Lawn_Mat" diffuse:(color 60 160 60)

        local allNew = #()
        local pathCount = 0
        local segCount = 0
        local validEdgesCount = 0

        format "\n======== AutoPlanter V3.3 开始生成 ========\n"
        format "AP V3.3: 选中物体数=% [ % ]\n" sel.count (for o in sel collect o.name)

        -- 状态锁定与成对操作闭环保护 (Rule 8)
        suspendEditing()
        try (
            undo "智能生成花坛" on (
                with redraw off (
                    local globalMinZ = 1e9
                    local bbMin = [1e9, 1e9, 1e9]
                    local bbMax = [-1e9, -1e9, -1e9]
                    for obj in sel do (
                        if obj.min.z < globalMinZ do globalMinZ = obj.min.z
                        bbMin.x = amin bbMin.x obj.min.x
                        bbMin.y = amin bbMin.y obj.min.y
                        bbMin.z = amin bbMin.z obj.min.z
                        bbMax.x = amax bbMax.x obj.max.x
                        bbMax.y = amax bbMax.y obj.max.y
                        bbMax.z = amax bbMax.z obj.max.z
                    )
                    format "AP V3.3: 全局 globalMinZ=% tolerance=% minWallH=%\n" globalMinZ tolerance minWallH
                    format "AP V3.3: 整体包围盒=(%,%)-(%,%)\n" bbMin.x bbMin.y bbMax.x bbMax.y
                    
                    local validEdges = #()
                    
                    -- 第一阶段：底层有效墙体边缘提取
                    for obj in sel do (
                        local baseZ = obj.min.z
                        if baseZ > (globalMinZ + 800.0) do (
                            format "AP V3.3: 跳过高位物体 % (minZ=%, globalMinZ=%)\n" obj.name baseZ globalMinZ
                            continue
                        )
                        
                        local tMesh = undefined
                        local objEdgeCount = 0
                        try (
                            tMesh = snapshotAsMesh obj
                            for f = 1 to tMesh.numfaces do (
                                local fNormal = getFaceNormal tMesh f
                                local flatN = [fNormal.x, fNormal.y, 0.0]
                                if (length flatN) < 0.2 do continue -- 忽略水平面
                                
                                local fVerts = getFace tMesh f
                                local vPos = #(getVert tMesh fVerts.x, getVert tMesh fVerts.y, getVert tMesh fVerts.z)
                                local faceMaxZ = amax vPos[1].z (amax vPos[2].z vPos[3].z)
                                local faceMinZ = amin vPos[1].z (amin vPos[2].z vPos[3].z)
                                local faceH = faceMaxZ - faceMinZ
                                
                                -- 过滤门槛/地台等矮面
                                if faceH < minWallH and minWallH > 0.0 do continue
                                
                                -- 只提取真正接地的底边 (过滤离地浮空的窗台与腰线)
                                if abs(faceMinZ - baseZ) <= tolerance do (
                                    local edges = #( #(1,2), #(2,3), #(3,1) )
                                    for e in edges do (
                                        local pA = vPos[e[1]]
                                        local pB = vPos[e[2]]
                                        if abs(pA.z - baseZ) <= tolerance and abs(pB.z - baseZ) <= tolerance do (
                                            if (distance pA pB) >= 50.0 do (
                                                append validEdges #(pA, pB, fNormal)
                                                objEdgeCount += 1
                                            )
                                        )
                                    )
                                )
                            )
                        ) catch (
                            format "AP V3.3: 提取网格底层边缘异常: %\n" (getCurrentException())
                        ) finally (
                            if tMesh != undefined do ( free tMesh; delete tMesh )
                        )
                        format "AP V3.3: 物体 [%] minZ=% maxZ=% 提取底边数=%\n" obj.name obj.min.z obj.max.z objEdgeCount
                    )
                    
                    validEdgesCount = validEdges.count
                    format "AP V3.3: 总有效底边数 e0=%\n" validEdgesCount
                    
                    if validEdgesCount == 0 then (
                        lbl_status.text = "状态: 未识别到底边"
                    ) else (
                        -- 第二阶段：共线边全局打组 (基于几何中心向外法向 + 2D 投影归并)
                        local bldgCenter = [ (bbMin.x + bbMax.x) * 0.5, (bbMin.y + bbMax.y) * 0.5, 0.0 ]
                        local lineGroups = #()
                        for ve in validEdges do (
                            local p1 = [ve[1].x, ve[1].y, 0.0]
                            local p2 = [ve[2].x, ve[2].y, 0.0]
                            if distance p1 p2 < 1.0 do continue
                            
                            local edgeDir = normalize (p2 - p1)
                            if edgeDir.x < 0 or (abs(edgeDir.x) < 0.001 and edgeDir.y < 0) do edgeDir *= -1
                            
                            -- 核心几何外法向计算：背离建筑中心的方向即为真正的外立面朝向 (100% 免疫模型面法向翻转/镜像负缩放)
                            local perpN = normalize [-edgeDir.y, edgeDir.x, 0.0]
                            local pMid = (p1 + p2) * 0.5
                            local rToMid = pMid - bldgCenter
                            local outV = if (dot rToMid perpN) >= 0.0 then perpN else (-perpN)
                            
                            local foundGroup = false
                            for g in lineGroups do (
                                local gBasePt = g[1][1]
                                local gDir = g[1][2]
                                local gOutV = g[1][3]
                                
                                -- 2D 平行且外法向一致
                                if abs(dot edgeDir gDir) > 0.98 and (dot outV gOutV) > 0.8 do (
                                    -- 2D 平面点到直线垂直距离
                                    local vecToP1 = p1 - gBasePt
                                    local dist2D = abs(vecToP1.x * gDir.y - vecToP1.y * gDir.x)
                                    if dist2D < 50.0 do (
                                        local t1 = dot (p1 - gBasePt) gDir
                                        local t2 = dot (p2 - gBasePt) gDir
                                        append g[2] #(amin t1 t2, amax t1 t2)
                                        foundGroup = true
                                        exit
                                    )
                                )
                            )
                            if not foundGroup do (
                                local t1 = 0.0
                                local t2 = dot (p2 - p1) edgeDir
                                append lineGroups #( #(p1, edgeDir, outV), #( #(amin t1 t2, amax t1 t2) ) )
                            )
                        )
                        format "AP V3.3: 初步打组组数 lineGroups=%\n" lineGroups.count
                        
                        -- 第2.5阶段：外立面保留与同墙内皮过滤
                        local exteriorGroups = #()
                        for i = 1 to lineGroups.count do (
                            local g = lineGroups[i]
                            local basePt = g[1][1]
                            local gDir = g[1][2]
                            local outV = g[1][3]
                            local toWall = basePt - bldgCenter
                            local score = dot toWall outV
                            
                            -- 检查是否存在同向平行的另一侧墙皮 (同墙内皮距离在 30mm ~ 600mm 之间)
                            local isInnerSkin = false
                            for j = 1 to lineGroups.count do (
                                if i == j do continue
                                local g2 = lineGroups[j]
                                local gDir2 = g2[1][2]
                                local outV2 = g2[1][3]
                                
                                -- 平行且外法向一致
                                if abs(dot gDir gDir2) > 0.98 and (dot outV outV2) > 0.8 do (
                                    local basePt2 = g2[1][1]
                                    local vecBetween = basePt2 - basePt
                                    local wallThick = abs(dot vecBetween outV)
                                    if wallThick >= 30.0 and wallThick <= 600.0 do (
                                        local toWall2 = basePt2 - bldgCenter
                                        local score2 = dot toWall2 outV2
                                        -- 离建筑中心更近的那一组，是室内侧内皮，予以过滤
                                        if score2 > score do (
                                            isInnerSkin = true
                                            format "AP V3.3: 过滤室内侧内墙皮 basePt=(%,%) score=% (外立面score=%)\n" basePt.x basePt.y score score2
                                            exit
                                        )
                                    )
                                )
                            )
                            if not isInnerSkin do append exteriorGroups g
                        )
                        format "AP V3.3: 外墙过滤后保留组数=%\n" exteriorGroups.count
                        lineGroups = exteriorGroups
                        
                        -- 第三阶段：无缝合并碎段（门洞自然留空断开）
                        local cleanSegments = #()
                        for g in lineGroups do (
                            local basePt = g[1][1]
                            local dirVec = g[1][2]
                            local outVec = g[1][3]
                            local intervals = g[2]
                            
                            qsort intervals sortIntervals
                            
                            -- 仅合并细小碎缝(<=300mm)，门洞(>300mm)保持自然断开
                            local mergedIntervals = #()
                            local currentInt = intervals[1]
                            for i = 2 to intervals.count do (
                                local nextInt = intervals[i]
                                if nextInt[1] <= currentInt[2] + 300.0 then (
                                    currentInt[2] = amax currentInt[2] nextInt[2]
                                ) else (
                                    append mergedIntervals currentInt
                                    currentInt = nextInt
                                )
                            )
                            append mergedIntervals currentInt
                            
                            for mi in mergedIntervals do (
                                local segLen = mi[2] - mi[1]
                                -- 过滤微小碎段 (< 250mm)，避免门洞侧壁/细碎凸起生成多余微型花坛
                                if segLen >= 250.0 do (
                                    local startPt = [basePt.x + dirVec.x * mi[1], basePt.y + dirVec.y * mi[1], globalMinZ]
                                    local endPt = [basePt.x + dirVec.x * mi[2], basePt.y + dirVec.y * mi[2], globalMinZ]
                                    
                                    -- 统一线段走向：让法线 outVec 位于线段前进方向的右侧 (右手系一致性)
                                    local rightVec = cross [0,0,1] outVec
                                    if (dot rightVec dirVec) < 0.0 do (
                                        local tmp = startPt
                                        startPt = endPt
                                        endPt = tmp
                                    )
                                    append cleanSegments #(startPt, endPt, outVec)
                                )
                            )
                        )
                        format "AP V3.3: 最终提取线段数 cleanSegments=%\n" cleanSegments.count
                        for csi = 1 to cleanSegments.count do (
                            local cs = cleanSegments[csi]
                            format "  段% 长度=% p1=(%,%) p2=(%,%) out=(%,%)\n" csi (distance cs[1] cs[2]) cs[1].x cs[1].y cs[2].x cs[2].y cs[3].x cs[3].y
                        )
                        
                        -- 第四阶段：折线拐角串联（支持任意旋转与相交求解）
                        local polylines = #()
                        local joinTol = amax 800.0 (wVal * 2.5)
                        
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
                                    
                                    if dStartToEnd < joinTol then (
                                        local d1 = normalize (pts[pts.count] - pts[pts.count-1])
                                        local d2 = normalize (seg[2] - seg[1])
                                        if abs(dot d1 d2) < 0.95 then (
                                            local intP = intersect2DLines pts[pts.count] d1 seg[1] d2
                                            if distance intP pts[pts.count] > 500.0 do intP = (seg[1] + pts[pts.count]) * 0.5
                                            pts[pts.count] = intP
                                        ) else (
                                            pts[pts.count] = (seg[1] + pts[pts.count]) * 0.5
                                        )
                                        append pts seg[2]
                                        append outs seg[3]
                                        deleteItem cleanSegments i
                                        added = true
                                    ) else if dEndToStart < joinTol then (
                                        local d1 = normalize (seg[2] - seg[1])
                                        local d2 = normalize (pts[2] - pts[1])
                                        if abs(dot d1 d2) < 0.95 then (
                                            local intP = intersect2DLines seg[2] d1 pts[1] d2
                                            if distance intP pts[1] > 500.0 do intP = (seg[2] + pts[1]) * 0.5
                                            pts[1] = intP
                                        ) else (
                                            pts[1] = (seg[2] + pts[1]) * 0.5
                                        )
                                        insertItem seg[1] pts 1
                                        insertItem seg[3] outs 1
                                        deleteItem cleanSegments i
                                        added = true
                                    ) else if dStartToStart < joinTol then (
                                        local d1 = normalize (seg[1] - seg[2])
                                        local d2 = normalize (pts[2] - pts[1])
                                        if abs(dot d1 d2) < 0.95 then (
                                            local intP = intersect2DLines seg[1] d1 pts[1] d2
                                            if distance intP pts[1] > 500.0 do intP = (seg[1] + pts[1]) * 0.5
                                            pts[1] = intP
                                        ) else (
                                            pts[1] = (seg[1] + pts[1]) * 0.5
                                        )
                                        insertItem seg[2] pts 1
                                        insertItem seg[3] outs 1
                                        deleteItem cleanSegments i
                                        added = true
                                    ) else if dEndToEnd < joinTol then (
                                        local d1 = normalize (pts[pts.count] - pts[pts.count-1])
                                        local d2 = normalize (seg[1] - seg[2])
                                        if abs(dot d1 d2) < 0.95 then (
                                            local intP = intersect2DLines pts[pts.count] d1 seg[2] d2
                                            if distance intP pts[pts.count] > 500.0 do intP = (seg[2] + pts[pts.count]) * 0.5
                                            pts[pts.count] = intP
                                        ) else (
                                            pts[pts.count] = (seg[2] + pts[pts.count]) * 0.5
                                        )
                                        append pts seg[1]
                                        append outs seg[3]
                                        deleteItem cleanSegments i
                                        added = true
                                    )
                                )
                            )
                            
                            if pts.count >= 3 and (distance pts[1] pts[pts.count]) < joinTol do (
                                append pts pts[1]
                                append outs outs[1]
                            )
                            append polylines #(pts, outs)
                        )
                        
                        format "AP V3.3: 拐角串联后折线数 polylines=%\n" polylines.count
                        for pli = 1 to polylines.count do (
                            local pl = polylines[pli]
                            local plen = 0.0
                            for i = 1 to (pl[1].count - 1) do plen += distance pl[1][i] pl[1][i+1]
                            format "  折线% 点数=% 长度=%m\n" pli pl[1].count (plen / 1000.0)
                        )
                        
                        -- 第五阶段：实体生成
                        pathCount = polylines.count
                        local minPathLen = amax 300.0 (wVal * 2.0)
                        
                        for pl in polylines do (
                            local pts = pl[1]
                            local plen = 0.0
                            for i = 1 to (pts.count - 1) do plen += distance pts[i] pts[i+1]
                            if plen >= minPathLen and (pts.count - 1) <= 60 do (
                                segCount += (pts.count - 1)
                                local got = buildPlanterPath pl[1] pl[2] matStone matLawn
                                if got != undefined and got.count > 0 do (
                                    join allNew got
                                )
                            )
                        )
                        
                        local roots = for o in allNew where (o != undefined and isValidNode o) collect o
                        if roots.count > 0 do (
                            try (select roots) catch ()
                        )
                        
                        format "AP V3.3: 生成对象数=% 已选中=%\n" allNew.count roots.count
                        format "======== AutoPlanter V3.3 完成 ========\n\n"
                        
                        if pathCount == 0 or roots.count == 0 then (
                            lbl_status.text = "状态: 未能生成有效路径"
                        ) else (
                            lbl_status.text = "状态: 完成 " + (pathCount as string) + "组花坛 (" + (roots.count as string) + "对象)"
                        )
                    )
                ) -- with redraw off
            ) -- undo on
        ) catch (
            messageBox ("生成花坛时发生错误: " + getCurrentException()) title:"错误"
            lbl_status.text = "状态: 发生异常"
            format "AP V3.3 异常: %\n" (getCurrentException())
        )
        -- 严格保障成对清理
        resumeEditing()
        enableSceneRedraw()
        forceCompleteRedraw()
    )
    
    on btn_gen_line pressed do (
        local sel = for o in selection where (isValidNode o and superClassOf o == Shape) collect o
        if sel.count == 0 do (
            messageBox "请先选中一个或多个二维线条 (Spline)！" title:"提示"
            return()
        )
        
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
                                        local inA = 0.0
                                        local inB = 0.0
                                        if k > 1 or (isClosed obj s) then (
                                            local pk = if k > 1 then getKnotPoint obj s (k-1) else getKnotPoint obj s nKnots
                                            pk.z = obj.min.z
                                            if (dot (normalize (pA - pk)) dVec) < 0.999 do inA = w * 0.5
                                        )
                                        if (k+1) < nKnots or (isClosed obj s) then (
                                            local pn = if (k+1) < nKnots then getKnotPoint obj s (k+2) else getKnotPoint obj s 1
                                            pn.z = obj.min.z
                                            if (dot dVec (normalize (pn - pB))) < 0.999 do inB = w * 0.5
                                        )
                                        local pA2 = pA + dVec * inA
                                        local pB2 = pB - dVec * inB
                                        local segLen = distance pA2 pB2
                                        if segLen > 0.001 do (
                                            local numFull = floor (segLen / slen) as integer
                                            local remain = segLen - (numFull * slen)
                                            local currentP = pA2
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
                                                local p2 = pB2
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
                                        local inA = w * 0.5
                                        local inB = w * 0.5
                                        local pk = getKnotPoint obj s (nKnots - 1)
                                        local pn = getKnotPoint obj s 2
                                        pk.z = obj.min.z; pn.z = obj.min.z
                                        if (dot (normalize (pA - pk)) dVec) > 0.999 do inA = 0.0
                                        if (dot dVec (normalize (pn - pB))) > 0.999 do inB = 0.0
                                        local pA2 = pA + dVec * inA
                                        local pB2 = pB - dVec * inB
                                        local segLen = distance pA2 pB2
                                        if segLen > 0.001 do (
                                            local numFull = floor (segLen / slen) as integer
                                            local remain = segLen - (numFull * slen)
                                            local currentP = pA2
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
                                                local p2 = pB2
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
                        try (delete stoneBox) catch()
                        
                        if stonesGroup.count > 0 do (
                            local g = group stonesGroup name:(sourceObj.name + "_Stones")
                            append newObjs g
                        )
                        
                        if newObjs.count > 0 do (
                            group newObjs name:(sourceObj.name + "_PlanterUnit")
                        )
                        try (delete obj) catch()
                    )
                )
            )
        ) catch (
            messageBox ("发生错误: " + getCurrentException()) title:"错误"
        )
        for tempSpline in tempSplineCopies where isValidNode tempSpline do try(delete tempSpline)catch()
        resumeEditing()
        enableSceneRedraw()
        forceCompleteRedraw()
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

        local mh = getINISetting iniFile "Settings" "minWallH"
        if mh != "" do spn_minWallH.value = mh as float
        
        local line_w = getINISetting iniFile "Settings" "line_stoneW"
        if line_w != "" do spn_line_stoneW.value = line_w as float
        
        local line_l = getINISetting iniFile "Settings" "line_stoneL"
        if line_l != "" do spn_line_stoneL.value = line_l as float
        
        local line_f = getINISetting iniFile "Settings" "line_fillet"
        if line_f != "" do spn_line_fillet.value = line_f as float
        
        local line_chkR = getINISetting iniFile "Settings" "line_useRadius"
        if line_chkR != "" do chk_line_useRadius.checked = ((toLower line_chkR) == "true" or line_chkR == "1")
        
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
        setINISetting iniFile "Settings" "minWallH" (spn_minWallH.value as string)
        
        setINISetting iniFile "Settings" "line_stoneW" (spn_line_stoneW.value as string)
        setINISetting iniFile "Settings" "line_stoneL" (spn_line_stoneL.value as string)
        setINISetting iniFile "Settings" "line_fillet" (spn_line_fillet.value as string)
        setINISetting iniFile "Settings" "line_useRadius" (chk_line_useRadius.checked as string)
        setINISetting iniFile "Settings" "line_pathRadius" (spn_line_pathRadius.value as string)
        setINISetting iniFile "Settings" "line_lawnZ" (spn_line_lawnZ.value as string)
    )
)

createDialog AutoPlanterRollout
