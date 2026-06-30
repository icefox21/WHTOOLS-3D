-- 退出脚本 v1.7
-- v1.7 修复：移除不存在的 isOpenGroup 函数（会报 undefined 错误）。
-- 组头无论打开/关闭都执行 clearSelection，两种情况结果相同，合并判断即可。

macroScript WhExitSubLevel
category:"whtool"
toolTip:"退出 (v1.7) - 退出子层级/取消选择"
buttonText:"退出 (v1.7)"
(
    on execute do (
        if selection.count > 0 then (
            local sel1 = selection[1]
            
            -- ============================================================
            -- 【优先处理：组相关的所有情况】
            -- 组对象不参与子层级，直接 clearSelection，不走修改器面板逻辑
            -- ============================================================
            
            -- 情况1：选中的是组头（不管打开/关闭状态，结果相同）→ 直接取消选择
            -- 注意：isOpenGroup 在部分 Max 版本中不存在，不要使用
            if isGroupHead sel1 then (
                clearSelection()
            )
            -- 情况2：组是"打开状态"，选中了组内的成员 → 直接取消选择
            else if isGroupMember sel1 then (
                clearSelection()
            )
            -- ============================================================
            -- 【普通物体：走子层级退出逻辑】
            -- ============================================================
            else (
                -- 先确保在 Modify 面板
                if getCommandPanelTaskMode() != #modify do
                    setCommandPanelTaskMode mode:#modify
                
                -- 获取当前面板的实际激活对象和层级
                local currObj = undefined
                try(currObj = modPanel.getCurrentObject())catch()
                local currLevel = subObjectLevel
                
                -- 【核心修复】先无条件退出当前的子层级！
                -- 这是解决带修改器时退不干净的唯一正确方法，必须在跳转顶层前执行！
                if currLevel != undefined and currLevel > 0 do (
                    subObjectLevel = 0
                )
                
                local needJumpTop = false
                
                -- 判断是否需要跳转到顶层修改器
                if sel1.modifiers.count > 0 do (
                    local topMod = sel1.modifiers[1]
                    if currObj != topMod do (
                        try (
                            modPanel.setCurrentObject topMod node:sel1
                            
                            -- 跳转后，如果顶层修改器恰好处于子层级，也把它关掉
                            if subObjectLevel != undefined and subObjectLevel > 0 do (
                                subObjectLevel = 0
                            )
                            needJumpTop = true
                        ) catch ()
                    )
                )
                
                -- 如果一开始既没有子层级，也没有发生修改器跳转（说明已经在最高层了），那么就彻底取消选择
                if (currLevel == 0 or currLevel == undefined) and (not needJumpTop) do (
                    clearSelection()
                )
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
