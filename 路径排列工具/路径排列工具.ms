-- 阿酷路径排列助手 v3.3 (极简直观重构版)
-- 专为“路径排列”深度定制，采用全步骤向导式 UI
-- 移除了原版中混淆的“道路摆车”等无用功能

(
    -- 全局变量与环境初始化
    global KF_PathPlantTool
    try(destroyDialog KF_PathPlantTool)catch()
    global KGL_PlantScattObj = #()
    global KGL_Plantcatbj = #()
    global KGL_GeneratedObjects = #() -- 用于追踪生成的对象
    global Kl_BoolAr = #()
    global KLPait_zVec = [0,0,1]
    global Syun = 1.0

    -- 1. 定义自定义属性 (存放在对象上)
    local PlantObjParams = attributes Akooattributes55 (
        parameters main (
            KP_PlantPercent type:#Integer default:1
            KP_PlantDist type:#float default:1.2
            KP_PlantScale type:#float default:1.0
        )
    )

    -- 2. 基础辅助函数
    fn kugegeoFilt o = (isValidNode o and (superclassof o == GeometryClass or (superclassof o == Shape and o.baseobject.renderable)))
    fn kuge_singleFIshape o = (isValidNode o and superclassof o == Shape)
    
    fn KHF_CollSrcRootNodes ZZ aa = (
        for m in ZZ do (
            if m.parent != undefined then (
                local idx = findItem aa m
                if idx != 0 do deleteItem aa idx
                KHF_CollSrcRootNodes #(m.parent) aa
            ) else if findItem aa m == 0 do append aa m
        )
    )

    -- 3. 核心放置逻辑 (严格规格排列)
    fn AK_plantPPFnGZ PathSpline FFD u SpNum isAlt = (
        global KL_FFFDegAR = #() -- 声明全局以供外部访问
        global KL_VBCX55 = #()
        
        if u == 1 then (
            append KL_VBCX55 #(0.0)
            local KL_MMA = false
            for m = 1 to SpNum do (
                local AkLen = curveLength PathSpline m
                local SpCount = (AkLen / FFD) as Integer
                if SpCount < 1 do SpCount = 1
                for aa = 0 to (SpCount - 1) do (
                    local Ffo = (1.0 / SpCount) * aa
                    local isAllowed = true
                    
                    if KF_PathPlantTool.cbx_skip.checked then (
                        if Kl_BoolAr.count == 0 do (
                            -- 这里直接使用传入的“种x隔y”设定
                            local pCount = random KF_PathPlantTool.spn_plant_min.value KF_PathPlantTool.spn_plant_max.value
                            local sCount = random KF_PathPlantTool.spn_skip_min.value KF_PathPlantTool.spn_skip_max.value
                            for q=1 to pCount do append Kl_BoolAr true
                            for q=1 to sCount do append Kl_BoolAr false
                        )
                        isAllowed = Kl_BoolAr[1]
                        deleteItem Kl_BoolAr 1
                    )
                    
                    if isAllowed then (
                        if KL_MMA do append KL_VBCX55 #((Ffo + m))
                        append KL_FFFDegAR #(Ffo, m)
                        KL_MMA = false
                    ) else (
                        if not KL_MMA do append KL_VBCX55[KL_VBCX55.count] (Ffo + m)
                        KL_MMA = true
                    )
                )
                if not (isClosed PathSpline m) do append KL_FFFDegAR #(1.0, m)
            )
            append KL_VBCX55[KL_VBCX55.count] (1.0 + SpNum)
        ) else (
            for m = 1 to SpNum do (
                local AkLen = curveLength PathSpline m
                local SpCount = (AkLen / FFD) as Integer
                if SpCount < 1 do SpCount = 1
                for aa = 0 to SpCount do (
                    local Ffo = (1.0 / SpCount) * aa
                    local KL_AAX = true
                    while KL_AAX do (
                        for gg in KL_VBCX55 where (Ffo + m) > gg[1] and (Ffo + m) < gg[2] do (
                            append KL_FFFDegAR #(Ffo, m)
                            KL_AAX = false
                        )
                        KL_AAX = false
                    )
                )
            )
        )
    )

    -- 4. 执行函数
    fn RunPathPlant = (
        KGL_PlantScattObj = for m in KGL_PlantScattObj where isValidNode m collect m
        KGL_Plantcatbj = #()
        for i=1 to KGL_PlantScattObj.count do (
            if (KF_PathPlantTool.KL_ML1.Items.Item(i-1)).checked do append KGL_Plantcatbj KGL_PlantScattObj[i]
        )

        if KGL_Plantcatbj.count > 0 and isValidNode KF_PathPlantTool.PK_Path.object then (
            setWaitCursor()
            undo "Path Plant" on (
                local PathObj = KF_PathPlantTool.PK_Path.object
                local SpNum = numSplines PathObj
                
                -- 准备对象库
                local ObjPool = #()
                local LastSizeAR = #()
                for m in KGL_Plantcatbj do (
                    local sz = m.max - m.min
                    append LastSizeAR ((sz.x + sz.y) / 2)
                    for n=1 to m.KP_PlantPercent do append ObjPool m
                )

                -- 决定是否完全打乱分配
                local isGlobalAlt = KF_PathPlantTool.cbx_alt.checked
                local LoopList = if not isGlobalAlt then KGL_Plantcatbj else #(KGL_Plantcatbj[1])
                Kl_BoolAr = #() -- 清空种空规律数组，让每次排列都重新开始计算

                for u = 1 to LoopList.count do (
                    local activeObjRef = LoopList[u]
                    local FFD = (LastSizeAR[u] * activeObjRef.KP_PlantDist)
                    
                    AK_plantPPFnGZ PathObj FFD u SpNum isGlobalAlt
                    
                    for oo = 1 to KL_FFFDegAR.count do (
                        local activeObj = if not isGlobalAlt then activeObjRef else ObjPool[random 1 ObjPool.count]
                        -- 矩阵计算
                        local strokeVec = tangentCurve3D PathObj KL_FFFDegAR[oo][2] KL_FFFDegAR[oo][1]
                        local yVec = normalize(cross [0,0,1] strokeVec)
                        local zVec = normalize(cross strokeVec yVec)
                        
                        local tm = matrix3 strokeVec yVec zVec [0,0,0]
                        
                        -- 随机处理
                        if KF_PathPlantTool.cbx_rot.checked do rotateZ tm (random -KF_PathPlantTool.spn_rot.value KF_PathPlantTool.spn_rot.value)
                        
                        tm.row4 = interpCurve3D PathObj KL_FFFDegAR[oo][2] KL_FFFDegAR[oo][1]
                        
                        -- 随机位移
                        if KF_PathPlantTool.cbx_pos.checked do (
                            local offsetVal = random 0 (KF_PathPlantTool.spn_pos.value * LastSizeAR[u])
                            tm.row4 += yVec * (if random 0 1 > 0.5 then offsetVal else -offsetVal)
                        )

                        -- 缩放
                        local sc = activeObj.transform.scale
                        if KF_PathPlantTool.cbx_scale.checked do (
                            local s = 1.0 + (random -KF_PathPlantTool.spn_scale.value KF_PathPlantTool.spn_scale.value)
                            sc *= s
                        )
                        
                        maxOps.cloneNodes activeObj cloneType:#instance newNodes:&nn
                        nn[1].transform = tm
                        nn[1].scale = sc
                        nn[1].boxMode = (KF_PathPlantTool.rad_view.state == 1)
                        append KGL_GeneratedObjects nn[1]
                    )
                )
            )
            setArrowCursor()
        ) else messagebox "请先完成【第一步】添加对象 并确保已完成【第三步】拾取路径线！"
    )

    -- 5. UI 定义 (重新设计的精简直观向导式排版)
    rollout KF_PathPlantTool "纯净路径排列助手" width:300 height:520 (
        
        local iniFile = getDir #plugcfg + "\\PathPlantTool_Settings.ini"
        
        fn saveSettings = (
            try(setINISetting iniFile "Settings" "PosChecked" (cbx_pos.checked as string))catch()
            try(setINISetting iniFile "Settings" "PosVal" (spn_pos.value as string))catch()
            try(setINISetting iniFile "Settings" "RotChecked" (cbx_rot.checked as string))catch()
            try(setINISetting iniFile "Settings" "RotVal" (spn_rot.value as string))catch()
            try(setINISetting iniFile "Settings" "ScaleChecked" (cbx_scale.checked as string))catch()
            try(setINISetting iniFile "Settings" "ScaleVal" (spn_scale.value as string))catch()
            try(setINISetting iniFile "Settings" "AltChecked" (cbx_alt.checked as string))catch()
            try(setINISetting iniFile "Settings" "SkipChecked" (cbx_skip.checked as string))catch()
            try(setINISetting iniFile "Settings" "PlantMin" (spn_plant_min.value as string))catch()
            try(setINISetting iniFile "Settings" "PlantMax" (spn_plant_max.value as string))catch()
            try(setINISetting iniFile "Settings" "SkipMin" (spn_skip_min.value as string))catch()
            try(setINISetting iniFile "Settings" "SkipMax" (spn_skip_max.value as string))catch()
            try(setINISetting iniFile "Settings" "RadView" (rad_view.state as string))catch()
        )
        
        fn loadSettings = (
            if doesFileExist iniFile do (
                try(local v = getINISetting iniFile "Settings" "PosChecked"; if v != "" do cbx_pos.checked = (v == "true"))catch()
                try(local v = getINISetting iniFile "Settings" "PosVal"; if v != "" do spn_pos.value = v as float)catch()
                try(local v = getINISetting iniFile "Settings" "RotChecked"; if v != "" do cbx_rot.checked = (v == "true"))catch()
                try(local v = getINISetting iniFile "Settings" "RotVal"; if v != "" do spn_rot.value = v as integer)catch()
                try(local v = getINISetting iniFile "Settings" "ScaleChecked"; if v != "" do cbx_scale.checked = (v == "true"))catch()
                try(local v = getINISetting iniFile "Settings" "ScaleVal"; if v != "" do spn_scale.value = v as float)catch()
                try(local v = getINISetting iniFile "Settings" "AltChecked"; if v != "" do cbx_alt.checked = (v == "true"))catch()
                try(local v = getINISetting iniFile "Settings" "SkipChecked"; if v != "" do cbx_skip.checked = (v == "true"))catch()
                try(local v = getINISetting iniFile "Settings" "PlantMin"; if v != "" do spn_plant_min.value = v as integer)catch()
                try(local v = getINISetting iniFile "Settings" "PlantMax"; if v != "" do spn_plant_max.value = v as integer)catch()
                try(local v = getINISetting iniFile "Settings" "SkipMin"; if v != "" do spn_skip_min.value = v as integer)catch()
                try(local v = getINISetting iniFile "Settings" "SkipMax"; if v != "" do spn_skip_max.value = v as integer)catch()
                try(local v = getINISetting iniFile "Settings" "RadView"; if v != "" do rad_view.state = v as integer)catch()
            )
        )

        -- 第一步：对象
        groupBox grp1 "第一步：准备种植源对象" pos:[10,10] width:280 height:175
        dotnetcontrol KL_ML1 "System.Windows.Forms.ListView" height:110 width:260 pos:[20,30]
        
        button btn_add "+ 拾取" pos:[20,150] width:45 height:25 tooltip:"拾取模型到列表"
        button btn_add_all "++ 选择" pos:[70,150] width:55 height:25 tooltip:"将已选模型加入列表"
        button btn_sub "- 移除" pos:[130,150] width:50 height:25 tooltip:"移除选中的条目"
        button btn_sub_all "-- 清空" pos:[185,150] width:50 height:25 tooltip:"清空列表"
        button btn_refresh "刷新" pos:[240,150] width:40 height:25

        -- 第二步：参数
        groupBox grp2 "第二步：路径排列参数设置" pos:[10,195] width:280 height:190
        
        checkbox cbx_pos "随机横向偏移: ±" pos:[30,220] checked:false
        spinner spn_pos "" range:[0.1,10.0,1.2] pos:[135,220] fieldWidth:45
        
        checkbox cbx_rot "沿路随机旋转: ±" pos:[30,250] checked:true
        spinner spn_rot "" range:[0,180,90] pos:[135,250] fieldWidth:45 type:#integer
        
        checkbox cbx_scale "随机缩放比例: ±" pos:[30,280] checked:false
        spinner spn_scale "" range:[0.1,1.0,0.1] pos:[135,280] fieldWidth:45
        
        checkbox cbx_alt "乱序随机交替 (打乱多对象的顺序)" pos:[30,310] checked:true

        checkbox cbx_skip "开启规律留空" pos:[30,340] checked:false tooltip:"俗称【种X隔Y】"
        spinner spn_plant_min "种" range:[1,100,3] pos:[135,340] fieldWidth:20 type:#integer tooltip:"种几个"
        spinner spn_plant_max "-" range:[1,100,3] pos:[185,340] fieldWidth:20 type:#integer tooltip:"最高到几个(随机)"
        spinner spn_skip_min "隔" range:[1,100,2] pos:[135,365] fieldWidth:20 type:#integer tooltip:"空出几个位置"
        spinner spn_skip_max "-" range:[1,100,3] pos:[185,365] fieldWidth:20 type:#integer tooltip:"最高空几位(随机)"

        -- 第三步和第四步：操作
        groupBox grp3 "第三步：路径拾取与执行" pos:[10,395] width:280 height:75
        pickbutton PK_Path "1. 拾取线 (Line)" pos:[20,415] width:100 height:45 autoDisplay:true filter:kuge_singleFIshape
        button btn_standard "2. 开始路径排列" pos:[135,415] width:145 height:45

        -- 底部杂项
        radiobuttons rad_view "" pos:[10,485] labels:#("方盒", "预览") default:2 columns:2
        button btn_del "清理全部生成物" pos:[135,485] width:95 height:25
        button btn_sel "选中它们" pos:[235,485] width:55 height:25

        fn KF_RefreshList = (
            local old_objs = for m in KGL_PlantScattObj where isValidNode m collect m
            KGL_PlantScattObj = old_objs
            KL_ML1.Items.clear()
            local range = #()
            for obj in KGL_PlantScattObj do (
                if not isProperty obj "KP_PlantPercent" do custAttributes.add obj PlantObjParams
                local lItem = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                lItem.checked = true
                lItem.SubItems.add (obj.KP_PlantPercent as string)
                lItem.SubItems.add (obj.KP_PlantDist as string)
                -- 显示包围盒参考高度
                local sz = obj.max - obj.min
                lItem.SubItems.add ((floor sz.z) as string) 
                append range lItem
            )
            KL_ML1.Items.AddRange range
        )

        on btn_add pressed do (
            local p = pickObject filter:kugegeoFilt
            if p != undefined do (
                KHF_CollSrcRootNodes #(p) KGL_PlantScattObj
                KF_RefreshList()
            )
        )
        on btn_add_all pressed do (
            local sel = for m in selection where kugegeoFilt m collect m
            if sel.count > 0 do (
                KHF_CollSrcRootNodes sel KGL_PlantScattObj
                KF_RefreshList()
            )
        )
        on btn_sub pressed do (
            if KL_ML1.SelectedIndices.count > 0 do (
                local idx = KL_ML1.SelectedIndices.Item(0) + 1
                deleteItem KGL_PlantScattObj idx
                KF_RefreshList()
            )
        )
        on btn_sub_all pressed do (
            KGL_PlantScattObj = #()
            KF_RefreshList()
        )
        on btn_refresh pressed do KF_RefreshList()
        
        on PK_Path picked aa do (
            btn_standard.text = "2. 立刻开始排列"
        )
        
        on btn_standard pressed do RunPathPlant()

        -- 底部杂项按钮功能实现
        on btn_del pressed do (
            local validObjs = for o in KGL_GeneratedObjects where isValidNode o collect o
            if validObjs.count > 0 do (
                undo "清理排列生成物" on (
                    delete validObjs
                )
            )
            KGL_GeneratedObjects = #()
        )
        
        on btn_sel pressed do (
            local validObjs = for o in KGL_GeneratedObjects where isValidNode o collect o
            if validObjs.count > 0 do select validObjs
        )
        
        on rad_view changed state do (
            local validObjs = for o in KGL_GeneratedObjects where isValidNode o collect o
            local isBox = (state == 1)
            if validObjs.count > 0 do (
                undo "切换预览模式" on (
                    for o in validObjs do o.boxMode = isBox
                )
            )
            saveSettings()
        )
        
        on cbx_pos changed state do saveSettings()
        on spn_pos changed val do saveSettings()
        on cbx_rot changed state do saveSettings()
        on spn_rot changed val do saveSettings()
        on cbx_scale changed state do saveSettings()
        on spn_scale changed val do saveSettings()
        on cbx_alt changed state do saveSettings()
        on cbx_skip changed state do saveSettings()
        on spn_plant_min changed val do saveSettings()
        on spn_plant_max changed val do saveSettings()
        on spn_skip_min changed val do saveSettings()
        on spn_skip_max changed val do saveSettings()

        on KF_PathPlantTool open do (
            loadSettings()
            KL_ML1.view = (dotNetClass "System.Windows.Forms.View").Details
            KL_ML1.Columns.add "源模型" 105
            KL_ML1.Columns.add "权重" 35
            KL_ML1.Columns.add "间距" 45
            KL_ML1.Columns.add "高度" 45
            KL_ML1.checkBoxes = true
            KL_ML1.fullRowSelect = true
            KF_RefreshList()
        )
        
        on KF_PathPlantTool close do saveSettings()
    )

    createDialog KF_PathPlantTool
)
