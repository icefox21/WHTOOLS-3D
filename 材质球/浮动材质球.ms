-- 浮动材质球 v1.5
-- 终极交互重构：废弃原生的 materialButton，使用 .NET Button 完美实现左键赋材质、右键弹菜单。
-- 背景色智能跟随材质颜色，替代无法实时生成的 3D 材质球。

global WH_FloatMat_Rollout
global WH_FloatMat_Config_Rollout
global WH_FloatMat_RCMenu
global WH_FloatMat_Struct

-- 轻柔系统提示音（代替弹窗）
fn WH_beep = ( try((dotNetClass "System.Media.SystemSounds").Asterisk.Play())catch() )

-- 定义核心逻辑体
struct WH_FloatMat_Core (
    iniFile = (getDir #userscripts) + "\\whtools_floatmat_config.ini",
    matArray = #(),
    currentBtnIdx = 0,
    
    fn getVRayMtl = (
        local vmat = undefined
        try(vmat = VRayMtl())catch()
        if vmat == undefined do try(vmat = PhysicalMaterial())catch()
        if vmat == undefined do try(vmat = StandardMaterial())catch()
        return vmat
    ),
    
    fn getSceneMatLibPath = (
        if maxFilePath == "" then (
            return (getDir #userscripts) + "\\WH_FloatMats_Untitled.mat"
        ) else (
            return maxFilePath + "WH_FloatMats_" + (getFilenameFile maxFileName) + ".mat"
        )
    ),
    
    fn saveSceneMats = (
        local libPath = getSceneMatLibPath()
        local tempLib = materialLibrary()
        for i = 1 to matArray.count do (
            if isKindOf matArray[i] Material then (
                append tempLib matArray[i]
            ) else (
                local dummy = StandardMaterial name:"WH_EMPTY_SLOT"
                append tempLib dummy
            )
        )
        try(saveTempMaterialLibrary tempLib libPath)catch()
    ),
    
    fn loadSceneMats totalSlots = (
        local libPath = getSceneMatLibPath()
        local newArray = #()
        if doesFileExist libPath then (
            local tempLib = undefined
            try(tempLib = loadTempMaterialLibrary libPath)catch()
            
            if tempLib != undefined then (
                for i = 1 to totalSlots do (
                    local isEmptySlot = true
                    if i <= tempLib.count and isKindOf tempLib[i] Material then (
                        local mName = ""
                        try(mName = tempLib[i].name as string)catch()
                        -- 名称不是留空展位标识且不是默认无名 VRayMtl，才视为真实材质
                        if mName != "WH_EMPTY_SLOT" and mName != "VRayMtl" do isEmptySlot = false
                    )
                    if isEmptySlot then (
                        append newArray undefined
                    ) else (
                        append newArray tempLib[i]
                    )
                )
            ) else (
                for i = 1 to totalSlots do append newArray undefined
            )
        ) else (
            for i = 1 to totalSlots do append newArray undefined
        )
        matArray = newArray
    ),
    
    fn loadConfig = (
        local c = getINISetting iniFile "Settings" "Cols"
        local r = getINISetting iniFile "Settings" "Rows"
        if c == "" do c = "4"
        if r == "" do r = "3"
        #(c as integer, r as integer)
    ),
    
    fn saveConfig c r = (
        setINISetting iniFile "Settings" "Cols" (c as string)
        setINISetting iniFile "Settings" "Rows" (r as string)
    ),
    
    fn getCurrentMeditMaterial = (
        if MatEditor.mode == #basic then (
            return meditMaterials[activeMeditSlot]
        ) else (
            local mat = undefined
            try (mat = sme.GetMtlInParamEditor()) catch()
            if mat != undefined and isKindOf mat Material then return mat
            
            try (
                if sme.isOpen() do (
                    local view = sme.GetView (sme.activeView)
                    if view != undefined do (
                        for i = 1 to view.GetNumNodes() do (
                            local n = view.GetNode i
                            if n.selected and isKindOf n.reference Material do return n.reference
                        )
                    )
                )
            ) catch()
        )
        return meditMaterials[activeMeditSlot]
    ),
    
    fn getMatColor mat = (
        local c = color 120 120 120
        try (
            if isProperty mat "diffuse" then c = mat.diffuse
            else if isProperty mat "diffuse_color" then c = mat.diffuse_color
            else if isProperty mat "color" then c = mat.color
            else if isProperty mat "base_color" then c = mat.base_color
            else if isProperty mat "colorDiffuse" then c = mat.colorDiffuse
            else if isProperty mat "baseColor" then c = mat.baseColor
            
            if classOf c != Color do c = color 120 120 120
        ) catch()
        
        return c
    ),
    
    fn getMatTexture mat = (
        local tex = undefined
        try (
            if isProperty mat "texmap_diffuse" and mat.texmap_diffuse != undefined then (
                if isProperty mat "texmap_diffuse_on" then (if mat.texmap_diffuse_on do tex = mat.texmap_diffuse) else tex = mat.texmap_diffuse
            )
            if tex == undefined and isProperty mat "diffuseMap" and mat.diffuseMap != undefined then (
                if isProperty mat "diffuseMapEnable" then (if mat.diffuseMapEnable do tex = mat.diffuseMap) else tex = mat.diffuseMap
            )
            if tex == undefined and isProperty mat "base_color_map" and mat.base_color_map != undefined then (
                if isProperty mat "base_color_map_on" then (if mat.base_color_map_on do tex = mat.base_color_map) else tex = mat.base_color_map
            )
            if tex == undefined and isProperty mat "texmap_base_color" and mat.texmap_base_color != undefined then (
                if isProperty mat "texmap_base_color_on" then (if mat.texmap_base_color_on do tex = mat.texmap_base_color) else tex = mat.texmap_base_color
            )
            if tex == undefined and isProperty mat "colorTexmap" and mat.colorTexmap != undefined do tex = mat.colorTexmap
            if tex == undefined and isProperty mat "baseColorTexmap" and mat.baseColorTexmap != undefined do tex = mat.baseColorTexmap
            if tex == undefined and isProperty mat "map_diffuse" and mat.map_diffuse != undefined do tex = mat.map_diffuse
            if tex == undefined and isProperty mat "base_map" and mat.base_map != undefined do tex = mat.base_map
        ) catch()
        if tex != undefined and isKindOf tex TextureMap then return tex
        return undefined
    ),
    
    fn bruteForceFindBitmapPath tex = (
        if tex == undefined do return undefined
        
        try (
            local props = getPropNames tex
            for p in props do (
                local val = getProperty tex p
                if classOf val == String and val != "" do (
                    local ext = toLower (getFilenameType val)
                    if ext == ".jpg" or ext == ".png" or ext == ".bmp" or ext == ".jpeg" or ext == ".tif" or ext == ".tiff" or ext == ".hdr" or ext == ".exr" or ext == ".tx" or ext == ".tga" do (
                        if doesFileExist val do return val
                        local absPath = mapPaths.getFullFilePath val
                        if absPath != "" do return absPath
                    )
                )
            )
        ) catch()
        
        try (
            for i = 1 to getNumSubTexmaps tex do (
                local sub = getSubTexmap tex i
                if sub != undefined do (
                    local res = bruteForceFindBitmapPath sub
                    if res != undefined do return res
                )
            )
        ) catch()
        
        return undefined
    ),
    
    fn updateBtnUI idx = (
        try (
            local mat = matArray[idx]
            local btn = undefined
            try(btn = execute ("WH_FloatMat_Rollout.btn_" + (idx as string)))catch()
            
            if btn != undefined do (
                local bw = 75
                local bh = 55  -- 位图只画球体，文字由 btn.Text 负责
                
                local bmp = dotNetObject "System.Drawing.Bitmap" bw bh
                local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
                
                try(g.SmoothingMode = (dotNetClass "System.Drawing.Drawing2D.SmoothingMode").AntiAlias)catch()
                try(g.InterpolationMode = (dotNetClass "System.Drawing.Drawing2D.InterpolationMode").HighQualityBicubic)catch()
                
                try (
                    local bgBrush = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 50 50 50)
                    g.FillRectangle bgBrush 0 0 bw bh
                    bgBrush.Dispose()
                ) catch()
                
                if isKindOf mat Material then (
                    local c = getMatColor mat
                    local rr = c.r as integer; local gg = c.g as integer; local bb = c.b as integer
                    if rr < 0 do rr = 0; if rr > 255 do rr = 255
                    if gg < 0 do gg = 0; if gg > 255 do gg = 255
                    if bb < 0 do bb = 0; if bb > 255 do bb = 255
                    
                    local d = 46
                    local cx = (bw - d) / 2
                    local cy = 4
                    local cx_i = cx as integer
                    local cy_i = cy as integer
                    local d_i = d as integer
                    
                    try (
                        local dropShBrush = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 100 0 0 0)
                        g.FillEllipse dropShBrush (cx_i+3) (cy_i+4) d_i d_i
                        dropShBrush.Dispose()
                    ) catch()
                    
                    local texImg = undefined
                    try (
                        local tex = getMatTexture mat
                        if tex != undefined do (
                            local rawPath = bruteForceFindBitmapPath tex
                            
                            local isStd = false
                            if rawPath != undefined do (
                                local ext = toLower (getFilenameType rawPath)
                                if ext == ".jpg" or ext == ".png" or ext == ".bmp" or ext == ".jpeg" do isStd = true
                            )
                            
                            local finalBmpPath = undefined
                            local baseDir = maxFilePath
                            if baseDir == "" do baseDir = getDir #scene
                            local thumbDir = pathConfig.appendPath baseDir "WH_FloatMat_Thumbs"
                            makeDir thumbDir
                            local tempFile = pathConfig.appendPath thumbDir ("wh_thumb_" + (idx as string) + ".bmp")
                            
                            if isStd then (
                                finalBmpPath = rawPath
                            ) else (
                                if rawPath != undefined and doesFileExist rawPath then (
                                    try (
                                        local tempMap = openBitmap rawPath
                                        if tempMap != undefined do (
                                            local maxBmp = bitmap 64 64
                                            copy tempMap maxBmp
                                            maxBmp.filename = tempFile
                                            save maxBmp
                                            close maxBmp
                                            close tempMap
                                            finalBmpPath = tempFile
                                        )
                                    ) catch()
                                )
                                if finalBmpPath == undefined do (
                                    try (
                                        local maxBmp = bitmap 64 64
                                        renderMap tex into:maxBmp size:[64,64] display:false filter:true
                                        maxBmp.filename = tempFile
                                        save maxBmp
                                        close maxBmp
                                        finalBmpPath = tempFile
                                    ) catch( try(close maxBmp)catch() )
                                )
                            )
                            
                            if finalBmpPath != undefined and doesFileExist finalBmpPath do (
                                sleep 0.02
                                local ms = dotNetObject "System.IO.MemoryStream"
                                local fs = dotNetObject "System.IO.FileStream" finalBmpPath (dotNetClass "System.IO.FileMode").Open (dotNetClass "System.IO.FileAccess").Read
                                fs.CopyTo ms
                                fs.Close()
                                ms.Position = 0
                                texImg = (dotNetClass "System.Drawing.Image").FromStream ms
                            )
                        )
                    ) catch (
                        format "[WH] updateBtnUI Texture Load Error: %\n" (getCurrentException())
                        texImg = undefined
                    )
                    
                    local path = undefined
                    try (
                        path = dotNetObject "System.Drawing.Drawing2D.GraphicsPath"
                        path.AddEllipse cx_i cy_i d_i d_i
                        g.SetClip path
                    ) catch()
                    
                    local isGlass = false
                    
                    try (
                        if classOf mat == VRayMtl then (
                            if isProperty mat "refraction" do (
                                if (classOf mat.refraction == Color and mat.refraction.v > 30) or (isProperty mat "texmap_refraction" and mat.texmap_refraction != undefined) do isGlass = true
                            )
                        ) else if classOf mat == PhysicalMaterial then (
                            if isProperty mat "transparency" and mat.transparency > 0.2 do isGlass = true
                        ) else if classOf mat == StandardMaterial then (
                            if isProperty mat "opacity" and mat.opacity < 85 do isGlass = true
                        )
                    ) catch()
                    
                    if texImg != undefined then (
                        try (
                            g.DrawImage texImg cx_i cy_i d_i d_i
                            texImg.Dispose()
                        ) catch()
                    ) else (
                        try (
                            if isGlass then (
                                local topRect = dotNetObject "System.Drawing.Rectangle" cx_i cy_i d_i (d_i/2 as integer)
                                local botRect = dotNetObject "System.Drawing.Rectangle" cx_i (cy_i + d_i/2 as integer) d_i (d_i/2 as integer)
                                
                                local topC1 = (dotNetClass "System.Drawing.Color").FromArgb 220 230 240
                                local topC2 = (dotNetClass "System.Drawing.Color").FromArgb 100 110 120
                                local botC1 = (dotNetClass "System.Drawing.Color").FromArgb 20 25 30
                                local botC2 = (dotNetClass "System.Drawing.Color").FromArgb 5 10 15
                                local topBrush = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" topRect topC1 topC2 (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").Vertical
                                local botBrush = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" botRect botC1 botC2 (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").Vertical
                                g.FillRectangle topBrush topRect
                                g.FillRectangle botBrush botRect
                                topBrush.Dispose(); botBrush.Dispose()
                                
                                local causticRect = dotNetObject "System.Drawing.Rectangle" cx_i (cy_i + (d_i*0.3) as integer) d_i ((d_i*0.7) as integer)
                                local cstC1 = (dotNetClass "System.Drawing.Color").FromArgb 0 255 255 255
                                local cstC2 = (dotNetClass "System.Drawing.Color").FromArgb 160 255 255 255
                                local cstBrush = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" causticRect cstC1 cstC2 (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").Vertical
                                g.FillRectangle cstBrush causticRect
                                cstBrush.Dispose()
                                
                                if rr > 10 or gg > 10 or bb > 10 do (
                                    local tintBrush = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 90 rr gg bb)
                                    g.FillRectangle tintBrush cx_i cy_i d_i d_i
                                    tintBrush.Dispose()
                                )
                                
                                local pen = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 60 255 255 255) 1
                                g.DrawLine pen cx_i (cy_i + d_i/2 as integer) (cx_i + d_i) (cy_i + d_i/2 as integer)
                                pen.Dispose()
                            ) else (
                                local baseBrush = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb rr gg bb)
                                g.FillEllipse baseBrush cx_i cy_i d_i d_i
                                baseBrush.Dispose()
                            )
                        ) catch()
                    )
                    
                    -- 绘制逼真的三维质感光影层（完美对标 3ds Max 材质编辑器）
                    try (
                        -- 1. 体积感阴影 (平滑的暗部过渡，使用全尺寸渐变以避免生硬边缘)
                        local shRect = dotNetObject "System.Drawing.Rectangle" (cx_i - d_i*0.2 as integer) (cy_i - d_i*0.2 as integer) (d_i*1.4 as integer) (d_i*1.4 as integer)
                        local shC1 = (dotNetClass "System.Drawing.Color").FromArgb 0 0 0 0
                        local shC2 = (dotNetClass "System.Drawing.Color").FromArgb 160 0 0 0
                        local shBrush = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" shRect shC1 shC2 (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").ForwardDiagonal
                        g.FillEllipse shBrush cx_i cy_i d_i d_i
                        shBrush.Dispose()
                        
                        -- 2. 边缘反光 (Rim light，增加通透感)
                        local rimRect = dotNetObject "System.Drawing.Rectangle" cx_i cy_i d_i d_i
                        local rimC1 = (dotNetClass "System.Drawing.Color").FromArgb 40 255 255 255
                        local rimC2 = (dotNetClass "System.Drawing.Color").FromArgb 0 255 255 255
                        local rimBrush = dotNetObject "System.Drawing.Drawing2D.LinearGradientBrush" rimRect rimC1 rimC2 (dotNetClass "System.Drawing.Drawing2D.LinearGradientMode").ForwardDiagonal
                        g.FillEllipse rimBrush cx_i cy_i d_i d_i
                        rimBrush.Dispose()
                        
                        -- 3. 极度柔和的高光点 (通过多层透明同心圆叠加，完美模拟安全不崩溃的径向渐变)
                        local hx = cx_i + (d_i * 0.1) as integer
                        local hy = cy_i + (d_i * 0.1) as integer
                        local maxHlSize = (d_i * 0.45) as float
                        local steps = 6
                        for i = steps to 1 by -1 do (
                            local ratio = (i as float) / steps
                            local alpha = 30 -- 每层叠加 30 的不透明度，最中心叠加6次形成高亮
                            local sSize = (maxHlSize * ratio) as integer
                            if sSize > 0 do (
                                local offset = ((maxHlSize - sSize)/2) as integer
                                local sRect = dotNetObject "System.Drawing.Rectangle" (hx + offset) (hy + offset) sSize sSize
                                local b = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb alpha 255 255 255)
                                g.FillEllipse b sRect
                                b.Dispose()
                            )
                        )
                    ) catch()
                    
                    try (
                        g.ResetClip()
                        if path != undefined do path.Dispose()
                    ) catch()
                    
                    try (
                        local pen = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 60 0 0 0) (1.0 as float)
                        g.DrawEllipse pen cx_i cy_i d_i d_i
                        pen.Dispose()
                    ) catch()
                    
                ) else (
                    -- 空槽位：实线斜纹 + 大"×"符号（最可靠的视觉标识）
                    try (
                        local pen = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 55 200 200 200) (1.0 as float)
                        local si = -bh
                        while si <= (bw + bh) do (
                            g.DrawLine pen si 0 (si + bh) bh
                            si += 8
                        )
                        pen.Dispose()
                    ) catch()
                    local cx_x = (bw / 2) as integer
                    local cy_x = ((bh / 2) - 4) as integer
                    local hs = 13
                    try (
                        local pen = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 150 190 190 190) (2.5 as float)
                        g.DrawLine pen (cx_x - hs) (cy_x - hs) (cx_x + hs) (cy_x + hs)
                        g.DrawLine pen (cx_x + hs) (cy_x - hs) (cx_x - hs) (cy_x + hs)
                        pen.Dispose()
                    ) catch()
                )
                
                try(g.Dispose())catch()
                
                -- 材质名称和空槽标识用 btn.Text 显示（最可靠方式）
                local matName = "空"
                local isEmptyDisplay = not (isKindOf mat Material)
                if isKindOf mat Material do (
                    try(matName = mat.name as string)catch()
                    if matName == "" or matName == undefined do matName = "未命名"
                )
                btn.Image = bmp
                btn.Text = matName
                btn.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 7.5
                if isEmptyDisplay then (
                    btn.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 110 110 110
                ) else (
                    btn.ForeColor = (dotNetClass "System.Drawing.Color").White
                )
                btn.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 50 50 50
                try (
                    btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                    btn.FlatAppearance.BorderSize = 0
                ) catch()
                btn.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").BottomCenter
                btn.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
                btn.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageAboveText
            )
        ) catch (
            format "[WH] updateBtnUI CRITICAL Error idx:% => %\n" idx (getCurrentException())
        )
    ),
    
    fn pickFromObject idx = (
        if selection.count > 0 then (
            local mat = selection[1].material
            if mat != undefined then (
                matArray[idx] = mat
                saveSceneMats()
                updateBtnUI idx
            ) else (
                WH_beep()
            )
        ) else (
            WH_beep()
        )
    ),
    
    fn pickFromMedit idx = (
        local mat = getCurrentMeditMaterial()
        if isKindOf mat Material then (
            matArray[idx] = mat
            saveSceneMats()
            updateBtnUI idx
        ) else (
            WH_beep()
        )
    ),
    
    fn applyMatToObject idx = (
        if selection.count > 0 then (
            local mat = matArray[idx]
            if isKindOf mat Material do (
                for obj in selection do obj.material = mat
            )
        ) else (
            WH_beep()
        )
    ),
    
    fn editInCompact idx = (
        local mat = matArray[idx]
        if isKindOf mat Material then (
            MatEditor.mode = #basic
            if not MatEditor.isOpen() do MatEditor.Open()
            meditMaterials[activeMeditSlot] = mat
        )
    ),
    
    fn editInSlate idx = (
        local mat = matArray[idx]
        if isKindOf mat Material then (
            MatEditor.mode = #advanced
            if not MatEditor.isOpen() do MatEditor.Open()
            try (
                local view = sme.GetView (sme.activeView)
                if view != undefined do view.CreateNode mat [0,0]
            ) catch()
        )
    ),
    
    fn renameMaterial idx = (
        local mat = matArray[idx]
        if isKindOf mat Material then (
            global WH_FloatMat_RenameMat = mat
            global WH_FloatMat_RenameIdx = idx
            
            -- 重启 Max 后 .mcr 不会重新定义 rollout，需在此动态补回
            if WH_FloatMat_Rename_Rollout == undefined or classOf WH_FloatMat_Rename_Rollout != RolloutClass do (
                execute (
                    "global WH_FloatMat_Rename_Rollout\n" +
                    "rollout WH_FloatMat_Rename_Rollout \"重命名材质\" width:220 height:80 (\n" +
                    "    edittext edt_name \"\" text:\"\" pos:[10,15] width:195\n" +
                    "    button btn_ok \"确定\" pos:[50,45] width:60 height:25\n" +
                    "    button btn_cancel \"取消\" pos:[115,45] width:60 height:25\n" +
                    "    on WH_FloatMat_Rename_Rollout open do (\n" +
                    "        if WH_FloatMat_RenameMat != undefined do (\n" +
                    "            edt_name.text = WH_FloatMat_RenameMat.name as string\n" +
                    "        )\n" +
                    "        setFocus edt_name\n" +
                    "    )\n" +
                    "    on btn_ok pressed do (\n" +
                    "        local newName = edt_name.text\n" +
                    "        if newName != \"\" and WH_FloatMat_RenameMat != undefined do (\n" +
                    "            local oldName = WH_FloatMat_RenameMat.name as string\n" +
                    "            WH_FloatMat_RenameMat.name = newName\n" +
                    "            for i = 1 to 24 do (\n" +
                    "                local m = meditMaterials[i]\n" +
                    "                if m != undefined and isKindOf m Material and m.name == oldName do m.name = newName\n" +
                    "            )\n" +
                    "            if WH_FloatMat_Struct != undefined do (\n" +
                    "                if isProperty WH_FloatMat_Struct \"updateBtnUI\" do WH_FloatMat_Struct.updateBtnUI WH_FloatMat_RenameIdx\n" +
                    "                if isProperty WH_FloatMat_Struct \"saveSceneMats\" do WH_FloatMat_Struct.saveSceneMats()\n" +
                    "            )\n" +
                    "        )\n" +
                    "        destroyDialog WH_FloatMat_Rename_Rollout\n" +
                    "    )\n" +
                    "    on btn_cancel pressed do ( destroyDialog WH_FloatMat_Rename_Rollout )\n" +
                    ")\n"
                )
            )
            
            try(destroyDialog WH_FloatMat_Rename_Rollout)catch()
            createDialog WH_FloatMat_Rename_Rollout style:#(#style_titlebar, #style_toolwindow) pos:mouse.screenpos
        ) else (
            WH_beep()
        )
    ),
    
    fn clearSlot idx = (
        matArray[idx] = undefined
        saveSceneMats()
        updateBtnUI idx
    ),
    
    fn showMenu idx = (
        currentBtnIdx = idx
        popupMenu WH_FloatMat_RCMenu
    ),
    
    fn onSlotMouseDown idx arg = (
        local isLeft = (arg.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left)
        local isRight = (arg.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right)
        
        local modKeys = (dotNetClass "System.Windows.Forms.Control").ModifierKeys
        local isAlt = modKeys == (dotNetClass "System.Windows.Forms.Keys").Alt
        local isShift = modKeys == (dotNetClass "System.Windows.Forms.Keys").Shift
        
        if isLeft then (
            if isAlt then WH_FloatMat_Struct.pickFromMedit idx
            else if isShift then WH_FloatMat_Struct.pickFromObject idx
            else WH_FloatMat_Struct.applyMatToObject idx
        ) else if isRight then (
            WH_FloatMat_Struct.showMenu idx
        )
    ),
    
    fn buildUI = (
        try (
            local cfg = loadConfig()
            local cols = cfg[1]
            local rows = cfg[2]
            local totalSlots = cols * rows
            
            loadSceneMats totalSlots
            
            local btnWidth = 75
            local btnHeight = 83  -- 55px球体图 + 28px文字区，彻底避免截断
            local spacing = 4
            local startX = 5
            local startY = 32
            
            local w = startX + cols * (btnWidth + spacing)
            local h = startY + rows * (btnHeight + spacing)
            
            local str = "rollout WH_FloatMat_Rollout \"浮动材质球\" (\n"
            str += "  local isDragging = false\n"
            str += "  local dragStartPos = [0,0]\n"
            str += "  button btn_cfg \"⚙️\" pos:[5,5] width:24 height:24 tooltip:\"布局设置\"\n"
            str += "  dotNetControl btn_close \"System.Windows.Forms.Button\" pos:[" + ((w - 25) as string) + ", 5] width:20 height:20 tooltip:\"关闭\"\n"
            
            for r = 1 to rows do (
                for c = 1 to cols do (
                    local idx = (r - 1) * cols + c
                    local x = startX + (c - 1) * (btnWidth + spacing)
                    local y = startY + (r - 1) * (btnHeight + spacing)
                    str += "  dotNetControl btn_" + (idx as string) + " \"System.Windows.Forms.Button\" pos:[" + (x as string) + "," + (y as string) + "] width:" + (btnWidth as string) + " height:" + (btnHeight as string) + "\n"
                )
            )
            
            str += "  on btn_cfg pressed do ( try(destroyDialog WH_FloatMat_Config_Rollout)catch(); createDialog WH_FloatMat_Config_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) pos:mouse.screenpos )\n"
            
            str += "  on WH_FloatMat_Rollout lbuttondown pos do ( isDragging = true; dragStartPos = pos )\n"
            str += "  on WH_FloatMat_Rollout lbuttonup pos do (\n"
            str += "    isDragging = false\n"
            str += "    local p = GetDialogPos WH_FloatMat_Rollout\n"
            str += "    setINISetting WH_FloatMat_Struct.iniFile \"Settings\" \"WinPosX\" (p.x as string)\n"
            str += "    setINISetting WH_FloatMat_Struct.iniFile \"Settings\" \"WinPosY\" (p.y as string)\n"
            str += "  )\n"
            str += "  on WH_FloatMat_Rollout mouseMove pos do ( if isDragging do ( local dPos = GetDialogPos WH_FloatMat_Rollout; SetDialogPos WH_FloatMat_Rollout (dPos + pos - dragStartPos) ) )\n"
            str += "  on btn_close Click do ( try(destroyDialog WH_FloatMat_Rollout)catch() )\n"
            
            str += "  on WH_FloatMat_Rollout open do (\n"
            str += "    btn_close.Text = \"×\"\n"
            str += "    btn_close.FlatStyle = (dotNetClass \"System.Windows.Forms.FlatStyle\").Flat\n"
            str += "    btn_close.FlatAppearance.BorderSize = 0\n"
            str += "    btn_close.ForeColor = (dotNetClass \"System.Drawing.Color\").White\n"
            str += "    btn_close.BackColor = (dotNetClass \"System.Drawing.Color\").FromArgb 200 60 60\n"
            str += "    btn_close.Cursor = (dotNetClass \"System.Windows.Forms.Cursors\").Hand\n"
            for i = 1 to totalSlots do (
                str += "    local ctrl = btn_" + (i as string) + "\n"
                str += "    ctrl.FlatStyle = (dotNetClass \"System.Windows.Forms.FlatStyle\").Flat\n"
                str += "    ctrl.FlatAppearance.BorderSize = 0\n"
                str += "    WH_FloatMat_Struct.updateBtnUI " + (i as string) + "\n"
            )
            str += "  )\n"
            
            for i = 1 to totalSlots do (
                str += "  on btn_" + (i as string) + " MouseDown arg do ( WH_FloatMat_Struct.onSlotMouseDown " + (i as string) + " arg )\n"
            )
            str += ")\n"
            
            -- 优先级：1. 当前对话框位置（重建时）2. INI 保存的位置 3. 默认右上角
            local dPos = undefined
            try(dPos = GetDialogPos WH_FloatMat_Rollout)catch()
            try(destroyDialog WH_FloatMat_Rollout)catch()

            execute str

            if dPos != undefined and dPos.x == 0 and dPos.y == 0 do dPos = undefined
            if dPos != undefined and not (dPos.x > -10000 and dPos.y > -10000) do dPos = undefined

            -- 尝试从 INI 恢复
            if dPos == undefined do (
                local sx = getINISetting iniFile "Settings" "WinPosX"
                local sy = getINISetting iniFile "Settings" "WinPosY"
                if sx != "" and sy != "" do
                    dPos = [sx as integer, sy as integer]
            )

            -- 默认：屏幕右上角（留出右侧面板宽度约 200px）
            if dPos == undefined do (
                local sw = sysInfo.desktopSize.x
                dPos = [(sw - w - 200), 62]
            )

            createDialog WH_FloatMat_Rollout width:w height:h pos:dPos style:#()
        ) catch (
            messagebox ("界面生成失败，错误信息：\n" + getCurrentException()) title:"错误报告"
        )
    )
)

