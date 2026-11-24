extends Node3D
## Coordinates in saves are floor-plan coordinates. Map them onto the XZ ground plane.
const UNIT=40.0
const WOOD=Color("#bc805c")
const CREAM=Color("#fff0cf")
const JADE=Color("#488e91")
const BRASS=Color("#daa956")
var game
var camera=Camera3D.new()
var scenery=Node3D.new()
var actors={}
var meals=[]
var materials={}
var meshes={}
var layout_dirty=true
var cursor
var shopkeeper
var decor_node
var server
var tray
var waiting_models=[]
var ground_material

func world(p:Vector2,h:float=0.0)->Vector3:
	return Vector3((p.x-640)/UNIT,h,(p.y-420)/UNIT)

func ground(mouse:Vector2)->Vector2:
	var hit=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	if hit==null: return Vector2(-9999,-9999)
	return Vector2(hit.x,hit.z)*UNIT+Vector2(640,420)

func guest_hit(mouse:Vector2,g)->bool:
	var foot=camera.unproject_position(world(g.position))
	var head=camera.unproject_position(world(g.position,1.75))
	return Geometry2D.get_closest_point_to_segment(mouse,foot,head).distance_to(mouse)<18

func material(color:Color):
	if not materials.has(color):
		var m=StandardMaterial3D.new()
		m.albedo_color=color.srgb_to_linear();m.roughness=0.82
		materials[color]=m
	return materials[color]

func piece(parent,pos:Vector3,size:Vector3,color:Color,form="box")->MeshInstance3D:
	if not meshes.has(form):
		match form:
			"round":
				var m=SphereMesh.new();m.radius=0.5;m.height=1;m.radial_segments=16;m.rings=8;meshes[form]=m
			"disc":
				var m=CylinderMesh.new();m.top_radius=0.5;m.bottom_radius=0.5;m.height=1;m.radial_segments=20;meshes[form]=m
			_: meshes[form]=BoxMesh.new()
	var obj=MeshInstance3D.new();obj.mesh=meshes[form];obj.material_override=material(color)
	parent.add_child(obj);obj.position=pos;obj.scale=size
	return obj

func label(parent,pos:Vector3,text:String):
	var note=Label3D.new();note.font=game.font;note.text=text;note.font_size=28;note.pixel_size=0.009
	note.billboard=BaseMaterial3D.BILLBOARD_ENABLED;note.outline_size=6
	parent.add_child(note);note.position=pos
	return note

func _ready():
	game=get_parent()
	add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=33.5
	camera.position=Vector3(2.2,20,22);camera.look_at(Vector3(0,0.65,0));camera.current=true
	var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#344451")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#fff2e9");env.ambient_light_energy=0.48
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	camera.environment=env
	var sun=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-54,-32,0);sun.light_energy=0.70;sun.shadow_enabled=true
	add_child(scenery)
	shopkeeper=character(self,JADE,Color("#754837"))
	server=character(self,Color("#9184bd"),Color("#a99aca"))
	tray=piece(shopkeeper,Vector3(.36,1.04,.32),Vector3(.47,.06,.4),CREAM,"disc")
	decor_node=Node3D.new();add_child(decor_node)
	piece(decor_node,Vector3(0,.25,0),Vector3(.6,.5,.6),WOOD,"disc")
	piece(decor_node,Vector3(0,.83,0),Vector3(.82,.85,.8),Color("#6d986b"),"round")
	cursor=piece(self,Vector3.ZERO,Vector3(.96,.045,.96),BRASS)
	cursor.visible=false
	var floor_mat=material(Color.WHITE).duplicate()
	floor_mat.albedo_texture=preload("res://art/imported/temp02/floor.png")
	floor_mat.uv1_triplanar=true;floor_mat.uv1_world_triplanar=true;floor_mat.uv1_scale=Vector3(.13,.13,.13)
	ground_material=floor_mat
	sync()

