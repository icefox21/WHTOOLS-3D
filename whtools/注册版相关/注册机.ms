-- ========================================================
-- WhtoolS 专用注册机 (Key Machine) - 绝密
-- ========================================================

rollout WHToolsKeygenUI "WhtoolS - 开发者注册机" width:350 height:220
(
    group "算号核心"
    (
        label lbl1 "客户提供的特征码 (Machine ID):" align:#left mask:true
        edittext edtMacID "" width:310 align:#center
        
        button btnGen "★ 生成正式授权码 ★" width:310 height:35 align:#center
        
        button btnGenTrial "⚡ 生成 2 天试用码 ⚡" width:310 height:35 align:#center offset:[0, 5]
        
        label lbl2 "计算得出的授权码 (License Key):" align:#left offset:[0, 5]
        edittext edtKey "" width:310 align:#center readOnly:true
    )
    
    fn generateKey macID = (
        -- 核心加密算法，必须与前台验证算法100%保持一致
        local keyInt = 0
        for i=1 to macID.count do (
            keyInt += (bit.charAsInt macID[i]) * 88
        )
        local finalKey = "WH-KEY-" + ((keyInt * 123) as string)
        return finalKey
    )

    fn generateTrialKey macID = (
        -- 获取 2 天后的日期
        local dt = (dotnetClass "System.DateTime").Now.AddDays 2
        local expDate = dt.ToString "yyyyMMdd"
        
        -- 混合 MacID 和日期进行哈希，使用试用版专有的 77 偏移量
        local rawStr = macID + expDate
        local keyInt = 0
        for i=1 to rawStr.count do (
            keyInt += (bit.charAsInt rawStr[i]) * 77
        )
        
        local finalKey = "WH-TRIAL-" + ((keyInt * 123) as string) + "-" + expDate
        return finalKey
    )
    
    on btnGen pressed do (
        if edtMacID.text == "" then (
            messageBox "请输入客户的 Machine ID！" title:"错误"
        ) else (
            local rawStr = edtMacID.text
            -- 清理可能附带的空格
            local cleanStr = ""
            for i=1 to rawStr.count do (
                if rawStr[i] != " " do cleanStr += rawStr[i]
            )
            
            local theKey = generateKey cleanStr
            edtKey.text = theKey
            
            setclipboardText theKey
            messageBox "计算成功！\n授权码已自动复制到剪贴板，可直接发送给客户！" title:"算号完毕"
        )
    )

    on btnGenTrial pressed do (
        if edtMacID.text == "" then (
            messageBox "请输入客户的 Machine ID！" title:"错误"
        ) else (
            local rawStr = edtMacID.text
            local cleanStr = ""
            for i=1 to rawStr.count do (
                if rawStr[i] != " " do cleanStr += rawStr[i]
            )
            
            local theKey = generateTrialKey cleanStr
            edtKey.text = theKey
            
            setclipboardText theKey
            messageBox "2 天试用码计算成功！\n授权码已自动复制到剪贴板。" title:"试用码发放"
        )
    )
)
createDialog WHToolsKeygenUI