rcMenu WH_FloatMat_RCMenu (
    menuItem mi_pickObj "✏️ 吸取选定物体材质"
    menuItem mi_fromMedit "📥 从编辑器导入当前"
    separator sep1
    menuItem mi_rename "🏷️ 重命名当前材质"
    menuItem mi_editCompact "📝 在精简编辑器中编辑"
    menuItem mi_editSlate "🌐 在节点编辑器中编辑"
    separator sep2
    menuItem mi_applyObj "➡️ 赋给选定物体"
    separator sep3
    menuItem mi_clear "❌ 清空"
    
    on mi_pickObj picked do WH_FloatMat_Struct.pickFromObject WH_FloatMat_Struct.currentBtnIdx
    on mi_fromMedit picked do WH_FloatMat_Struct.pickFromMedit WH_FloatMat_Struct.currentBtnIdx
    on mi_rename picked do WH_FloatMat_Struct.renameMaterial WH_FloatMat_Struct.currentBtnIdx
    on mi_editCompact picked do WH_FloatMat_Struct.editInCompact WH_FloatMat_Struct.currentBtnIdx
    on mi_editSlate picked do WH_FloatMat_Struct.editInSlate WH_FloatMat_Struct.currentBtnIdx
    on mi_applyObj picked do WH_FloatMat_Struct.applyMatToObject WH_FloatMat_Struct.currentBtnIdx
    on mi_clear picked do WH_FloatMat_Struct.clearSlot WH_FloatMat_Struct.currentBtnIdx
)

