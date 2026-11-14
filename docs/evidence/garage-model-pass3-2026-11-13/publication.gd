extends "res://tests/test_menu_responsiveness.gd"
func run() -> void:
 architecture()
 var candidate: Node = (load("res://../build/garage-model-pass3-2026-11-13/candidate/workshop_v1.scn") as PackedScene).instantiate()
 var published: Node = (load(GarageEnvironment.PREPARED_ARCHITECTURE) as PackedScene).instantiate()
 var a: Array = []
 var b: Array = []
 geometry(candidate,a); geometry(published,b)
 check(a == b,"published workshop matches paired-render candidate geometry and finishes")
 candidate.free(); published.free()
 print("GARAGE_PROP_PUBLICATION ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
