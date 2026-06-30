fn SceneRedraws = (enableSceneRedraw();completeRedraw())

fn C_Sub_A_B ai =
(
	if getCommandPanelTaskMode() != #modify do setCommandPanelTaskMode mode:#modify
	
	local sel = for i in selection collect i
	if sel.count == 1 do
	(
		local mods = #(NURBSSurf,Editable_Patch,SplineShape,line,Editable_Poly,Editable_mesh,Edit_Mesh,Edit_Spline,Edit_Poly,Edit_Patch,FFD_2x2x2,FFD_3x3x3,FFD_4x4x4,FFDBox,FFDCyl,Lathe,SliceModifier,Bend,Twist,Bevel_Profile,Displace,Normalmodifier,HSDS,Mirror)
		local istrue = false
		
		local aa = undefined
		try(aa = modPanel.getCurrentObject())catch()
		
		if aa != undefined and finditem mods (classof aa) != 0 then
		(
			istrue = true
			try(subObjectLevel = ai)catch()
		)
		else
		(
			for i = 1 to sel[1].modifiers.count do
			(
				if finditem mods (classof sel[1].modifiers[i]) != 0 then
				(
					istrue = true
					try (
						modPanel.setCurrentObject sel[1].modifiers[i] node:sel[1]
						subObjectLevel = ai
					) catch()
					exit
				)
			)
		)
		
		if not istrue then
		(
			try(
				modPanel.setCurrentObject sel[1].baseObject node:sel[1]
				
				if numSubObjectLevels == 0 or classof sel[1].baseObject == Rectangle then
				(
					local oldBase = sel[1].baseObject
					local newBase = undefined
					local needConvert = false
					
					if classof oldBase == Rectangle then 
					(
						local tempNode = splineShape isHidden:true
						tempNode.baseObject = copy oldBase
						convertToSplineShape tempNode
						for s = 1 to (numsplines tempNode) do
							for v = 1 to (numknots tempNode s) do setKnotType tempNode s v #corner
						updateShape tempNode
						newBase = tempNode.baseObject
						delete tempNode
						needConvert = true
					)else
					if superclassof oldBase == shape then 
					(
						local tempNode = splineShape isHidden:true
						tempNode.baseObject = copy oldBase
						convertToSplineShape tempNode
						newBase = tempNode.baseObject
						delete tempNode
						needConvert = true
					)else
					if superclassof oldBase == GeometryClass and classof oldBase != Targetobject then
					(
						local tempNode = box isHidden:true
						tempNode.baseObject = copy oldBase
						converttomesh tempNode
						newBase = tempNode.baseObject
						delete tempNode
						needConvert = true
					)
					
					if needConvert do
					(
						local instNodes = #()
						InstanceMgr.GetInstances sel[1] &instNodes
						for n in instNodes do n.baseObject = newBase
					)
				)
				
				modPanel.setCurrentObject sel[1].baseObject node:sel[1]
				subObjectLevel = ai
			)catch()
		)
	)
	
	if sel.count > 1 do
	(
		try(subObjectLevel = ai)catch()
	)
	SceneRedraws()
)

macroScript C_Sub_1 category:"AA_Com" toolTip:"可编辑层级1" ButtonText:"可编辑层级1"
(on isEnabled return selection.count > 0; on execute do (C_Sub_A_B 1))
