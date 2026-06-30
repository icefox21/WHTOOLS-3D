global lcl_view_TB,lcl_view_FBA,lcl_view_LRA,lcl_view_LRB,lcl_view_FBB,lcl_swap_view,lcl_view_camera,lcl_view_Camlist,lcl_view_ViewCamCR
global KGL_IgnGroupMode         ----忽略组模式状态指示变量;
global lcl_iso_Lib=#()
macroScript ViewRotate category:"阿酷" tooltip:"视图_旋转视图" buttonText:"旋转视图"
(KF_ViewRotate())
macroScript view_top category:"阿酷" tooltip:"视图_顶视图" buttonText:"顶视图"
(lcl_view_TB())
macroScript view_FBA category:"阿酷" tooltip:"视图_前视图" buttonText:"前视图"
(lcl_view_FBA())
macroScript view_LRA category:"阿酷" tooltip:"视图_左视图" buttonText:"左视图"
(lcl_view_LRA())
macroScript view_LRB category:"阿酷" tooltip:"视图_右视图" buttonText:"右视图"
(lcl_view_LRB())
macroScript view_FBB category:"阿酷" tooltip:"视图_后视图" buttonText:"后视图"
(lcl_view_FBB())
macroScript view_swap category:"阿酷" tooltip:"视图_功能切换" buttonText:"功能切换"
(lcl_swap_view())
macroScript view_cameraF category:"阿酷" tooltip:"视图_前一相机" buttonText:"前一相机"
(lcl_view_camera 1)
macroScript view_cameraA category:"阿酷" tooltip:"视图_后一相机" buttonText:"后一相机"
(lcl_view_camera -1)
macroScript view_Camlist category:"阿酷" tooltip:"视图_相机列表" buttonText:"相机列表"
(lcl_view_Camlist())
macroScript view_ViewCamCR category:"阿酷" tooltip:"视图_视图相机" buttonText:"视图相机"
(lcl_view_ViewCamCR())
macroScript view_CutrQiehuanA category:"阿酷" tooltip:"视图_坐标系A" buttonText:"坐标系A"
(on isChecked do(KGL_CurrentCustview=="AKOOViewCUSTOM1")
 on execute do(lcl_KF_CutrQiehuan KFR_ToolBar1F.KC_CU116 (KGL_CurrentCustview!="AKOOViewCUSTOM1") "AKOOViewCUSTOM1"))
macroScript view_CutrQiehuanB category:"阿酷" tooltip:"视图_坐标系B" buttonText:"坐标系B"
(on isChecked do(KGL_CurrentCustview=="AKOOViewCUSTOM2")
 on execute do(lcl_KF_CutrQiehuan KFR_ToolBar1F.KC_CU117 (KGL_CurrentCustview!="AKOOViewCUSTOM2") "AKOOViewCUSTOM2"))
macroScript view_CutrQiehuanC category:"阿酷" tooltip:"视图_坐标系C" buttonText:"坐标系C"
(on isChecked do(KGL_CurrentCustview=="AKOOViewCUSTOM3")
 on execute do(lcl_KF_CutrQiehuan KFR_ToolBar1F.KC_CU118 (KGL_CurrentCustview!="AKOOViewCUSTOM3") "AKOOViewCUSTOM3"))


global lcl_Select_Mat,lcl_Select_Col,lcl_Select_MatCol,lcl_Select_Mod,lcl_Select_Ins,lcl_Select_wireframe,lcl_Select_wireEqual,lcl_Select_Dep,lcl_Select_ModifiLI,lcl_Select_CLofiLI,lcl_Select_MaterialLI
macroScript Select_Mat category:"阿酷" toolTip:"选择_材质选择" buttonText:"材质选择"
(lcl_Select_Mat())
macroScript Select_Col category:"阿酷" toolTip:"选择_颜色选择" buttonText:"颜色选择"
(lcl_Select_Col())
macroScript Select_MatCol category:"阿酷" toolTip:"选择_MC选择" buttonText:"MC选择"
(lcl_Select_MatCol())
macroScript Select_Mod category:"阿酷" toolTip:"选择_修改选择" buttonText:"修改选择"
(lcl_Select_Mod())
macroScript Select_Ins category:"阿酷" toolTip:"选择_关联选择" buttonText:"关联选择"
(lcl_Select_Ins())
macroScript Select_wireframe category:"阿酷" toolTip:"选择_拓补选择" buttonText:"拓补选择"
(lcl_Select_wireframe())
macroScript Select_wireEqual category:"阿酷" toolTip:"选择_相等选择" buttonText:"相等选择"
(lcl_Select_wireEqual())
macroScript Select_Dep category:"阿酷" toolTip:"选择_影响选择" buttonText:"影响选择"
(lcl_Select_Dep())
macroScript Select_ModifiLI category:"阿酷" toolTip:"选择_修改列表" buttonText:"修改列表"
(lcl_Select_ModifiLI())            
macroScript Select_CLofiLI category:"阿酷" toolTip:"选择_对象列表" buttonText:"对象列表"
(lcl_Select_CLofiLI()) 
macroScript Select_MaterialLI category:"阿酷" toolTip:"选择_材质列表" buttonText:"材质列表"
(lcl_Select_MaterialLI())

global lcl_HFI_IsoMode,lcl_HFI_hideUnSel,lcl_HFI_UnHideSwap,lcl_HFI_Unfreezebypick,lcl_HFI_UnHideAll,lcl_HFI_UnFreezeAll,lcl_HFI_DispelAll,lcl_Frozen_Hide
macroScript HFI_IsoMode category:"阿酷" toolTip:"HFI_隔离模式" buttonText:"隔离模式"
(on isChecked do(if lcl_iso_Lib!=undefined do if lcl_iso_Lib.count>0 do(kkkiso=for kkk in lcl_iso_Lib[1] where IsValidNode kkk collect kkk	
                                           if kkkiso.count>0 do kkkiso[1].isHiddenInVpt==true))
 on execute do(lcl_HFI_IsoMode()))
