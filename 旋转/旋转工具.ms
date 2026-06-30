-- 旋转工具 v1.0
(
    global WhRotation_Rollout
    try(destroyDialog WhRotation_Rollout)catch()
    
    -- 默认预设值
    local presetX = #(90.0, 180.0, -90.0)
    local presetY = #(90.0, 180.0, -90.0)
    local presetZ = #(90.0, 180.0, -90.0)
    
    fn rotateSelection axis angle = (
        if selection.count == 0 do return()
        undo "旋转工具" on (
            local vtm = getViewTM()
            if vtm == undefined do vtm = matrix3 1
            -- 极端重要：必须消除视图矩阵的“摄像机位置平移”，变成纯正的观察方向旋转矩阵，否则物体会绕着远处的摄像机公转而飞走！
            vtm.translation = [0, 0, 0]
            
            local rotM = case axis of (
                #x: rotateXMatrix angle
                #y: rotateYMatrix angle
                #z: rotateZMatrix angle
            )
            
            -- 仅操作顶层节点，防止对组内子层级进行二次双重变换
            local topNodes = for n in selection where (n.parent == undefined or not n.parent.isSelected) collect n
            
            for obj in topNodes do (
                -- 读取每个物体的真实轴心(Pivot)而不是几何中心，支持用户自定义旋转轴！
                local ctr = obj.pivot
                local pivotTM = (transMatrix -ctr) * vtm * rotM * (inverse vtm) * (transMatrix ctr)
                obj.transform = obj.transform * pivotTM
            )
        )
    )

    rollout WhRotation_Rollout "快速旋转工具" width:220 height:240 (
        local iniFile = getDir #plugcfg + "\\WhRotation_Settings.ini"
        
        fn saveSettings = (
            try (
                setINISetting iniFile "Settings" "AngleX" (spnX.value as string)
                setINISetting iniFile "Settings" "AngleY" (spnY.value as string)
                setINISetting iniFile "Settings" "AngleZ" (spnZ.value as string)
                setINISetting iniFile "Presets" "X1" (presetX[1] as string)
                setINISetting iniFile "Presets" "X2" (presetX[2] as string)
                setINISetting iniFile "Presets" "X3" (presetX[3] as string)
                setINISetting iniFile "Presets" "Y1" (presetY[1] as string)
                setINISetting iniFile "Presets" "Y2" (presetY[2] as string)
                setINISetting iniFile "Presets" "Y3" (presetY[3] as string)
                setINISetting iniFile "Presets" "Z1" (presetZ[1] as string)
                setINISetting iniFile "Presets" "Z2" (presetZ[2] as string)
                setINISetting iniFile "Presets" "Z3" (presetZ[3] as string)
            ) catch()
        )
        
        fn loadSettings = (
            try (
                if doesFileExist iniFile do (
                    local v = getINISetting iniFile "Settings" "AngleX"
                    if v != "" do spnX.value = v as float
                    v = getINISetting iniFile "Settings" "AngleY"
                    if v != "" do spnY.value = v as float
                    v = getINISetting iniFile "Settings" "AngleZ"
                    if v != "" do spnZ.value = v as float
                    
                    v = getINISetting iniFile "Presets" "X1"
                    if v != "" do (presetX[1] = v as float; btnX1.text = (v as string))
                    v = getINISetting iniFile "Presets" "X2"
                    if v != "" do (presetX[2] = v as float; btnX2.text = (v as string))
                    v = getINISetting iniFile "Presets" "X3"
                    if v != "" do (presetX[3] = v as float; btnX3.text = (v as string))
                    
                    v = getINISetting iniFile "Presets" "Y1"
                    if v != "" do (presetY[1] = v as float; btnY1.text = (v as string))
                    v = getINISetting iniFile "Presets" "Y2"
                    if v != "" do (presetY[2] = v as float; btnY2.text = (v as string))
                    v = getINISetting iniFile "Presets" "Y3"
                    if v != "" do (presetY[3] = v as float; btnY3.text = (v as string))
                    
                    v = getINISetting iniFile "Presets" "Z1"
                    if v != "" do (presetZ[1] = v as float; btnZ1.text = (v as string))
                    v = getINISetting iniFile "Presets" "Z2"
                    if v != "" do (presetZ[2] = v as float; btnZ2.text = (v as string))
                    v = getINISetting iniFile "Presets" "Z3"
                    if v != "" do (presetZ[3] = v as float; btnZ3.text = (v as string))
                )
            ) catch()
        )

        groupBox grpX "X 轴" pos:[5,5] width:210 height:70
        spinner spnX "角度:" range:[-3600,3600,90] type:#float pos:[15,25] fieldWidth:50
        button btnX_apply "旋转" pos:[125,23] width:80 height:22
        button btnX1 "90" pos:[15,48] width:60 height:20
        button btnX2 "180" pos:[80,48] width:60 height:20
        button btnX3 "-90" pos:[145,48] width:60 height:20
        
        groupBox grpY "Y 轴" pos:[5,80] width:210 height:70
        spinner spnY "角度:" range:[-3600,3600,90] type:#float pos:[15,100] fieldWidth:50
        button btnY_apply "旋转" pos:[125,98] width:80 height:22
        button btnY1 "90" pos:[15,123] width:60 height:20
        button btnY2 "180" pos:[80,123] width:60 height:20
        button btnY3 "-90" pos:[145,123] width:60 height:20
        
        groupBox grpZ "Z 轴" pos:[5,155] width:210 height:70
        spinner spnZ "角度:" range:[-3600,3600,90] type:#float pos:[15,175] fieldWidth:50
        button btnZ_apply "旋转" pos:[125,173] width:80 height:22
        button btnZ1 "90" pos:[15,198] width:60 height:20
        button btnZ2 "180" pos:[80,198] width:60 height:20
        button btnZ3 "-90" pos:[145,198] width:60 height:20

        -- X 轴事件
        on btnX_apply pressed do rotateSelection #x spnX.value
        on btnX1 pressed do rotateSelection #x presetX[1]
        on btnX2 pressed do rotateSelection #x presetX[2]
        on btnX3 pressed do rotateSelection #x presetX[3]
        
        on btnX1 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设1?" title:"设置预设"
            if val do (presetX[1] = spnX.value; btnX1.text = (spnX.value as string); saveSettings())
        )
        on btnX2 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设2?" title:"设置预设"
            if val do (presetX[2] = spnX.value; btnX2.text = (spnX.value as string); saveSettings())
        )
        on btnX3 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设3?" title:"设置预设"
            if val do (presetX[3] = spnX.value; btnX3.text = (spnX.value as string); saveSettings())
        )

        -- Y 轴事件
        on btnY_apply pressed do rotateSelection #y spnY.value
        on btnY1 pressed do rotateSelection #y presetY[1]
        on btnY2 pressed do rotateSelection #y presetY[2]
        on btnY3 pressed do rotateSelection #y presetY[3]
        
        on btnY1 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设1?" title:"设置预设"
            if val do (presetY[1] = spnY.value; btnY1.text = (spnY.value as string); saveSettings())
        )
        on btnY2 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设2?" title:"设置预设"
            if val do (presetY[2] = spnY.value; btnY2.text = (spnY.value as string); saveSettings())
        )
        on btnY3 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设3?" title:"设置预设"
            if val do (presetY[3] = spnY.value; btnY3.text = (spnY.value as string); saveSettings())
        )

        -- Z 轴事件
        on btnZ_apply pressed do rotateSelection #z spnZ.value
        on btnZ1 pressed do rotateSelection #z presetZ[1]
        on btnZ2 pressed do rotateSelection #z presetZ[2]
        on btnZ3 pressed do rotateSelection #z presetZ[3]
        
        on btnZ1 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设1?" title:"设置预设"
            if val do (presetZ[1] = spnZ.value; btnZ1.text = (spnZ.value as string); saveSettings())
        )
        on btnZ2 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设2?" title:"设置预设"
            if val do (presetZ[2] = spnZ.value; btnZ2.text = (spnZ.value as string); saveSettings())
        )
        on btnZ3 rightClick do (
            local val = queryBox "是否将当前输入框的值设为预设3?" title:"设置预设"
            if val do (presetZ[3] = spnZ.value; btnZ3.text = (spnZ.value as string); saveSettings())
        )
        
        on WhRotation_Rollout open do loadSettings()
        on WhRotation_Rollout close do saveSettings()
    )
    createDialog WhRotation_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)
