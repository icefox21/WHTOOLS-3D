global iniPathPc = getDir #plugcfg + "\PianChuangSettings.ini"
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

        fn getOrCreatePchMaterial matName defaultCreator = (
            local foundMat = undefined
            -- 1. 优先从场景材质中查找同名材质，以确保完全复用同一个材质球实例
            for m in sceneMaterials do (
                if m.name == matName do (
                    foundMat = m
                    exit
                )
            )
            -- 2. 备选从材质编辑器 24 个槽位中查找，防止未赋给物体的材质丢失
            if foundMat == undefined do (
                for i = 1 to 24 do (
                    if meditMaterials[i] != undefined and meditMaterials[i].name == matName do (
                        foundMat = meditMaterials[i]
                        exit
                    )
                )
            )
            -- 3. 如果均未找到，则调用传入的创建函数生成默认材质
            if foundMat == undefined do (
                foundMat = defaultCreator()
            )
            foundMat
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
                    -- 定义窗框材质创建函数，改名叫 "窗框"
                    local createFrame = (fn _createF = (
                        local hasVray = false
                        try ( if VRayMtl != undefined do hasVray = true ) catch()
                        local m
                        if hasVray then (
                            m = VRayMtl name:"窗框"
                            m.diffuse = color 11 11 12
                            try(m.reflection = color 80 80 80)catch() 
                            try(m.hilight_glossiness = 0.75)catch()
                            try(m.reflection_glossiness = 0.75)catch() 
                            try(m.reflection_fresnel = true)catch()
                            try(m.reflection_ior = 2.2)catch() 
                        ) else (
                            m = StandardMaterial name:"窗框"
                            m.diffuse = color 50 50 50
                        )
                        m
                    ))
                    
                    -- 定义玻璃材质创建函数，改名叫 "玻璃"
                    local createGlass = (fn _createG = (
                        local hasVray = false
                        try ( if VRayMtl != undefined do hasVray = true ) catch()
                        local m
                        if hasVray then (
                            m = VRayMtl name:"玻璃"
                            m.diffuse = color 10 15 20 
                            try(m.reflection = color 69 69 69)catch()
                            try(m.hilight_glossiness = 1.0)catch()
                            try(m.reflection_glossiness = 1.0)catch()
                            try(m.reflection_fresnel = false)catch()
                            try(m.reflection_ior = 1.8)catch()
                            try(m.refraction = color 180 190 200)catch() 
                            try(m.refraction_glossiness = 1.0)catch()
                            try(m.refraction_ior = 1.52)catch()
                            try(m.refraction_affectShadows = true)catch() 
                            try(m.reflection_maxDepth = 5)catch()
                            try(m.refraction_maxDepth = 8)catch()
                        ) else (
                            m = StandardMaterial name:"玻璃"
                            m.diffuse = color 10 30 50
                            m.opacity = 20
                        )
                        m
                    ))
                    
                    -- 智能拉取或新建同名材质球，防止多批次重复生成
                    local frameMat = getOrCreatePchMaterial "窗框" createFrame
                    local glMat = getOrCreatePchMaterial "玻璃" createGlass
                    
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

try(destroyDialog UI_WinMakerTool)catch()
createDialog UI_WinMakerTool style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)