macroScript HFI_HideSel category:"阿酷" toolTip:"HFI_隐藏选择" buttonText:"隐藏选择"
(lcl_HFI_HideSel())
macroScript HFI_UnHideLast category:"阿酷" toolTip:"HFI_撤消隐藏" buttonText:"撤消隐藏"
(lcl_HFI_UnHideLast())
macroScript HFI_hideUnSel category:"阿酷" toolTip:"HFI_隐藏未选" buttonText:"隐藏未选"
(lcl_HFI_hideUnSel())
macroScript HFI_UnHideSwap  category:"阿酷" toolTip:"HFI_交换隐藏" buttonText:"交换隐藏"
(lcl_HFI_UnHideSwap())
macroScript HFI_Unfreezebypick category:"阿酷" tooltip:"HFI_点击解冻" buttonText:"点击解冻"
(lcl_HFI_Unfreezebypick())
macroScript HFI_UnHideall  category:"阿酷" toolTip:"HFI_显示所有" buttonText:"显示所有"
(lcl_HFI_UnHideAll())
macroScript HFI_Unfreezeall category:"阿酷" toolTip:"HFI_解冻所有" buttonText:"解冻所有"
(lcl_HFI_UnFreezeAll())
macroScript HFI_DispelAll  category:"阿酷" toolTip:"HFI_打开所有" buttonText:"打开所有"
(lcl_HFI_DispelAll())
macroScript HFI_HideFre category:"阿酷" tooltip:"HFI_隐藏冻结"  buttonText:"隐藏冻结" 
(on isChecked do(maxOps.hideFrozenObjects)
 on altExecute type do(lcl_Frozen_Hide true)
 on execute do(lcl_Frozen_Hide false))

global lcl_PRO_GetMat,lcl_PRO_GetCol,lcl_PRO_GetModify,lcl_PRO_NameBymat,lcl_PRO_SelColRandom,lcl_PRO_ColBymat,lcl_PRO_ColByGroup,lcl_PRO_CastWhite,lcl_PRO_CenPivot
macroScript PRO_GetMat category:"阿酷" tooltip:"属性_获取材质" buttonText:"获取材质"
 (lcl_PRO_GetMat())
macroScript PRO_GetCol category:"阿酷" tooltip:"属性_获取颜色" buttonText:"获取颜色"
 (lcl_PRO_GetCol())
macroScript PRO_GetModify category:"阿酷" tooltip:"属性_获取修改" buttonText:"获取修改"
 (lcl_PRO_GetModify())
macroScript PRO_NameBymat category:"阿酷" tooltip:"属性_按材质名" buttonText:"按材质名"
 (lcl_PRO_NameBymat())
macroScript PRO_SelColRandom category:"阿酷" tooltip:"属性_颜色随机" buttonText:"颜色随机"
 (lcl_PRO_SelColRandom())
macroScript PRO_ColBymat category:"阿酷" tooltip:"属性_颜色按材" buttonText:"颜色按材"
 (lcl_PRO_ColBymat())
macroScript PRO_ColByGroup category:"阿酷" tooltip:"属性_颜色按组" buttonText:"颜色按组"
 (lcl_PRO_ColByGroup())
macroScript PRO_CastWhite category:"阿酷" tooltip:"属性_去掉白色" buttonText:"去掉白色"
 (lcl_PRO_CastWhite())
macroScript PRO_ColBlack category:"阿酷" tooltip:"属性_线框全黑" buttonText:"线框全黑"
 (lcl_PRO_ColBlack())
macroScript PRO_CenPivot category:"阿酷" tooltip:"属性_轴点定位" buttonText:"轴点定位"
 (lcl_PRO_CenPivot())
 
global lcl_XY_plan,lcl_KMoveAXY,lcl_KRotateZ,lcl_Tools_RotateALZZ,lcl_Tools_RotateALZX,lcl_Tools_RotateALDW,lcl_Tools_RotateALSF,lcl_Tools_Gravity,lcl_Tools_RanMSR
 macroScript MRS_XY_plan category:"阿酷" tooltip:"MRS_XY平面" buttonText:"XY平面"
(lcl_XY_plan())										  
macroScript MRS_MoveA category:"阿酷" tooltip:"MRS_平面移动" buttonText:"平面移动"
(on execute do lcl_KMoveAXY true
 on altExecute type do lcl_KMoveAXY false)
macroScript MRS_RotateZ category:"阿酷" tooltip:"MRS_Z轴旋转" buttonText:"Z轴旋转"
(on execute do lcl_KRotateZ true
 on altExecute type do lcl_KRotateZ false)
macroScript MRS_ScaleN category:"阿酷" tooltip:"MRS_N缩放" buttonText:"N缩放"
(on execute do lcl_KScaleN true
 on altExecute type do lcl_KScaleN false)
macroScript MRS_Scale category:"阿酷" tooltip:"MRS_缩放" buttonText:"缩放"
(on execute do lcl_KScale true
 on altExecute type do lcl_KScale false)
macroScript MRS_RotateALZZ category:"阿酷" toolTip:"MRS_角度转正" buttonText:"角度转正" 
(lcl_Tools_RotateALZZ())   
macroScript MRS_RotateALZX category:"阿酷" toolTip:"MRS_旋转角度" buttonText:"旋转角度" 
(lcl_Tools_RotateALZX())
macroScript MRS_RotateALDW category:"阿酷" toolTip:"MRS_旋转对齐" buttonText:"旋转对齐" 
(lcl_Tools_RotateALDW())
macroScript MRS_RotateALSFN category:"阿酷" toolTip:"MRS_旋转N缩" buttonText:"旋转N缩" 
(lcl_Tools_RotateALSF 0)
macroScript MRS_RotateALSF category:"阿酷" toolTip:"MRS_旋转缩放" buttonText:"旋转缩放" 
(lcl_Tools_RotateALSF 1)
 macroScript MRS_Gravity category:"阿酷" toolTip:"MRS_落地" buttonText:"落地"
