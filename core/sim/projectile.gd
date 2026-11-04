class_name SimProjectile
extends RefCounted

var id: int = 0
var map_id: String = ""
var owner_id: int = 0
var skill: SkillDef = null
var effects: Dictionary = {}      # efeitos ao acertar, já com maestria e evoluções
var power: float = 1.0
var position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var speed: float = 12.0
var traveled: float = 0.0
var max_distance: float = 10.0
var radius: float = 0.4
var pierce: bool = false
var hit_ids: Array[int] = []
var color: Color = Color.WHITE
var is_basic: bool = false