-- 定义设置面板
rollout WH_FloatMat_Config_Rollout "布局设置" width:200 height:105 (
    spinner spn_cols "列数 (左右):" range:[1,20,4] type:#integer pos:[20,20] fieldWidth:40
    spinner spn_rows "行数 (上下):" range:[1,20,3] type:#integer pos:[20,50] fieldWidth:40
    button btn_guide "📖 操作指南" pos:[10,75] width:180 height:22
    
    on btn_guide pressed do (
        local msg = "【浮动材质球 极速操作指南】\n\n"
        msg += "左键相关：\n"
        msg += "• [左键单击] 槽位：将该材质赋予选中的物体\n"
        msg += "• [Alt + 左键单击] 槽位：将【材质编辑器】中当前的激活材质导入到此槽位\n"
        msg += "• [Shift + 左键单击] 槽位：吸取场景中【选中物体】的材质到此槽位\n"
        msg += "• [左键拖动] 空隙/空槽/锚点：自由移动面板位置\n\n"
        msg += "右键相关：\n"
        msg += "• [右键单击] 槽位/空槽：弹出材质专属功能菜单\n"
        msg += "• [右键单击] 锚点：弹出面板设置与管理菜单\n"
        messagebox msg title:"操作指南"
    )
    
    on WH_FloatMat_Config_Rollout open do (
        local cfg = WH_FloatMat_Struct.loadConfig()
        spn_cols.value = cfg[1]
        spn_rows.value = cfg[2]
    )
    
    on spn_cols changed val do (
        WH_FloatMat_Struct.saveConfig val spn_rows.value
        WH_FloatMat_Struct.buildUI()
    )
    
    on spn_rows changed val do (
        WH_FloatMat_Struct.saveConfig spn_cols.value val
        WH_FloatMat_Struct.buildUI()
    )
)