(lcl_Tools_Gravity())
macroScript MRS_RanMSR category:"阿酷" toolTip:"MRS_随机变换" buttonText:"随机变换"
(lcl_Tools_RanMSR())

global lcl_subLevel_T,lcl_subLevel_Exit,lcl_subLevel_Modifier
macroScript subLevel_1 category:"阿酷" toolTip:"堆栈_子层级1" buttonText:"子层级1"
(lcl_subLevel_T 1)
macroScript subLevel_2 category:"阿酷" toolTip:"堆栈_子层级2" buttonText:"子层级2"
(lcl_subLevel_T 2)
macroScript subLevel_3 category:"阿酷" toolTip:"堆栈_子层级3" buttonText:"子层级3"
(lcl_subLevel_T 3)
macroScript subLevel_4 category:"阿酷" toolTip:"堆栈_子层级4" buttonText:"子层级4"
(lcl_subLevel_T 4)
macroScript subLevel_5 category:"阿酷" toolTip:"堆栈_子层级5" buttonText:"子层级5"
(lcl_subLevel_T 5)
macroScript subLevel_Exit category:"阿酷" toolTip:"堆栈_退出" buttonText:"退出"
(lcl_subLevel_Exit())
macroScript ModifierNum_1 category:"阿酷" toolTip:"堆栈_修改器1" buttonText:"修改器1"
(lcl_subLevel_Modifier 1)
macroScript ModifierNum_2 category:"阿酷" toolTip:"堆栈_修改器2" buttonText:"修改器2"
(lcl_subLevel_Modifier 2)
macroScript ModifierNum_3 category:"阿酷" toolTip:"堆栈_修改器3" buttonText:"修改器3"
(lcl_subLevel_Modifier 3)
macroScript ModifierNum_4 category:"阿酷" toolTip:"堆栈_修改器4" buttonText:"修改器4"
(lcl_subLevel_Modifier 4)
macroScript ModifierNum_5 category:"阿酷" toolTip:"堆栈_修改器5" buttonText:"修改器5"
(lcl_subLevel_Modifier 5)

global lcl_Group_g,lcl_Group_Un,lcl_Group_exp,lcl_Group_Ignore
macroScript Group_g category:"阿酷" toolTip:"组_结组" buttonText:"结组"
(lcl_Group_g())
macroScript Group_Un category:"阿酷" toolTip:"组_解组" buttonText:"解组" buttonText:"解组" 
(on isChecked do((for jk in selection where isGroupHead jk  or isGroupMember jk collect jk).count!=0)
 on execute do(lcl_Group_Un()))
macroScript Group_exp category:"阿酷" toolTip:"组_打散组" buttonText:"打散组"
(lcl_Group_exp())
macroScript Group_Ignore category:"阿酷" toolTip:"组_忽略组" buttonText:"忽略组"
(on isChecked do KGL_IgnGroupMode
 on altExecute type do(lcl_Group_Ignore true)
 on execute do(lcl_Group_Ignore false))

global lcl_ME_fillScene,lcl_ME_fillSEL,lcl_ME_fillVIEW,lcl_ME_fillMatLib,lcl_ME_fillNULL,lcl_ME_fillMulMat,lcl_ME_fillHomonMat,lcl_ME_fillBitmap,lcl_ME_fillMiBitmap
macroScript ME_fillScene category:"阿酷" toolTip:"装载_装载场景" buttonText:"装载场景"
(lcl_ME_fillScene())
macroScript ME_fillSEL category:"阿酷" toolTip:"装载_装载选择" buttonText:"装载选择"
(lcl_ME_fillSEL())
macroScript ME_fillVIEW category:"阿酷" toolTip:"装载_装载可视" buttonText:"装载可视"
(lcl_ME_fillVIEW())
macroScript ME_fillMatLib category:"阿酷" toolTip:"装载_装载库" buttonText:"装载库"
(lcl_ME_fillMatLib())
macroScript ME_fillNULL category:"阿酷" toolTip:"装载_清空" buttonText:"清空"
(lcl_ME_fillNULL())
macroScript ME_fillMulMat category:"阿酷" toolTip:"装载_装载多维" buttonText:"装载多维" 
(lcl_ME_fillMulMat())
macroScript ME_fillHomonMat category:"阿酷" toolTip:"装载_装载同名" buttonText:"装载同名"
(lcl_ME_fillHomonMat())
macroScript ME_fillBitmap category:"阿酷" toolTip:"装载_装载位图" buttonText:"装载位图"
(lcl_ME_fillBitmap())
macroScript ME_fillMissBitmap category:"阿酷" toolTip:"装载_丢失位图" buttonText:"丢失位图"
(lcl_ME_fillMiBitmap())
macroScript ME_fillNoneBitmap category:"阿酷" toolTip:"装载_装无位图" buttonText:"装无位图"
(lcl_ME_fillNoneBitmap())