func character(parent,cloth:Color,hair:Color):
	var root=Node3D.new();parent.add_child(root)
	for x in [-.16,.16]:
		piece(root,Vector3(x,.29,0),Vector3(.23,.51,.24),Color("#665865"))
		piece(root,Vector3(x,.105,.06),Vector3(.29,.20,.38),Color("#795842"),"round")
	piece(root,Vector3(0,.87,0),Vector3(.73,.86,.48),CREAM,"round")
	piece(root,Vector3(0,.76,.18),Vector3(.59,.57,.21),cloth)
	for x in [-.39,.39]:
		piece(root,Vector3(x,.88,.02),Vector3(.18,.51,.20),CREAM,"round")
		piece(root,Vector3(x,.64,.06),Vector3(.18,.18,.19),Color("#f4c5a1"),"round")
	var skin=Color("#f8c9a6")
	piece(root,Vector3(0,1.56,.03),Vector3(.79,.74,.67),skin,"round")
	piece(root,Vector3(0,1.79,-.04),Vector3(.86,.49,.72),hair,"round")
	for x in [-.32,.32]: piece(root,Vector3(x,1.58,-.05),Vector3(.20,.52,.51),hair,"round")
	for x in [-.14,.14]: piece(root,Vector3(x,1.55,.342),Vector3(.078,.105,.044),Color("#443440"),"round")
	piece(root,Vector3(-.13,1.77,.26),Vector3(.45,.17,.17),hair,"round").rotation.z=.24
	return root

func station(pos:Vector3,title:String,color:Color,width:float):
	piece(scenery,pos+Vector3(0,.49,0),Vector3(width,.98,.87),color)
	piece(scenery,pos+Vector3(0,1.02,0),Vector3(width+.12,.13,1.02),CREAM)
	piece(scenery,pos+Vector3(0,.81,.45),Vector3(width,.045,.04),BRASS)
	label(scenery,pos+Vector3(0,1.42,0),title)

func rebuild():
	for child in scenery.get_children(): scenery.remove_child(child);child.queue_free()
	var l=game.layout
	# Contiguous floor slabs respect the same room shape as pathfinding.
	for y in range(l.HEIGHT):
		var start=-99
		for x in range(-7,l.WIDTH+1):
			var valid=x<0 or l.floor_at(Vector2i(x,y))
			if valid and start==-99: start=x
			if not valid and start!=-99:
				var first=world(l.center(Vector2i(start,y)));var last=world(l.center(Vector2i(x-1,y)))
				piece(scenery,(first+last)/2+Vector3(0,-.12,0),Vector3(x-start,.24,1),WOOD).material_override=ground_material
				start=-99
	# The wall is built around five openings. The glass, sill, jambs and wall
	# have different depths, so the openings remain legible from a side view.
	var back=world(Vector2(620,190))
	var plaster=Color("#a3bec5")
	var timber=WOOD.darkened(.17)
	piece(scenery,back+Vector3(0,.44,-.13),Vector3(28,.88,.36),plaster)
	piece(scenery,back+Vector3(0,2.91,-.13),Vector3(28,.22,.36),timber)
	var last_edge=-14.0
	for center_x in [-10,-5,0,5,10]:
		var edge=center_x-1.55
		piece(scenery,back+Vector3((last_edge+edge)/2,1.84,-.13),Vector3(edge-last_edge,1.92,.36),plaster)
		var w=back+Vector3(center_x,1.84,-.13)
		var glass=piece(scenery,w-Vector3(0,0,.03),Vector3(3.08,1.85,.045),Color("#91d6e4"))
		var glass_material=glass.material_override.duplicate()
		glass_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_material.albedo_color.a=.4;glass.material_override=glass_material
		for side in [-1,1]:
			piece(scenery,w+Vector3(side*1.52,0,0),Vector3(.115,1.92,.44),CREAM)
		piece(scenery,w+Vector3(0,0,.07),Vector3(.08,1.91,.11),CREAM)
		piece(scenery,w+Vector3(0,.28,.07),Vector3(3.05,.07,.11),CREAM)
		piece(scenery,w+Vector3(0,-.93,.11),Vector3(3.45,.16,.65),WOOD)
		last_edge=center_x+1.55
	piece(scenery,back+Vector3((last_edge+14)/2,1.84,-.13),Vector3(14-last_edge,1.92,.36),plaster)
	for x in [-13.8,-7.5,-2.5,2.5,7.5,13.8]:
		piece(scenery,back+Vector3(x,1.47,.1),Vector3(.16,2.94,.26),timber)
	for t in l.tables:
		var cells=l.body(t);var pos=(world(l.center(cells[0]))+world(l.center(cells[1])))/2
		var dims=Vector3(1.92,.13,.91) if t.rot%2==0 else Vector3(.91,.13,1.92)
		piece(scenery,pos+Vector3(0,.91,0),dims,WOOD)
		for x in [-1,1]:
			for z in [-1,1]:
				piece(scenery,pos+Vector3(x*(dims.x/2-.14),.43,z*(dims.z/2-.14)),Vector3(.13,.86,.13),WOOD.darkened(.25))
		for c in cells:
			var q=world(l.center(c),1.07)
			piece(scenery,q,Vector3(.52,.2,.52),BRASS,"disc")
			piece(scenery,q+Vector3(0,.105,0),Vector3(.44,.02,.44),Color("#a44d32"),"disc")
		var outward=Vector3(l.chairs(t)[0].x-cells[0].x,0,l.chairs(t)[0].y-cells[0].y)
		for c in l.chairs(t):
			var q=world(l.center(c))
			piece(scenery,q+Vector3(0,.46,0),Vector3(.69,.17,.66),Color("#a96e6c"))
			piece(scenery,q+Vector3(0,.23,0),Vector3(.49,.45,.46),WOOD)
			var back_size=Vector3(.69,.53,.1) if outward.z!=0 else Vector3(.1,.53,.66)
			piece(scenery,q+outward*.29+Vector3(0,.78,0),back_size,WOOD)
	for f in l.feeders: station(world(l.center(Vector2i(f.x,f.y))),"补",JADE,.8)
	for f in l.facilities: station(world(l.center(Vector2i(f.x,f.y))),game.FACILITY[int(f.kind)],JADE,.85)
	station(world(Vector2(170,220)),"月桥集市",Color("#81a27e"),3.4)
	station(world(Vector2(190,580)),"料理台",JADE,3.5)
	for i in range(5):
		piece(scenery,world(Vector2(120+i*25,220),1.18),Vector3(.43,.28,.35),game.COLORS[i],"round")
	var burner=world(Vector2(172,580),1.21)
	piece(scenery,burner,Vector3(.67,.34,.67),BRASS,"disc")
	piece(scenery,burner+Vector3(0,.18,0),Vector3(.55,.025,.55),Color("#a64d38"),"disc")
	station(world(Vector2(160,365)),"开店铃",WOOD,1)
	piece(scenery,world(Vector2(160,365),1.24),Vector3(.55,.35,.55),BRASS,"round")
	layout_dirty=false