-- 定义重命名面板
rollout WH_FloatMat_Rename_Rollout "重命名材质" width:220 height:80 (
    edittext edt_name "" text:"" pos:[10,15] width:195
    button btn_ok "确定" pos:[50,45] width:60 height:25
    button btn_cancel "取消" pos:[115,45] width:60 height:25
    
    on WH_FloatMat_Rename_Rollout open do (
        if WH_FloatMat_RenameMat != undefined do (
            edt_name.text = WH_FloatMat_RenameMat.name as string
        )
        setFocus edt_name
    )
    
    on btn_ok pressed do (
        local newName = edt_name.text
        if newName != "" and WH_FloatMat_RenameMat != undefined do (
            local oldName = WH_FloatMat_RenameMat.name as string
            WH_FloatMat_RenameMat.name = newName
            
            -- 同步尝试修改材质编辑器里同名的材质
            for i = 1 to 24 do (
                local m = meditMaterials[i]
                if m != undefined and isKindOf m Material and m.name == oldName then (
                    m.name = newName
                )
            )
            
            if WH_FloatMat_Struct != undefined then (
                if isProperty WH_FloatMat_Struct "updateBtnUI" do WH_FloatMat_Struct.updateBtnUI WH_FloatMat_RenameIdx
                if isProperty WH_FloatMat_Struct "saveSceneMats" do WH_FloatMat_Struct.saveSceneMats()
            )
        )
        destroyDialog WH_FloatMat_Rename_Rollout
    )
    
    on btn_cancel pressed do (
        destroyDialog WH_FloatMat_Rename_Rollout
    )
)

-- 定义供工具栏使用的 MacroScript
macroScript WhFloatMat
category:"whtool"
toolTip:"浮动材质球"
buttonText:"浮动材质球"
(
    on execute do (
        try(destroyDialog WH_FloatMat_Config_Rollout)catch()
        
        WH_FloatMat_Struct = WH_FloatMat_Core()
        WH_FloatMat_Struct.buildUI()
    )
)

-- 直接执行块
(
    try(destroyDialog WH_FloatMat_Config_Rollout)catch()
    
    WH_FloatMat_Struct = WH_FloatMat_Core()
    WH_FloatMat_Struct.buildUI()
    
    -- 注册场景回调 (Scene Callbacks)
    callbacks.removeScripts id:#wh_floatmat_cb
    local cbStr = "if WH_FloatMat_Struct != undefined and isProperty WH_FloatMat_Struct \"buildUI\" do ( try(WH_FloatMat_Struct.buildUI())catch() )"
    callbacks.addScript #filePostOpen cbStr id:#wh_floatmat_cb
    callbacks.addScript #systemPostReset cbStr id:#wh_floatmat_cb
    callbacks.addScript #systemPostNew cbStr id:#wh_floatmat_cb
)