global lcl_collapse_Mesh,lcl_collapse_Union,lcl_collapse_Union_Mul,lcl_Collapse_ByMatSel,lcl_Collapse_ByMatSce,lcl_Explode_ByMat,lcl_Explode_ByElem,lcl_Explode_ByEQElem
macroScript col_MeshSel category:"阿酷" tooltip:"塌陷_选择转换" buttonText:"选择转换"
(lcl_collapse_Mesh false)
macroScript col_MeshSce category:"阿酷" tooltip:"塌陷_场景转换" buttonText:"场景转换"
(lcl_collapse_Mesh true)	
macroScript col_Union category:"阿酷" tooltip:"塌陷_塌陷合并" buttonText:"塌陷合并"
(lcl_collapse_Union())
macroScript col_Union_Mul category:"阿酷" tooltip:"塌陷_塌陷多维" buttonText:"塌陷多维"
(lcl_collapse_Union_Mul())
macroScript Col_ByMatSel category:"阿酷" toolTip:"塌陷_选择按材" buttonText:"选择按材"
(lcl_Collapse_ByMatSel())
macroScript Col_ByMatSce category:"阿酷" toolTip:"塌陷_场景按组" buttonText:"场景按组"
(lcl_Collapse_ByMatSce())
macroScript Exp_ByMat category:"阿酷" toolTip:"塌陷_按材质炸" buttonText:"按材质炸"
(lcl_Explode_ByMat())
macroScript Exp_ByElem category:"阿酷" toolTip:"塌陷_按体炸" buttonText:"按体炸"
(lcl_Explode_ByElem())
macroScript Exp_ByEQElem category:"阿酷" toolTip:"塌陷_按等体炸" buttonText:"按等体炸"
(lcl_Explode_ByEQElem())

global kuge_spline_fnlib,lcl_spline_Weld,lcl_spline_Fuse,lcl_spline_Connect,lcl_spline_division,lcl_spline_AutoDiv,lcl_spline_Detach,lcl_Spline_Normalize,lcl_Spline_Optimize
macroScript spline_Attach category:"阿酷"  toolTip:"图形_添加" buttonText:"添加"
(kuge_spline_fnlib splineOps.startAttach 0 false)
macroScript spline_AttachM category:"阿酷"  toolTip:"图形_添加列表" buttonText:"添加列表"
(kuge_spline_fnlib splineOps.attachMultiple 0 false)
macroScript spline_Refine category:"阿酷"  toolTip:"图形_加点" buttonText:"加点"
(kuge_spline_fnlib splineOps.startRefine 1 false)
macroScript spline_Weld category:"阿酷"  toolTip:"图形_焊接" buttonText:"焊接"
(lcl_spline_Weld())
macroScript spline_Fuse category:"阿酷"  toolTip:"图形_强制焊接" buttonText:"强制焊接"
(lcl_spline_Fuse())
macroScript Spline_Connect category:"阿酷" toolTip:"图形_连接" buttonText:"连接"
(lcl_spline_Connect())
	
macroScript spline_Outline category:"阿酷"  toolTip:"图形_扩边" buttonText:"扩边"
(kuge_spline_fnlib splineOps.startOutline 3 true)
macroScript spline_Trim category:"阿酷"  toolTip:"图形_修剪" buttonText:"修剪"
(kuge_spline_fnlib splineOps.startTrim 3 false)
macroScript spline_Extend category:"阿酷"  toolTip:"图形_延伸" buttonText:"延伸"
(kuge_spline_fnlib splineOps.startExtend 3 false)
	
macroScript Spline_division category:"阿酷" toolTip:"图形_等分面板" buttonText:"等分面板"
(lcl_spline_division())
macroScript spline_AutoDiv category:"阿酷"  toolTip:"图形_自动等分" buttonText:"自动等分"	
(lcl_spline_AutoDiv())
macroScript Spline_detach category:"阿酷" toolTip:"图形_分离" buttonText:"分离"
(lcl_spline_Detach())
macroScript spline_Normalize category:"阿酷"  toolTip:"图形_规格化" buttonText:"规格化"
(lcl_Spline_Normalize())
macroScript Spline_Optimize category:"阿酷"  toolTip:"图形_优化" buttonText:"优化"
(lcl_Spline_Optimize())

global lcl_Material_ByobjUnite,lcl_Material_BymatUnite,lcl_Material_AutoUnite,lcl_Material_LibReplace,lcl_Material_RightKey,KGL_SceneMatLIB,KGL_CurerMatLIB
macroScript Material_ByobjUnite category:"阿酷" toolTip:"材质_选择合并" buttonText:"选择合并"
(lcl_Material_ByobjUnite())
macroScript Material_BymatUnite category:"阿酷" toolTip:"材质_名字合并" buttonText:"名字合并"
(lcl_Material_BymatUnite())
macroScript Material_AutoUnite category:"阿酷" toolTip:"材质_自动合并" buttonText:"自动合并"
(lcl_Material_AutoUnite())
macroScript Material_LibReplace category:"阿酷" toolTip:"材质_模版替换" buttonText:"模版替换"
(on isChecked do((getINISetting (getMAXIniFile()) "akoo2009" "MatLibSwitch")=="1")
 on execute do lcl_Material_LibReplace())
macroScript Material_MLSHouse category:"阿酷" toolTip:"材质_模版库A" buttonText:"模版库A"
(on execute do lcl_Material_Switch 1 false
 on altExecute type do lcl_Material_Switch 1 true)
macroScript Material_MLSPublic category:"阿酷" toolTip:"材质_模版库B" buttonText:"模版库B"
(on execute do lcl_Material_Switch 2 false
 on altExecute type do lcl_Material_Switch 2 true)
macroScript Material_RightKey category:"阿酷" toolTip:"材质_右键材质" buttonText:"右键材质"
(lcl_Material_RightKey())
	

