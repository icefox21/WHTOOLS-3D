fn w_to_c sys pos=
( 
	ve=(pos-sys.translationpart)
	vec=normalize ve	
	x=(length ve)*(dot vec sys[1])
	y=(length ve)*(dot vec sys[2])
	z=(length ve)*(dot vec sys[3])	
	return [x,y,z]
)
rollout wh_Batch_object_cutting "批量物体切割" width:176 height:38
(
	local bnpy=6
	local bndi=24 
	local wh_url_text="了解更多作品请进"
	button btn_Two_cutting "两点切割" pos:[6,bnpy] width:80 height:22 toolTip:"两点定切线把物体切开两部分"
	button btn_Three_cutting "三点切除" pos:[90,bnpy] width:80 height:22 toolTip:"两点定切线，第三点确定切除的那部分"
		
	on btn_Two_cutting pressed  do undo on
-- 	try
	(
		
		max create mode
		arr_set=#()
		arr_obj=#()
		arr_new=#()
		arr_set=selection as array
		convertToPoly arr_set
		for s in arr_set do 
		(
			if (classof s) == Editable_Poly do append arr_obj s
		)
		print "请取第一点"  --取点
		pt1=pickPoint snap:#3D 
		print "请取第二点"
		pt2=pickPoint snap:#3D 
		pm=getViewTM()
		yy=pm[3]
		xx=pt2-pt1--设定坐标系统
		zz=cross xx yy
		yy=cross zz xx
		xx=normalize xx
		yy=normalize yy
		zz=normalize zz
		sys=(matrix3 xx yy zz pt1)
		if arr_obj.count > 0 then
		(
			for o in arr_obj do
			(
				oc=convertToPoly(box()) 
				polyop.deleteFaces oc #all
				polyop.attach oc (copy o)
				od=convertToPoly(box()) 
				d=box pos:o.pos wirecolor:o.wirecolor
				polyop.deleteFaces od #all
				polyop.attach od (copy o)
-- 				oc.split = on	
				oc.slice zz pt1
				ov=polyop.getNumFaces oc
				arr_tf=#()
				for i in 1 to ov do
				(
					fc=polyop.getFaceCenter oc i
					fcv=w_to_c sys fc
					if fcv.z>0 do append arr_tf i
				)
				tf=(arr_tf as bitarray)
				polyop.deleteFaces oc tf
				convertToPoly o
				polyop.deleteFaces o #all
				polyop.attach o oc
				update o
				if polyop.getNumFaces o == 0 then delete o
-- 				od.split = on
				od.slice zz pt1
				dv=polyop.getNumFaces od
				arr_df=#()
				for i in 1 to dv do
				(
					fc=polyop.getFaceCenter od i
					fcv=w_to_c sys fc
					if fcv.z<0 do append arr_df i
				)
				df=(arr_df as bitarray)
				polyop.deleteFaces od df
				convertToPoly d
				polyop.deleteFaces d #all
				polyop.attach d od
				update d
				if polyop.getNumFaces d == 0 then delete d else 
				(
-- 					setGroupMember d false
					append arr_new d
				)
			)
			select arr_new
			group arr_new
		)else
		(
			messageBox "请选择物体"
		)
	)
-- 	catch()
	
	on btn_Three_cutting pressed  do undo on
	try
	(
		max create mode
		arr_set=#()
		arr_obj=#()
		arr_cut=#()
		arr_set=selection as array
		convertToPoly arr_set
		for s in arr_set do 
		(
			if (classof s) == Editable_Poly do append arr_obj s
		)
		print "请取第一点"  --取点
		pt1=pickPoint snap:#3D 
		print "请取第二点"
		pt2=pickPoint snap:#3D 
		print "请取第三点"
		pt3=pickPoint snap:#3D 
		xx=pt2-pt1--设定坐标系统
		zz=pt3-pt1
		yy=cross zz xx
		zz=cross xx yy
		xx=normalize xx
		yy=normalize yy
		zz=normalize zz
		sys=(matrix3 xx yy zz pt1)
		if arr_obj.count > 0 then
		(
			for o in arr_obj do
			(
				oc=convertToPoly(box()) 
				polyop.deleteFaces oc #all
				polyop.attach oc (copy o)
				oc.slice zz pt1
				ov=polyop.getNumFaces oc
				arr_tf=#()
				for i in 1 to ov do
				(
					fc=polyop.getFaceCenter oc i
					fcv=w_to_c sys fc
					if fcv.z>0 do append arr_tf i
				)
				tf=(arr_tf as bitarray)
				polyop.deleteFaces oc tf
				convertToPoly o
				polyop.deleteFaces o #all
				polyop.attach o oc
				update o
				if polyop.getNumFaces o == 0 then delete o else append arr_cut o
			)
			select arr_cut
		)else
		(
			messageBox "请选择物体"
		)
	)catch()
)
createdialog wh_Batch_object_cutting