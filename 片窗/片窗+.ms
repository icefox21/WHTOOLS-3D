global iniPathPc = getDir #plugcfg + "\PianChuangPlusSettings.ini" -- Legacy fallback only.
global UI_WinMakerToolPlus
try(destroyDialog UI_WinMakerToolPlus)catch()
try(closeRolloutFloater PC_Floater)catch() -- close stale rollout before redefining UI
global presetContextMenu
global pcPlusScriptPath = undefined

fn pcPlusGetScriptPath = (
    if pcPlusScriptPath != undefined then (
        return pcPlusScriptPath
    )
    pcPlusScriptPath = try (
        getSourceFileName()
    ) catch (
        undefined
    )
    if pcPlusScriptPath == undefined or pcPlusScriptPath == "" then (
        pcPlusScriptPath = "H:\\新软件\\3D脚本\\片窗\\片窗+.ms"
    )
    pcPlusScriptPath
)

struct structPreset (name, cols, rows, colPositions, rowPositions, colSegData, rowSegData)

global logDebug
fn logDebug msg = (
    -- Debug logging disabled: keep PianChuang+ as a single-file script and avoid startup disk I/O.
    ok
)

global detachFacesAsNode
fn detachFacesAsNode obj faceSet nodeName = (
    local oldCount = objects.count
    local success = polyop.detachFaces obj faceSet delete:true asNode:true name:nodeName
    if not success do return undefined
    if objects.count > oldCount then (
        objects[objects.count]
    ) else (
        undefined
    )
)

global findOppositeFace
fn findOppositeFace obj f1 = (
    local n1 = polyop.getFaceNormal obj f1
    local c1 = polyop.getFaceCenter obj f1
    
    local bestFace = undefined
    local minOffset = 1e9
    
    local numFaces = polyop.getNumFaces obj
    for f = 1 to numFaces do (
        if f != f1 do (
            local n2 = polyop.getFaceNormal obj f
-- 检测法线方向是否朝外 (dot product < -0.5)
            if (dot n1 n2) < -0.5 do (
                local c2 = polyop.getFaceCenter obj f
                local v = c2 - c1
                local dist_along_normal = abs (dot v n1)
-- 墙面在一般建筑高度范围内 (约 1 到 2000 mm)
                if dist_along_normal > 1.0 and dist_along_normal < 2000.0 do (
                    local v_parallel = v - (dot v n1) * n1
                    local offset = length v_parallel
                    -- 中心偏移在一定范围内 (比如小于 1000)
                    if offset < 1000.0 and offset < minOffset do (
                        minOffset = offset
                        bestFace = f
                    )
                )
            )
        )
    )
    bestFace
)




-- Native Right-Click Context Menu
rcMenu presetContextMenu
(
    menuItem menuGenerate "生成窗户"
    menuItem menuEdit "编辑预设"
    menuItem menuDelete "删除预设"
    
    on menuGenerate picked do (
        if UI_WinMakerToolPlus != undefined do UI_WinMakerToolPlus.makeWindow()
    )
    
    on menuEdit picked do (
        if UI_WinMakerToolPlus != undefined and UI_WinMakerToolPlus.contextMenuIndex != undefined and UI_WinMakerToolPlus.contextMenuIndex > 0 do (
            UI_WinMakerToolPlus.editPreset UI_WinMakerToolPlus.contextMenuIndex
        )
    )
    
    on menuDelete picked do (
        if UI_WinMakerToolPlus != undefined and UI_WinMakerToolPlus.contextMenuIndex != undefined and UI_WinMakerToolPlus.contextMenuIndex > 0 do (
            if queryBox "确定要删除该预设吗？" title:"确认" do (
                UI_WinMakerToolPlus.deletePresetAtIndex UI_WinMakerToolPlus.contextMenuIndex
            )
        )
    )
)

-- ===== 可视化网格编辑器 =====
-- divX/divY: #(pos, activeSegs array)  activeSegs: list of 1 and/or 2
global _gridEdit_result = undefined
global _gridEdit_colPositions = undefined
global _gridEdit_rowPositions = undefined
global _gridEdit_colSegData = undefined
global _gridEdit_rowSegData = undefined
global _gridEdit_divX = #()
global _gridEdit_divY = #()
global _gridEdit_divXStr = ""
global _gridEdit_divYStr = ""
global _gridEdit_selType = ""
global _gridEdit_selIdx = 0
global _gridEdit_dragging = false

-- 序列化 div 数组为字符串（绕开 MaxScript 数组子属性赋值 bug）
fn serializeDivs divs = (
    local s = ""
    for d in divs do (
        if s != "" do s += "|"
        s += (d[1] as string) + ":"
        for i = 1 to d[2].count do (
            if i > 1 do s += ","
            s += (d[2][i] as string)
        )
    )
    s
)

-- 从字符串反序列化 div 数组
fn deserializeDivs str = (
    local result = #()
    if str == "" do return result
    local entries = filterString str "|"
    for entry in entries do (
        local parts = filterString entry ":"
        if parts.count >= 1 do (
            local pos = parts[1] as float
            local segs = #(1)
            if parts.count >= 2 then (
                segs = #()
                local segParts = filterString parts[2] ","
                for sp in segParts do (
                    local sv = sp as integer
                    if sv != undefined do append segs sv
                )
                if segs.count == 0 do append segs 1
            )
            if pos != undefined do append result #(pos, segs)
        )
    )
    result
)

fn gridEdit_divToRatio divs = (
    local positions = #()
    for d in divs do (if d[2].count > 0 do append positions d[1])
    sort positions
    local all = #(0.0)
    for p in positions do append all p
    append all 1.0
    local r = #()
    for i = 2 to all.count do (
        local gap = all[i] - all[i-1]
        local v = (gap * 100.0) as integer
        if v < 1 do v = 1
        append r (v as string)
    )
    if r.count == 0 do append r "1"
    local result = r[1]
    for i = 2 to r.count do result += "," + r[i]
    result
)

-- Row ratios need to be reversed because the grid editor uses screen coords (Y down)
-- but the 3D model and thumbnail use bottom-to-top convention (row[1] = bottom)
fn gridEdit_divToRatioReversed divs = (
    local positions = #()
    for d in divs do (if d[2].count > 0 do append positions d[1])
    sort positions
    local all = #(0.0)
    for p in positions do append all p
    append all 1.0
    local r = #()
    for i = 2 to all.count do (
        local gap = all[i] - all[i-1]
        local v = (gap * 100.0) as integer
        if v < 1 do v = 1
        append r (v as string)
    )
    if r.count == 0 do append r "1"
    -- Reverse the array so screen-top becomes model-top
    local rev = #()
    for i = r.count to 1 by -1 do append rev r[i]
    local result = rev[1]
    for i = 2 to rev.count do result += "," + rev[i]
    result
)

fn gridEdit_countActive divs = (
    local count = 0
    for d in divs do (if d[2].count > 0 do count += 1)
    count
)

-- 从编辑器 div 数组提取 position 数组（ascending，用于列）
fn gridEdit_getPositions divs = (
    local positions = #()
    for d in divs do (if d[2].count > 0 do append positions d[1])
    sort positions
    local all = #(0.0)
    for p in positions do append all p
    append all 1.0
    all
)

-- 从序列化字符串计算列段数据（每条竖线跨哪些行段）
-- 从序列化字符串计算列段数据（每条竖线跨哪些行段）
-- 使用实际的段数据，并将行段索引从屏幕坐标映射到模型坐标
fn gridEdit_calcColSegData = (
    local divY = deserializeDivs _gridEdit_divYStr
    local numRowSegs = 1
    for d in divY do (if d[2].count > 0 do numRowSegs += 1)
    local divX = deserializeDivs _gridEdit_divXStr
    local result = ""
    local first = true
    for d in divX do (
        if d[2].count > 0 do (
            if not first do result += ";"
            first = false
            result += (d[1] as string) + ":"
            -- 使用实际的 d[2] 段数据，并反转行段索引（屏幕Y→模型Y）
            -- 编辑器 seg k → 模型 seg (numRowSegs + 1 - k)
            local segFirst = true
            for s in d[2] do (
                local modelSeg = numRowSegs + 1 - s
                if not segFirst do result += ","
                segFirst = false
                result += (modelSeg as string)
            )
        )
    )
    result
)

-- 从序列化字符串计算行段数据（每条横线跨哪些列段）
-- 使用实际的段数据，列段索引不需要反转
fn gridEdit_calcRowSegData = (
    local divX = deserializeDivs _gridEdit_divXStr
    local numColSegs = 1
    for d in divX do (if d[2].count > 0 do numColSegs += 1)
    local divY = deserializeDivs _gridEdit_divYStr
    local result = ""
    local first = true
    for d in divY do (
        if d[2].count > 0 do (
            if not first do result += ";"
            first = false
            -- 屏幕坐标 → 模型坐标（与 gridEdit_getRowPositions 一致）
            result += ((1.0 - d[1]) as string) + ":"
            -- 使用实际的 d[2] 段数据（列方向无需反转）
            local segFirst = true
            for s in d[2] do (
                if not segFirst do result += ","
                segFirst = false
                result += (s as string)
            )
        )
    )
    result
)

-- 从段数据字符串解析为 #(position, #(segs...)) 数组
fn parseSegData segStr = (
    local result = #()
    if segStr == undefined or segStr == "" do return result
    local entries = filterString segStr ";"
    for entry in entries do (
        local parts = filterString entry ":"
        if parts.count >= 2 do (
            local pos = parts[1] as float
            local segs = #()
            local segParts = filterString parts[2] ","
            for sp in segParts do (
                local sv = sp as integer
                if sv != undefined do append segs sv
            )
            if pos != undefined and segs.count > 0 do (
                append result #(pos, segs)
            )
        )
    )
    result
)

-- 从编辑器 div 数组提取 position 数组并反转（用于行：屏幕Y向下→模型Y向上）
fn gridEdit_getRowPositions divs = (
    local positions = #()
    for d in divs do (if d[2].count > 0 do append positions d[1])
    sort positions
    -- 反转：屏幕坐标 0=top, 1=bottom → 模型坐标 0=bottom, 1=top
    local reversed = #()
    for i = positions.count to 1 by -1 do append reversed (1.0 - positions[i])
    local all = #(0.0)
    for p in reversed do append all p
    append all 1.0
    all
)

-- 从 ratio 字符串还原 position 数组（用于从 INI 加载的预设）
fn ratiosToPositions ratioStr = (
    local parts = filterString ratioStr ",:; "
    local ratios = #()
    for p in parts do (
        local val = p as float
        if val != undefined and val > 0.0 then append ratios val
        else append ratios 1.0
    )
    if ratios.count == 0 do append ratios 1.0
    local ratioSum = 0.0
    for r in ratios do ratioSum += r
    local all = #(0.0)
    local acc = 0.0
    for r in ratios do (
        acc += r
        append all (acc / ratioSum)
    )
    all
)

fn gridEdit_fullSegs divs = (
    local n = divs.count + 1
    local r = #()
    for i = 1 to n do append r i
    r
)

fn gridEdit_remSeg segs val = (
    local r = #()
    for s in segs where s != val do append r s
    r
)

fn insertSorted &divs val segs = (
    local idx = divs.count + 1
    for i = 1 to divs.count do (
        if divs[i][1] > val do (
            idx = i
            exit
        )
    )
    insertItem #(val, segs) divs idx
    idx
)

fn gridEdit_splitSegs segs k = (
    local r = #()
    for s in segs do (
        if s < k then append r s
        else if s == k then (
            append r k
            append r (k + 1)
        ) else (
            append r (s + 1)
        )
    )
    r
)

fn gridEdit_mergeSegs segs k = (
    local r = #()
    for s in segs do (
        if s < k then (
            if (findItem r s) == 0 do append r s
        ) else if s == k or s == k+1 then (
            if (findItem r k) == 0 do append r k
        ) else (
            local val = s - 1
            if (findItem r val) == 0 do append r val
        )
    )
    r
)

