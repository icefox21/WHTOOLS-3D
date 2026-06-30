(
    global UI_UnitFixer
    try(destroyDialog UI_UnitFixer)catch()
    
    rollout UI_UnitFixer "场景尺寸倍增修复器 v1.3" width:280 height:240
    (
        label lblInfo1 "专门解决修改系统单位后，旧模型过小/过大" pos:[15,10]
        label lblInfo2 "导致输入参数与实际尺寸脱节的终极问题" pos:[20,30]
        
        groupBox grp1 "一键修复 (常用)" pos:[10,55] width:260 height:60
        button btnMtoMM "系统单位【米】改【毫米】(放大1000倍)" pos:[20,75] width:240 height:30
        
        groupBox grp2 "自定义修复缩放" pos:[10,120] width:260 height:50
        spinner spnFactor "缩放倍数:" range:[0.0001, 100000.0, 1.0] type:#float fieldwidth:60 pos:[30,140]
        button btnCustom "执行自定义缩放" pos:[150,140] width:110 height:20
        
        groupBox grp3 "后遗症急救包" pos:[10,180] width:260 height:50
        button btnFixCam "点我：修复标准相机被压扁/拉伸" pos:[20,200] width:240 height:25
        
        on btnMtoMM pressed do (
            if queryBox "警告：该操作将把当前整个场景(所有模型)的物理尺寸强行放大 1000 倍！\n\n确定执行吗？" title:"确认修复" do (
                try (rescaleWorldUnits 1000.0; messageBox "修复完成！" title:"成功") catch ()
            )
        )
        
        on btnCustom pressed do (
            local fac = spnFactor.value
            if queryBox ("确认缩放 " + (fac as string) + " 倍吗？") title:"确认自定义修复" do (
                try (rescaleWorldUnits fac; messageBox "修复完成！" title:"成功") catch ()
            )
        )
        
        on btnFixCam pressed do (
            local fixCount = 0
            undo "Fix Standard Camera Squash" on (
                for c in cameras do (
                    if superClassOf c == camera then (
                        -- 3ds Max 标准相机的压扁，通常是因为它所在的层级（Group 或 父物体）被缩放了
                        -- 或者是相机/目标点自身残留了缩放矩阵
                        local wasFixed = false
                        
                        -- 1: 断开父子层级，剥离恶意的组缩放继承
                        if c.parent != undefined do (
                            c.parent = undefined
                            wasFixed = true
                        )
                        if c.target != undefined and c.target.parent != undefined do (
                            c.target.parent = undefined
                            wasFixed = true
                        )
                        
                        -- 2: 强制重置相机的缩放控制
                        try (
                            if c.scale != [1,1,1] do (
                                c.scale = [1,1,1]
                                wasFixed = true
                            )
                            ResetScale c
                        ) catch()
                        
                        -- 3: 强制重置目标点的缩放控制
                        try (
                            if c.target != undefined then (
                                if c.target.scale != [1,1,1] do (
                                    c.target.scale = [1,1,1]
                                    wasFixed = true
                                )
                                ResetScale c.target
                            )
                        ) catch()
                        
                        if wasFixed do fixCount += 1
                    )
                )
            )
            messageBox ("已为您暴力重置了 " + (fixCount as string) + " 个相机的底层变形（解除了组绑定/层级带来的拉伸）。\n\n请按 C 键查看视野是否变回正常！\n(如果相机原本在组里，现在已经被摘出至最外层了，这样才能保证物理正确)") title:"修复完成"
        )
    )
    createDialog UI_UnitFixer
)