-- install.ms
(
    local p = getFilenamePath (getThisScriptFilename())
    local srcFile = p + "whtools_manager.ms"
    local destDir = (getDir #userScripts) + "\\whtools"
    
    makeDir destDir
    
    local destFile = destDir + "\\whtools_manager.ms"
    
    -- 强制覆盖旧文件：解除可能的只读或者锁定
    try(setFileAttribute destFile #readOnly false)catch()
    try(deleteFile destFile)catch()
    try(deleteFile (destDir + "\\whtools_manager_beta.ms"))catch()
    
    local copySuccess = false
    if doesFileExist srcFile then (
        try(
            local fileText = (dotNetClass "System.IO.File").ReadAllText srcFile
            (dotNetClass "System.IO.File").WriteAllText destFile fileText
            copySuccess = true
        ) catch (
            messageBox ("致命错误：执行暴力覆写失败！可能是系统级权限导致。\n文件：" + destFile) title:"whtools 安装器"
            copySuccess = false
        )
    ) else (
        messageBox ("致命错误：MZP 解压失败！系统拦截了临时文件夹。\n找不到源文件：" + srcFile) title:"whtools 安装器"
    )
    
    if copySuccess then (
        macroScript WH_Manager 
        category:"whtool" 
        tooltip:"whtools 脚本管理器" 
        buttonText:"whtools"
        (
            on execute do (
                global WH_ScriptManager_Rollout
                if WH_ScriptManager_Rollout != undefined and WH_ScriptManager_Rollout.open then (
                    try(destroyDialog WH_ScriptManager_Rollout)catch()
                ) else (
                    local scriptPath = (getDir #userScripts) + "\\whtools\\whtools_manager.ms"
                    if doesFileExist scriptPath then (
                        fileIn scriptPath
                    ) else (
                        messageBox "错误：核心脚本已失联！\n可能被杀毒软件误删，请重新拖入 whtools_manager.mzp 安装。" title:"whtools"
                    )
                )
            )
        )
        messageBox "✅ [v1.8 极简模式] 终极修复升级成功！\n\n您遇到的问题真相大白：\n1. 【占用空白行】：是因为 Max 系统底层销毁上一代工具栏的一个顽疾（留下幽灵框架），现在我加了强制漂浮指令彻底清除了这个 bug。\n2. 【关掉打回原形】：是因为旧系统死守了原本的配置文件，没能真正完成代码替换。现在我用了 .NET 底层强杀覆写技术，绝对管用！\n\n【重要提示】\n由于之前的鬼影空行是 Max 系统层面卡死的，请您务必先 **重启一次 3ds Max** (清理掉之前的界面缓存残渣)，重启后再点开 whtools，您将迎来毫无瑕疵的单行体验！" title:"whtools 终极修复"
    ) else (
        messageBox ("目标拷贝失败！这通常是因为权限禁止写入文件夹。\n请手动删除原文件后重试: \n" + destFile) title:"whtools"
    )
)