rollout WH_GridEdit_Rollout "网格编辑器" width:300 height:340 (
    label lblHint "左键=加横线 | 右键=加竖线 | 点击线=拖动 | Shift+左键=删全线 | Shift+右键=删段" pos:[10,5] width:290
    dotNetControl pvCanvas "System.Windows.Forms.Panel" pos:[10,25] width:280 height:240
    label lblInfo "列: 1  行: 1" pos:[10,275] width:200
    button btnClear "清空全部" pos:[10,295] width:80 height:25
    button btnOK "保存预设" pos:[110,295] width:80 height:25
    button btnCancel "取消" pos:[210,295] width:80 height:25
    
    fn updateInfo = ( lblInfo.text = "列: " + (gridEdit_countActive _gridEdit_divX + 1) as string + "  行: " + (gridEdit_countActive _gridEdit_divY + 1) as string )
    fn refreshPreview = ( pvCanvas.Invalidate(); updateInfo() )
    
    fn findNearest mx my = (
        local w = pvCanvas.Width; local h = pvCanvas.Height
        local nx = (mx - 2.0) / (w - 4.0); local ny = (my - 2.0) / (h - 4.0)
        local thr = 8.0 / w
        local bD = 1e9; local bT = ""; local bI = 0; local bS = 0
        
        local rowP = #(0.0)
        for d in _gridEdit_divY do (if d[2].count > 0 do append rowP d[1])
        append rowP 1.0
        sort rowP
        
        for i = 1 to _gridEdit_divX.count do (
            local d = _gridEdit_divX[i]
            local dx = abs (nx - d[1])
            if dx < thr do (
                for seg in d[2] do (
                    if seg > 0 and seg < rowP.count do (
                        local y1 = rowP[seg]
                        local y2 = rowP[seg+1]
                        if ny >= y1 and ny <= y2 and dx < bD do (
                            bD = dx; bT = "x"; bI = i; bS = seg
                        )
                    )
                )
            )
        )
        
        local colP = #(0.0)
        for d in _gridEdit_divX do (if d[2].count > 0 do append colP d[1])
        append colP 1.0
        sort colP
        
        for i = 1 to _gridEdit_divY.count do (
            local d = _gridEdit_divY[i]
            local dy = abs (ny - d[1])
            if dy < thr do (
                for seg in d[2] do (
                    if seg > 0 and seg < colP.count do (
                        local x1 = colP[seg]
                        local x2 = colP[seg+1]
                        if nx >= x1 and nx <= x2 and dy < bD do (
                            bD = dy; bT = "y"; bI = i; bS = seg
                        )
                    )
                )
            )
        )
        #(bT, bI, bS)
    )
    
    fn drawGrid sender args = (
        local g = args.Graphics; local w = sender.Width; local h = sender.Height
        local bgB = undefined
        local bdrP = undefined
        local selP = undefined
        local lnP = undefined
        try (
            bgB = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 40 40 45)
            g.FillRectangle bgB 0 0 w h
            
            bdrP = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 150 150 150) 2.0
            g.DrawRectangle bdrP 1 1 (w-3) (h-3)
            
            selP = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 255 100 100) 2.5
            lnP = dotNetObject "System.Drawing.Pen" ((dotNetClass "System.Drawing.Color").FromArgb 200 220 240) 1.5
            
            local rowP = #(0.0)
            for d in _gridEdit_divY do (if d[2].count > 0 do append rowP d[1])
            append rowP 1.0
            sort rowP
            
            local colP = #(0.0)
            for d in _gridEdit_divX do (if d[2].count > 0 do append colP d[1])
            append colP 1.0
            sort colP
            
            for i = 1 to _gridEdit_divX.count do (
                local d = _gridEdit_divX[i]
                if d[2].count > 0 do (
                    local x = (d[1] * (w-4) + 2) as integer
                    local isS = (_gridEdit_selType == "x" and _gridEdit_selIdx == i)
                    for seg in d[2] do (
                        if seg > 0 and seg < rowP.count do (
                            local y1 = (rowP[seg] * (h-4) + 2) as integer
                            local y2 = (rowP[seg+1] * (h-4) + 2) as integer
                            g.DrawLine (if isS then selP else lnP) x y1 x y2
                        )
                    )
                )
            )
            
            for i = 1 to _gridEdit_divY.count do (
                local d = _gridEdit_divY[i]
                if d[2].count > 0 do (
                    local y = (d[1] * (h-4) + 2) as integer
                    local isS = (_gridEdit_selType == "y" and _gridEdit_selIdx == i)
                    for seg in d[2] do (
                        if seg > 0 and seg < colP.count do (
                            local x1 = (colP[seg] * (w-4) + 2) as integer
                            local x2 = (colP[seg+1] * (w-4) + 2) as integer
                            g.DrawLine (if isS then selP else lnP) x1 y x2 y
                        )
                    )
                )
            )
        ) catch ()
        if bgB != undefined do try(bgB.Dispose())catch()
        if bdrP != undefined do try(bdrP.Dispose())catch()
        if selP != undefined do try(selP.Dispose())catch()
        if lnP != undefined do try(lnP.Dispose())catch()
    )
    
    on pvCanvas Paint sender args do (
        try (
            drawGrid sender args
        ) catch ()
    )
    
    on pvCanvas MouseDown sender args do (
        local w = pvCanvas.Width; local h = pvCanvas.Height
        local nx = (args.X - 2.0) / (w - 4.0); local ny = (args.Y - 2.0) / (h - 4.0)
        local modKeys = (dotNetClass "System.Windows.Forms.Control").ModifierKeys
        local shiftKey = (dotNetClass "System.Windows.Forms.Keys").Shift
        local isShift = (bit.and (modKeys.GetHashCode()) (shiftKey.GetHashCode())) != 0
        local near = findNearest args.X args.Y
        
        if isShift then (
            if near[1] != "" and near[2] > 0 then (
                if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left then (
                    -- Shift+左键：删除整条线
                    if near[1] == "x" then (
                        local k = near[2]
                        for i = 1 to _gridEdit_divY.count do (
                            _gridEdit_divY[i][2] = gridEdit_mergeSegs _gridEdit_divY[i][2] k
                        )
                        deleteItem _gridEdit_divX k
                    ) else (
                        local k = near[2]
                        for i = 1 to _gridEdit_divX.count do (
                            _gridEdit_divX[i][2] = gridEdit_mergeSegs _gridEdit_divX[i][2] k
                        )
                        deleteItem _gridEdit_divY k
                    )
                ) else if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then (
                    -- Shift+右键：删除局部段
                    if near[1] == "x" then (
                        local k = near[2]
                        local ns = gridEdit_remSeg _gridEdit_divX[k][2] near[3]
                        if ns.count > 0 then (
                            _gridEdit_divX[k][2] = ns
                        ) else (
                            for i = 1 to _gridEdit_divY.count do (
                                _gridEdit_divY[i][2] = gridEdit_mergeSegs _gridEdit_divY[i][2] k
                            )
                            deleteItem _gridEdit_divX k
                        )
                    ) else (
                        local k = near[2]
                        local ns = gridEdit_remSeg _gridEdit_divY[k][2] near[3]
                        if ns.count > 0 then (
                            _gridEdit_divY[k][2] = ns
                        ) else (
                            for i = 1 to _gridEdit_divX.count do (
                                _gridEdit_divX[i][2] = gridEdit_mergeSegs _gridEdit_divX[i][2] k
                            )
                            deleteItem _gridEdit_divY k
                        )
                    )
                )
                _gridEdit_selType = ""; _gridEdit_selIdx = 0; refreshPreview()
            )
        ) else if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left then (
            if near[1] != "" and near[2] > 0 then (
                _gridEdit_selType = near[1]; _gridEdit_selIdx = near[2]; _gridEdit_dragging = true; refreshPreview()
            ) else if (ny > 0.02 and ny < 0.98) then (
                -- 左键：加整条横线
                local segs = gridEdit_fullSegs _gridEdit_divX
                local k = insertSorted &_gridEdit_divY ny segs
                local xi = 1
                while xi <= _gridEdit_divX.count do (
                    _gridEdit_divX[xi] = #(_gridEdit_divX[xi][1], gridEdit_splitSegs _gridEdit_divX[xi][2] k)
                    xi += 1
                )
                _gridEdit_divXStr = serializeDivs _gridEdit_divX
                _gridEdit_divYStr = serializeDivs _gridEdit_divY
                _gridEdit_selType = "y"; _gridEdit_selIdx = k; refreshPreview()
            )
        ) else if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then (
            if near[1] != "" and near[2] > 0 then (
                _gridEdit_selType = near[1]; _gridEdit_selIdx = near[2]; refreshPreview()
            ) else if (nx > 0.02 and nx < 0.98) then (
                -- 右键：加整条竖线
                local segs = gridEdit_fullSegs _gridEdit_divY
                logDebug ("=== 加竖线 ===")
                logDebug ("divY count before: " + _gridEdit_divY.count as string)
                for i = 1 to _gridEdit_divY.count do (
                    logDebug ("  divY[" + i as string + "] before split: segs=" + (_gridEdit_divY[i][2] as string))
                )
                local k = insertSorted &_gridEdit_divX nx segs
                logDebug ("insertSorted k=" + k as string + " divX count=" + _gridEdit_divX.count as string)
                local yi = 1
                while yi <= _gridEdit_divY.count do (
                    local oldSegs = _gridEdit_divY[yi][2]
                    local newSegs = gridEdit_splitSegs oldSegs k
                    _gridEdit_divY[yi] = #(_gridEdit_divY[yi][1], newSegs)
                    yi += 1
                )
                -- 立即序列化，绕开 MaxScript 数组子属性赋值 bug
                _gridEdit_divYStr = serializeDivs _gridEdit_divY
                _gridEdit_divXStr = serializeDivs _gridEdit_divX
                _gridEdit_selType = "x"; _gridEdit_selIdx = k; refreshPreview()
            )
        )
    )
    
    on pvCanvas MouseMove sender args do (
        if _gridEdit_dragging and _gridEdit_selIdx > 0 do (
            local w = pvCanvas.Width; local h = pvCanvas.Height
            if (_gridEdit_selType == "x" and _gridEdit_selIdx <= _gridEdit_divX.count) then (
                local val = (args.X - 2.0) / (w - 4.0)
                local minV = 0.02
                local maxV = 0.98
                if _gridEdit_selIdx > 1 do minV = _gridEdit_divX[_gridEdit_selIdx-1][1] + 0.01
                if _gridEdit_selIdx < _gridEdit_divX.count do maxV = _gridEdit_divX[_gridEdit_selIdx+1][1] - 0.01
                _gridEdit_divX[_gridEdit_selIdx][1] = amin (amax val minV) maxV
                refreshPreview()
            ) else if (_gridEdit_selType == "y" and _gridEdit_selIdx <= _gridEdit_divY.count) then (
                local val = (args.Y - 2.0) / (h - 4.0)
                local minV = 0.02
                local maxV = 0.98
                if _gridEdit_selIdx > 1 do minV = _gridEdit_divY[_gridEdit_selIdx-1][1] + 0.01
                if _gridEdit_selIdx < _gridEdit_divY.count do maxV = _gridEdit_divY[_gridEdit_selIdx+1][1] - 0.01
                _gridEdit_divY[_gridEdit_selIdx][1] = amin (amax val minV) maxV
                refreshPreview()
            )
        )
    )
    on pvCanvas MouseUp sender args do ( _gridEdit_dragging = false )
    on btnClear pressed do ( _gridEdit_divX = #(); _gridEdit_divY = #(); _gridEdit_selType = ""; _gridEdit_selIdx = 0; refreshPreview() )
    on btnOK pressed do (
        -- 强制序列化当前状态（绕开 MaxScript 数组子属性赋值 bug）
        _gridEdit_divXStr = serializeDivs _gridEdit_divX
        _gridEdit_divYStr = serializeDivs _gridEdit_divY
        logDebug ("=== btnOK 保存 ===")
        logDebug ("divXStr: " + _gridEdit_divXStr)
        logDebug ("divYStr: " + _gridEdit_divYStr)
        try (
            local r1 = gridEdit_divToRatio _gridEdit_divX
            local r2 = gridEdit_divToRatioReversed _gridEdit_divY
            ::_gridEdit_result = #(r1, r2)
            -- 同时保存精确的 position 数组和段数据
            ::_gridEdit_colPositions = gridEdit_getPositions _gridEdit_divX
            ::_gridEdit_rowPositions = gridEdit_getRowPositions _gridEdit_divY
            ::_gridEdit_colSegData = gridEdit_calcColSegData()
            ::_gridEdit_rowSegData = gridEdit_calcRowSegData()
            -- DEBUG
            logDebug ("=== btnOK 保存 ===")
            logDebug ("divX count: " + _gridEdit_divX.count as string)
            for i = 1 to _gridEdit_divX.count do (
                local d = _gridEdit_divX[i]
                logDebug ("  divX[" + i as string + "] pos=" + d[1] as string + " segs=" + (d[2] as string))
            )
            logDebug ("divY count: " + _gridEdit_divY.count as string)
            for i = 1 to _gridEdit_divY.count do (
                local d = _gridEdit_divY[i]
                logDebug ("  divY[" + i as string + "] pos=" + d[1] as string + " segs=" + (d[2] as string))
            )
            logDebug ("colPositions: " + (::_gridEdit_colPositions as string))
            logDebug ("rowPositions: " + (::_gridEdit_rowPositions as string))
            logDebug ("colSegData: " + (::_gridEdit_colSegData as string))
            logDebug ("rowSegData: " + (::_gridEdit_rowSegData as string))
        ) catch (
            ::_gridEdit_result = undefined
            ::_gridEdit_colPositions = undefined
            ::_gridEdit_rowPositions = undefined
            ::_gridEdit_colSegData = undefined
            ::_gridEdit_rowSegData = undefined
        )
        destroyDialog WH_GridEdit_Rollout
    )
    on btnCancel pressed do ( ::_gridEdit_result = undefined; destroyDialog WH_GridEdit_Rollout )
    on WH_GridEdit_Rollout open do ( pvCanvas.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 40 40 45; refreshPreview() )
)