global lcl_Purge_ZeroFace,lcl_Purge_AllGroup,lcl_Purge_NullLayer,lcl_Purge_AllLayer,lcl_Purge_ViewShape,lcl_Purge_AllShape,lcl_Purge_UVWMap,lcl_Purge_LoseTexmap
global lcl_Purge_AllTexmap,lcl_Purge_lights,lcl_Purge_cameras,lcl_Purge_NoneMatObj,lcl_Purge_MulMatObj,lcl_Purge_MissUVObj,lcl_Purge_OverObj,lcl_Purge_MeMory
macroScript Pur_ZeroFace category:"阿酷" toolTip:"清理_空物体" buttonText:"空物体"
(lcl_Purge_ZeroFace())
macroScript Pur_Group category:"阿酷" toolTip:"清理_所有组" buttonText:"所有组"
(lcl_Purge_AllGroup())
macroScript Pur_NullLay category:"阿酷" toolTip:"清理_空图层" buttonText:"空图层"
(lcl_Purge_NullLayer())
macroScript Pur_AllLay category:"阿酷" toolTip:"清理_所有图层" buttonText:"所有图层"
(lcl_Purge_AllLayer())
macroScript Pur_ViewShape category:"阿酷" toolTip:"清理_可视图形" buttonText:"可视图形"
(lcl_Purge_ViewShape())
macroScript Pur_AllShape category:"阿酷" toolTip:"清理_所有图形" buttonText:"所有图形"
(lcl_Purge_AllShape())
macroScript Pur_UVWMap category:"阿酷" toolTip:"清理_贴图坐标" buttonText:"贴图坐标"
(lcl_Purge_UVWMap())
macroScript Pur_LoseTex category:"阿酷" toolTip:"清除_丢失贴图" buttonText:"丢失贴图"
 (lcl_Purge_LoseTexmap())
macroScript Pur_AllTex category:"阿酷" toolTip:"清除_所有贴图" buttonText:"所有贴图"
 (lcl_Purge_AllTexmap())
macroScript Pur_ligh category:"阿酷" toolTip:"清理_删灯光" buttonText:"删灯光"
(lcl_Purge_lights())
macroScript Pur_camer category:"阿酷" toolTip:"清理_删相机" buttonText:"删相机"
(lcl_Purge_cameras())
macroScript Pur_NMatObj category:"阿酷" toolTip:"清理_选无材" buttonText:"选无材"
(lcl_Purge_NoneMatObj())
macroScript Pur_MMatObj category:"阿酷" toolTip:"清理_选多维" buttonText:"选多维"
(lcl_Purge_MulMatObj())
macroScript Pur_MiUVObj category:"阿酷" toolTip:"清理_选无UV" buttonText:"选无UV"
(lcl_Purge_MissUVObj())
macroScript Pur_OverObj category:"阿酷" toolTip:"清理_选重复" buttonText:"选重复"
(lcl_Purge_OverObj())
macroScript Pur_MeMory category:"阿酷" toolTip:"清理_清理内存" buttonText:"清理内存"
(lcl_Purge_MeMory())

global lcl_Modifier_ExtrudeK,lcl_KF_ExtrudeTo,lcl_Modifier_ExtrudeRoll,lcl_Modifier_BevelK,lcl_Modifier_Bevel_ProfileK,lcl_Modifier_FFDK,lcl_Modifier_Bend,lcl_Modifier_ShellK
global lcl_Modifier_MapScaler,lcl_Modifier_uvwmap,lcl_Modifier_EditMesh
macroScript Modif_ExtrudeK category:"阿酷" toolTip:"修改_挤出" buttonText:"挤出"
(on isVisible do validModifier selection (Extrude())
on execute do(lcl_Modifier_ExtrudeK()))
macroScript Modif_ExtrudeTo category:"阿酷" toolTip:"修改_挤出到" buttonText:"挤出到"
(lcl_KF_ExtrudeTo())
macroScript Modif_ExtrudeRoll category:"阿酷" toolTip:"修改_挤出面板" buttonText:"挤出面板"
(lcl_Modifier_ExtrudeRoll())
macroScript Modif_BevelK category:"阿酷" toolTip:"修改_倒角" buttonText:"倒角"
(on isVisible do validModifier selection (Bevel())
on execute do(lcl_Modifier_BevelK()))
macroScript Modif_Bevel_ProfileK category:"阿酷" toolTip:"修改_倒角轮廓" buttonText:"倒角轮廓"
(on isVisible do validModifier selection (Bevel_Profile())
on execute do(lcl_Modifier_Bevel_ProfileK()))
macroScript Modif_FFDK1 category:"阿酷" toolTip:"修改_FFD2X2" buttonText:"FFD2X2"
(on isEnabled do validModifier selection (FFDBox deformType:1)
  on execute do(lcl_Modifier_FFDK (ffdBox deformType:1) true))
macroScript Modif_FFDK2 category:"阿酷" toolTip:"修改_FFDBOX" buttonText:"FFDBOX"
(on isEnabled do validModifier selection (FFDBox deformType:1)
  on execute do(lcl_Modifier_FFDK (ffdBox deformType:1) false))
macroScript Modif_Bend category:"阿酷" toolTip:"修改_弯曲" buttonText:"弯曲"
(lcl_Modifier_Bend())
macroScript Modif_ShellK category:"阿酷" toolTip:"修改_加壳" buttonText:"加壳"
(lcl_Modifier_ShellK())
macroScript Modif_MapScaler category:"阿酷" toolTip:"修改_整体贴图" buttonText:"整体贴图"
(lcl_Modifier_MapScaler())
macroScript Modif_uvwmap category:"阿酷" toolTip:"修改_方位贴图" buttonText:"方位贴图"
(lcl_Modifier_uvwmap())
macroScript UVWmap_Direction category:"阿酷" toolTip:"修改_贴图定向" buttonText:"贴图定向"
(lcl_UVWmap_Direction())
macroScript UVWmap_ZoomB2 category:"阿酷" toolTip:"修改_贴图放大2" buttonText:"贴图放大2"
(lcl_UVWmap_Zoom true 2)
macroScript UVWmap_ZoomB15 category:"阿酷" toolTip:"修改_贴图放大15" buttonText:"贴图放大15"
(lcl_UVWmap_Zoom true 1.5)
macroScript UVWmap_ZoomB11 category:"阿酷" toolTip:"修改_贴图放大11" buttonText:"贴图放大11"
(lcl_UVWmap_Zoom true 1.1)
macroScript UVWmap_ZoomS09 category:"阿酷" toolTip:"修改_贴图缩小09" buttonText:"贴图缩小09"
(lcl_UVWmap_Zoom false 0.9)
macroScript UVWmap_ZoomS075 category:"阿酷" toolTip:"修改_贴图缩小075" buttonText:"贴图缩小075"
(lcl_UVWmap_Zoom false 0.75)
macroScript UVWmap_ZoomS05 category:"阿酷" toolTip:"修改_贴图缩小05" buttonText:"贴图缩小05"
(lcl_UVWmap_Zoom false 0.5)
macroScript Modif_EditMesh category:"阿酷" toolTip:"修改_编辑网格" buttonText:"编辑网格"
(lcl_Modifier_EditMesh())

