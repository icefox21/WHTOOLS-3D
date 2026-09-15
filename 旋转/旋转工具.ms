-- 旋转工具 v2.2
-- 正交视图：点左右 = 绕「视图竖轴」（屏幕上下方向的轴），点上下 = 绕「视图横轴」
(
    global WhSpin_Rollout
    global WhSpinTool
    global WhSpinDrawFn
    global WhSpin_Angle = 90.0
    global WhSpin_Presets = #(90.0, 45.0, 15.0, 5.0)
    global WhSpin_IniFile = getDir #plugcfg + "\\WhSpin_Settings.ini"
    global WhSpin_ToolActive = false

    try (destroyDialog WhSpin_Rollout) catch()
    try (unRegisterRedrawViewsCallback WhSpinDrawFn) catch()
    try (stopTool WhSpinTool) catch()

    fn WhSpinTopNodes = (
        for n in selection where (n.parent == undefined or not n.parent.isSelected) collect n
    )

    -- 视图轴：row1=屏幕右，row2=屏幕上，row3=视线
    fn WhSpinViewAxes = (
        local vtm = getViewTM()
        local right = vtm.row1
        local up = vtm.row2
        if (length right) < 1e-8 do right = [1, 0, 0]
        if (length up) < 1e-8 do up = [0, 1, 0]
        #(normalize right, normalize up)
    )

    -- 绕给定世界方向轴、以 Pivot 为中心旋转
    fn WhSpinRotateAxis axisVec angle = (
        if angle == 0 do return()
        local tops = WhSpinTopNodes()
        if tops.count == 0 do return()
        undo "WhSpin 旋转" on (
            for obj in tops do (
                about obj.pivot rotate obj (angleAxis angle axisVec)
            )
        )
    )

    -- 左右 = 绕视图竖轴（屏幕上竖着的那根轴，前视图里常是世界Z或Y）
    -- 上下 = 绕视图横轴（屏幕上横着的那根轴）
    fn WhSpinDo dir = (
        local a = WhSpin_Angle
        local ax = WhSpinViewAxes()
        local right = ax[1]
        local up = ax[2]
        case dir of (
            #left:  WhSpinRotateAxis up (-a)
            #right: WhSpinRotateAxis up (a)
            #up:    WhSpinRotateAxis right (a)
            #down:  WhSpinRotateAxis right (-a)
        )
    )

    -- 点击点相对 Pivot：先换到视图空间，取屏幕右/上分量
    -- 正交下 worldPoint 落在构造平面上，不能直接用世界坐标差
    fn WhSpinClickDelta obj clickWp = (
        local inv = inverse (getViewTM())
        local c = clickWp * inv
        local p = obj.pivot * inv
        [c.x - p.x, c.y - p.y]
    )

    -- 更稳：用视图空间里，把点击射线与过 Pivot、面向相机的平面求交
    fn WhSpinClickOnViewPlane obj = (
        local vtm = getViewTM()
        local inv = inverse vtm
        local pivV = obj.pivot * inv
        local clickV = undefined
        try (clickV = viewPoint) catch()
        if clickV == undefined do (
            try (
                local wp = worldPoint
                clickV = wp * inv
            ) catch()
        )
        if clickV == undefined do return undefined
        -- 用点击的视图X/Y，深度对齐到 Pivot（正交下这样最稳）
        [clickV.x - pivV.x, clickV.y - pivV.y]
    )

    fn WhSpinDirFromDelta d = (
        if d == undefined do return undefined
        if (abs d.x) >= (abs d.y) then (
            if d.x >= 0 then #right else #left
        ) else (
            if d.y >= 0 then #up else #down
        )
    )

    fn WhSpinWorldToScreen wp = (
        local r = undefined
        try (r = mapWorldToScreen wp) catch()
        if r != undefined do return r
        try (r = viewport.mapWorldToScreen wp) catch()
        if r != undefined do return r
        undefined
    )

    fn WhSpinHandleOffsets pivot = (
        local ax = WhSpinViewAxes()
        local right = ax[1]
        local up = ax[2]
        local pix = 56.0
        local wOff = 100.0
        try (
            local s = getScreenScaleFactor pivot
            if s != undefined and (abs s) > 1e-8 do wOff = pix / (abs s)
        ) catch()
        if wOff < 0.01 do wOff = 0.01
        #(right * wOff, -right * wOff, up * wOff, -up * wOff)
    )

    fn WhSpinDrawFn = (
        try (
            if not WhSpin_ToolActive do return()
            local tops = WhSpinTopNodes()
            if tops.count == 0 do return()
            local p = tops[1].pivot
            local offs = WhSpinHandleOffsets p
            gw.setColor #line (color 255 140 40)
            gw.setLineWidth 3
            gw.marker (p + offs[1]) #circle
            gw.marker (p + offs[2]) #circle
            gw.marker (p + offs[3]) #circle
            gw.marker (p + offs[4]) #circle
            gw.setColor #line (color 255 220 120)
            gw.hText (p + offs[3] * 1.3) "上=绕横轴"
            gw.hText (p + offs[4] * 1.3) "下=绕横轴"
            gw.hText (p + offs[1] * 1.3) "右=绕竖轴"
            gw.hText (p + offs[2] * 1.3) "左=绕竖轴"
        ) catch()
    )

    fn WhSpinStartFeedback = (
        WhSpin_ToolActive = true
        try (unRegisterRedrawViewsCallback WhSpinDrawFn) catch()
        registerRedrawViewsCallback WhSpinDrawFn
        completeRedraw()
    )

    fn WhSpinStopFeedback = (
        WhSpin_ToolActive = false
        try (unRegisterRedrawViewsCallback WhSpinDrawFn) catch()
        completeRedraw()
    )

    tool WhSpinTool
    (
        on activate do WhSpinStartFeedback()
        on deactivate do WhSpinStopFeedback()
        on mousePoint click do (
            if click == 1 then (
                if selection.count == 0 then (
                    messagebox "请先选择要旋转的物体。" title:"旋转工具"
                    #stop
                ) else (
                    local tops = WhSpinTopNodes()
                    if tops.count > 0 do (
                        local obj = tops[1]
                        local d = WhSpinClickOnViewPlane obj
                        if d == undefined do (
                            try (d = WhSpinClickDelta obj worldPoint) catch()
                        )
                        local dir = WhSpinDirFromDelta d
                        if dir != undefined do WhSpinDo dir
                        completeRedraw()
                    )
                )
            ) else if click == 3 then (
                #stop
            )
        )
        on mouseAbort click do #stop
    )

    fn WhSpinStartTool = (
        if selection.count == 0 do (
            messagebox "请先选择要旋转的物体。" title:"旋转工具"
            return()
        )
        try (stopTool WhSpinTool) catch()
        startTool WhSpinTool prompt:"【旋转】点左右=绕屏幕上竖轴，点上下=绕屏幕上横轴 | 右键/Esc 结束"
    )

    fn WhSpinSave = (
        try (
            setINISetting WhSpin_IniFile "Settings" "Angle" (WhSpin_Angle as string)
            for i = 1 to 4 do (
                setINISetting WhSpin_IniFile "Presets" ("P" + i as string) (WhSpin_Presets[i] as string)
            )
        ) catch()
    )

    fn WhSpinLoad = (
        try (
            if doesFileExist WhSpin_IniFile do (
                local v = getINISetting WhSpin_IniFile "Settings" "Angle"
                if v != "" do WhSpin_Angle = v as float
                for i = 1 to 4 do (
                    v = getINISetting WhSpin_IniFile "Presets" ("P" + i as string)
                    if v != "" do WhSpin_Presets[i] = v as float
                )
            )
        ) catch()
    )

    rollout WhSpin_Rollout "快速旋转 v2.2" width:250 height:280
    (
        spinner spnAngle "角度:" range:[-3600, 3600, 90] type:#float fieldWidth:70 pos:[12, 12]
        label lblUnit "度" pos:[95, 14]
        button btnStart "启动点击旋转" pos:[120, 10] width:115 height:24

        groupBox grpDir "方向（按当前视图轴）" pos:[8, 42] width:234 height:58
        button btnLeft  "左" pos:[16, 62] width:52 height:28
        button btnRight "右" pos:[74, 62] width:52 height:28
        button btnUp    "上" pos:[132, 62] width:52 height:28
        button btnDown  "下" pos:[190, 62] width:44 height:28

        groupBox grpPre "预设（左键使用，右键设为当前角度）" pos:[8, 108] width:234 height:58
        button btnP1 "90" pos:[16, 128] width:52 height:28
        button btnP2 "45" pos:[74, 128] width:52 height:28
        button btnP3 "15" pos:[132, 128] width:52 height:28
        button btnP4 "5"  pos:[190, 128] width:44 height:28

        groupBox grpHelp "说明" pos:[8, 174] width:234 height:92
        label lb1 "1. 前视图等正交视图使用" pos:[16, 194]
        label lb2 "2. 点左右→绕屏幕上竖轴转" pos:[16, 212]
        label lb3 "3. 点上下→绕屏幕上横轴转" pos:[16, 230]
        label lb4 "4. 中心=物体Pivot；右键/Esc退出" pos:[16, 248]

        fn refreshPresetText = (
            btnP1.text = WhSpin_Presets[1] as string
            btnP2.text = WhSpin_Presets[2] as string
            btnP3.text = WhSpin_Presets[3] as string
            btnP4.text = WhSpin_Presets[4] as string
        )

        on WhSpin_Rollout open do (
            WhSpinLoad()
            spnAngle.value = WhSpin_Angle
            refreshPresetText()
        )
        on WhSpin_Rollout close do (
            WhSpinStopFeedback()
            try (stopTool WhSpinTool) catch()
            WhSpinSave()
        )

        on spnAngle changed val do (
            WhSpin_Angle = val
            WhSpinSave()
        )

        on btnStart pressed do WhSpinStartTool()

        on btnLeft  pressed do WhSpinDo #left
        on btnRight pressed do WhSpinDo #right
        on btnUp    pressed do WhSpinDo #up
        on btnDown  pressed do WhSpinDo #down

        on btnP1 pressed do (WhSpin_Angle = WhSpin_Presets[1]; spnAngle.value = WhSpin_Angle)
        on btnP2 pressed do (WhSpin_Angle = WhSpin_Presets[2]; spnAngle.value = WhSpin_Angle)
        on btnP3 pressed do (WhSpin_Angle = WhSpin_Presets[3]; spnAngle.value = WhSpin_Angle)
        on btnP4 pressed do (WhSpin_Angle = WhSpin_Presets[4]; spnAngle.value = WhSpin_Angle)

        on btnP1 rightClick do (
            if queryBox "把当前角度设为预设1？" title:"设置预设" do (
                WhSpin_Presets[1] = spnAngle.value; refreshPresetText(); WhSpinSave()
            )
        )
        on btnP2 rightClick do (
            if queryBox "把当前角度设为预设2？" title:"设置预设" do (
                WhSpin_Presets[2] = spnAngle.value; refreshPresetText(); WhSpinSave()
            )
        )
        on btnP3 rightClick do (
            if queryBox "把当前角度设为预设3？" title:"设置预设" do (
                WhSpin_Presets[3] = spnAngle.value; refreshPresetText(); WhSpinSave()
            )
        )
        on btnP4 rightClick do (
            if queryBox "把当前角度设为预设4？" title:"设置预设" do (
                WhSpin_Presets[4] = spnAngle.value; refreshPresetText(); WhSpinSave()
            )
        )
    )

    createDialog WhSpin_Rollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)
