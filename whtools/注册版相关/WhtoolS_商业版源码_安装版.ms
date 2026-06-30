-- ========================================================
-- 脚本名称: WH 集合工具箱 (WH Toolbox) - 商业加密版
-- ========================================================
global WHToolboxUI

( -- BEGIN MAIN SCRIPT BLOCK
-- ============================
-- 许可验证模块 (DRM Core)
-- ============================
global WHAuth_getMachineID
WHAuth_getMachineID = fn WHAuth_getMachineID_impl = (
    -- 取消MAC地址依赖，改用更为稳定的系统所在盘符序列号 + 电脑名
    local cDriveSerial = "UNKNOWN"
    local volStr = ""
    try (
        HiddenDOSCommand "vol C: > \"%temp%\\vol_temp.txt\"" startpath:"C:\\"
        local f = openFile (getDir #temp + "\\vol_temp.txt") mode:"r"
        if f != undefined do (
            readLine f
            volStr = readLine f
            close f
        )
    ) catch ()
    
    local txtTokens = filterString volStr " "
    if txtTokens.count > 0 then cDriveSerial = txtTokens[txtTokens.count]
    
    local compName = sysInfo.computername
    
    -- 混合散列
    local rawID = cDriveSerial + "_" + compName
    local mixID = 0
    for i=1 to rawID.count do (
        mixID += ((bit.charAsInt rawID[i]) * i * 31)
    )
    
    local finalID = "WH-" + (abs mixID as string) + "-TS"
    return finalID
)

global WHAuth_generateKey
WHAuth_generateKey = fn WHAuth_generateKey_impl macID = (
    -- 简单的倒序+偏移加密算法 (注册机也要用同款)
    local keyInt = 0
    for i=1 to macID.count do (
        keyInt += (bit.charAsInt macID[i]) * 88
    )
    local finalKey = "WH-KEY-" + ((keyInt * 123) as string)
    return finalKey
)

global WHAuth_iniPath = getDir #plugcfg + "\\WHToolsAuth.ini"
global WHAuth_currentMacID = WHAuth_getMachineID()
global WHAuth_trialDate = "" -- 记录试用过期日期

local isAuthorized = false
local savedKey = getINISetting WHAuth_iniPath "License" "Key"

-- 1. 正式版验证
if savedKey == (WHAuth_generateKey WHAuth_currentMacID) then (
    isAuthorized = true
)
-- 2. 试用版验证 (WH-TRIAL-[Hash]-[YYYYMMDD])
else if matchPattern savedKey pattern:"WH-TRIAL-*" then (
    local tokens = filterString savedKey "-"
    if tokens.count >= 4 then (
        local inputHash = tokens[3]
        local expDate = tokens[4]
        
        -- 重建哈希进行比对
        local rawStr = WHAuth_currentMacID + expDate
        local keyInt = 0
        for i=1 to rawStr.count do (
            keyInt += (bit.charAsInt rawStr[i]) * 77
        )
        local calcHash = (keyInt * 123) as string
        
        if inputHash == calcHash then (
            -- 检查是否过期
            local today = (dotnetClass "System.DateTime").Now.ToString "yyyyMMdd"
            if (today as integer) <= (expDate as integer) then (
                isAuthorized = true
                WHAuth_trialDate = expDate
            )
        )
    )
)

if not isAuthorized then (
    rollout WHToolsAuthUI "WhtoolS - 软件授权" width:300 height:180
    (
        label lbl1 "本机特征码 (Machine ID):" pos:[20,20]
        edittext edtMacID "" text:WHAuth_currentMacID pos:[15,40] width:260 readOnly:true
        
        button btnCopy "⎘ 复制特征码发给开发者" pos:[20,70] width:260 height:30
        
        label lbl2 "请输入授权码 (License Key):" pos:[20,110]
        edittext edtKey "" pos:[15,130] width:180
        button btnAct "激活" pos:[205,130] width:75 height:20
        
        on btnCopy pressed do (
            setclipboardText WHAuth_currentMacID
            messageBox "特征码已复制到剪贴板！" title:"提示"
        )
        
        on btnAct pressed do (
            local inputKey = edtKey.text
            local keyValid = false
            
            if inputKey == (WHAuth_generateKey WHAuth_currentMacID) then (
                keyValid = true
            )
            else if matchPattern inputKey pattern:"WH-TRIAL-*" then (
                local tokens = filterString inputKey "-"
                if tokens.count >= 4 then (
                    local inputHash = tokens[3]
                    local expDate = tokens[4]
                    
                    local rawStr = WHAuth_currentMacID + expDate
                    local keyInt = 0
                    for i=1 to rawStr.count do (
                        keyInt += (bit.charAsInt rawStr[i]) * 77
                    )
                    local calcHash = (keyInt * 123) as string
                    
                    if inputHash == calcHash then (
                        local today = (dotnetClass "System.DateTime").Now.ToString "yyyyMMdd"
                        if (today as integer) <= (expDate as integer) then (
                            keyValid = true
                        ) else (
                            messageBox "该试用码已过期！" title:"激活失败"
                            return ()
                        )
                    )
                )
            )

            if keyValid then (
                setINISetting WHAuth_iniPath "License" "Key" inputKey
                
                -- 提取精简版时间 (比如 2026/03/25)
                local tTokens = filterString localtime " "
                local briefTime = if tTokens.count > 0 then tTokens[1] else localtime
                setINISetting WHAuth_iniPath "License" "AuthTime" briefTime
                
                messageBox "授权成功！欢迎使用 WhtoolS。\n请重新运行本脚本！" title:"激活成功"
                try(destroyDialog WHToolsAuthUI)catch()
            ) else (
                messageBox "授权码错误，请联系开发者获取正确授权码！" title:"激活失败"
            )
        )
    )
    createDialog WHToolsAuthUI modal:true
) else (
-- 授权通过，向下加载工具箱主程序

-- 脚本名称: WH 集合工具箱 (WH Toolbox)
-- ========================================================

global customIsolateMgr
global rCustomIsolate
global SplineOffsetRollout

try(cui.UnRegisterDialogBar WHToolboxUI)catch()
try(destroyDialog WHToolboxUI)catch()

global iniPathPc = getDir #plugcfg + "\\PianChuangSettings.ini"

-- Source: 智能车位生成器_带摆放车辆.ms
rollout ParkingGeneratorUI "智能车位生成器 (含随机摆车) v2.0" width:250
(
    -- 备选车辆模型库
    local vehiclePool = #()

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
            return ()
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
                            
                            -- 完美数学原理方案: 提取并保留车辆原本视口显示“正向”的完美身姿(继承可能带有纠偏的轴心旋转和缩放)
                            local srcRotScale = srcCar.transform
                            srcRotScale.row4 = [0,0,0]
                            
                            -- 提取车位的纯净方位信息(完全抹除可能被用户意外拖拽拉伸产生的不均匀缩放)
                            local dirX = normalize areaNode.transform.row1
                            local dirY = normalize areaNode.transform.row2
                            local dirZ = normalize areaNode.transform.row3
                            local rotArea = matrix3 dirX dirY dirZ [0,0,0]
                            
                            -- 开始在极安全的局部与世界坐标夹层中处理: 先带入车辆原始身姿
                            local finalMatrix = srcRotScale
                            
                            -- 【关键修正】由于车位面默认是沿着样条线方向(X轴)拉伸，车位深度是Y轴，
                            -- 而汽车模型通常车头朝向自身的+Y，放入环境后会导致“横着停”。
                            -- 我们在此处直接追加一个 90 度的底层偏转，让它正视车位开口。
                            finalMatrix = finalMatrix * (rotateZMatrix -90.0)
                            
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
)

-- Source: 片窗.ms
rollout UI_WinMakerTool "PianChuang Tool V26 - Custom Grid" width:230 height:365
    (
        groupBox grpParam "参数设置 (Parameters)" pos:[10,10] width:210 height:140
        
        label lblOuter "外框 (Outer) :" pos:[20,35]
        spinner spnOuterSize "" range:[0,1000,75] type:#float pos:[100,35] fieldwidth:55
        label lblOuterUnit "mm" pos:[165,35]
        
        label lblInner "内分隔 (Inner) :" pos:[20,60]
        spinner spnInnerSize "" range:[0,1000,50] type:#float pos:[100,60] fieldwidth:55
        label lblInnerUnit "mm" pos:[165,60]
        
        label lblFrame "框厚度 (Frame) :" pos:[20,85]
        spinner spnFrameThick "" range:[1,1000,80] type:#float pos:[100,85] fieldwidth:55
        label lblFrameUnit "mm" pos:[165,85]
        
        label lblGlass "玻璃厚 (Glass) :" pos:[20,110]
        spinner spnGlassThick "" range:[1,1000,8] type:#float pos:[100,110] fieldwidth:55
        label lblGlassUnit "mm" pos:[165,110]
        
        groupBox grpGrid "快速分格 (Quick Grid)" pos:[10,155] width:210 height:60
        
        -- 全新进化：基于高亮微型预览图的 4 个全图形化按键，彻底淘汰冗余文字！
        button btnGrid22 "" pos:[18, 172] width:42 height:32 tooltip:"田字格 (2列2行)"
        button btnGrid32 "" pos:[68, 172] width:42 height:32 tooltip:"三分两段 (3列2行)"
        button btnGrid23 "" pos:[118, 172] width:42 height:32 tooltip:"两分三段 (2列3行)"
        button btnGrid33 "" pos:[168, 172] width:42 height:32 tooltip:"九宫格 (3列3行)"
        
        groupBox grpCustomGrid "自定义分格 (Custom Grid)" pos:[10,225] width:210 height:75
        spinner spnCols "竖向列:" range:[1,100,4] type:#integer pos:[20, 245] fieldwidth:45
        spinner spnRows "横向行:" range:[1,100,4] type:#integer pos:[125, 245] fieldwidth:45
        button btnGridCustom "执行自定义网格划分" pos:[16, 268] width:198 height:25
        
        button btnMake "秒速生成片窗 (Make Window)" pos:[10, 310] width:210 height:45
        
        -- 🔥 首创：利用 3ds Max 底层内存像素绘画引擎 (Pixel Renderer)
        -- 在脚本打开的0.01秒内，纯粹通过数学数组瞬间绘制出四张高精度的网格结构预览图，
        -- 并神不知鬼不觉地将其镶嵌进按钮里！无需任何外部附带 jpg 图片文件！
        fn renderGridIcon w h cols rows filename = (
            local bg = (color 60 60 65)  -- 高质感深灰色暗黑UI背景
            local ln = (color 200 210 220) -- 高亮设计线稿色
            local bmp = bitmap w h color:bg
            
            -- 绘制微缩模型边界线（外框1像素）
            for x = 0 to w-1 do (setPixels bmp [x,0] #(ln); setPixels bmp [x,h-1] #(ln))
            for y = 0 to h-1 do (setPixels bmp [0,y] #(ln); setPixels bmp [w-1,y] #(ln))
            
            -- 绘制内部切割结构线（加宽到双像素以增强高清辨识度）
            for i = 1 to cols-1 do (
                local x = (i as float / cols * w) as integer
                for y = 0 to h-1 do (
                    setPixels bmp [x,y] #(ln)
                    if x+1 < w do setPixels bmp [x+1,y] #(ln)
                )
            )
            for j = 1 to rows-1 do (
                local y = (j as float / rows * h) as integer
                for x = 0 to w-1 do (
                    setPixels bmp [x,y] #(ln)
                    if y+1 < h do setPixels bmp [x,y+1] #(ln)
                )
            )
            
            local path = getDir #temp + "\\" + filename + ".bmp"
            bmp.filename = path
            save bmp
            close bmp
            return path
        )
        
        on UI_WinMakerTool open do (
            try (
                local p22 = renderGridIcon 42 32 2 2 "PchGrid22"
                btnGrid22.images = #(p22, undefined, 1, 1, 1, 1, 1)
                
                local p32 = renderGridIcon 42 32 3 2 "PchGrid32"
                btnGrid32.images = #(p32, undefined, 1, 1, 1, 1, 1)
                
                local p23 = renderGridIcon 42 32 2 3 "PchGrid23"
                btnGrid23.images = #(p23, undefined, 1, 1, 1, 1, 1)
                
                local p33 = renderGridIcon 42 32 3 3 "PchGrid33"
                btnGrid33.images = #(p33, undefined, 1, 1, 1, 1, 1)
            ) catch ()
            
            try (
                local vOut = getINISetting iniPathPc "Settings" "OuterSize"
                if vOut != "" do spnOuterSize.value = vOut as float
                local vIn = getINISetting iniPathPc "Settings" "InnerSize"
                if vIn != "" do spnInnerSize.value = vIn as float
                local vFD = getINISetting iniPathPc "Settings" "FrameDepth"
                if vFD != "" do spnFrameThick.value = vFD as float
                local vGD = getINISetting iniPathPc "Settings" "GlassDepth"
                if vGD != "" do spnGlassThick.value = vGD as float
                
                local vCols = getINISetting iniPathPc "Settings" "CustomCols"
                if vCols != "" do spnCols.value = vCols as integer
                local vRows = getINISetting iniPathPc "Settings" "CustomRows"
                if vRows != "" do spnRows.value = vRows as integer
            ) catch ()
        )
        
        on UI_WinMakerTool close do (
            try (
                setINISetting iniPathPc "Settings" "OuterSize" (spnOuterSize.value as string)
                setINISetting iniPathPc "Settings" "InnerSize" (spnInnerSize.value as string)
                setINISetting iniPathPc "Settings" "FrameDepth" (spnFrameThick.value as string)
                setINISetting iniPathPc "Settings" "GlassDepth" (spnGlassThick.value as string)
                setINISetting iniPathPc "Settings" "CustomCols" (spnCols.value as string)
                setINISetting iniPathPc "Settings" "CustomRows" (spnRows.value as string)
            ) catch ()
        )
        
        fn cleanFlatLines obj preVerts = (
            local numE = polyop.getNumEdges obj
            if numE == 0 do return()
            local openE = polyop.getOpenEdges obj
            local intE = #{1..numE} - openE
            local coplanarE = #{}
            
            for e in intE do (
                local ev = polyop.getEdgeVerts obj e
                if preVerts[ev[1]] and preVerts[ev[2]] do (
                    local fList = (polyop.getFacesUsingEdge obj #{e}) as array
                    if fList.count == 2 do (
                        local m1 = polyop.getFaceMatID obj fList[1]
                        local m2 = polyop.getFaceMatID obj fList[2]
                        if m1 == 2 and m2 == 2 do (
                            local n1 = polyop.getFaceNormal obj fList[1]
                            local n2 = polyop.getFaceNormal obj fList[2]
                            if (dot n1 n2) > 0.999 do append coplanarE e
                        )
                    )
                )
            )
            
            if not coplanarE.isEmpty do (
                local checkVerts = polyop.getVertsUsingEdge obj coplanarE
                local oldEdgeCount = polyop.getNumEdges obj
                
                local success = false
                try (
                    local ep = Edit_Poly()
                    addModifier obj ep
                    ep.SetSelection #Edge coplanarE
                    ep.ButtonOp #RemoveEdge
                    local forceEval = obj.mesh
                    collapseStack obj
                    success = true
                ) catch (
                    try(deleteModifier obj 1)catch()
                )
                
                if not success do (
                    resumeEditing()
                    local currSel = getCurrentSelection()
                    select obj
                    try ( if subobjectLevel != 2 do subobjectLevel = 2 ) catch ()
                    obj.EditablePoly.SetSelection #Edge coplanarE
                    obj.EditablePoly.Remove()
                    try ( if subobjectLevel != 0 do subobjectLevel = 0 ) catch ()
                    if currSel.count > 0 do select currSel
                    suspendEditing()
                )
                
                local deadV = #()
                for v in checkVerts do (
                    try(if (polyop.getEdgesUsingVert obj #{v}).numberset == 0 do append deadV v)catch()
                )
                if deadV.count > 0 do polyop.deleteVerts obj deadV
            )
        )

        fn generateGrid objs cols rows = (
            if objs.count == 0 do return()
            
            try (
                disableSceneRedraw()
                
                undo "Quick Grid Math" on (
                    local processedNodes = #()
                    for obj in objs do (
                        if superclassof obj == Shape or superclassof obj == GeometryClass do (
                            try(InstanceMgr.MakeObjectsUnique #(obj) #individual)catch()
                            convertTo obj Editable_Poly
                            
                            if (polyop.getNumFaces obj) == 1 and (polyop.getNumEdges obj) == 4 do (
                                local fVerts = polyop.getFaceVerts obj 1
                                
                                local v_A = polyop.getVert obj fVerts[1]
                                local v_B = polyop.getVert obj fVerts[2]
                                local v_C = polyop.getVert obj fVerts[3]
                                local v_D = polyop.getVert obj fVerts[4]
                                
                                polyop.deleteVerts obj #{1..(polyop.getNumVerts obj)}
                                
                                local vertMap = #()
                                for i = 0 to cols do (
                                    local u = (i as float) / cols
                                    local colArr = #()
                                    for j = 0 to rows do (
                                        local v = (j as float) / rows
                                        local pt = (1.0-u)*(1.0-v)*v_A + u*(1.0-v)*v_B + u*v*v_C + (1.0-u)*v*v_D
                                        local newVIdx = polyop.createVert obj pt
                                        append colArr newVIdx
                                    )
                                    append vertMap colArr
                                )
                                
                                for i = 1 to cols do (
                                    for j = 1 to rows do (
                                        local vA = vertMap[i][j]
                                        local vB = vertMap[i+1][j]
                                        local vC = vertMap[i+1][j+1]
                                        local vD = vertMap[i][j+1]
                                        polyop.createPolygon obj #(vA, vB, vC, vD)
                                    )
                                )
                                
                                append processedNodes obj
                            )
                        )
                    )
                    if processedNodes.count > 0 do select processedNodes
                )
                
                enableSceneRedraw()
                redrawViews()
            ) catch (
                enableSceneRedraw()
                redrawViews()
                throw()
            )
        )
        
        on btnGrid22 pressed do generateGrid (getCurrentSelection()) 2 2
        on btnGrid32 pressed do generateGrid (getCurrentSelection()) 3 2
        on btnGrid23 pressed do generateGrid (getCurrentSelection()) 2 3
        on btnGrid33 pressed do generateGrid (getCurrentSelection()) 3 3
        
        on btnGridCustom pressed do generateGrid (getCurrentSelection()) spnCols.value spnRows.value

        on btnMake pressed do (
            local objs = getCurrentSelection()
            if objs.count == 0 do return()
            
            local validObjs = #()
            for obj in objs do (
                if superclassof obj == GeometryClass do (
                    try(InstanceMgr.MakeObjectsUnique #(obj) #individual)catch()
                    if classof obj != Editable_Poly do convertTo obj Editable_Poly
                    append validObjs obj
                )
            )
            if validObjs.count == 0 do return()
            
            try (
                setINISetting iniPathPc "Settings" "OuterSize" (spnOuterSize.value as string)
                setINISetting iniPathPc "Settings" "InnerSize" (spnInnerSize.value as string)
                setINISetting iniPathPc "Settings" "FrameDepth" (spnFrameThick.value as string)
                setINISetting iniPathPc "Settings" "GlassDepth" (spnGlassThick.value as string)
                setINISetting iniPathPc "Settings" "CustomCols" (spnCols.value as string)
                setINISetting iniPathPc "Settings" "CustomRows" (spnRows.value as string)
            ) catch ()
            
            local oldTaskMode = getCommandPanelTaskMode()
            if oldTaskMode != #modify do setCommandPanelTaskMode #modify
            
            try (
                disableSceneRedraw()
                suspendEditing()
                
                undo "MakeWindow UltraFast" on (
                    local frameMat, glMat
                    local hasVray = false
                    try ( if VRayMtl != undefined do hasVray = true ) catch()
                    
                    if hasVray then (
                        frameMat = VRayMtl name:"Frame_Mat"
                        frameMat.diffuse = color 11 11 12
                        try(frameMat.reflection = color 80 80 80)catch() 
                        try(frameMat.hilight_glossiness = 0.75)catch()
                        try(frameMat.reflection_glossiness = 0.75)catch() 
                        try(frameMat.reflection_fresnel = true)catch()
                        try(frameMat.reflection_ior = 2.2)catch() 
                        glMat = VRayMtl name:"Glass_Mat"
                        glMat.diffuse = color 10 15 20 
                        try(glMat.reflection = color 220 220 220)catch() 
                        try(glMat.refraction = color 180 190 200)catch() 
                        try(glMat.reflection_fresnel = true)catch()
                        try(glMat.reflection_ior = 1.8)catch() 
                        try(glMat.refraction_ior = 1.52)catch()
                        try(glMat.refraction_affectShadows = true)catch() 
                        try(glMat.reflection_maxDepth = 5)catch() 
                    ) else (
                        frameMat = StandardMaterial name:"Frame_Mat"
                        frameMat.diffuse = color 50 50 50
                        glMat = StandardMaterial name:"Glass_Mat"
                        glMat.diffuse = color 10 30 50
                        glMat.opacity = 20
                    )
                    
                    local outerFrameSize = spnOuterSize.value
                    local innerFrameSize = spnInnerSize.value
                    local frameThickness = spnFrameThick.value
                    local glassThickness = spnGlassThick.value
                    
                    local groupInset = outerFrameSize - (innerFrameSize / 2.0)
                    local polyInset = innerFrameSize / 2.0
                    
                    for obj in validObjs do (
                        local numF = polyop.getNumFaces obj
                        local glassFaces = #{1..numF}
                        
                        polyop.setFaceMatID obj glassFaces 1
                        
                        if groupInset > 0 do (
                            polyop.bevelFaces obj glassFaces 0.0 -groupInset
                            polyop.setFaceMatID obj glassFaces 2
                        )
                        if groupInset == 0 do polyop.setFaceMatID obj glassFaces 2
                        
                        local preVerts = #{1..(polyop.getNumVerts obj)}
                        
                        if polyInset > 0 do (
                            local oldFaceCount = polyop.getNumFaces obj
                            local successB = false
                            try (
                                local epBevel = Edit_Poly()
                                addModifier obj epBevel
                                epBevel.SetSelection #Face glassFaces
                                epBevel.bevelType = 2
                                epBevel.bevelHeight = 0.0
                                epBevel.bevelOutline = -polyInset
                                epBevel.ButtonOp #Bevel
                                local forceEval = obj.mesh
                                collapseStack obj
                                successB = true
                            ) catch (
                                try(deleteModifier obj 1)catch()
                            )
                            
                            if (polyop.getNumFaces obj) == oldFaceCount or not successB do (
                                for f in glassFaces as array do (
                                    try(polyop.bevelFaces obj #{f} 0.0 -polyInset)catch()
                                )
                            )
                        )
                        
                        if not glassFaces.isEmpty do (
                            local baseName = obj.name
                            local rndStr = (random 1000 9999) as string
                            local frameObjName = baseName + "_Frame_" + rndStr
                            local glassObjName = baseName + "_Glass_" + rndStr
                            
                            obj.name = frameObjName
                            
                            polyop.detachFaces obj glassFaces delete:true asNode:true name:glassObjName
                            local glassObj = getNodeByName glassObjName
                            
                            cleanFlatLines obj preVerts
                            polyop.setFaceMatID obj #{1..(polyop.getNumFaces obj)} 1
                            
                            local fShell = Shell innerAmount:(frameThickness/2.0) outerAmount:(frameThickness/2.0)
                            addModifier obj fShell
                            obj.material = frameMat
                            obj.wirecolor = color 0 0 0
                            
                            if glassObj != undefined do (
                                polyop.setFaceMatID glassObj #{1..(polyop.getNumFaces glassObj)} 1
                                local gShell = Shell innerAmount:(glassThickness/2.0) outerAmount:(glassThickness/2.0)
                                addModifier glassObj gShell
                                glassObj.material = glMat
                                glassObj.wirecolor = color 0 0 0
                            )
                        )
                    )
                )
                
                resumeEditing()
                clearSelection()
                if validObjs.count > 0 do select validObjs
                enableSceneRedraw()
                redrawViews()
                if oldTaskMode != #modify do setCommandPanelTaskMode oldTaskMode
            ) catch (
                resumeEditing()
                enableSceneRedraw()
                redrawViews()
                throw()
            )
        )
    )

-- Source: 隔离独立空间工具_安装版.ms
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

rollout rCustomIsolate "Isolate Space Tool" width:180 height:275 (
    group "隔离空间 (多层)" (
        button btn_isolate   "隔离选择" width:160 height:40 tooltip:"隔离选中物体，防 Unhide All"
        button btn_endIsolate "取消隔离" width:160 height:40 tooltip:"回退一层隔离空间"
        label lbl_info "当前隔离层: 0" align:#center
    )
    
    group "视图孤立 (Alt+Q)" (
        button btn_nativeIso "孤立选择" width:160 height:30 tooltip:"执行 3ds Max 原生孤立 (Alt+Q)"
        button btn_hfiUnhide "取消孤立" width:160 height:30 tooltip:"执行 HFI 安全显示所有 (不打断隔离空间)"
    )

    fn updateInfo = (
        if customIsolateMgr != undefined do
            lbl_info.text = "当前隔离层: " + (customIsolateMgr.stack.count as string)
    )

    on btn_isolate pressed do (
        setINISetting (getMAXIniFile()) "LayerDialog" "PromptUnhideAllLayers" "0"
        setINISetting (getMAXIniFile()) "LayerDialog" "UnhideAllLayers" "0"

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
            
            -- 如果完全退出了隔离状态（栈为空），则恢复系统默认询问行为
            if customIsolateMgr.stack.count == 0 do (
                setINISetting (getMAXIniFile()) "LayerDialog" "PromptUnhideAllLayers" "1"
            )
        ) else (
            messageBox "当前没有处于隔离状态的空间。" title:"提示"
        )
    )
    
    on btn_hfiUnhide pressed do (
        -- Safety Unhide: Excludes nodes on '_隔离临时层_'
        undo "WH_SafeUnhide" on (
            local isoLayer = LayerManager.getLayerFromName "_隔离临时层_"
            if isoLayer != undefined do isoLayer.on = false
            
            for o in objects where (o.isHidden and (o.layer == undefined or o.layer.name != "_隔离临时层_")) do o.isHidden = false
            forceCompleteRedraw()
        )
    )
    
    on btn_nativeIso pressed do (
        -- Native Isolate (40194 is standard for Isolate Selection)
        if IsolateSelection != undefined then (
            try ( IsolateSelection.EnterIsolateSelectionMode() ) catch ( actionMan.executeAction 0 40194 )
        ) else (
            actionMan.executeAction 0 40194
        )
    )

    on rCustomIsolate open do (
        rCustomIsolate.title = "隔离空间工具" -- Lazy load Chinese title to prevent encoding bias
        if customIsolateMgr != undefined do customIsolateMgr.loadFromScene()
        updateInfo()
    )
)

-- Source: 偏移+.ms
-- 作者: 你的AI助理 (进阶极净 实时预览版)
-- 目的: 在3ds Max中实现类似CAD的“偏移”功能，支持无损实时预览。
-- 修复: 新增共线点化简与绝对直线识别，根除直角产生交叉尖刺、且直线段完全不产生多余顶点！

rollout SplineOffsetRollout "样条线偏移工具" width:260 height:290
(
    spinner spn_distance "偏移距离:" type:#float range:[-1e9,1e9,200.0] fieldwidth:80 pos:[20,10]
    spinner spn_samples "曲线插值数:" type:#integer range:[1,100,16] fieldwidth:80 pos:[20,40]
    
    label lbl_line1 "----------------------------------------" pos:[20,65]

    checkbox chk_preview "开启实时预览 (所见即所得)" checked:false pos:[20,80]
    checkbutton chk_reverseDir "【 方 向 反 转 】 (切换内外)" width:220 height:30 checked:false pos:[20,100] highlightColor:(color 120 180 255)
    
    label lbl_line2 "----------------------------------------" pos:[20,135]

    checkbox chk_deleteOriginal "偏移后删除原样条线" checked:true pos:[20,150]
    checkbox chk_selectNew "执行后选中新偏移线" checked:false pos:[20,170]
    
    button btn_run "确认生成 (执行偏移)" width:220 height:32 pos:[20,195] tooltip:"如果在预览模式下，会将当前预览转正。否则直接执行。"

    label lbl_tip "使用说明: 勾选'实时预览'后可拖动距离或\n方向反转实时观察。调整满意后点击确认。" pos:[20,235] width:220 height:50

    timer tmr_init interval:50 active:false

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
                                        if isCls do try(close newSh spIdx)catch()
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
                                        if isCls do try(close newSh spIdx)catch()
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

    local selChangeCb = undefined

    fn onSelectionChanged ev nd = (
        if chk_preview.checked do tmr_init.active = true
    )

    -- 主执行按钮
    on btn_run pressed do
    (
        saveSettings()
        chk_preview.checked = false 
        clearPreview()
        doOffset isPreview:false
    )

    on tmr_init tick do
    (
        tmr_init.active = false
        if chk_preview.checked do (
            clearPreview()
            doOffset isPreview:true
        )
    )

    -- 面板生命周期
    on SplineOffsetRollout open do
    (
        loadSettings()
        if chk_preview.checked do tmr_init.active = true
        selChangeCb = NodeEventCallback selectionChanged:onSelectionChanged
    )

    on SplineOffsetRollout close do
    (
        saveSettings()
        selChangeCb = undefined
        gc light:true
        chk_preview.checked = false
        clearPreview()
    )
)

-- Source: 线条平分.ms
/*
线条平分连接脚本
功能：选择样条线中的两条线段或整条样条线，按数量平分并在相应等分点上连接
新增功能：支持生成实体双线连接（保留板厚），并将剩余空间等分
*/



rollout splConnectDialog "线条平分连接" width:190 height:170 (
    spinner spnNum "分段数/板数:" range:[1,100,2] type:#integer pos:[15, 15] width:150
    checkbox chkThick "生成实体板(双连线)" checked:true pos:[15, 45]
    spinner spnThick "板厚参数:" range:[0.001, 10000, 1000.0] type:#float pos:[15, 70] width:150
    checkbox chkEnds "包含首尾两端" checked:false pos:[15, 100]
    button btnConnect "连 接" width:155 height:35 pos:[15, 125]
    
    on chkThick changed state do spnThick.enabled = state
    on splConnectDialog open do spnThick.enabled = chkThick.checked
    
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

rollout WHToolboxUI "WhtoolS" width:280 height:800
(
    checkbutton btnTab1 "车位" width:50 height:30 pos:[8,5] checked:true
    checkbutton btnTab2 "片窗" width:50 height:30 pos:[60,5]
    checkbutton btnTab3 "隔离" width:50 height:30 pos:[112,5]
    checkbutton btnTab4 "偏移" width:50 height:30 pos:[164,5]
    checkbutton btnTab5 "连接" width:50 height:30 pos:[216,5]
    
    GroupBox grpLine "" pos:[5,40] width:270 height:2
    
    subRollout sub_tools "" width:270 height:705 pos:[5,50]
    
    GroupBox grpBottomLine "" pos:[5,760] width:270 height:2
    label lblAuth "已授权-永久" pos:[15,777] width:160
    button btnUninstall "卸载插件" pos:[190,773] width:80 height:22 tooltip:"完全卸载本插件并清除本机授权信息"
    
    fn switchTab idx = (
        try(for r in sub_tools.rollouts do RemoveSubRollout sub_tools r)catch()
        
        btnTab1.checked = (idx == 1)
        btnTab2.checked = (idx == 2)
        btnTab3.checked = (idx == 3)
        btnTab4.checked = (idx == 4)
        btnTab5.checked = (idx == 5)

        if idx == 1 do try(AddSubRollout sub_tools ParkingGeneratorUI; ParkingGeneratorUI.open = true)catch()
        if idx == 2 do try(AddSubRollout sub_tools UI_WinMakerTool; UI_WinMakerTool.open = true)catch()
        if idx == 3 do try(AddSubRollout sub_tools rCustomIsolate; rCustomIsolate.open = true)catch()
        if idx == 4 do try(AddSubRollout sub_tools SplineOffsetRollout; SplineOffsetRollout.open = true)catch()
        if idx == 5 do try(AddSubRollout sub_tools splConnectDialog; splConnectDialog.open = true)catch()
    )
    
    on btnTab1 changed state do if state then switchTab 1 else btnTab1.checked = true
    on btnTab2 changed state do if state then switchTab 2 else btnTab2.checked = true
    on btnTab3 changed state do if state then switchTab 3 else btnTab3.checked = true
    on btnTab4 changed state do if state then switchTab 4 else btnTab4.checked = true
    on btnTab5 changed state do if state then switchTab 5 else btnTab5.checked = true
    
    on btnUninstall pressed do
    (
        if queryBox "确定要完全卸载 WhtoolS 插件并清除本机授权吗？\n卸载后插件将彻底关闭，系统深处的安装核心也会被同时移除。" title:"卸载警告" do
        (
            local iniPathAuth = getDir #plugcfg + "\\WHToolsAuth.ini"
            setINISetting iniPathAuth "License" "Key" ""
            setINISetting iniPathAuth "License" "AuthTime" ""
            
            -- 完全抹除深度的安装版残留文件
            local mcrPath1 = getDir #usermacros + "\\WhtoolS_Button.mcr"
            local mcrPath2 = getDir #usermacros + "\\whtool-WhtoolS_Installer.mcr"
            local corePath = getDir #userscripts + "\\WhtoolS_Core.mse"
            try(if doesFileExist mcrPath1 do deleteFile mcrPath1)catch()
            try(if doesFileExist mcrPath2 do deleteFile mcrPath2)catch()
            try(if doesFileExist corePath do deleteFile corePath)catch()
            
            try(cui.UnRegisterDialogBar WHToolboxUI)catch()
            try(destroyDialog WHToolboxUI)catch()
            messageBox "插件核心引擎、快捷配置及本机授权凭证已全部彻底抹除！\n\n（💡 提示：工具栏上若还看着残留的那个空壳图标，您可以按住键盘 Alt 键，用鼠标直接把它拖拽到画面空白处扔掉即可！重启后它在自定义菜单里也已彻底消失不复存在。）" title:"卸载成功"
        )
    )

    on WHToolboxUI open do
    (
        switchTab 1
        if WHAuth_trialDate != "" then (
            local yr = substring WHAuth_trialDate 1 4
            local mt = substring WHAuth_trialDate 5 2
            local dy = substring WHAuth_trialDate 7 2
            lblAuth.text = "试用期至: " + yr + "/" + mt + "/" + dy
        ) else (
            lblAuth.text = "已授权-永久"
        )
    )
    
    on WHToolboxUI resized size do
    (
        try(
            sub_tools.height = size.y - 95
            sub_tools.width = size.x - 10
            grpLine.width = size.x - 10
            
            grpBottomLine.width = size.x - 10
            grpBottomLine.pos = [5, size.y - 40]
            lblAuth.pos = [15, size.y - 23]
            btnUninstall.pos = [size.x - 90, size.y - 27]
        )catch()
    )
)

createDialog WHToolboxUI style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing)
try(cui.RegisterDialogBar WHToolboxUI style:#(#cui_dock_left, #cui_dock_right, #cui_floatable))catch()

) -- End of isAuthorized Context
) -- END MAIN SCRIPT BLOCK

---------------------------------------------------------
-- WhtoolS 自动安装与注册 MacroScript 模块 (仅首次拖入执行)
---------------------------------------------------------
try (
    local currentScript = getSourceFileName()
    if currentScript != undefined do (
        local currentLower = toLower currentScript
        local targetDir = getDir #userscripts
        local targetPath = targetDir + "\\WhtoolS_Core.mse"
        local targetLower = toLower targetPath
        
        if currentLower != targetLower then (
            -- 来源于外部文件拖入，执行核心文件部署并创建快捷指令
            try(deleteFile targetPath)catch()
            local copied = copyFile currentScript targetPath
            
            if copied then (
                -- 核心打包代码：仅创建一句简单的 fileIn 指令，绝对避免拖拽卡顿
                -- CRITICAL: macroScript header tokens cannot contain multi-byte (Chinese) chars
                -- They are parsed by a strict ASCII tokenizer. Use ASCII for ALL header fields.
                local mcrString = "macroScript WhtoolS_Installer\n" +
                                  "category:\"whtool\"\n" +
                                  "buttonText:\"WhtoolS\"\n" +
                                  "tooltip:\"WhtoolS Pro\"\n" +
                                  "(\n" +
                                  "    on execute do (\n" +
                                  "        local corePath = getDir #userscripts + \"/WhtoolS_Core.mse\"\n" +
                                  "        if doesFileExist corePath then fileIn corePath\n" +
                                  "        else messageBox \"Core file missing. Please drag the installer again.\" title:\"WhtoolS Error\"\n" +
                                  "    )\n" +
                                  ")\n"
                                  
                -- 写入到专门的 mcr 文件并执行将其注册进 Max UI 系统
                local mcrPath = getDir #usermacros + "\\WhtoolS_Button.mcr"
                local fMcr = createFile mcrPath
                format "%" mcrString to:fMcr
                close fMcr
                
                -- 让 Max 刷新并加载这个刚刚生成的轻量级 macro
                fileIn mcrPath
                
                messageBox "✨静默部署成功！✨\n\n此安装包已永久内置入 3ds Max 系统目录。\n请前往菜单栏：\n[ 自定义(Customize) -> 自定义用户界面(Customize User Interface) -> 工具栏(Toolbars) ]\n在 whtool 分类下，把 WhtoolS 图标直接拖放到面板上即可永久使用！" title:"WhtoolS 自动部署器"
            ) else (
                messageBox "写入核心目录权限不足：请尝试右键使用管理员权限重新启动 3ds Max 后再拖放本安装包。" title:"静默安装失败"
            )
        )
    )
) catch ()

