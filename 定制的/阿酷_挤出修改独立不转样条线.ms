
AK_INIT_File = ((GetDir #Scripts) + "\\Cool_Tools\\help\\AK_INIT_MAX+.ini")


if (getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmlast") == "" do setINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmlast" "50"
if (getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmout2") == "" do setINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmout2" "200"
if (getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmout3") == "" do setINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmout3" "240"

fn KF_SceneUnitsJC = 
(
	case units.SystemType of
	(
		#inches:(global Syun = 0.03937) ---英寸
		#feet:(global Syun = 0.003280) ---英尺
		#miles:(global Syun = 1000.0) ---微米
		#millimeters:(global Syun = 1.0) ---毫米
		#centimeters:(global Syun = 0.1) ---厘米
		#meters:(global Syun = 0.001) ---米
		#kilometers:(global Syun = 0.000001) ---千米
		default:(global Syun = 1.0) ---毫米
	)
)
-- KF_SceneUnitsJC()

-- global kugeEXinit4X = true
global lcl_kugeCH_Ex 
global kuge_Ex_YS
global kuge_ex_nf
global KL_Oldnum = #()
fn kuge_ex_nf o = ((for kk in o.modifiers where kk.classid[1] == 160 or kk.classid[1] == 4119 collect kk).count > 0)
fn kuge_Ex_YS AB = 
(
	KF_SceneUnitsJC()
	local cc = ((getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmlast")as Float) * Syun
	if selection.count > 0 do
	(
		global kugeEXar = #()
		global kugeEXar_obj = #()
		if selection.count == 1 and superClassOf selection[1] == shape and InstanceMgr.GetInstances selection[1]() < 2 do
-- 		(if canConvertTo selection[1] SplineShape do convertToSplineShape selection[1])
		for yo in selection where SuperClassOf yo == shape do CenterPivot yo
		if validModifier selection (Extrude ()) do
		(
			if getCommandPanelTaskMode() != #modify do setCommandPanelTaskMode mode:#modify
			if AB then kugeExcur11 = (Extrude())
			else kugeExcur11 = (bevel())
			modPanel.addModToSelection kugeExcur11
			if AB then kugeExcur11.amount = cc
			else if hasProperty kugeExcur11 "级别_1_高度" then kugeExcur11.级别_1_高度 = cc
			else kugeExcur11.Level_1_Height = cc
		)
		for i in selection do for uu in i.modifiers where uu.classid[1] == 160 and findItem kugeEXar uu == 0 do
		(
			append kugeEXar uu
			if kugeEXar_obj.count < 1 do append kugeEXar_obj i
			global kugeEXinit4X = true
		)
		if kugeEXar.count == 0 do
		(
			for i in selection do for uu in i.modifiers where uu.classid[1] == 4119 and findItem kugeEXar uu == 0 do
			(
				append kugeEXar uu
				if kugeEXar_obj.count < 1 do append kugeEXar_obj i
				global kugeEXinit4X = false
			)
		)
	)
)
fn lcl_KF_ExtrudeTo = 
(
	if selection.count > 0 do 
	(
		kuge_Ex_YS kugeEXinit4X
		if kugeEXar.count > 0 do
		(
			if not snapMode.active do snapMode.active = true
			kugesnapt = snapMode.type
			snapMode.type = #3D
			if (classof (kugeExClipo = pickPoint snap:#3D)) == Point3 
			do
			(
				snapMode.type = kugesnapt
				undo off(kugeExTOb = editable_mesh pos:kugeExClipo
				in coordsys kugeEXar_obj[1] kugeex_end = kugeExTOb.pos[3]
				delete kugeExTOb
			)
			if kugeex_end > 1 or kugeex_end < -1 do
			(
				for uu in kugeEXar do
				(
					if kugeEXinit4X then uu.amount = kugeex_end
					else if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = kugeex_end
					else uu.Level_1_Height = kugeex_end
				)
				if findItem KL_Oldnum (kugeex_end as string) == 0 do
				(
					KL_Oldnum = join #(kugeex_end as string) KL_Oldnum
					if KL_Oldnum.count > 9 do deleteItem KL_Oldnum KL_Oldnum.count
				)
			)
		)
		snapMode.type = kugesnapt
	)
)
)


fn lcl_Modifier_ExtrudeRoll_ = 
(
	KF_SceneUnitsJC()
	global kugeEXilast = ((getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmlast")as Float) * Syun 
	global kugeEXinit2 = ((getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmout2")as Float) * Syun
	global kugeEXinit3 = ((getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmout3")as Float) * Syun
	global kugeEXinit4X = true -- (getINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeMODESta" ) == "1"
	local kugeExnuZ2,kugeChannelnum1,kuge_Ex_m3
	undo on
	(
		if selection.count > 0 do
		(
			kuge_Ex_YS kugeEXinit4X
			if kugeEXar.count > 0 do
			(
				rollout lcl_kugeCH_Ex ""
				(
					edittext kugeExnuZ2 fieldWidth:67 pos:[5,5]
					listbox kugeChannelnum2 items:KL_Oldnum height:9 width:46 selection:0 pos:[86,4]
					listbox kugeChannelnum1 items:#((kugeEXilast as string),(kugeEXinit2 as string),(kugeEXinit3 as string),"挤出到_","获取量_","点取距离_") height:6 width:68 selection:0 pos:[9,28]
					button KC_BT1 "" pos:[5,115] width:70 enabled:(selection.count == 1)
					checkbox kuge_Ex_m3 "" triState:2 align:#left pos:[5,140]
					on kugeExnuZ2 changed hhh do(if (hhh[hhh.count] == " " or (hhh as Float) == undefined)and hhh != "-" do DestroyDialog lcl_kugeCH_Ex)
					on kugeExnuZ2 entered hhh do
					(
						if hhh != "" do
						(
							undo on(if hhh as Float != undefined and((hhh as Float) > 0 or (hhh as Float) < 0)
							then
							(
								KF_SceneUnitsJC()
								setINISetting (AK_INIT_File) "akoo2009" "KUGEExtrudeAmlast" (((hhh as Float) / Syun)as string)
								kuge_Ex_YS kugeEXinit4X
								KL_Exnn1 = hhh as Float
								for uu in kugeEXar do
								(
									if kugeEXinit4X then uu.amount = KL_Exnn1
									else if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = KL_Exnn1
									else uu.Level_1_Height = KL_Exnn1
								)
								if findItem KL_Oldnum hhh == 0 do
								(
									KL_Oldnum = join #(hhh) KL_Oldnum
									if KL_Oldnum.count > 9 do deleteItem KL_Oldnum KL_Oldnum.count
								)
								DestroyDialog lcl_kugeCH_Ex
							)
							else
							(
								kugeExnuZ2.text = ""
								DestroyDialog lcl_kugeCH_Ex
							)
						)
					)
				)
				on kugeChannelnum1 selected ppp do
				(
					undo on(DestroyDialog lcl_kugeCH_Ex
					case ppp of
					(
						1:(for uu in kugeEXar do
						(
							if kugeEXinit4X then uu.amount = kugeEXilast
							else if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = kugeEXilast
							else uu.Level_1_Height = kugeEXilast
						)
						if findItem KL_Oldnum (kugeEXilast as string) == 0 do
						(
							KL_Oldnum = join #(kugeEXilast as string) KL_Oldnum
							if KL_Oldnum.count > 9 do deleteItem KL_Oldnum KL_Oldnum.count
						)
					)
					2:(for uu in kugeEXar do
					(
						if kugeEXinit4X then uu.amount = kugeEXinit2
						else if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = kugeEXinit2
						else uu.Level_1_Height = kugeEXinit2
					)
				)
				3:(for uu in kugeEXar do
				(
					if kugeEXinit4X then uu.amount = kugeEXinit3
					else if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = kugeEXinit3
					else uu.Level_1_Height = kugeEXinit3
				)
			)
			4:(lcl_KF_ExtrudeTo())
			5:(lclEXMatkk = pickObject message:"点击挤出量获取对象:" filter:kuge_ex_nf
			if classof lclEXMatkk == Editable_mesh then
			(
				KL_Pikeobj = #()
				for uu in lclEXMatkk.modifiers where uu.classid[1] == 160 or uu.classid[1] == 4119 do append KL_Pikeobj uu
				lclEXMatpik = KL_Pikeobj[1]
			)
			else lclEXMatpik = kugeEXar[1]
			case of
			(
				(hasProperty lclEXMatpik "amount"):(KL_ETbg1 = lclEXMatpik.amount)
				(hasProperty lclEXMatpik "级别_1_高度"):(KL_ETbg1 = lclEXMatpik.级别_1_高度)
				(hasProperty lclEXMatpik "Level_1_Height"):(KL_ETbg1 = lclEXMatpik.Level_1_Height)
			)
			if kugeEXinit4X then for uu in kugeEXar do uu.amount = KL_ETbg1
			else for uu in kugeEXar do if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = KL_ETbg1
			else uu.Level_1_Height = KL_ETbg1
			if findItem KL_Oldnum (KL_ETbg1 as string) == 0 and (KL_ETbg1 as string) != "undefined" do
			(
				KL_Oldnum = join #(KL_ETbg1 as string) KL_Oldnum
				if KL_Oldnum.count > 9 do deleteItem KL_Oldnum KL_Oldnum.count
			)
		)
		6:(if not snapMode.active do snapMode.active = true
		kugesnapt = snapMode.type
		snapMode.type = #3D
		if (classof (kugeExCl1 = pickPoint snap:#3D)) == Point3 do
		(
			if (classof (kugeExCl2 = pickPoint snap:#3D rubberBand:kugeExCl1)) == Point3 
			then
			(
				snapMode.type = kugesnapt
				KL_Dist = distance kugeExCl1 kugeExCl2
				for uu in kugeEXar do
				(
					if kugeEXinit4X then uu.amount = KL_Dist
					else if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = KL_Dist
					else uu.Level_1_Height = KL_Dist
				)
				if findItem KL_Oldnum (KL_Dist as string) == 0 and (KL_Dist as string) != "undefined" do
				(
					KL_Oldnum = join #(KL_Dist as string) KL_Oldnum
					if KL_Oldnum.count > 9 do deleteItem KL_Oldnum KL_Oldnum.count
				)
			)
			else snapMode.type = kugesnapt
		)
	)
)
)
)
on kugeChannelnum2 selected ppp do
(
	undo on(DestroyDialog lcl_kugeCH_Ex
	KL_A = KL_Oldnum[ppp] as Float
	for uu in kugeEXar do
	(
		if kugeEXinit4X then uu.amount = KL_A
		else if hasProperty uu "级别_1_高度" then uu.级别_1_高度 = KL_A
		else uu.Level_1_Height = KL_A
	)
)
)
on kuge_Ex_m3 changed bu3 do
(
	for uu in kugeEXar do
	(
		if kugeEXinit4X then uu.capStart = bu3
		else
		(
			if bu3 then bu33 = 1
			else bu33 = 0
			if hasProperty uu "级别_1_高度" then
			(
				uu.封闭底部 = bu33
				uu.封闭顶部 = bu33
			)
			else
			(
				uu.Cap_Bottom = bu33
				uu.Cap_Top = bu33
			)
		)
	)
)
on KC_BT1 pressed do
(
	if selection.count == 1 do
	(
		if kugeEXinit4X then kugeEx11 = (bevel())
		else kugeEx11 = (Extrude())
		if kugeEXinit4X then
		(
			for i in selection do for uu in i.modifiers where uu.classid[1] == 160 do
			(
				if uu.name == "挤出" then
				(
					KL_FF1 = modPanel.getModifierIndex i uu
					KL_FF2 = uu.amount
					deleteModifier i KL_FF1
					if i.modifiers.count > KL_FF1 then modPanel.setCurrentObject i.modifiers[(KL_FF1 + 1)] node:i ui:true
					else modPanel.setCurrentObject i.baseObject node:i ui:true
					modPanel.addModToSelection kugeEx11
					kugeEx11.级别_1_高度 = KL_FF2
				)
				else
				(
					KL_FF1 = modPanel.getModifierIndex i uu
					KL_FF2 = uu.amount
					deleteModifier i KL_FF1
					if i.modifiers.count > KL_FF1 then modPanel.setCurrentObject i.modifiers[(KL_FF1 + 1)] node:i ui:true
					else modPanel.setCurrentObject i.baseObject node:i ui:true
					modPanel.addModToSelection kugeEx11
					kugeEx11.Level_1_Height = KL_FF2
				)
			)
		)
		else
		(
			for i in selection do for uu in i.modifiers where uu.classid[1] == 4119 do
			(
				if uu.name == "倒角" then
				(
					KL_FF1 = modPanel.getModifierIndex i uu
					KL_FF2 = uu.级别_1_高度
					deleteModifier i KL_FF1
					if i.modifiers.count > KL_FF1 then modPanel.setCurrentObject i.modifiers[(KL_FF1 + 1)] node:i ui:true
					else modPanel.setCurrentObject i.baseObject node:i ui:true
					modPanel.addModToSelection kugeEx11 
					kugeEx11.amount = KL_FF2
				)
				else
				(
					KL_FF1 = modPanel.getModifierIndex i uu
					KL_FF2 = uu.Level_1_Height
					deleteModifier i KL_FF1
					if i.modifiers.count > KL_FF1 then modPanel.setCurrentObject i.modifiers[(KL_FF1 + 1)] node:i ui:true
					else modPanel.setCurrentObject i.baseObject node:i ui:true
					modPanel.addModToSelection kugeEx11
					kugeEx11.amount = KL_FF2
				)
			)
		)
		kuge_Ex_YS kugeEXinit4X
		KL_OOO = GetDialogPos lcl_kugeCH_Ex
		try(DestroyDialog lcl_kugeCH_Ex)catch()
		CreateDialog lcl_kugeCH_Ex pos:[KL_OOO[1],KL_OOO[2]] width:140 height:158
		setFocus lcl_kugeCH_Ex.kugeExnuZ2 
	)
)
on lcl_kugeCH_Ex rbuttondown vvdd do(DestroyDialog lcl_kugeCH_Ex)
on lcl_kugeCH_Ex open do
(
	kuge_Ex_YS kugeEXinit4X
	if kugeEXinit4X then
	(
		lcl_kugeCH_Ex.title = "阿酷_挤出[倒角]"
		KC_BT1.text = "挤出→倒角"
		kuge_Ex_m3.text = "挤出底盖"
	)
	else
	(
		lcl_kugeCH_Ex.title = "阿酷_倒角[挤出]"
		KC_BT1.text = "倒角→挤出"
		kuge_Ex_m3.text = "倒角封口"
	)
)
)
CreateDialog lcl_kugeCH_Ex pos:[(mouse.screenpos[1] - 140),mouse.screenpos[2]] width:140 height:158
setFocus lcl_kugeCH_Ex.kugeExnuZ2
)
)
)
)


macroScript C_Sub_2 category:"AA_Com" toolTip:"阿酷_挤出_a" ButtonText:"阿酷_挤出_a"
    (on isEnabled return selection.count >0;on execute do(lcl_Modifier_ExtrudeRoll_()))