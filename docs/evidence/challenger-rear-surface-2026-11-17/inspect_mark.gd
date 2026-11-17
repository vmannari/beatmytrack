extends SceneTree
func _initialize() -> void:
 var results: Dictionary={}
 for stage: String in ["mark-diagnostic","corner-qualified"]:
  var pic: Image=Image.load_from_file("res://../build/challenger-rear-surface-2026-11-17/views-"+stage+"/mobile/simple/white-rear-right.png")
  var dark: Array=[]
  for y: int in range(584,598):
   for x: int in range(804,818):
    var c: Color=pic.get_pixel(x,y)
    if maxf(c.r,maxf(c.g,c.b))<150.0/255.0:dark.append([x,y])
  print(stage," dark=",dark)
  results[stage]=dark
 assert(results["mark-diagnostic"].size()==6 and results["corner-qualified"].is_empty())
 FileAccess.open("res://../docs/evidence/challenger-rear-surface-2026-11-17/corner-pixels.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 quit()
