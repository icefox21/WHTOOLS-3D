-- 退出脚本 v1.8
-- 任意子对象层级（点、线、面、体）优先退出到对象层级。
-- 打开组内的成员也允许处于子对象层级，不能提前 clearSelection。

macroScript WhExitSubLevel
category:"whtool"
toolTip:"退出 (v1.8) - 退出子层级/取消选择"
buttonText:"退出 (v1.8)"
(
    on execute do (
        if selection.count > 0 then (
            local sel1 = selection[1]
            
            -- 先确保在 Modify 面板，再读取当前子对象层级。
            if getCommandPanelTaskMode() != #modify do
                setCommandPanelTaskMode mode:#modify

            local currLevel = undefined
            try(currLevel = subObjectLevel)catch()

            -- 点、线、面、体等任何子对象层级都优先退出。
            -- 不区分普通物体、组头或打开组内的成员。
            if currLevel != undefined and currLevel > 0 then (
                try(subObjectLevel = 0)catch()
            ) else (
                -- 已处于对象层级时，才取消模型选择。
                clearSelection()
            )
        ) else (
            -- 没有选对象：清除特殊画笔和拾取模式，重置到移动工具
            try(thePainterInterface.endPaintSession())catch()
            try(toolMode.commandMode = #select)catch()
            max move
        )
        
        completeRedraw()
    )
)