func sync():
	if layout_dirty: rebuild()
	shopkeeper.position=world(game.player);tray.visible=game.held>=0
	server.visible=game.employee;server.position=world(game.staff_pos)
	decor_node.visible=game.decor;decor_node.position=world(game.decor_pos)
	cursor.visible=game.build_mode and not game.panel.visible if game.panel!=null else false
	if cursor.visible: cursor.position=world(game.layout.center(game.layout.cell(ground(get_viewport().get_mouse_position()))),.03)
	var present={}
	for g in game.guests:
		if g==null: continue
		var id=int(g.ticket);present[id]=true
		if not actors.has(id):
			var actor=character(self,game.COLORS[g.wish],Color("#695665"))
			var bubble=label(actor,Vector3(0,2.25,0),"")
			actors[id]=[actor,bubble]
		var node=actors[id][0];node.position=world(g.position)
		node.scale.y=.81 if g.trip.is_empty() else 1.0
		var bubble=actors[id][1];bubble.visible=g.order>=0 and g.trip.is_empty()
		if bubble.visible: bubble.text="谢谢！" if g.bonus else game.SPECIALS[g.order]
	for id in actors.keys():
		if not present.has(id): actors[id][0].queue_free();actors.erase(id)
	while waiting_models.size()<game.waiting.size(): waiting_models.append(character(self,JADE,WOOD))
	while waiting_models.size()>game.waiting.size(): waiting_models.pop_back().queue_free()
	for i in range(waiting_models.size()): waiting_models[i].position=world(game.layout.center(Vector2i(20-i%6,11-int(i/6))))
	while meals.size()<game.plates.size():
		var plate=piece(self,Vector3.ZERO,Vector3(.5,.055,.5),CREAM,"disc")
		piece(plate,Vector3(0,1,0),Vector3(.65,2,.64),BRASS,"round")
		meals.append(plate)
	while meals.size()>game.plates.size(): meals.pop_back().queue_free()
	for i in range(meals.size()):
		var p=game.plates[i];meals[i].position=world(game.layout.center(game.layout.routes[p.route].cell),1.01)
		meals[i].get_child(0).material_override=material(game.COLORS[int(p.food)%6])
