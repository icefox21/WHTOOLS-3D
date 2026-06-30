rollout ParkingGeneratorUI "智能车位生成器 (含随机摆车) v2.0" width:250
(
    -- 备选车辆模型库
    local vehiclePool = #()
    
    local iniFile = getDir #plugcfg + "\\ParkingGenerator_Settings.ini"
    
    fn saveSettings = (
        try (
            setINISetting iniFile "Settings" "Type" (rdoType.state as string)
            setINISetting iniFile "Settings" "Length" (spnLength.value as string)
            setINISetting iniFile "Settings" "Width" (spnWidth.value as string)
            setINISetting iniFile "Settings" "LineThick" (spnLineThick.value as string)
            setINISetting iniFile "Settings" "Thickness" (spnThickness.value as string)
            setINISetting iniFile "Settings" "Vacancy" (spnVacancy.value as string)
            setINISetting iniFile "Settings" "Flip" (spnFlip.value as string)
        ) catch()
    )
    
    fn loadSettings = (
        try (
            if doesFileExist iniFile do (
                local v = getINISetting iniFile "Settings" "Type"
                if v != "" do rdoType.state = v as integer
                
                v = getINISetting iniFile "Settings" "Length"
                if v != "" do spnLength.value = v as float
                
                v = getINISetting iniFile "Settings" "Width"
                if v != "" do spnWidth.value = v as float
                
                v = getINISetting iniFile "Settings" "LineThick"
                if v != "" do spnLineThick.value = v as float
                
                v = getINISetting iniFile "Settings" "Thickness"
                if v != "" do spnThickness.value = v as float
                
                v = getINISetting iniFile "Settings" "Vacancy"
                if v != "" do spnVacancy.value = v as integer
                
                v = getINISetting iniFile "Settings" "Flip"
                if v != "" do spnFlip.value = v as integer
            )
        ) catch()
    )

    group "使用说明" (
        label lbl1 "拾取一条或多条样条线" align:#left
        label lbl2 "车位数量根据长短自动平分。" align:#left
    )
    
    group "类型预设" (
        radiobuttons rdoType "" labels:#("机动车位", "非机动车位") align:#center
    )
    
    group "参数设置" (
        spinner spnLength "长度 (mm):" range:[100, 100000, 5600] type:#float fieldwidth:70 align:#center offset:[15, 0]
        spinner spnWidth  "宽度 (mm):"  range:[100, 100000, 3000] type:#float fieldwidth:70 align:#center offset:[15, 0]
        spinner spnLineThick "白线 (mm):" range:[10, 1000, 100] type:#float fieldwidth:70 align:#center offset:[15, 0]
        spinner spnThickness "厚度 (mm):" range:[0, 1000, 5] type:#float fieldwidth:70 align:#center offset:[15, 0]
    )
    
    button btnCreateSelected "一键批量生成 (选线)" width:220 height:45
    
    group "随机摆放车辆 (第二步)" (
        button btnAddVehicles "1. 添加当前选中模型为备选车" width:220 height:30
        label lblTip "提示:请确保初始车头朝向为+Y或-Y" align:#center
        listbox lbxVehicles "备选车辆车库 (0):" height:4
        button btnClearVehicles "清空车库" width:220
        
        spinner spnVacancy "车位空置率 (%):" range:[0, 100, 30] type:#integer fieldwidth:50 align:#left offset:[10, 5]
        spinner spnFlip "随机朝外率 (%):" range:[0, 100, 50] type:#integer fieldwidth:50 align:#left offset:[10, 0]
        
        button btnPlaceVehicles "2. 在选中的车位上随机摆车" width:220 height:40
    )
    
    -- 类型选择变更时自动更新数值
    on rdoType changed state do
    (
        if state == 1 then (
            -- 机动车位默认参数
            spnLength.value = 5600
            spnWidth.value = 3000
            spnLineThick.value = 100
        ) else (
            -- 非机动车位默认参数
            spnLength.value = 2000
            spnWidth.value = 600
            spnLineThick.value = 50
        )
    )
    
    fn createParkingMesh lineNode W D lineThick thickness uvSize =
    (
        if not (superClassOf lineNode == Shape or superClassOf lineNode == line) do (
            return undefined
        )
        
        local curveLen = 0.0
        try(curveLen = curveLength lineNode 1)catch(
            return undefined
        )
        
        local N = floor (curveLen / W)
        if N < 1 do N = 1
        
        -- 分解为两个完全独立的对象，方便后期分类管理
        local tempPlane1 = Plane length:1 width:1 lengthsegs:1 widthsegs:1
        local polyWhite = convertToPoly tempPlane1
        polyop.deleteVerts polyWhite #{1..4}
        polyWhite.name = uniqueName "ParkingLines_"
        
        local tempPlane2 = Plane length:1 width:1 lengthsegs:1 widthsegs:1
        local polyGreen = convertToPoly tempPlane2
        polyop.deleteVerts polyGreen #{1..4}
        polyGreen.name = uniqueName "ParkingArea_"
        
        -- 生成X顶点坐标 (长度方向)
        local X_coords = #()
        for i = 0 to N do (
            append X_coords (i * W)
            append X_coords (i * W + lineThick)
        )
        
        -- 生成Y顶点坐标 (深度方向)
        local Y_coords = #(0.0, lineThick, D - lineThick, D)
        
        -- 将所有顶点插入到两个Poly中保持相同拓扑结构
        for y in Y_coords do (
            for x in X_coords do (
                polyop.createVert polyWhite [x, y, 0]
                polyop.createVert polyGreen [x, y, 0]
            )
        )
        
        local numCols = X_coords.count - 1
        local numRows = Y_coords.count - 1
        
        -- 创建四边形面
        for r = 1 to numRows do (
            for c = 1 to numCols do (
                local v_BL = (r - 1) * X_coords.count + c
                local v_BR = v_BL + 1
                local v_TL = r * X_coords.count + c
                local v_TR = v_TL + 1
                
                local isGreen = (r == 2 and (mod c 2) == 0.0)
                if isGreen then (
                    polyop.createPolygon polyGreen #(v_BL, v_BR, v_TR, v_TL)
                ) else (
                    polyop.createPolygon polyWhite #(v_BL, v_BR, v_TR, v_TL)
                )
            )
        )
        
        -- 清理两个模型中自身不需要的孤立顶点
        for p in #(polyWhite, polyGreen) do (
            local usedVerts = #{}
            for f = 1 to (polyop.getNumFaces p) do (
                usedVerts += polyop.getFaceVerts p f as bitarray
            )
            local allVerts = #{1..(polyop.getNumVerts p)}
            local unused = allVerts - usedVerts
            if not unused.isEmpty do polyop.deleteVerts p unused
        )
        
        -- 赋予独立材质 (判断并使用 VRayMtl)
        local baseMatClass = Standardmaterial
        if VRayMtl != undefined do baseMatClass = VRayMtl
        
        local matWhite = baseMatClass()
        matWhite.name = "白线材质 (White)"
        matWhite.diffuse = color 200 200 200
        
        local matGreen = baseMatClass()
        matGreen.name = "车位内部 (Parking Area)"
        matGreen.diffuse = color 80 120 80
        
        -- 这里给车位内部随便分配一个基础棋盘格贴图占位，以确保显示按钮能被点亮
        local tempChecker = Checker()
        tempChecker.color1 = color 68 86 43 -- Color 1: R=68, G=86, B=43
        tempChecker.color2 = color 35 47 21 -- Color 2: R=35, G=47, B=21
        tempChecker.coords.U_Tiling = 3.0
        tempChecker.coords.V_Tiling = 3.0
        if isProperty matGreen "texmap_diffuse" then matGreen.texmap_diffuse = tempChecker
        else if isProperty matGreen "diffuseMap" then matGreen.diffuseMap = tempChecker
        
        polyWhite.material = matWhite
        polyGreen.material = matGreen
        
        polyWhite.wirecolor = color 0 0 0
        polyGreen.wirecolor = color 0 0 0
        
        -- 强制开启视口显示材质/贴图的功能开关（Show Shaded Material in Viewport）
        try(showTextureMap matGreen true)catch()
        
        -- 对齐到目标线条
        local startP = [0,0,0]
        local endP = [1,0,0]
        try (
            startP = interpCurve3D lineNode 1 0.0
            endP   = interpCurve3D lineNode 1 1.0
        ) catch ()
        
        local dir = [1,0,0]
        if (distance startP endP) > 0.001 do (
            dir = normalize (endP - startP)
        )
        
        local yDir = normalize (cross [0,0,1] dir)
        if length yDir < 0.001 do yDir = [0,1,0]
        
        local zDir = normalize (cross dir yDir)
        local tm = matrix3 dir yDir zDir startP
        
        polyWhite.transform = tm
        polyGreen.transform = tm
        
        -- 赋予UV并对齐Gizmo
        local uvGreen = Uvwmap maptype:0 length:uvSize width:uvSize
        addModifier polyGreen uvGreen
        try(polyGreen.modifiers[#UVW_Map].gizmo.position = [0, 0, 0])catch()
        
        local uvWhite = Uvwmap maptype:0 length:uvSize width:uvSize
        addModifier polyWhite uvWhite
        try(polyWhite.modifiers[#UVW_Map].gizmo.position = [0, 0, 0])catch()

        -- 增加壳修改器生成厚度
        if thickness > 0 do (
            local shellModWhite = Shell innerAmount:0 outerAmount:thickness
            addModifier polyWhite shellModWhite
            
            local shellModGreen = Shell innerAmount:0 outerAmount:thickness
            addModifier polyGreen shellModGreen
        )
        
        -- 将白线父子连接到绿色车位上，使得它们可以独立选择材质，但移动绿色车位时能一起跟着走
        polyWhite.parent = polyGreen
        
        return #(polyGreen, polyWhite)
    )
    
    on btnCreateSelected pressed do
    (
        if selection.count == 0 then (
            messageBox "请先在场景中框选或选中一条/多条样条线！" title:"提示"
        )
        else (
            local validLines = #()
            for obj in selection do (
                if (superClassOf obj == Shape or superClassOf obj == line) do (
                    append validLines obj
                )
            )
            
            if validLines.count == 0 then (
                messageBox "您选中的对象中没有包含有效的样条线 (Spline/Line)！" title:"提示"
            )
            else (
                -- 移除多重强行包裹的 undo 范围以提高老版本 Max 的拓扑内存稳定性
                local createdObjs = #()
                
                -- 获取系统基准单位比例
                local mmToSys = 1.0
                try ( 
                    local v = units.decodeValue "1mm"
                    if classOf v == Float then mmToSys = v 
                ) catch()
                
                -- 判断当前单选框状态得出当前UV尺寸
                local currentUvSize = 1300.0 * mmToSys
                if rdoType.state == 2 do currentUvSize = 600.0 * mmToSys
                
                local wScale = (spnWidth.value as float) * mmToSys
                local lScale = (spnLength.value as float) * mmToSys
                local lineTScale = (spnLineThick.value as float) * mmToSys
                local thkScale = (spnThickness.value as float) * mmToSys
                
                for obj in validLines do (
                    local res = createParkingMesh obj wScale lScale lineTScale thkScale currentUvSize
                    if res != undefined do (
                        append createdObjs res[1]
                        append createdObjs res[2]
                    )
                )
                if createdObjs.count > 0 do select createdObjs
            )
        )
    )
    
    -- ============================
    -- 车辆摆放功能模块
    -- ============================
    
    fn collectNodes n arr = (
        append arr n
        for c in n.children do collectNodes c arr
    )

    fn cloneNodeHierarchy srcNode = (
        local sourceNodes = #()
        collectNodes srcNode sourceNodes
        
        local clonedNodes
        maxOps.cloneNodes sourceNodes cloneType:#instance newNodes:&clonedNodes
        -- 防御：clone 失败或返回空数组时不崩溃
        if clonedNodes == undefined or clonedNodes.count == 0 do return undefined
        return clonedNodes[1]
    )

    on btnAddVehicles pressed do (
        if selection.count == 0 then (
            messageBox "请先选中要作为备选车辆的模型！(支持选中多个)" title:"提示"
        ) else (
            -- 寻找选中物体的最高层级（组头）
            local roots = #()
            for obj in selection do (
                local r = obj
                while r.parent != undefined do r = r.parent
                appendIfUnique roots r
            )
            
            for r in roots do (
                if isValidNode r do appendIfUnique vehiclePool r
            )
            
            local names = #()
            for v in vehiclePool do append names (if v.name != undefined then v.name else "未知车辆")
            lbxVehicles.items = names
            lbxVehicles.caption = "备选车辆车库 (" + vehiclePool.count as string + "):"
        )
    )
    
    on btnClearVehicles pressed do (
        vehiclePool = #()
        lbxVehicles.items = #()
        lbxVehicles.caption = "备选车辆车库 (0):"
    )
    
    on btnPlaceVehicles pressed do (
        if vehiclePool.count == 0 then (
            messageBox "请先添加备选车辆模型！\n如果需要先生成车位，请先执行第一步生成。" title:"提示"
            return ()
        )
        if selection.count == 0 then (
            messageBox "请先选中生成的绿色车位物体 (例如包含 ParkingArea 文字的物体)！" title:"提示"
            return ()
        )
        
        local targetAreas = #()
        for obj in selection do (
            if matchPattern obj.name pattern:"*ParkingArea_*" do (
                append targetAreas obj
            )
        )
        
        if targetAreas.count == 0 then (
            messageBox "选中的物体中没有发现车位实体 (包含 ParkingArea_ 的物体)，请重新检查选择。" title:"提示"
        )
        
        local placeCount = 0
        local skipCount = 0
        
        -- 禁用视口重绘，极大地提高大批量实例摆放的速度
        with redraw off (
            undo "一键摆放车辆" on (
                for areaNode in targetAreas do (
                    local basePoly = areaNode.baseObject
                    if classOf basePoly != Editable_Poly do continue
                    
                    local numFaces = polyop.getNumFaces basePoly
                    for f = 1 to numFaces do (
                        -- 只取表面法线朝上的面，避免因为厚度或底面等坍塌问题重叠生成多辆车
                        local localNormal = polyop.getFaceNormal basePoly f
                        if localNormal.z < 0.99 do continue
                        
                        -- 空置率判断
                        if (random 1 100) <= spnVacancy.value then (
                            skipCount += 1
                            continue
                        )
                        
                        -- 获取该面在局部空间下的中心，并计算出该中心在世界坐标下的绝地位置
                        local localCenter = polyop.getFaceCenter basePoly f
                        local worldCenter = localCenter * areaNode.transform
                        
                        local srcCar = vehiclePool[random 1 vehiclePool.count]
                        if isValidNode srcCar then (
                            local newCar = cloneNodeHierarchy srcCar
                            -- clone 失败防御：跳过本次，不崩溃
                            if newCar == undefined do continue
                            
                            -- 提取车辆原始旋转+缩放（去掉位移），继承模型自身的轴心对齐
                            local srcRotScale = srcCar.transform
                            srcRotScale.row4 = [0,0,0]
                            
                            -- 提取车位的纯净方位（归一化，消除意外缩放污染）
                            -- row1(X) = 沿样条线方向（车位宽度方向，多个车位并排）
                            -- row2(Y) = 垂直样条线方向（车位深度方向，车头/车尾指向）
                            -- row3(Z) = 向上
                            local dirX = normalize areaNode.transform.row1
                            local dirY = normalize areaNode.transform.row2
                            local dirZ = normalize areaNode.transform.row3
                            local rotArea = matrix3 dirX dirY dirZ [0,0,0]
                            
                            -- 开始在极安全的局部与世界坐标夹层中处理: 先带入车辆原始身姿
                            local finalMatrix = srcRotScale
                            
                            -- 【修正说明】
                            -- rotArea 已将车的本地 +Y 映射到车位深度方向(row2=垂直样条线)。
                            -- 车头朝 +Y 的车模无需额外旋转即可正停。
                            -- (原来的 -90° 把车头转到 +X，即沿样条线方向，导致横停——已删除)
                            
                            -- 若命中随机朝外，原地绕原始正立Z轴纯净调头180
                            if (random 1 100) <= spnFlip.value do (
                                finalMatrix = finalMatrix * (rotateZMatrix 180.0)
                            )
                            
                            -- 最终装载：完美套用到车位面的旋转角度中，降落在计算好的世界坐标网格中心点
                            finalMatrix = finalMatrix * rotArea
                            finalMatrix.row4 = worldCenter
                            
                            newCar.transform = finalMatrix
                            
                            placeCount += 1
                        )
                    )
                )
            )
        )
    )
    
    on ParkingGeneratorUI open do loadSettings()
    on ParkingGeneratorUI close do saveSettings()
)

try(destroyDialog ParkingGeneratorUI)catch()
createDialog ParkingGeneratorUI style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)
