extends SceneTree
func _initialize() -> void:
 var folder: String = ProjectSettings.globalize_path("res://../build/editor-incremental-2026-10-13/mobile-track_9b72c019537a01e582fd103ba69f8c83")
 for theme: String in ["pine","winter","night_city"]:
  var a := Image.load_from_file(folder+"/"+theme+"-original.png")
  var b := Image.load_from_file(folder+"/"+theme+"-incremental.png")
  var diff := Image.create(a.get_width(),a.get_height(),false,Image.FORMAT_RGB8)
  var count: int = 0; var box := Rect2i(); var points: Array = []
  for y: int in range(a.get_height()):
   for x: int in range(a.get_width()):
    if a.get_pixel(x,y)==b.get_pixel(x,y): continue
    count += 1
    box = Rect2i(x,y,1,1) if count==1 else box.expand(Vector2i(x,y))
    diff.set_pixel(x,y,Color.WHITE)
    if points.size()<12:points.append([x,y,a.get_pixel(x,y),b.get_pixel(x,y)])
  print(theme," count=",count," bounds=",box," points=",points)
  diff.save_png(ProjectSettings.globalize_path("res://../docs/evidence/editor-t05-t11-2026-10-23/")+theme+"-diff.png")
 quit()