global lcl_collapse_Reset,lcl_Tools_SliceTools,lcl_Tools_RanSelect,lcl_Tools_SelIndexFace,lcl_Tools_RanSelSub,lcl_Tools_ByDirFace,lcl_Tools_FiArray
global lcl_Instan_Unique,lcl_Instan_Establish,KF_Scene_DelBacke_fna,lcl_Scene_DetchBynum,lcl_Render_RendererClass
macroScript Tools_Reset category:"阿酷" tooltip:"工具_复位" buttonText:"复位"
(lcl_collapse_Reset())
macroScript Tools_SliceTools category:"阿酷" toolTip:"工具_切片工具" buttonText:"切片工具"
(lcl_Tools_SliceTools())  
macroScript Tools_RanSelect category:"阿酷" toolTip:"工具_随机对象" buttonText:"随机对象"
(lcl_Tools_RanSelect())
macroScript Tools_SelIndexFace category:"阿酷" toolTip:"工具_选择同号" buttonText:"选择同号"
(lcl_Tools_SelIndexFace())
macroScript Tools_RanSelSub category:"阿酷" toolTip:"工具_随机元素" buttonText:"随机元素"
(lcl_Tools_RanSelSub())
macroScript Tools_ByDirFace category:"阿酷" toolTip:"工具_扩展选面" buttonText:"扩展选面"
(lcl_Tools_ByDirFace())
macroScript Tools_FiArray category:"阿酷" toolTip:"工具_填充阵列" buttonText:"填充阵列"
(lcl_Tools_FiArray())
macroScript Tools_InsUnique category:"阿酷" toolTip:"工具_断开关联" buttonText:"断开关联"
(lcl_Instan_Unique())
macroScript Tools_InsEstablish category:"阿酷" toolTip:"工具_建立关联" buttonText:"建立关联"
(lcl_Instan_Establish())
macroScript Tools_DelBacke category:"阿酷" toolTip:"工具_删除背面" buttonText:"删除背面"
(KF_Scene_DelBacke_fna())
macroScript Tools_DetchBynum category:"阿酷" toolTip:"工具_按面数拆" buttonText:"按面数拆"
(lcl_Scene_DetchBynum())
macroScript Tools_RendererClass category:"阿酷" toolTip:"工具_切换渲染" buttonText:"切换渲染"
(lcl_Render_RendererClass())
global lcl_Spline_AuotConn,lcl_Instan_Advanced,lcl_Advan_DelCamback
macroScript Tools_SplAuConn category:"阿酷"  toolTip:"工具_图形自连" buttonText:"图形自连"	
(lcl_Spline_AuotConn())
macroScript Tools_AdvanInstan category:"阿酷" toolTip:"工具_高级关联" buttonText:"高级关联"
(lcl_Instan_Advanced())


macroScript Miscell_ImmedShudown category:"阿酷" toolTip:"其它_计时关机" buttonText:"计时关机"
(lcl_ImmedShudown())
macroScript Miscell_SelByNameRo category:"阿酷" toolTip:"其它_旧版面板" buttonText:"旧版面板"
(lcl_SelByNameRo())
macroScript Miscell_SaveAbnormal category:"阿酷" toolTip:"其它_保存异常" buttonText:"保存异常"
(lcl_SaveAbnormal())
macroScript Miscell_ResetSetup category:"阿酷" toolTip:"其它_设置复位" buttonText:"设置复位"
(lcl_Miscell_ResetSetup())
macroScript Miscell_Win_Cross category:"阿酷" toolTip:"其它_框选方向" buttonText:"框选方向"
(lcl_Win_Cross())
macroScript Miscell_MulSamAuto category:"阿酷" toolTip:"其它_素材小样" buttonText:"素材小样"
(lcl_Miscell_MulSamAuto())
macroScript Miscell_RepFileClear category:"阿酷" toolTip:"其它_重复文件" buttonText:"重复文件"
(lcl_Miscell_RepFileClear())
macroScript Miscell30_FileManage category:"阿酷" toolTip:"其它_文件管理" buttonText:"文件管理"
(lcl_Miscell30_FileManage())
	
	
macroScript Modifier30_RetoreExtrude category:"阿酷" toolTip:"高级_再造挤出" buttonText:"再造挤出"
(lcl_Modifier30_RetoreExtrude())
macroScript Advan_SceneBitMan3 category:"阿酷" toolTip:"高级_资源收集" buttonText:"资源收集"
(if lcl_Advan_SceneBitMan3!=undefined do lcl_Advan_SceneBitMan3())
macroScript Advan_SuperPlantTools category:"阿酷" toolTip:"高级_超级种植" buttonText:"超级种植"
(lcl_Advan_SuperPlantTools())
macroScript Advan_ModeBank3 category:"阿酷" toolTip:"高级_素材管理" buttonText:"素材管理"
(if lcl_Advan_ModeBank3!=undefined do lcl_Advan_ModeBank3())
	