rollout UI_WinMakerToolPlus "PianChuang+ Window Maker V8.6" width:430 height:510
(
    -- Rollout Local Variables
    local presets = #()
    local pendingLayoutWidth = 400
    local pendingLayoutHeight = 510
    local contextMenuIndex = undefined
    local openingError = ""
    local openingDidModify = false
    
    -- Forward declarations of functions
    local makeWindow, applyPreset, partitionPoly, sliceAndCreateOpening, refreshListView, layoutPresetItems, loadPresets, saveAllPresetsToINI, applyMainUILayout
    local pchPack, pchUnpack, pchArrayToString, pchStringToFloatArray, pchReadScriptLines, pchFindEmbeddedLine
    local pchGetEmbeddedSetting, pchGetEmbeddedPresetCount, pchLoadEmbeddedPreset, pchLoadLegacyPresets
    local pchEmbeddedLooksDefault, pchPresetToGridEdit, pchWriteEmbeddedData
    
-- 生成默认预设 (如 3 -> "1,1,1")
    fn makeEqualRatio count = (
        local r = "1"
        for i = 2 to count do r += ",1"
        r
    )
    
    fn pchPack val = (
        if val == undefined or val == "" then (
            "-"
        ) else (
            val as string
        )
    )
    
    fn pchUnpack val = (
        if val == undefined or val == "-" then (
            undefined
        ) else (
            val
        )
    )
    
    fn pchArrayToString arr = (
        if arr == undefined then (
            return "-"
        )
        local s = ""
        for i = 1 to arr.count do (
            if i > 1 do s += ","
            s += (arr[i] as string)
        )
        if s == "" then (
            "-"
        ) else (
            s
        )
    )
    
    fn pchStringToFloatArray str = (
        local arr = #()
        if str == undefined or str == "-" or str == "" then (
            return arr
        )
        local parts = filterString str ","
        for pt in parts do (
            local val = pt as float
            if val != undefined do append arr val
        )
        arr
    )
    
    fn pchReadScriptLines = (
        local result = #()
        local path = pcPlusGetScriptPath()
        if doesFileExist path then (
            local f = openFile path mode:"r"
            if f != undefined then (
                while not eof f do append result (readLine f)
                close f
            )
        )
        result
    )
    
    fn pchFindEmbeddedLine prefix = (
        local lines = pchReadScriptLines()
        for line in lines do (
            if matchPattern line pattern:(prefix + "*") then (
                return line
            )
        )
        ""
    )
    
    fn pchGetEmbeddedSetting key = (
        local line = pchFindEmbeddedLine "--Settings|"
        if line == "" then (
            return ""
        )
        local parts = filterString line "|"
        for p in parts do (
            local kv = filterString p "="
            if kv.count == 2 and kv[1] == key then (
                return kv[2]
            )
        )
        ""
    )
    
    fn pchGetEmbeddedPresetCount = (
        local line = pchFindEmbeddedLine "--PresetCount|"
        if line == "" then (
            return 0
        )
        local parts = filterString line "|"
        if parts.count >= 2 then (
            parts[2] as integer
        ) else (
            0
        )
    )
    
    fn pchLoadEmbeddedPreset idx = (
        local lines = pchReadScriptLines()
        local prefix = "--Preset|" + (idx as string) + "|"
        for line in lines do (
            if matchPattern line pattern:(prefix + "*") then (
                local parts = filterString line "|"
                if parts.count >= 5 then (
                    local p = structPreset name:parts[3] cols:parts[4] rows:parts[5]
                    if parts.count >= 6 then (
                        local cp = pchStringToFloatArray parts[6]
                        if cp.count > 0 then (
                            p.colPositions = cp
                        )
                    )
                    if parts.count >= 7 then (
                        local rp = pchStringToFloatArray parts[7]
                        if rp.count > 0 then (
                            p.rowPositions = rp
                        )
                    )
                    if parts.count >= 8 then (
                        p.colSegData = pchUnpack parts[8]
                    )
                    if parts.count >= 9 then (
                        p.rowSegData = pchUnpack parts[9]
                    )
                    return p
                )
            )
        )
        undefined
    )

    fn pchLoadLegacyPresets = (
        local legacyPresets = #()
        local countStr = getINISetting iniPathPc "Presets" "Count"
        local count = 0
        if countStr != "" then (
            count = countStr as integer
        )
        if count > 0 then (
            for i = 1 to count do (
                local nameVal = getINISetting iniPathPc "Presets" ("Preset" + i as string + "_Name")
                local colsVal = getINISetting iniPathPc "Presets" ("Preset" + i as string + "_Cols")
                local rowsVal = getINISetting iniPathPc "Presets" ("Preset" + i as string + "_Rows")
                append legacyPresets (structPreset name:nameVal cols:colsVal rows:rowsVal)
            )
            for i = 1 to legacyPresets.count do (
                local dataPath = getDir #plugcfg + "\\PianChuangPlusPresetsData.ini"
                local section = "Preset_" + (i as string)
                local colPosStr = getINISetting dataPath section "ColPositions"
                if colPosStr != "" then (
                    local arr = pchStringToFloatArray colPosStr
                    if arr.count > 0 then (
                        legacyPresets[i].colPositions = arr
                    )
                )
                local rowPosStr = getINISetting dataPath section "RowPositions"
                if rowPosStr != "" then (
                    local arr = pchStringToFloatArray rowPosStr
                    if arr.count > 0 then (
                        legacyPresets[i].rowPositions = arr
                    )
                )
                local csStr = getINISetting dataPath section "ColSegData"
                if csStr != "" then (
                    legacyPresets[i].colSegData = csStr
                )
                local rsStr = getINISetting dataPath section "RowSegData"
                if rsStr != "" then (
                    legacyPresets[i].rowSegData = rsStr
                )
            )
        )
        legacyPresets
    )

    fn pchEmbeddedLooksDefault = (
        if presets.count != 6 then (
            return false
        )
        if presets[1].cols != "1,3,1" or presets[1].rows != "1" then (
            return false
        )
        if presets[2].cols != "1,3,1" or presets[2].rows != "3,1" then (
            return false
        )
        if presets[3].cols != "3,1" or presets[3].rows != "3,1" then (
            return false
        )
        if presets[4].cols != "1,3,1" or presets[4].rows != "1,2,1" then (
            return false
        )
        if presets[5].cols != "1" or presets[5].rows != "1,2" then (
            return false
        )
        if presets[6].cols != "1,1,1" or presets[6].rows != "1,3" then (
            return false
        )
        for p in presets do (
            if p.colPositions != undefined or p.rowPositions != undefined or p.colSegData != undefined or p.rowSegData != undefined then (
                return false
            )
        )
        true
    )

    fn pchPresetToGridEdit p = (
        _gridEdit_divX = #()
        _gridEdit_divY = #()
        _gridEdit_selType = ""
        _gridEdit_selIdx = 0
        _gridEdit_dragging = false
        
        local colPositions = if p.colPositions != undefined then p.colPositions else (ratiosToPositions p.cols)
        local rowPositions = if p.rowPositions != undefined then p.rowPositions else (ratiosToPositions p.rows)
        local numColSegs = colPositions.count - 1
        local numRowSegs = rowPositions.count - 1
        
        if p.colSegData != undefined then (
            local parsedCols = parseSegData p.colSegData
            for entry in parsedCols do (
                local screenSegs = #()
                for s in entry[2] do (
                    append screenSegs (numRowSegs + 1 - s)
                )
                append _gridEdit_divX #(entry[1], screenSegs)
            )
        ) else (
            for i = 2 to colPositions.count - 1 do (
                local segs = #()
                for s = 1 to numRowSegs do append segs s
                append _gridEdit_divX #(colPositions[i], segs)
            )
        )
        
        if p.rowSegData != undefined then (
            local parsedRows = parseSegData p.rowSegData
            for entry in parsedRows do (
                append _gridEdit_divY #((1.0 - entry[1]), entry[2])
            )
        ) else (
            for i = rowPositions.count - 1 to 2 by -1 do (
                local segs = #()
                for s = 1 to numColSegs do append segs s
                append _gridEdit_divY #((1.0 - rowPositions[i]), segs)
            )
        )
        
        _gridEdit_divXStr = serializeDivs _gridEdit_divX
        _gridEdit_divYStr = serializeDivs _gridEdit_divY
    )
    
    fn pchWriteEmbeddedData = (
        local path = pcPlusGetScriptPath()
        local lines = pchReadScriptLines()
        local newLines = #()
        local inData = false
        
        for line in lines do (
            if matchPattern line pattern:"--PCHPLUS_DATA_BEGIN*" then (
                inData = true
            ) else (
                if matchPattern line pattern:"--PCHPLUS_DATA_END*" then (
                    inData = false
                ) else (
                    if not inData then (
                        append newLines line
                    )
                )
            )
        )
        
        append newLines "--PCHPLUS_DATA_BEGIN"
        local outerSizeStr = pchGetEmbeddedSetting "OuterSize"
        local innerSizeStr = pchGetEmbeddedSetting "InnerSize"
        local frameDepthStr = pchGetEmbeddedSetting "FrameDepth"
        local glassDepthStr = pchGetEmbeddedSetting "GlassDepth"
        local heightEnabledStr = pchGetEmbeddedSetting "HeightEnable"
        local sillSizeStr = pchGetEmbeddedSetting "SillSize"
        local depthSizeStr = pchGetEmbeddedSetting "DepthSize"
        local winHeightSizeStr = pchGetEmbeddedSetting "WinHeightSize"
        local windowWidthStr = pchGetEmbeddedSetting "WindowWidth"
        local windowHeightStr = pchGetEmbeddedSetting "WindowHeight"
        
        if outerSizeStr == "" then outerSizeStr = "75.0"
        if innerSizeStr == "" then innerSizeStr = "50.0"
        if frameDepthStr == "" then frameDepthStr = "80.0"
        if glassDepthStr == "" then glassDepthStr = "8.0"
        if heightEnabledStr == "" then heightEnabledStr = "true"
        if sillSizeStr == "" then sillSizeStr = "1200.0"
        if depthSizeStr == "" then depthSizeStr = "250.0"
        if winHeightSizeStr == "" then winHeightSizeStr = "1600.0"
        if windowWidthStr == "" then windowWidthStr = "430"
        if windowHeightStr == "" then windowHeightStr = "510"
        
        try (
            outerSizeStr = spnOuterSize.value as string
            innerSizeStr = spnInnerSize.value as string
            frameDepthStr = spnFrameThick.value as string
            glassDepthStr = spnGlassThick.value as string
            if chkHeightEnable.checked then (
                heightEnabledStr = "true"
            ) else (
                heightEnabledStr = "false"
            )
            sillSizeStr = spnSill.value as string
            depthSizeStr = spnDepth.value as string
            winHeightSizeStr = spnWinHeight.value as string
            windowWidthStr = UI_WinMakerToolPlus.width as string
            windowHeightStr = UI_WinMakerToolPlus.height as string
        ) catch ()
        
        local settingLine = "--Settings"
        settingLine += "|OuterSize=" + outerSizeStr
        settingLine += "|InnerSize=" + innerSizeStr
        settingLine += "|FrameDepth=" + frameDepthStr
        settingLine += "|GlassDepth=" + glassDepthStr
        settingLine += "|HeightEnable=" + heightEnabledStr
        settingLine += "|SillSize=" + sillSizeStr
        settingLine += "|DepthSize=" + depthSizeStr
        settingLine += "|WinHeightSize=" + winHeightSizeStr
        settingLine += "|WindowWidth=" + windowWidthStr
        settingLine += "|WindowHeight=" + windowHeightStr
        append newLines settingLine
        append newLines ("--PresetCount|" + (presets.count as string))
        for i = 1 to presets.count do (
            local p = presets[i]
            local presetLine = "--Preset|" + (i as string)
            presetLine += "|" + (pchPack p.name)
            presetLine += "|" + (pchPack p.cols)
            presetLine += "|" + (pchPack p.rows)
            presetLine += "|" + (pchArrayToString p.colPositions)
            presetLine += "|" + (pchArrayToString p.rowPositions)
            presetLine += "|" + (pchPack p.colSegData)
            presetLine += "|" + (pchPack p.rowSegData)
            append newLines presetLine
        )
        append newLines "--PCHPLUS_DATA_END"
        
        local f = createFile path
        if f != undefined do (
            for line in newLines do format "%\n" line to:f
            close f
        )
    )
    
    -- UI Layout
    timer tmrResizeLayout interval:180 active:false
    groupBox grpPresets "预设样式 (Presets)" pos:[8,8] width:234 height:232
    dotNetControl lvPresets "System.Windows.Forms.ListView" pos:[14,24] width:222 height:178
    button btnSavePreset "新增预设" pos:[14,208] width:222 height:24
    button btnUISmaller "-" pos:[14,208] width:26 height:24 tooltip:"缩小预设区"
    button btnUILarger "+" pos:[42,208] width:26 height:24 tooltip:"放大预设区"
    
    groupBox grpParam "参数设置 (Parameters)" pos:[8,246] width:234 height:168
    
    checkbox chkHeightEnable "启用台高/内凹/窗高" pos:[18,266] width:190 checked:true
    
    spinner spnSill "台高:" range:[0,5000,1200] type:#float pos:[55,290] fieldwidth:68
    label lblSillUnit "mm" pos:[155,290] width:24 height:16
    
    spinner spnDepth "内凹:" range:[0,5000,250] type:#float pos:[215,290] fieldwidth:68 tooltip:"沿选择面向墙体内部凹入；实体墙自动限制在墙厚内"
    label lblDepthUnit "mm" pos:[315,290] width:24 height:16
    
    spinner spnWinHeight "窗高:" range:[10,5000,1600] type:#float pos:[55,314] fieldwidth:68
    label lblWinHeightUnit "mm" pos:[155,314] width:24 height:16
    
    spinner spnOuterSize "外框:" range:[0,1000,75] type:#float pos:[55,340] fieldwidth:68
    label lblOuterUnit "mm" pos:[155,340] width:24 height:16
    
    spinner spnInnerSize "内框:" range:[0,1000,50] type:#float pos:[215,340] fieldwidth:68
    label lblInnerUnit "mm" pos:[315,340] width:24 height:16
    
    spinner spnFrameThick "框厚:" range:[1,1000,80] type:#float pos:[55,364] fieldwidth:68
    label lblFrameUnit "mm" pos:[155,364] width:24 height:16
    
    spinner spnGlassThick "玻厚:" range:[1,1000,8] type:#float pos:[215,364] fieldwidth:68
    label lblGlassUnit "mm" pos:[315,364] width:24 height:16
    
    button btnGridEdit "可视化编辑 (Grid Editor)" pos:[8,424] width:234 height:28
    
    button btnMake "生成窗户 (Make Window)" pos:[8, 460] width:234 height:42

    fn applyMainUILayout = (
        try ( lvPresets.SuspendLayout() ) catch ()
                local minW = 430
        local minH = 510
        local w = UI_WinMakerToolPlus.width
        local h = UI_WinMakerToolPlus.height
        if w < minW then (
            UI_WinMakerToolPlus.width = minW
            w = minW
        )
        if h < minH then (
            UI_WinMakerToolPlus.height = minH
            h = minH
        )
        local contentW = w - 16
        local paramY = h - 264
        local deltaY = paramY - 246
        local presetH = paramY - 14
        if presetH < 232 do presetH = 232
        
        grpPresets.pos = [grpPresets.pos.x, 8]
        grpPresets.width = contentW
        grpPresets.height = presetH
        lvPresets.pos = [lvPresets.pos.x, 24]
        lvPresets.width = w - 28
        lvPresets.height = presetH - 54
        btnUISmaller.pos = [btnUISmaller.pos.x, presetH - 24]
        btnUILarger.pos = [btnUILarger.pos.x, presetH - 24]
        btnSavePreset.pos = [btnSavePreset.pos.x, presetH - 24]
        btnSavePreset.width = w - 88
        
        grpParam.pos = [grpParam.pos.x, paramY]
        grpParam.width = contentW
        chkHeightEnable.pos = [chkHeightEnable.pos.x, 266 + deltaY]
        
        -- Keep parameter controls fixed and readable. Only the preset area grows.
        spnSill.pos = [spnSill.pos.x, 290 + deltaY]
        lblSillUnit.pos = [lblSillUnit.pos.x, 292 + deltaY]
        spnDepth.pos = [spnDepth.pos.x, 290 + deltaY]
        lblDepthUnit.pos = [lblDepthUnit.pos.x, 292 + deltaY]
        
        spnWinHeight.pos = [spnWinHeight.pos.x, 314 + deltaY]
        lblWinHeightUnit.pos = [lblWinHeightUnit.pos.x, 316 + deltaY]
        
        spnOuterSize.pos = [spnOuterSize.pos.x, 340 + deltaY]
        lblOuterUnit.pos = [lblOuterUnit.pos.x, 342 + deltaY]
        spnInnerSize.pos = [spnInnerSize.pos.x, 340 + deltaY]
        lblInnerUnit.pos = [lblInnerUnit.pos.x, 342 + deltaY]
        
        spnFrameThick.pos = [spnFrameThick.pos.x, 364 + deltaY]
        lblFrameUnit.pos = [lblFrameUnit.pos.x, 366 + deltaY]
        spnGlassThick.pos = [spnGlassThick.pos.x, 364 + deltaY]
        lblGlassUnit.pos = [lblGlassUnit.pos.x, 366 + deltaY]
        
        btnGridEdit.pos = [btnGridEdit.pos.x, h - 86]
        btnGridEdit.width = contentW
        btnMake.pos = [btnMake.pos.x, h - 50]
        btnMake.width = contentW
        try ( lvPresets.ResumeLayout true ) catch ()
    )

    -- Helper Functions
    fn renderGridIcon w h colPositions rowPositions filename colSegData:undefined rowSegData:undefined = (
        local bg = (color 60 60 65)
        local ln = (color 200 210 220)
        local bmp = bitmap w h color:bg
        
        for x = 0 to w-1 do (
            setPixels bmp [x, 0] #(ln)
            setPixels bmp [x, h-1] #(ln)
        )
        for y = 0 to h-1 do (
            setPixels bmp [0, y] #(ln)
            setPixels bmp [w-1, y] #(ln)
        )
        
        -- Draw columns (vertical lines). Segment data = which row segments the line spans.
        if colSegData != undefined and colSegData.count > 0 then (
            -- Segment-aware: draw partial lines
            for entry in colSegData do (
                local xPos = entry[1]
                local segs = entry[2]
                local x = (xPos * w) as integer
                if x > 0 and x < w-1 do (
                    for seg in segs do (
                        if seg > 0 and seg < rowPositions.count do (
                            -- rowPositions in model coords (0=bottom, 1=top), invert for screen
                            local yTop = ((1.0 - rowPositions[seg+1]) * h) as integer
                            local yBot = ((1.0 - rowPositions[seg]) * h) as integer
                            for y = yTop to yBot do (
                                setPixels bmp [x, y] #(ln)
                                if x+1 < w-1 do setPixels bmp [x+1, y] #(ln)
                            )
                        )
                    )
                )
            )
        ) else (
            -- No segment data: draw full lines (backward compatible)
            for i = 2 to colPositions.count - 1 do (
                local x = (colPositions[i] * w) as integer
                if x > 0 and x < w-1 do (
                    for y = 0 to h-1 do (
                        setPixels bmp [x, y] #(ln)
                        if x+1 < w-1 do setPixels bmp [x+1, y] #(ln)
                    )
                )
            )
        )
        
        -- Draw rows (horizontal lines). Segment data = which col segments the line spans.
        if rowSegData != undefined and rowSegData.count > 0 then (
            for entry in rowSegData do (
                local yPos = entry[1]
                local segs = entry[2]
                local y = ((1.0 - yPos) * h) as integer
                if y > 0 and y < h-1 do (
                    for seg in segs do (
                        if seg > 0 and seg < colPositions.count do (
                            local xLeft = (colPositions[seg] * w) as integer
                            local xRight = (colPositions[seg+1] * w) as integer
                            for x = xLeft to xRight do (
                                setPixels bmp [x, y] #(ln)
                                if y+1 < h-1 do setPixels bmp [x, y+1] #(ln)
                            )
                        )
                    )
                )
            )
        ) else (
            for i = 2 to rowPositions.count - 1 do (
                local y = ((1.0 - rowPositions[i]) * h) as integer
                if y > 0 and y < h-1 do (
                    for x = 0 to w-1 do (
                        setPixels bmp [x, y] #(ln)
                        if y+1 < h-1 do setPixels bmp [x, y+1] #(ln)
                    )
                )
            )
        )
        
        local path = getDir #temp + "\\" + filename + ".bmp"
        bmp.filename = path
        save bmp
        close bmp
        path
    )

    fn loadNetImage filePath = (
        local img = undefined
        try (
            local bytes = (dotNetClass "System.IO.File").ReadAllBytes filePath
            local ms = dotNetObject "System.IO.MemoryStream" bytes
            img = (dotNetClass "System.Drawing.Image").FromStream ms
        ) catch ()
        img
    )

    fn parseRatios str = (
        local r = #()
        local parts = filterString str ",:; "
        for p in parts do (
            local val = p as float
            if val != undefined and val > 0.0 then (
                append r val
            ) else (
                append r 1.0
            )
        )
        if r.count == 0 do append r 1.0
        r
    )

    fn getSelectedFaceOfPoly obj = (
        if obj != undefined and (classOf obj == Editable_Poly or classOf obj.baseObject == Editable_Poly) then (
            if subObjectLevel == 4 then (
                local faceSel = polyop.getFaceSelection obj as array
                if faceSel.count > 0 then (
                    return faceSel[1]
                )
            )
        )
        undefined
    )

    fn isSingleQuadPlane obj = (
        if obj != undefined and (classOf obj == Editable_Poly or classOf obj.baseObject == Editable_Poly) then (
            if (polyop.getNumFaces obj) == 1 and (polyop.getNumEdges obj) == 4 then (
                return true
            )
        )
        false
    )

    fn partitionPoly obj faceIdx colPositions rowPositions colSegData:undefined rowSegData:undefined = in coordsys world (
        logDebug ("=== partitionPoly ===")
        logDebug ("  colPositions=" + (colPositions as string))
        logDebug ("  rowPositions=" + (rowPositions as string))
        logDebug ("  colSegData=" + (if colSegData != undefined then (colSegData as string) else "undefined"))
        logDebug ("  rowSegData=" + (if rowSegData != undefined then (rowSegData as string) else "undefined"))
        local targetObj = obj
        if faceIdx != undefined then (
            local newName = uniqueName (obj.name + "_WindowPlane_")
            local newObj = detachFacesAsNode obj #{faceIdx} newName
            if newObj == undefined do (
                return undefined
            )
            targetObj = newObj
            select targetObj
            max modify mode
            subObjectLevel = 0
        )
        
        if classOf targetObj != Editable_Poly do convertTo targetObj Editable_Poly
        
        local fVerts = polyop.getFaceVerts targetObj 1
        if fVerts.count != 4 do (
            return targetObj
        )
        
        -- 获取四个顶点位置
        local pts = #()
        for vi in fVerts do append pts (polyop.getVert targetObj vi)
        
        -- 确定四边形的空间朝向：找到"水平"和"垂直"方向
        -- 对于窗户面（通常是垂直面），"垂直"方向与世界Z轴对齐
        -- "水平"方向则是面内的另一个方向
        
        -- 按Z坐标将4个顶点分成上下两组
        local idxArr = #(1, 2, 3, 4)
        -- 冒泡排序，按Z从低到高
        for i = 1 to 3 do (
            for j = 1 to (4-i) do (
                if pts[idxArr[j]].z > pts[idxArr[j+1]].z do (
                    local tmp = idxArr[j]; idxArr[j] = idxArr[j+1]; idxArr[j+1] = tmp
                )
            )
        )
        -- 下面两个顶点（Z较低）
        local botIdx1 = idxArr[1]; local botIdx2 = idxArr[2]
        -- 上面两个顶点（Z较高）
        local topIdx1 = idxArr[3]; local topIdx2 = idxArr[4]
        
        -- 在底部两个点中，找出左和右（用面平面内的水平方向判断）
        -- 面法线
        local fNormal = polyop.getFaceNormal targetObj 1
        -- "上"方向 = 世界Z
        local upDir = [0,0,1]
        -- "右"方向 = upDir cross fNormal（面内水平方向）
        local rightDir = normalize (cross upDir fNormal)
        
        -- 底部：按rightDir投影排序，较小的在左边
        local v_BL, v_BR, v_TL, v_TR
        if (dot pts[botIdx1] rightDir) <= (dot pts[botIdx2] rightDir) then (
            v_BL = pts[botIdx1]; v_BR = pts[botIdx2]
        ) else (
            v_BL = pts[botIdx2]; v_BR = pts[botIdx1]
        )
        -- 顶部同理
        if (dot pts[topIdx1] rightDir) <= (dot pts[topIdx2] rightDir) then (
            v_TL = pts[topIdx1]; v_TR = pts[topIdx2]
        ) else (
            v_TL = pts[topIdx2]; v_TR = pts[topIdx1]
        )
        
        -- 双线性插值映射：u=列(左→右), v=行(底→顶)
        -- v_A=BL(u=0,v=0), v_B=BR(u=1,v=0), v_C=TR(u=1,v=1), v_D=TL(u=0,v=1)
        local v_A = v_BL
        local v_B = v_BR
        local v_C = v_TR
        local v_D = v_TL
        
        polyop.deleteVerts targetObj #{1..(polyop.getNumVerts targetObj)}
        
        local cols = colPositions.count - 1
        local rows = rowPositions.count - 1
        
        local vertMap = #()
        for i = 0 to cols do (
            local u = colPositions[i+1]
            local colArr = #()
            for j = 0 to rows do (
                local v = rowPositions[j+1]
                local pt = (1.0-u)*(1.0-v)*v_A + u*(1.0-v)*v_B + u*v*v_C + (1.0-u)*v*v_D
                local newVIdx = polyop.createVert targetObj pt
                append colArr newVIdx
            )
            append vertMap colArr
        )
        
        local vSep = #()
        for i = 1 to (cols + 1) do (
            local r = #()
            for j = 1 to rows do append r false
            append vSep r
        )
        local hSep = #()
        for i = 1 to cols do (
            local r = #()
            for j = 1 to (rows + 1) do append r false
            append hSep r
        )

        for j = 1 to rows do (
            vSep[1][j] = true
            vSep[cols + 1][j] = true
        )
        for i = 1 to cols do (
            hSep[i][1] = true
            hSep[i][rows + 1] = true
        )

        if colSegData == undefined then (
            if cols >= 2 do (
                for i = 2 to cols do (
                    for j = 1 to rows do vSep[i][j] = true
                )
            )
        ) else (
            for entry in colSegData do (
                local colIdx = -1
                if cols >= 2 do (
                    for pi = 2 to cols do (
                        if abs(colPositions[pi] - entry[1]) < 0.001 do (
                            colIdx = pi
                            exit
                        )
                    )
                )
                if colIdx != -1 do (
                    for s in entry[2] do (
                        if s >= 1 and s <= rows do vSep[colIdx][s] = true
                    )
                )
            )
        )

        if rowSegData == undefined then (
            for i = 1 to cols do (
                if rows >= 2 do (
                    for j = 2 to rows do hSep[i][j] = true
                )
            )
        ) else (
            for entry in rowSegData do (
                local rowIdx = -1
                if rows >= 2 do (
                    for pi = 2 to rows do (
                        if abs(rowPositions[pi] - entry[1]) < 0.001 do (
                            rowIdx = pi
                            exit
                        )
                    )
                )
                if rowIdx != -1 do (
                    for s in entry[2] do (
                        if s >= 1 and s <= cols do hSep[s][rowIdx] = true
                    )
                )
            )
        )

        local visited = #()
        for i = 1 to cols do (
            local r = #()
            for j = 1 to rows do append r false
            append visited r
        )

        for startI = 1 to cols do (
            for startJ = 1 to rows do (
                if not visited[startI][startJ] do (
                    local stack = #(#(startI, startJ))
                    local cells = #()
                    local cellKeys = #()
                    visited[startI][startJ] = true

                    while stack.count > 0 do (
                        local c = stack[stack.count]
                        deleteItem stack stack.count
                        local ci = c[1]
                        local cj = c[2]
                        append cells c
                        append cellKeys ((ci as string) + "_" + (cj as string))

                        if ci > 1 and not vSep[ci][cj] and not visited[ci - 1][cj] do (
                            visited[ci - 1][cj] = true
                            append stack #(ci - 1, cj)
                        )
                        if ci < cols and not vSep[ci + 1][cj] and not visited[ci + 1][cj] do (
                            visited[ci + 1][cj] = true
                            append stack #(ci + 1, cj)
                        )
                        if cj > 1 and not hSep[ci][cj] and not visited[ci][cj - 1] do (
                            visited[ci][cj - 1] = true
                            append stack #(ci, cj - 1)
                        )
                        if cj < rows and not hSep[ci][cj + 1] and not visited[ci][cj + 1] do (
                            visited[ci][cj + 1] = true
                            append stack #(ci, cj + 1)
                        )
                    )

                    local usedKeys = #()
                    for base in cells do (
                        local bi = base[1]
                        local bj = base[2]
                        local baseKey = (bi as string) + "_" + (bj as string)
                        if (findItem usedKeys baseKey) == 0 do (
                            local rectW = 1
                            local canGrow = true
                            while (canGrow and ((bi + rectW) <= cols)) do (
                                local nextKey = ((bi + rectW) as string) + "_" + (bj as string)
                                if ((findItem cellKeys nextKey) > 0) and ((findItem usedKeys nextKey) == 0) and (not vSep[bi + rectW][bj]) then (
                                    rectW += 1
                                ) else (
                                    canGrow = false
                                )
                            )

                            local rectH = 1
                            canGrow = true
                            while (canGrow and ((bj + rectH) <= rows)) do (
                                for xi = bi to (bi + rectW - 1) do (
                                    if canGrow do (
                                        local nextKey = (xi as string) + "_" + ((bj + rectH) as string)
                                        if (((findItem cellKeys nextKey) == 0) or ((findItem usedKeys nextKey) > 0) or hSep[xi][bj + rectH]) do (
                                            canGrow = false
                                        )
                                    )
                                )
                                if canGrow do rectH += 1
                            )

                            for xi = bi to (bi + rectW - 1) do (
                                for yj = bj to (bj + rectH - 1) do (
                                    append usedKeys ((xi as string) + "_" + (yj as string))
                                )
                            )

                            local polyVerts = #()
                            append polyVerts vertMap[bi][bj]
                            if bj > 1 and rectW > 1 do (
                                for xi = (bi + 1) to (bi + rectW - 1) do append polyVerts vertMap[xi][bj]
                            )
                            append polyVerts vertMap[bi + rectW][bj]
                            if (bi + rectW) <= cols and rectH > 1 do (
                                for yj = (bj + 1) to (bj + rectH - 1) do append polyVerts vertMap[bi + rectW][yj]
                            )
                            append polyVerts vertMap[bi + rectW][bj + rectH]
                            if (bj + rectH) <= rows and rectW > 1 do (
                                for xi = (bi + rectW - 1) to (bi + 1) by -1 do append polyVerts vertMap[xi][bj + rectH]
                            )
                            append polyVerts vertMap[bi][bj + rectH]
                            if bi > 1 and rectH > 1 do (
                                for yj = (bj + rectH - 1) to (bj + 1) by -1 do append polyVerts vertMap[bi][yj]
                            )
                            local ok = polyop.createPolygon targetObj polyVerts
                            logDebug ("  createRect bi=" + (bi as string) + " bj=" + (bj as string) + " w=" + (rectW as string) + " h=" + (rectH as string) + " verts=" + (polyVerts.count as string) + " ok=" + (ok as string))
                        )
                    )
                )
            )
        )
        
        logDebug ("faces=" + (polyop.getNumFaces targetObj) as string)
        
        targetObj
    )

    fn sliceAndCreateOpening obj f1 f2 h_bottom h_top depth_pull = in coordsys world (
        openingError = ""
        openingDidModify = false

        if f1 == undefined or f1 < 1 or f1 > (polyop.getNumFaces obj) do (
            openingError = "开洞失败：选择面的编号已经失效，请重新选择墙面。"
            return undefined
        )

        local n1 = polyop.getFaceNormal obj f1
        if (length n1) < 0.0001 do (
            openingError = "开洞失败：无法读取选择面的法线。"
            return undefined
        )
        n1 = normalize n1

        -- Slice the selected wall face in place. Splitting its shared boundary edges keeps
        -- the lower wall, side walls and the new extrusion in one Editable Poly topology.
        fn splitFaceAtZ polyObj faceID zHeight = (
            if faceID == undefined or faceID < 1 or faceID > (polyop.getNumFaces polyObj) do return #()

            local sourceNormal = polyop.getFaceNormal polyObj faceID
            if (length sourceNormal) < 0.0001 do return #()
            sourceNormal = normalize sourceNormal

            local oldFaceCount = polyop.getNumFaces polyObj
            local faceBits = #{}
            faceBits[faceID] = true

            try (
                polyop.slice polyObj faceBits (ray [0, 0, zHeight] [0, 0, 1]) inCoordsys:#world
            ) catch ()
            update polyObj

            -- Recover faces previously touched by V8.1: its failed cut could have left
            -- two vertices at the target height without the edge that joins them.
            if (polyop.getNumFaces polyObj) <= oldFaceCount do (
                local existingCutVerts = #()
                if faceID <= (polyop.getNumFaces polyObj) do (
                    for vertID in (polyop.getFaceVerts polyObj faceID) do (
                        local worldPos = polyop.getVert polyObj vertID
                        if abs(worldPos.z - zHeight) <= 0.01 do appendIfUnique existingCutVerts vertID
                    )
                )
                if existingCutVerts.count == 2 do (
                    try (polyop.createEdge polyObj existingCutVerts[1] existingCutVerts[2]) catch ()
                    update polyObj
                )
            )

            local newFaceCount = polyop.getNumFaces polyObj
            if newFaceCount <= oldFaceCount do return #()

            local resultFaces = #()
            local candidateFaces = #(faceID)
            for candidateID = (oldFaceCount + 1) to newFaceCount do append candidateFaces candidateID

            for candidateID in candidateFaces do (
                if candidateID >= 1 and candidateID <= newFaceCount do (
                    local candidateNormal = polyop.getFaceNormal polyObj candidateID
                    if (length candidateNormal) > 0.0001 do (
                        candidateNormal = normalize candidateNormal
                        if (dot candidateNormal sourceNormal) > 0.99 do appendIfUnique resultFaces candidateID
                    )
                )
            )
            resultFaces
        )

        fn getFaceWorldZRange polyObj faceID = (
            if faceID == undefined or faceID < 1 or faceID > (polyop.getNumFaces polyObj) do return undefined
            local minZ = 1e9
            local maxZ = -1e9
            for vertID in (polyop.getFaceVerts polyObj faceID) do (
                local worldPos = polyop.getVert polyObj vertID
                if worldPos.z < minZ do minZ = worldPos.z
                if worldPos.z > maxZ do maxZ = worldPos.z
            )
            if maxZ <= minZ then undefined else #(minZ, maxZ)
        )

        fn findFaceByHeight polyObj faceList minZ maxZ = (
            local result = undefined
            for faceID in faceList do (
                if faceID >= 1 and faceID <= (polyop.getNumFaces polyObj) do (
                    local centerWorld = polyop.getFaceCenter polyObj faceID
                    if centerWorld.z > minZ and centerWorld.z < maxZ do result = faceID
                )
            )
            result
        )

        fn findFaceCrossingZ polyObj faceList zHeight tolerance:0.01 = (
            local result = undefined
            local bestSpan = 1e9
            for faceID in faceList do (
                local zRange = undefined
                if faceID >= 1 and faceID <= (polyop.getNumFaces polyObj) do (
                    local rangeMinZ = 1e9
                    local rangeMaxZ = -1e9
                    for vertID in (polyop.getFaceVerts polyObj faceID) do (
                        local worldPos = polyop.getVert polyObj vertID
                        if worldPos.z < rangeMinZ do rangeMinZ = worldPos.z
                        if worldPos.z > rangeMaxZ do rangeMaxZ = worldPos.z
                    )
                    if rangeMaxZ > rangeMinZ do zRange = #(rangeMinZ, rangeMaxZ)
                )
                if zRange != undefined do (
                    if zRange[1] < (zHeight - tolerance) and zRange[2] > (zHeight + tolerance) do (
                        local span = zRange[2] - zRange[1]
                        if span < bestSpan do (
                            bestSpan = span
                            result = faceID
                        )
                    )
                )
            )
            result
        )

        fn findFaceReachingTop polyObj faceList minCenterZ targetTop tolerance:0.01 = (
            local result = undefined
            local bestTop = -1e9
            for faceID in faceList do (
                local zRange = undefined
                if faceID >= 1 and faceID <= (polyop.getNumFaces polyObj) do (
                    local rangeMinZ = 1e9
                    local rangeMaxZ = -1e9
                    for vertID in (polyop.getFaceVerts polyObj faceID) do (
                        local worldPos = polyop.getVert polyObj vertID
                        if worldPos.z < rangeMinZ do rangeMinZ = worldPos.z
                        if worldPos.z > rangeMaxZ do rangeMaxZ = worldPos.z
                    )
                    if rangeMaxZ > rangeMinZ do zRange = #(rangeMinZ, rangeMaxZ)
                )
                if zRange != undefined do (
                    local centerWorld = polyop.getFaceCenter polyObj faceID
                    if centerWorld.z > minCenterZ and zRange[2] >= (targetTop - tolerance) do (
                        if zRange[2] > bestTop do (
                            bestTop = zRange[2]
                            result = faceID
                        )
                    )
                )
            )
            result
        )
        local sourceRange = getFaceWorldZRange obj f1
        if sourceRange == undefined do (
            openingError = "开洞失败：选择面没有有效的高度范围。"
            return undefined
        )

        local sourceMinZ = sourceRange[1]
        local sourceMaxZ = sourceRange[2]
        local boundaryTolerance = amax 0.01 ((sourceMaxZ - sourceMinZ) * 0.00001)
        if h_bottom < sourceMinZ do h_bottom = sourceMinZ
        if h_top > sourceMaxZ do h_top = sourceMaxZ
        if h_top <= (h_bottom + boundaryTolerance) do (
            openingError = "开洞失败：窗顶高度必须高于窗台高度。"
            return undefined
        )

        local useBottomBoundary = h_bottom <= (sourceMinZ + boundaryTolerance)
        local useTopBoundary = h_top >= (sourceMaxZ - boundaryTolerance)
        logDebug ("openingZ bottom=" + (h_bottom as string) + " top=" + (h_top as string) + " sourceTop=" + (sourceMaxZ as string) + " useTopBoundary=" + (useTopBoundary as string))

        local firstSplitFaces = #(f1)
        if not useBottomBoundary do (
            local beforeVerts = polyop.getNumVerts obj
            local beforeEdges = polyop.getNumEdges obj
            local beforeFaces = polyop.getNumFaces obj
            firstSplitFaces = splitFaceAtZ obj f1 h_bottom
            if (polyop.getNumVerts obj) != beforeVerts or (polyop.getNumEdges obj) != beforeEdges or (polyop.getNumFaces obj) != beforeFaces do openingDidModify = true
            if firstSplitFaces.count < 2 do (
                openingError = "第一条横线连接失败：无法在窗台高度切开选择面。"
                return undefined
            )
        )

        local upperFace = undefined
        if useTopBoundary then (
            upperFace = findFaceReachingTop obj firstSplitFaces (h_bottom + boundaryTolerance) sourceMaxZ tolerance:boundaryTolerance
        ) else (
            upperFace = findFaceCrossingZ obj firstSplitFaces h_top tolerance:boundaryTolerance
        )
        if upperFace == undefined do (
            openingError = "第一条横线已生成，但找不到覆盖窗顶高度的上方面。"
            return undefined
        )

        local middleFace = upperFace
        if not useTopBoundary do (
            local beforeSecondVerts = polyop.getNumVerts obj
            local beforeSecondEdges = polyop.getNumEdges obj
            local beforeSecondFaces = polyop.getNumFaces obj
            local secondSplitFaces = splitFaceAtZ obj upperFace h_top
            if (polyop.getNumVerts obj) != beforeSecondVerts or (polyop.getNumEdges obj) != beforeSecondEdges or (polyop.getNumFaces obj) != beforeSecondFaces do openingDidModify = true
            if secondSplitFaces.count < 2 do (
                openingError = "第二条横线连接失败：无法在窗顶高度切开上方面。"
                return undefined
            )

            middleFace = findFaceByHeight obj secondSplitFaces (h_bottom + boundaryTolerance) (h_top - boundaryTolerance)
            if middleFace == undefined do (
                openingError = "两条横线已经生成，但无法识别中间的窗面。"
                return undefined
            )
        )
        -- Depth is always a recess. A single wall face uses negative normal.
        -- A solid wall uses the opposite face as the interior direction and never
        -- crosses it: keep a 1 mm residual wall to avoid coplanar overlap.
        local requestedDepth = abs depth_pull
        local recessDepth = requestedDepth
        local extrudeAmount = -recessDepth
        if f2 != undefined and f2 >= 1 and f2 <= (polyop.getNumFaces obj) do (
            local frontCenterWorld = polyop.getFaceCenter obj middleFace
            local backCenterWorld = polyop.getFaceCenter obj f2
            local toBack = backCenterWorld - frontCenterWorld
            local normalWorld = n1
            local signedWallDepth = dot toBack normalWorld
            if abs(signedWallDepth) > 0.0001 do (
                recessDepth = amin requestedDepth (amax 0.0 (abs(signedWallDepth) - 1.0))
                if signedWallDepth >= 0.0 then (
                    extrudeAmount = recessDepth
                ) else (
                    extrudeAmount = -recessDepth
                )
            )
        )

        local capFace = middleFace
        if (abs extrudeAmount) > 0.0001 do (
            local oldVertCount = polyop.getNumVerts obj
            local middleFaceBits = #{}
            middleFaceBits[middleFace] = true
            polyop.extrudeFaces obj middleFaceBits extrudeAmount
            update obj
            openingDidModify = true

            local newVertCount = polyop.getNumVerts obj
            if newVertCount <= oldVertCount do (
                openingError = "中间窗面挤出失败。"
                return undefined
            )

            local newVerts = #{}
            for vertID = (oldVertCount + 1) to newVertCount do newVerts[vertID] = true
            capFace = undefined
            for faceID = 1 to (polyop.getNumFaces obj) do (
                local oneFace = #{}
                oneFace[faceID] = true
                local faceVerts = polyop.getVertsUsingFace obj oneFace
                local faceNewVerts = faceVerts * newVerts
                if not faceNewVerts.isEmpty and (faceVerts - newVerts).isEmpty do capFace = faceID
            )
            if capFace == undefined do (
                openingError = "窗面已经挤出，但无法识别挤出后的端面。"
                return undefined
            )
        )

        local capVerts = polyop.getFaceVerts obj capFace
        if capVerts.count < 3 do (
            openingError = "挤出端面的顶点数量无效。"
            return undefined
        )

        local winPlaneObj = box length:1 width:1 height:1
        convertTo winPlaneObj Editable_Poly
        polyop.deleteFaces winPlaneObj #{1..(polyop.getNumFaces winPlaneObj)}
        update winPlaneObj
        winPlaneObj.name = uniqueName (obj.name + "_WindowPlane_")
        winPlaneObj.transform = obj.transform
        local windowVerts = #()
        for vertID in capVerts do append windowVerts (polyop.createVert winPlaneObj (polyop.getVert obj vertID))
        local windowFace = polyop.createPolygon winPlaneObj windowVerts
        if (windowFace == undefined) or (windowFace <= 0) do (
            try (delete winPlaneObj) catch ()
            openingError = "窗洞已经生成，但创建后续窗体基准面失败。"
            return undefined
        )

        local capFaceBits = #{}
        capFaceBits[capFace] = true
        polyop.deleteFaces obj capFaceBits delIsoVerts:false
        update obj
        CenterPivot winPlaneObj
        winPlaneObj
    )
        fn createWindowPlaneFromFace obj f = (
            local verts = polyop.getFaceVerts obj f
            if verts.count < 3 do return undefined
            local winPlane = box length:1 width:1 height:1
            convertTo winPlane Editable_Poly
            polyop.deleteFaces winPlane #{1..(polyop.getNumFaces winPlane)}
            winPlane.name = uniqueName (obj.name + "_WindowPlane_")
            winPlane.transform = obj.transform
            local newVerts = #()
            if verts.count == 4 then (
                for v in verts do (
                    append newVerts (polyop.createVert winPlane (polyop.getVert obj v))
                )
            ) else (
                local pts = #()
                for v in verts do append pts (polyop.getVert obj v)
                local n = normalize (polyop.getFaceNormal obj f)
                local vDir = [0,0,1] - (n * (dot [0,0,1] n))
                if (length vDir) < 0.001 do vDir = [1,0,0] - (n * (dot [1,0,0] n))
                if (length vDir) < 0.001 do vDir = [0,1,0] - (n * (dot [0,1,0] n))
                vDir = normalize vDir
                local hDir = normalize (cross vDir n)
                local center = [0,0,0]
                for p in pts do center += p
                center = center / pts.count
                local minH = 1e9
                local maxH = -1e9
                local minV = 1e9
                local maxV = -1e9
                for p in pts do (
                    local d = p - center
                    local hp = dot d hDir
                    local vp = dot d vDir
                    if hp < minH do minH = hp
                    if hp > maxH do maxH = hp
                    if vp < minV do minV = vp
                    if vp > maxV do maxV = vp
                )
                local corners = #(
                    center + hDir * minH + vDir * minV,
                    center + hDir * maxH + vDir * minV,
                    center + hDir * maxH + vDir * maxV,
                    center + hDir * minH + vDir * maxV
                )
                for p in corners do append newVerts (polyop.createVert winPlane p)
            )
            if newVerts.count == 4 then (
                polyop.createPolygon winPlane newVerts
                CenterPivot winPlane
                winPlane
            ) else (
                try(delete winPlane)catch()
                undefined
            )
        )

        fn applyPreset colPositions rowPositions colSegData:undefined rowSegData:undefined = in coordsys world (
        logDebug "=== applyPreset 开始 ==="
        local redrawSuspended = true
        disableSceneRedraw()
        suspendEditing()
        try (
        local sel = selection as array
        logDebug ("选择对象数: " + sel.count as string)
        if sel.count == 1 then (
            local obj = sel[1]
            logDebug ("对象: " + obj.name + " 类型: " + (classOf obj as string))
            if classOf obj != Editable_Poly do convertTo obj Editable_Poly
            
            local faceSel = (polyop.getFaceSelection obj) as array
            logDebug ("选中面数: " + faceSel.count as string)
            if faceSel.count == 2 then (
                local f1 = faceSel[1]
                local f2 = faceSel[2]
                
                local n1 = polyop.getFaceNormal obj f1
                local n2 = polyop.getFaceNormal obj f2
                if (dot n1 n2) > -0.5 then (
                    messageBox "请选择两个方向相反的墙面！" title:"提示"
                    return()
                )
                
                local verts = polyop.getFaceVerts obj f1
                local z_min = 1e9
                local z_max = -1e9
                for v in verts do (
                    local pos = (in coordsys world (polyop.getVert obj v))
                    if pos.z < z_min do z_min = pos.z
                    if pos.z > z_max do z_max = pos.z
                )
                
                local h_bottom = z_min
                if chkHeightEnable.checked do h_bottom += spnSill.value
                
                local h_top = z_max
                if chkHeightEnable.checked do h_top = h_bottom + spnWinHeight.value
                
                local faceH = z_max - z_min
                if h_bottom < z_min + 1.0 do h_bottom = z_min + 1.0
                if h_bottom > z_max - 20.0 do h_bottom = z_max - 20.0
                
                if h_top < h_bottom + 10.0 do h_top = h_bottom + 10.0
                if h_top > z_max do h_top = z_max
                
                local depth_pull = 0.0
                if chkHeightEnable.checked do depth_pull = spnDepth.value
                
                local winPlane = undefined
                undo "智能开洞片窗" on (
                    winPlane = sliceAndCreateOpening obj f1 f2 h_bottom h_top depth_pull
                    if winPlane != undefined do (
                        select winPlane
                        max modify mode
                        partitionPoly winPlane undefined colPositions rowPositions colSegData:colSegData rowSegData:rowSegData
                        makeWindow()
                    )
                )
                if winPlane == undefined do (
                    if openingDidModify do try (max undo) catch ()
                    messageBox (if openingError != "" then openingError else "原墙开洞失败。") title:"提示"
                )
            ) else if faceSel.count == 1 then (
                logDebug "进入单面模式"
                local f1 = faceSel[1]
                
                -- 尝试自动寻找墙体背面，实现一键穿透开洞
                local f2 = findOppositeFace obj f1
                if f2 != undefined then (
                    logDebug ("找到相反面: " + f2 as string + "，自动切换为双面智能开洞模式")
                    local verts = polyop.getFaceVerts obj f1
                    local z_min = 1e9
                    local z_max = -1e9
                    for v in verts do (
                        local pos = (in coordsys world (polyop.getVert obj v))
                        if pos.z < z_min do z_min = pos.z
                        if pos.z > z_max do z_max = pos.z
                    )
                    
                    local h_bottom = z_min
                    if chkHeightEnable.checked do h_bottom += spnSill.value
                    
                    local h_top = z_max
                    if chkHeightEnable.checked do h_top = h_bottom + spnWinHeight.value
                    
                    if h_bottom < z_min + 1.0 do h_bottom = z_min + 1.0
                    if h_bottom > z_max - 20.0 do h_bottom = z_max - 20.0
                    
                    if h_top < h_bottom + 10.0 do h_top = h_bottom + 10.0
                    if h_top > z_max do h_top = z_max
                    
                    local depth_pull = 0.0
                    if chkHeightEnable.checked do depth_pull = spnDepth.value
                    
                    local winPlane = undefined
                    undo "智能开洞片窗" on (
                        winPlane = sliceAndCreateOpening obj f1 f2 h_bottom h_top depth_pull
                        if winPlane != undefined then (
                            select winPlane
                            max modify mode
                            partitionPoly winPlane undefined colPositions rowPositions colSegData:colSegData rowSegData:rowSegData
                            polyop.flipNormals winPlane #{1..(polyop.getNumFaces winPlane)}
                            makeWindow()
                        )
                    )
                    if winPlane == undefined do (
                        if openingDidModify do try (max undo) catch ()
                        messageBox (if openingError != "" then openingError else "原墙开洞失败。") title:"提示"
                    )
                ) else (
                    logDebug "未找到相反面，使用原墙就地连线挤出模式"
                    local verts = polyop.getFaceVerts obj f1
                    local z_min = 1e9
                    local z_max = -1e9
                    for v in verts do (
                        local pos = (in coordsys world (polyop.getVert obj v))
                        if pos.z < z_min do z_min = pos.z
                        if pos.z > z_max do z_max = pos.z
                    )

                    local h_bottom = z_min
                    if chkHeightEnable.checked do h_bottom += spnSill.value
                    local h_top = z_max
                    if chkHeightEnable.checked do h_top = h_bottom + spnWinHeight.value
                    if h_bottom < z_min + 1.0 do h_bottom = z_min + 1.0
                    if h_bottom > z_max - 20.0 do h_bottom = z_max - 20.0
                    if h_top < h_bottom + 10.0 do h_top = h_bottom + 10.0
                    if h_top > z_max do h_top = z_max

                    local depth_pull = 0.0
                    if chkHeightEnable.checked do depth_pull = spnDepth.value
                    local winPlane = undefined
                    undo "单面原墙连线挤出片窗" on (
                        winPlane = sliceAndCreateOpening obj f1 undefined h_bottom h_top depth_pull
                        if winPlane != undefined do (
                            select winPlane
                            max modify mode
                            partitionPoly winPlane undefined colPositions rowPositions colSegData:colSegData rowSegData:rowSegData
                            polyop.flipNormals winPlane #{1..(polyop.getNumFaces winPlane)}
                            makeWindow()
                        )
                    )
                    if winPlane == undefined do (
                        if openingDidModify do try (max undo) catch ()
                        messageBox (if openingError != "" then openingError else "原墙开洞失败。") title:"提示"
                    )
                )
            ) else if faceSel.count > 2 then (
                undo "多面平面片窗" on (
                    local faceSet = polyop.getFaceSelection obj
                    local winPlanes = #()
                    local failedCount = 0
                    for f in faceSel do (
                        local winPlane = createWindowPlaneFromFace obj f
                        if winPlane != undefined then (
                            append winPlanes winPlane
                        ) else (
                            failedCount += 1
                        )
                    )
                    if winPlanes.count > 0 then (
                        try (polyop.deleteFaces obj faceSet) catch ()
                        local madeCount = 0
                        for winPlane in winPlanes do (
                            local okMade = false
                            try (
                                select winPlane
                                max modify mode
                                partitionPoly winPlane undefined colPositions rowPositions colSegData:colSegData rowSegData:rowSegData
                                polyop.flipNormals winPlane #{1..(polyop.getNumFaces winPlane)}
                                select winPlane
                                makeWindow()
                                madeCount += 1
                                okMade = true
                            ) catch (
                                failedCount += 1
                            )
                            if not okMade do try(delete winPlane)catch()
                        )
                        if failedCount > 0 do (
                            messageBox ("批量生成完成 " + madeCount as string + "/" + faceSel.count as string + " 个。\n有 " + failedCount as string + " 个面没有成功，请检查这些面是否过窄、重叠或拓扑异常。") title:"提示"
                        )
                    ) else (
                        messageBox "没有可生成的有效面，请检查选择的面是否过窄、重叠或拓扑异常。" title:"提示"
                    )
                )
            ) else if isSingleQuadPlane obj then (
                undo "平面物体片窗" on (
                    select obj
                    max modify mode
                    partitionPoly obj undefined colPositions rowPositions colSegData:colSegData rowSegData:rowSegData
                    polyop.flipNormals obj #{1..(polyop.getNumFaces obj)}
                    makeWindow()
                )
            ) else (
                messageBox "请在 Editable Poly 中选择 1 个、2 个相反墙面，或多个四边形平面面；也可以选择一个单面的平面物体。" title:"提示"
            )
        ) else (
            messageBox "请选择且仅选择一个对象！" title:"提示"
        )
        ) catch (
            logDebug ("Error in applyPreset: " + getCurrentException())
            messageBox ("生成过程发生错误，已安全终止。\n错误详情：" + getCurrentException()) title:"安全拦截"
        )
        if redrawSuspended do (
            resumeEditing()
            enableSceneRedraw()
            completeRedraw()
        )
    )

    fn loadPresets = (
        presets = #()
        local embeddedCount = pchGetEmbeddedPresetCount()
        if embeddedCount > 0 then (
            for i = 1 to embeddedCount do (
                local p = pchLoadEmbeddedPreset i
                if p != undefined then (
                    append presets p
                )
            )
        )
        
        local legacyPresets = pchLoadLegacyPresets()
        
        local shouldUseLegacy = false
        if legacyPresets.count > presets.count then (
            shouldUseLegacy = true
        ) else (
            if legacyPresets.count > 0 and legacyPresets.count >= presets.count then (
                local embeddedIsDefault = pchEmbeddedLooksDefault()
                if embeddedIsDefault then (
                    shouldUseLegacy = true
                )
            )
        )
        
        if shouldUseLegacy then (
            presets = legacyPresets
            saveAllPresetsToINI()
        ) else (
            if presets.count == 0 then (
                presets = #(
                    (structPreset name:"1" cols:"1,3,1" rows:"1"),
                    (structPreset name:"2" cols:"1,3,1" rows:"3,1"),
                    (structPreset name:"3" cols:"3,1" rows:"3,1"),
                    (structPreset name:"4" cols:"1,3,1" rows:"1,2,1"),
                    (structPreset name:"5" cols:"1" rows:"1,2"),
                    (structPreset name:"6" cols:"1,1,1" rows:"1,3")
                )
            )
        )
    )

    fn saveAllPresetsToINI = (
        try (
            pchWriteEmbeddedData()
        ) catch (
            logDebug ("Save embedded data failed: " + getCurrentException())
        )
    )

    fn layoutPresetItems = (
        local colsPerRow = ((lvPresets.Width - 6) / 58) as integer
        if colsPerRow < 1 do colsPerRow = 1
        for i = 1 to lvPresets.Items.Count do (
            local item = lvPresets.Items.Item[i - 1]
            local col = mod (i - 1) colsPerRow
            local row = ((i - 1) / colsPerRow) as integer
            item.Position = dotNetObject "System.Drawing.Point" (6 + col * 58) (4 + row * 48)
        )
    )

    fn refreshListView = (
        lvPresets.Items.Clear()
        
        local imgList = dotNetObject "System.Windows.Forms.ImageList"
        imgList.ImageSize = dotNetObject "System.Drawing.Size" 40 30
        imgList.ColorDepth = (dotNetClass "System.Windows.Forms.ColorDepth").Depth32Bit
        
        for i = 1 to presets.count do (
            local p = presets[i]
            local colPositions = if p.colPositions != undefined then p.colPositions else (ratiosToPositions p.cols)
            local rowPositions = if p.rowPositions != undefined then p.rowPositions else (ratiosToPositions p.rows)
            local colSeg = if p.colSegData != undefined then (parseSegData p.colSegData) else undefined
            local rowSeg = if p.rowSegData != undefined then (parseSegData p.rowSegData) else undefined
            logDebug ("=== renderGridIcon preset " + i as string + " ===")
            logDebug ("  colPositions: " + (colPositions as string))
            logDebug ("  rowPositions: " + (rowPositions as string))
            logDebug ("  p.colPositions: " + (p.colPositions as string))
            logDebug ("  p.rowPositions: " + (p.rowPositions as string))
            logDebug ("  p.colSegData: " + (p.colSegData as string))
            logDebug ("  p.rowSegData: " + (p.rowSegData as string))
            local filename = "PchGridPlus_" + i as string
            local path = renderGridIcon 40 30 colPositions rowPositions filename colSegData:colSeg rowSegData:rowSeg
            
            local img = loadNetImage path
            if img != undefined do (
                imgList.Images.Add img
            )
        )
        
        try (
            if lvPresets.LargeImageList != undefined do (
                lvPresets.LargeImageList.Dispose()
            )
        ) catch ()
        
        lvPresets.LargeImageList = imgList
        
        for i = 1 to presets.count do (
            local item = dotNetObject "System.Windows.Forms.ListViewItem" presets[i].name (i - 1)
            lvPresets.Items.Add item
        )
        layoutPresetItems()
    )

    fn deletePresetAtIndex idx = (
        if idx > 0 and idx <= presets.count do (
            deleteItem presets idx
            for i = 1 to presets.count do (
                presets[i].name = i as string
            )
            saveAllPresetsToINI()
            refreshListView()
        )
    )

    fn editPreset idx = (
        if idx > 0 and idx <= presets.count then (
            local p = presets[idx]
            
            ::_gridEdit_result = undefined
            ::_gridEdit_colPositions = undefined
            ::_gridEdit_rowPositions = undefined
            ::_gridEdit_colSegData = undefined
            ::_gridEdit_rowSegData = undefined
            pchPresetToGridEdit p
            
            createDialog WH_GridEdit_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) modal:true
            if ::_gridEdit_result != undefined then (
                p.name = (idx as string)
                p.cols = ::_gridEdit_result[1]
                p.rows = ::_gridEdit_result[2]
                p.colPositions = ::_gridEdit_colPositions
                p.rowPositions = ::_gridEdit_rowPositions
                p.colSegData = ::_gridEdit_colSegData
                p.rowSegData = ::_gridEdit_rowSegData
                saveAllPresetsToINI()
                refreshListView()
            )
        )
    )

    fn getOrCreatePchMaterial matName defaultCreator = (
        local foundMat = undefined
        for m in sceneMaterials do (
            if m.name == matName do (
                foundMat = m
                exit
            )
        )
        if foundMat == undefined do (
            for i = 1 to 24 do (
                if meditMaterials[i] != undefined and meditMaterials[i].name == matName do (
                    foundMat = meditMaterials[i]
                    exit
                )
            )
        )
        if foundMat == undefined do (
            foundMat = defaultCreator()
        )
        foundMat
    )

    fn isVrayMaterial m = (
        local r = false
        try ( if VRayMtl != undefined and (classOf m) == VRayMtl do r = true ) catch ()
        r
    )

    fn applyOldPchFrameMaterial m = (
        if m == undefined do return undefined
        m.name = "窗框"
        if isVrayMaterial m then (
            m.diffuse = color 11 11 12
            try(m.reflection = color 80 80 80)catch()
            try(m.hilight_glossiness = 0.75)catch()
            try(m.reflection_glossiness = 0.75)catch()
            try(m.reflection_fresnel = true)catch()
            try(m.reflection_ior = 2.2)catch()
        ) else (
            try(m.diffuse = color 50 50 50)catch()
            try(m.opacity = 100)catch()
        )
        m
    )

    fn applyOldPchGlassMaterial m = (
        if m == undefined do return undefined
        m.name = "玻璃"
        if isVrayMaterial m then (
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
            try(m.diffuse = color 10 30 50)catch()
            try(m.opacity = 20)catch()
        )
        m
    )

    fn makeOldPchFrameMaterial = (
        local hasVray = false
        try ( if VRayMtl != undefined do hasVray = true ) catch()
        local m = if hasVray then (VRayMtl name:"窗框") else (StandardMaterial name:"窗框")
        applyOldPchFrameMaterial m
    )

    fn makeOldPchGlassMaterial = (
        local hasVray = false
        try ( if VRayMtl != undefined do hasVray = true ) catch()
        local m = if hasVray then (VRayMtl name:"玻璃") else (StandardMaterial name:"玻璃")
        applyOldPchGlassMaterial m
    )

    fn cleanFlatLines obj preVerts = (
        local numE = polyop.getNumEdges obj
        if numE == 0 do return()
        local openE = polyop.getOpenEdges obj
        local intE = #{1..numE} - openE
        local coplanarE = #{}
        
        for e in intE do (
            local fList = (polyop.getFacesUsingEdge obj #{e}) as array
            if fList.count == 2 do (
                local m1 = polyop.getFaceMatID obj fList[1]
                local m2 = polyop.getFaceMatID obj fList[2]
                if m1 == m2 do (
                    local n1 = polyop.getFaceNormal obj fList[1]
                    local n2 = polyop.getFaceNormal obj fList[2]
                    if (dot n1 n2) > 0.999 do append coplanarE e
                )
            )
        )
        
        if not coplanarE.isEmpty do (
            local currSel = getCurrentSelection()
            select obj
            max modify mode
            try ( if subobjectLevel != 2 do subobjectLevel = 2 ) catch ()
            obj.EditablePoly.SetSelection #Edge coplanarE
            obj.EditablePoly.Remove flag:1
            try ( if subobjectLevel != 0 do subobjectLevel = 0 ) catch ()
            if currSel.count > 0 do select currSel
        )
    )

    fn makeWindow = (
        logDebug "=== makeWindow 开始 ==="
        local objs = getCurrentSelection()
        logDebug ("选中对象数: " + objs.count as string)
        if objs.count == 0 do return()
        
        local validObjs = #()
        for obj in objs do (
            if superclassof obj == GeometryClass do (
                try(InstanceMgr.MakeObjectsUnique #(obj) #individual)catch()
                if classof obj != Editable_Poly do convertTo obj Editable_Poly
                append validObjs obj
                logDebug ("有效对象: " + obj.name + " 面数=" + (polyop.getNumFaces obj) as string)
            )
        )
        if validObjs.count == 0 do return()
        
        try (
            saveAllPresetsToINI()
        ) catch ()
        
        -- ImageList disposal
        try (
            disableSceneRedraw()
            suspendEditing()
            
            undo "MakeWindow UltraFast" on (
                local frameMat = applyOldPchFrameMaterial (getOrCreatePchMaterial "窗框" makeOldPchFrameMaterial)
                local glMat = applyOldPchGlassMaterial (getOrCreatePchMaterial "玻璃" makeOldPchGlassMaterial)
                
                local outerFrameSize = spnOuterSize.value
                local innerFrameSize = spnInnerSize.value
                local frameThickness = spnFrameThick.value
                local glassThickness = spnGlassThick.value
                
                local groupInset = outerFrameSize - (innerFrameSize / 2.0)
                local polyInset = innerFrameSize / 2.0
                
                for obj in validObjs do (
                    local numF = polyop.getNumFaces obj
                    local glassFaces = #{1..numF}
                    logDebug ("处理对象: " + obj.name + " 面数=" + numF as string + " groupInset=" + groupInset as string + " polyInset=" + polyInset as string)
                    
                    polyop.setFaceMatID obj glassFaces 1
                    
                    if groupInset > 0 do (
                        polyop.bevelFaces obj glassFaces 0.0 -groupInset
                        polyop.setFaceMatID obj glassFaces 2
                    )
                    if groupInset == 0 do polyop.setFaceMatID obj glassFaces 2
                    
                    local preVerts = #{1..(polyop.getNumVerts obj)}
                    
                    if polyInset > 0 do (
                        for f in glassFaces as array do (
                            try(polyop.bevelFaces obj #{f} 0.0 -polyInset)catch()
                        )
                    )
                    
                    if not glassFaces.isEmpty do (
                        local baseName = obj.name
                        local rndStr = (random 1000 9999) as string
                        local frameObjName = baseName + "_Frame_" + rndStr
                        local glassObjName = baseName + "_Glass_" + rndStr
                        
                        obj.name = frameObjName
                        
                        logDebug ("分离玻璃面数: " + glassFaces.numberSet as string)
                        local glassObj = detachFacesAsNode obj glassFaces glassObjName
                        logDebug ("glassObj: " + (if glassObj != undefined then glassObj.name + " 面数=" + (polyop.getNumFaces glassObj) as string else "undefined"))
                        
                        cleanFlatLines obj preVerts
                        polyop.setFaceMatID obj #{1..(polyop.getNumFaces obj)} 1
                        logDebug ("frame面数: " + (polyop.getNumFaces obj) as string)
                        
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
            if oldTaskMode != undefined and oldTaskMode != #modify do setCommandPanelTaskMode oldTaskMode
        ) catch (
            resumeEditing()
            enableSceneRedraw()
            if oldTaskMode != undefined and oldTaskMode != #modify do setCommandPanelTaskMode oldTaskMode
            throw()
        )
    )

    -- Event Handlers
    on UI_WinMakerToolPlus open do (
        lvPresets.View = (dotNetClass "System.Windows.Forms.View").LargeIcon
        lvPresets.MultiSelect = false
        lvPresets.AutoArrange = false
        lvPresets.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").None
        
        lvPresets.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 60 60 65
        lvPresets.ForeColor = (dotNetClass "System.Drawing.Color").White
        
        try (
            local vWinW = pchGetEmbeddedSetting "WindowWidth"
            local vWinH = pchGetEmbeddedSetting "WindowHeight"
            if vWinW != "" do UI_WinMakerToolPlus.width = amax 430 (vWinW as integer)
            if vWinH != "" do UI_WinMakerToolPlus.height = amax 510 (vWinH as integer)
        ) catch ()
                                                                
        applyMainUILayout()
        
        loadPresets()
        refreshListView()
        
        try (
            local vOut = pchGetEmbeddedSetting "OuterSize"
            if vOut == "" do vOut = getINISetting iniPathPc "Settings" "OuterSize"
            if vOut != "" do spnOuterSize.value = vOut as float
            local vIn = pchGetEmbeddedSetting "InnerSize"
            if vIn == "" do vIn = getINISetting iniPathPc "Settings" "InnerSize"
            if vIn != "" do spnInnerSize.value = vIn as float
            local vFD = pchGetEmbeddedSetting "FrameDepth"
            if vFD == "" do vFD = getINISetting iniPathPc "Settings" "FrameDepth"
            if vFD != "" do spnFrameThick.value = vFD as float
            local vGD = pchGetEmbeddedSetting "GlassDepth"
            if vGD == "" do vGD = getINISetting iniPathPc "Settings" "GlassDepth"
            if vGD != "" do spnGlassThick.value = vGD as float

            
            -- Height controls
            local vHeightEnable = pchGetEmbeddedSetting "HeightEnable"
            if vHeightEnable == "" do vHeightEnable = getINISetting iniPathPc "Settings" "HeightEnable"
            if vHeightEnable != "" do chkHeightEnable.checked = (vHeightEnable == "true")
            local vSill = pchGetEmbeddedSetting "SillSize"
            if vSill == "" do vSill = getINISetting iniPathPc "Settings" "SillSize"
            if vSill != "" do spnSill.value = vSill as float
            local vDepth = pchGetEmbeddedSetting "DepthSize"
            if vDepth == "" do vDepth = getINISetting iniPathPc "Settings" "DepthSize"
            if vDepth != "" do spnDepth.value = vDepth as float
            local vWinHeight = pchGetEmbeddedSetting "WinHeightSize"
            if vWinHeight == "" do vWinHeight = getINISetting iniPathPc "Settings" "WinHeightSize"
            if vWinHeight != "" do spnWinHeight.value = vWinHeight as float
        ) catch ()
    )
    
    on btnUISmaller pressed do (
        try (
            UI_WinMakerToolPlus.height = amax 510 (UI_WinMakerToolPlus.height - 80)
            
            applyMainUILayout()
            layoutPresetItems()
            pchWriteEmbeddedData()
        ) catch ()
    )
    
    on btnUILarger pressed do (
        try (
            UI_WinMakerToolPlus.width = UI_WinMakerToolPlus.width + 80
            UI_WinMakerToolPlus.height = UI_WinMakerToolPlus.height + 80
            applyMainUILayout()
            layoutPresetItems()
            pchWriteEmbeddedData()
        ) catch ()
    )
    
    
    
    on UI_WinMakerToolPlus resized newSize do (
        try (
            applyMainUILayout()
            tmrResizeLayout.active = false
            tmrResizeLayout.active = true
        ) catch ()
    )
    
    on tmrResizeLayout tick do (
        tmrResizeLayout.active = false
        try (
            layoutPresetItems()
        ) catch ()
    )
    
    on UI_WinMakerToolPlus close do (
        try (tmrResizeLayout.active = false) catch ()
        try (
            saveAllPresetsToINI()
        ) catch ()
        
        try (
            if lvPresets.LargeImageList != undefined do (
                lvPresets.LargeImageList.Dispose()
            )
        ) catch ()
    )
    
    on lvPresets MouseClick ev do (
        local item = lvPresets.GetItemAt ev.X ev.Y
        if item != undefined then (
            local idx = item.Index + 1
            local p = presets[idx]
            
            local mouseButtons = dotNetClass "System.Windows.Forms.MouseButtons"
            if ev.Button == mouseButtons.Left then (
                undo "片窗+生成" on (
                    local cp = if p.colPositions != undefined then p.colPositions else (ratiosToPositions p.cols)
                    local rp = if p.rowPositions != undefined then p.rowPositions else (ratiosToPositions p.rows)
                    local cs = if p.colSegData != undefined then (parseSegData p.colSegData) else undefined
                    local rs = if p.rowSegData != undefined then (parseSegData p.rowSegData) else undefined
                    applyPreset cp rp colSegData:cs rowSegData:rs
                )
            ) else if ev.Button == mouseButtons.Right then (
                contextMenuIndex = idx
                popUpMenu presetContextMenu
            )
        )
    )
    
    on btnSavePreset pressed do (
        if presets.count >= 20 then (
            messageBox "预设数量已达上限 (20个)！请先右键删除不需要的预设。" title:"提示"
        ) else (
            -- 打开可视化编辑器来新增预设
            _gridEdit_divX = #()
            _gridEdit_divY = #()
            ::_gridEdit_result = undefined
            ::_gridEdit_colPositions = undefined
            ::_gridEdit_rowPositions = undefined
            ::_gridEdit_colSegData = undefined
            ::_gridEdit_rowSegData = undefined
            createDialog WH_GridEdit_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) modal:true
            if ::_gridEdit_result != undefined then (
                local colText = ::_gridEdit_result[1]
                local rowText = ::_gridEdit_result[2]
                local nextNum = (presets.count + 1) as string
                local newPreset = structPreset name:nextNum cols:colText rows:rowText colPositions:(_gridEdit_colPositions) rowPositions:(_gridEdit_rowPositions) colSegData:(_gridEdit_colSegData) rowSegData:(_gridEdit_rowSegData)
                append presets newPreset
                saveAllPresetsToINI()
                refreshListView()
            )
        )
    )

    on btnGridEdit pressed do (
        _gridEdit_divX = #()
        _gridEdit_divY = #()
        ::_gridEdit_result = undefined
        ::_gridEdit_colPositions = undefined
        ::_gridEdit_rowPositions = undefined
        ::_gridEdit_colSegData = undefined
        ::_gridEdit_rowSegData = undefined
        createDialog WH_GridEdit_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) modal:true
        if ::_gridEdit_result != undefined then (
            local colText = ::_gridEdit_result[1]
            local rowText = ::_gridEdit_result[2]
            if presets.count >= 20 then (
                messageBox "预设数量已达上限 (20个)！请先右键删除不需要的预设。" title:"提示"
            ) else (
                local nextNum = (presets.count + 1) as string
                local newPreset = structPreset name:nextNum cols:colText rows:rowText colPositions:(_gridEdit_colPositions) rowPositions:(_gridEdit_rowPositions) colSegData:(_gridEdit_colSegData) rowSegData:(_gridEdit_rowSegData)
                append presets newPreset
                saveAllPresetsToINI()
                refreshListView()
            )
        )
    )
    
    on btnMake pressed do (
        makeWindow()
    )
)

try(destroyDialog UI_WinMakerToolPlus)catch()
try(closeRolloutFloater PC_Floater)catch()
createDialog UI_WinMakerToolPlus style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow, #style_resizing)
--PCHPLUS_DATA_BEGIN
--Settings|OuterSize=75.0|InnerSize=50.0|FrameDepth=80.0|GlassDepth=8.0|HeightEnable=true|SillSize=1200.0|DepthSize=250.0|WinHeightSize=1600.0|WindowWidth=430|WindowHeight=510
--PresetCount|19
--Preset|1|1|27,48,24|35,64|0.0,0.271739,0.757246,1.0|0.0,0.355932,1.0|0.271739:2,1;0.757246:2,1|0.355932:1,3
--Preset|2|2|26,45,28|72,27|0.0,0.264493,0.717391,1.0|0.0,0.720339,1.0|0.264493:2,1;0.717391:2,1|0.720339:1,2,3
--Preset|3|3|30,69|68,31|0.0,0.304348,1.0|0.0,0.686441,1.0|0.304348:2,1|0.686441:1
--Preset|4|4|69,30|32,67|0.0,0.695652,1.0|0.0,0.326271,1.0|0.695652:2,1|0.326271:2
--Preset|5|5|25,47,27|70,29|0.0,0.257246,0.728261,1.0|0.0,0.70339,1.0|0.257246:2,1;0.728261:2,1|0.70339:1,3
--Preset|6|6|48,51|75,24|0.0,0.485507,1.0|0.0,0.758475,1.0|0.485507:2,1|0.758475:1,2
--Preset|7|7|23,25,26,24|75,25|0.0,0.235507,0.492754,0.753623,1.0|0.0,0.75,1.0|0.235507:2,1;0.492754:2,1;0.753623:2,1|0.75:1,2,3,4
--Preset|8|8|23,26,26,23|28,71|0.0,0.23913,0.5,0.764493,1.0|0.0,0.288136,1.0|0.23913:2;0.5:2,1;0.764493:2|0.288136:1,2,3,4
--Preset|9|9|100|38,61|0.0,1.0|0.0,0.389831,1.0|-|0.389831:1
--Preset|10|10|49,50|100|0.0,0.496377,1.0|0.0,1.0|0.496377:1|-
--Preset|11|11|23,53,22|30,69|0.0,0.235507,0.771739,1.0|0.0,0.309322,1.0|0.235507:2,1;0.771739:2,1|0.309322:1,3
--Preset|12|12|50,49|69,30|0.0,0.503623,1.0|0.0,0.699153,1.0|0.503623:1|0.699153:1,2
--Preset|13|13|23,24,26,25|27,50,22|0.0,0.235507,0.481884,0.75,1.0|0.0,0.271186,0.779661,1.0|0.235507:2;0.481884:3,2,1;0.75:2|0.779661:1,2,3,4;0.271186:1,2,3,4
--Preset|14|14|50,50|28,47,24|0.0,0.5,1.0|0.0,0.283898,0.758475,1.0|0.5:3,2,1|0.758475:1,2;0.283898:1,2
--Preset|15|15|14,15,17,18,16,17|28,46,24|0.0,0.148551,0.300725,0.478261,0.663043,0.82971,1.0|0.0,0.288136,0.754237,1.0|0.148551:2;0.300725:3,2,1;0.478261:2;0.663043:3,2,1;0.82971:2|0.754237:1,2,3,4,5,6;0.288136:1,2,3,4,5,6
--Preset|16|16|48,51|27,47,25|0.0,0.485507,1.0|0.0,0.271186,0.745763,1.0|0.485507:2|0.745763:1,2;0.271186:1,2
--Preset|17|17|48,51|69,30|0.0,0.481884,1.0|0.0,0.694915,1.0|0.481884:2,1|0.694915:1,2
--Preset|18|18|100|73,26|0.0,1.0|0.0,0.733051,1.0|-|0.733051:1
--Preset|19|19|100|100|0.0,1.0|0.0,1.0|-|-
--PCHPLUS_DATA_END