macroScript Advan_DelCamback category:"阿酷" toolTip:"高级_视角减面" buttonText:"视角减面"
(lcl_Advan_DelCamback())
global lcl_Module_dashed,lcl_Render_SceneBitMan,lcl_Render_Msample,lcl_render_flow,lcl_Advan_PlantTools
macroScript Advan_dashed category:"阿酷" toolTip:"高级_车线生成" buttonText:"车线生成"
(if lcl_Module_dashed!=undefined do lcl_Module_dashed())
macroScript Advan_FitTerrain category:"阿酷" toolTip:"高级_地形拟合" buttonText:"地形拟合"
(if lcl_Advan_FitTerrain!=undefined do lcl_Advan_FitTerrain())
macroScript Advan_Msample category:"阿酷" toolTip:"高级_批量小样" buttonText:"批量小样"
(if lcl_Render_Msample!=undefined do lcl_Render_Msample()) 
macroScript Advan_Renderflow category:"阿酷" toolTip:"高级_渲染流程" buttonText:"渲染流程"
(if lcl_render_flow!=undefined do lcl_render_flow())


macroScript Advan_SuperPlant_BrushAC1 category:"阿酷" toolTip:"高级_超级种植_笔刷乘1" buttonText:"笔刷乘1"
(if lcl_Advan_SuperPlant_BrushAC1!=undefined do lcl_Advan_SuperPlant_BrushAC1())
macroScript Advan_SuperPlant_Brushlower1 category:"阿酷" toolTip:"高级_超级种植_笔刷除1" buttonText:"笔刷除1"
(if lcl_Advan_SuperPlant_Brushlower1!=undefined do lcl_Advan_SuperPlant_Brushlower1())
macroScript Advan_SuperPlant_BrushAC2 category:"阿酷" toolTip:"高级_超级种植_笔刷乘2" buttonText:"笔刷乘2"
(if lcl_Advan_SuperPlant_BrushAC2!=undefined do lcl_Advan_SuperPlant_BrushAC2())
macroScript Advan_SuperPlant_Brushlower2 category:"阿酷" toolTip:"高级_超级种植_笔刷除2" buttonText:"笔刷除2"
(if lcl_Advan_SuperPlant_Brushlower2!=undefined do lcl_Advan_SuperPlant_Brushlower2())
	
global KKFF_JMQDHF
macroScript AK_AkooRollON category:"阿酷" toolTip:"__AK面板开关" buttonText:"AK"
(KKFF_JMQDHF())

global lcl_Advan_ModeBank_Model,lcl_Advan_ModeBank_Mater,lcl_Advan_ModeBank_Textmap,lcl_Advan_ModeBank_PagePre,lcl_Advan_ModeBank_PageNex
macroScript Advan_ModeBank_Model category:"阿酷" toolTip:"高级_素材管理_模型库" buttonText:"模型库"
(if lcl_Advan_ModeBank_Model!=undefined do lcl_Advan_ModeBank_Model())
macroScript Advan_ModeBank_Mater category:"阿酷" toolTip:"高级_素材管理_材质库" buttonText:"材质库"
(if lcl_Advan_ModeBank_Mater!=undefined do lcl_Advan_ModeBank_Mater())
macroScript Advan_ModeBank_Textmap category:"阿酷" toolTip:"高级_素材管理_贴图库" buttonText:"贴图库"
(if lcl_Advan_ModeBank_Textmap!=undefined do lcl_Advan_ModeBank_Textmap())
macroScript Advan_ModeBank_PagePre category:"阿酷" toolTip:"高级_素材管理_上一屏" buttonText:"上一屏"
(if lcl_Advan_ModeBank_PagePre!=undefined do lcl_Advan_ModeBank_PagePre())
macroScript Advan_ModeBank_PageNex category:"阿酷" toolTip:"高级_素材管理_下一屏" buttonText:"下一屏"
(if lcl_Advan_ModeBank_PageNex!=undefined do lcl_Advan_ModeBank_PageNex())

global ViewgeoFilt,lcl_Rmmat,lcl_RmRmat,KGM_RIMatArray
	
	
macroScript AKRmmat1 category:"阿酷右键材质" toolTip:"AKRM_Mater1" buttonText:"Mater1"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[1]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[1]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[1])
macroScript AKRmmat2 category:"阿酷右键材质" toolTip:"AKRM_Mater2" buttonText:"Mater2"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[2]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[2]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[2])
macroScript AKRmmat3 category:"阿酷右键材质" toolTip:"AKRM_Mater3" buttonText:"Mater3"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[3]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[3]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[3])
macroScript AKRmmat4 category:"阿酷右键材质" toolTip:"AKRM_Mater4" buttonText:"Mater4"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[4]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[4]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[4])
macroScript AKRmmat5 category:"阿酷右键材质" toolTip:"AKRM_Mater5" buttonText:"Mater5"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[5]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[5]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[5])
macroScript AKRmmat6 category:"阿酷右键材质" toolTip:"AKRM_Mater6" buttonText:"Mater6"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[6]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[6]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[6])
macroScript AKRmmat7 category:"阿酷右键材质" toolTip:"AKRM_Mater7" buttonText:"Mater7"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[7]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[7]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[7])
macroScript AKRmmat8 category:"阿酷右键材质" toolTip:"AKRM_Mater8" buttonText:"Mater8"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[8]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[8]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[8])
macroScript AKRmmat9 category:"阿酷右键材质" toolTip:"AKRM_Mater9" buttonText:"Mater9"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[9]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[9]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[9])
macroScript AKRmmat10 category:"阿酷右键材质" toolTip:"AKRM_Mater10" buttonText:"Mater10"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[10]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[10]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[10])
macroScript AKRmmat11 category:"阿酷右键材质" toolTip:"AKRM_Mater11" buttonText:"Mater11"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[11]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[11]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[11])
macroScript AKRmmat12 category:"阿酷右键材质" toolTip:"AKRM_Mater12" buttonText:"Mater12"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[12]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[12]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[12])
macroScript AKRmmat13 category:"阿酷右键材质" toolTip:"AKRM_Mater13" buttonText:"Mater13"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[13]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[13]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[13])
macroScript AKRmmat14 category:"阿酷右键材质" toolTip:"AKRM_Mater14" buttonText:"Mater14"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[14]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[14]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[14])
macroScript AKRmmat15 category:"阿酷右键材质" toolTip:"AKRM_Mater15" buttonText:"Mater15"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[15]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[15]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[15])
macroScript AKRmmat16 category:"阿酷右键材质" toolTip:"AKRM_Mater16" buttonText:"Mater16"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[16]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[16]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[16])
macroScript AKRmmat17 category:"阿酷右键材质" toolTip:"AKRM_Mater17" buttonText:"Mater17"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[17]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[17]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[17])
macroScript AKRmmat18 category:"阿酷右键材质" toolTip:"AKRM_Mater18" buttonText:"Mater18"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[18]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[18]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[18])
macroScript AKRmmat19 category:"阿酷右键材质" toolTip:"AKRM_Mater19" buttonText:"Mater19"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[19]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[19]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[19])
macroScript AKRmmat20 category:"阿酷右键材质" toolTip:"AKRM_Mater20" buttonText:"Mater20"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[20]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[20]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[20])
macroScript AKRmmat21 category:"阿酷右键材质" toolTip:"AKRM_Mater21" buttonText:"Mater21"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[21]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[21]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[21])
macroScript AKRmmat22 category:"阿酷右键材质" toolTip:"AKRM_Mater22" buttonText:"Mater22"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[22]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[22]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[22])
macroScript AKRmmat23 category:"阿酷右键材质" toolTip:"AKRM_Mater23" buttonText:"Mater23"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[23]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[23]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[23])
macroScript AKRmmat24 category:"阿酷右键材质" toolTip:"AKRM_Mater24" buttonText:"Mater24"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[24]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[24]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[24])

macroScript AKRmmat25 category:"阿酷右键材质" toolTip:"AKRM_Mater25" buttonText:"Mater25"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[25]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[25]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[25])
macroScript AKRmmat26 category:"阿酷右键材质" toolTip:"AKRM_Mater26" buttonText:"Mater26"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[26]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[26]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[26])
macroScript AKRmmat27 category:"阿酷右键材质" toolTip:"AKRM_Mater27" buttonText:"Mater27"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[27]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[27]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[27])
macroScript AKRmmat28 category:"阿酷右键材质" toolTip:"AKRM_Mater28" buttonText:"Mater28"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[28]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[28]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[28])
macroScript AKRmmat29 category:"阿酷右键材质" toolTip:"AKRM_Mater29" buttonText:"Mater29"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[29]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[29]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[29])
macroScript AKRmmat30 category:"阿酷右键材质" toolTip:"AKRM_Mater30" buttonText:"Mater30"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[30]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[30]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[30])
macroScript AKRmmat31 category:"阿酷右键材质" toolTip:"AKRM_Mater31" buttonText:"Mater31"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[31]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[31]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[31])
macroScript AKRmmat32 category:"阿酷右键材质" toolTip:"AKRM_Mater32" buttonText:"Mater32"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[32]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[32]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[32])
macroScript AKRmmat33 category:"阿酷右键材质" toolTip:"AKRM_Mater33" buttonText:"Mater33"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[33]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[33]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[33])
macroScript AKRmmat34 category:"阿酷右键材质" toolTip:"AKRM_Mater34" buttonText:"Mater34"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[34]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[34]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[34])
macroScript AKRmmat35 category:"阿酷右键材质" toolTip:"AKRM_Mater35" buttonText:"Mater35"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[35]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[35]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[35])
macroScript AKRmmat36 category:"阿酷右键材质" toolTip:"AKRM_Mater36" buttonText:"Mater36"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[36]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[36]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[36])
macroScript AKRmmat37 category:"阿酷右键材质" toolTip:"AKRM_Mater37" buttonText:"Mater37"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[37]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[37]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[37])
macroScript AKRmmat38 category:"阿酷右键材质" toolTip:"AKRM_Mater38" buttonText:"Mater38"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[38]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[38]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[38])
macroScript AKRmmat39 category:"阿酷右键材质" toolTip:"AKRM_Mater39" buttonText:"Mater39"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[39]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[39]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[39])
macroScript AKRmmat40 category:"阿酷右键材质" toolTip:"AKRM_Mater40" buttonText:"Mater40"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[40]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[40]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[40])
macroScript AKRmmat41 category:"阿酷右键材质" toolTip:"AKRM_Mater41" buttonText:"Mater41"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[41]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[41]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[41])
macroScript AKRmmat42 category:"阿酷右键材质" toolTip:"AKRM_Mater42" buttonText:"Mater42"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[42]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[42]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[42])
macroScript AKRmmat43 category:"阿酷右键材质" toolTip:"AKRM_Mater43" buttonText:"Mater43"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[43]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[43]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[43])
macroScript AKRmmat44 category:"阿酷右键材质" toolTip:"AKRM_Mater44" buttonText:"Mater44"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[44]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[44]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[44])
macroScript AKRmmat45 category:"阿酷右键材质" toolTip:"AKRM_Mater45" buttonText:"Mater45"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[45]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[45]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[45])
macroScript AKRmmat46 category:"阿酷右键材质" toolTip:"AKRM_Mater46" buttonText:"Mater46"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[46]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[46]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[46])
macroScript AKRmmat47 category:"阿酷右键材质" toolTip:"AKRM_Mater47" buttonText:"Mater47"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[47]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[47]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[47])
macroScript AKRmmat48 category:"阿酷右键材质" toolTip:"AKRM_Mater48" buttonText:"Mater48"
(on isChecked do(findItem(for m in selection where ViewgeoFilt m collect m.material)KGM_RIMatArray[48]!=0 and KGM_RIMatArray[1]!=undefined)
 on execute do lcl_Rmmat KGM_RIMatArray[48]
 on altExecute type do lcl_RmRmat KGM_RIMatArray[48])

