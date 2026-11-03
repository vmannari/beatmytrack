class_name VehicleCustomisation
extends RefCounted
## Local cosmetic part IDs. Never included in simulation, tickets or PB keys.
const VERSION: int = 1
const CATEGORIES: Array[String] = ["hood", "aero", "rims", "body"]
const LABELS: Dictionary = {"hood":"Hood", "aero":"Rear aero", "rims":"Rims", "body":"Body kits"}
const OPTIONS: Dictionary = {
	"hood":[["stock","Original"],["louvres","Twin louvres"],["scoop","Rally scoop"],["dome","Power dome"],
		["extractor","Track extractor"],["cowl","Raised cowl"],["twin_scoop","Twin intakes"],["reverse","Reverse intake"],["ribs","Pressed ribs"],["vented","Vented dome"]],
	"aero":[["stock","Original"],["lip","Roof lip"],["ducktail","Ducktail"],["wing","GT wing"],
		["touring","Hatch sweep"],["pedestal","Low rear wing"],["swan","Swan neck"],["biwing","Rear twin blade"],["rallywing","Rally hoop"],["endurance","Endurance rear"],
		["whale","Whale tail"],["drag","Drag deck"],["splitwing","Swept wing"]],
	"rims":[["stock","Original"],["five","Forged five"],["split","Split six"],["turbine","Turbine"],
		["mesh","Cross mesh"],["dish","Deep dish"],["rallydisc","Rally disc"],["six","Sport six"],["ten","Slim ten"],["tri","Tri spoke"]],
	"body":[["stock","Original"],["street","Street"],["rally","Rally"],["club","Club sport"],
		["heritage","Heritage"],["touring","Touring"],["wide","Wide arch"],["endurance","Endurance"],["gravel","Gravel"],["urban","Urban sport"]]}

const DESCRIPTIONS: Dictionary = {
	"hood":["Factory finish","Twin-bank vented hood","Raised intake","Sculpted centre bulge","Recessed heat extractor","Raised rear cowl","Paired intake openings","Rear-facing intake","Pressed reinforcement ribs","Vented centre bulge"],
	"aero":["Factory finish","Subtle roof-edge extension","Raised trailing edge","Tall twin-mounted wing","Swept hatch extension","Low deck-mounted wing","Top-mounted wing supports","Two rear aero blades","Raised rally hoop","Long rear aero profile","Broad sculpted tail","Extended rear deck","Split rear wing"] ,
	"rims":["Factory finish","Five broad spokes","Six split spokes","Swept turbine blades","Cross-spoke lattice","Deep recessed centre","Closed rally face","Six sculpted spokes","Ten narrow spokes","Three broad spokes"],
	"body":["Factory finish","Low front lip and side skirts","Rally arches and mud flaps","Front splitter and sill extensions","Subtle classic arch trim","Touring lip and sill package","Extended wheel arches","Deep splitter and rear diffuser","Raised gravel trim and mud flaps","Sculpted street trim"]}

const KIT_CARS: Array[String] = ["compact","kart","hovercraft","forklift","electric"]
const ELECTRIC_OPTIONS: Dictionary = {
	"hood":[["stock","Original"],["volt_centre","Centre sculpt"],["volt_twin","Twin channels"],["volt_carbon","Carbon centre"],["volt_blade","Blade channels"],["volt_vent","Shoulder sculpt"],["volt_triple","Triple contour"],["volt_sweep","Swept channels"],["volt_crest","Raised crest"],["volt_delta","Delta panel"],["volt_split","Split centre"],["volt_edge","Edge blades"],["volt_track","Touring sculpt"],["volt_ridge","Twin ridges"],["volt_sport","Sport panel"],["volt_race","Race channels"]],
	"aero":[["stock","Original"],["volt_lip","Deck lip"],["volt_ducktail","Ducktail"],["volt_low","Low wing"],["volt_swept","Swept wing"],["volt_bridge","Bridge wing"],["volt_twin","Twin blade"],["volt_gt","GT wing"],["volt_arc","Arc wing"],["volt_endurance","Endurance wing"],["volt_swan","Swan wing"],["volt_split","Split wing"],["volt_club","Club wing"],["volt_wide","Wide wing"],["volt_race","Race wing"],["volt_aero","Aero blade"]],
	"rims":[["stock","Original"],["volt_three","Forged three"],["volt_four","Forged four"],["volt_five","Forged five"],["volt_six","Forged six"],["volt_seven","Forged seven"],["volt_eight","Forged eight"],["volt_nine","Forged nine"],["volt_ten","Forged ten"],["volt_twelve","Forged twelve"],["volt_splitfive","Split five"],["volt_splitsix","Split six"],["volt_turbine","Turbine"],["volt_blade","Aero blades"],["volt_disc","Aero disc"],["volt_mesh","Cross mesh"]],
	"body":[["stock","Original"],["volt_street","Street kit"],["volt_sport","Sport kit"],["volt_club","Club kit"],["volt_touring","Touring kit"],["volt_track","Track kit"],["volt_endurance","Endurance kit"],["volt_carbon","Carbon kit"],["volt_blade","Blade kit"],["volt_sweep","Swept kit"],["volt_wide","Wide kit"],["volt_split","Split kit"],["volt_gt","GT kit"],["volt_aero","Aero kit"],["volt_stealth","Stealth kit"],["volt_race","Race kit"]]}
const ELECTRIC_DESCRIPTIONS: Dictionary = {
	"hood":["Factory finish","Sculpted centre panel","Twin shaped channels","Dark centre panel","Paired narrow blades","Smooth swept shoulder contours","Three shallow painted contours","Swept shoulder channels","Raised centre crest","Tapered centre panel","Split centre panels","Narrow edge blades","Broad touring panel with soft channels","Twin raised ridges","Broad sport centre","Swept race channels"],
	"aero":["Factory finish","Low trailing lip","Raised trailing edge","Low mounted wing","Swept wing profile","Bridged rear wing","Two stacked blades","Broad GT wing","Curved rear blade","Long endurance wing","Top-supported wing","Split rear blades","Compact club wing","Wide rear wing","High race wing","Thin aerodynamic blade"],
	"rims":["Factory finish","Three broad spokes","Four forged spokes","Five forged spokes","Six forged spokes","Seven forged spokes","Eight forged spokes","Nine forged spokes","Ten narrow spokes","Twelve narrow spokes","Five paired spokes","Six paired spokes","Swept turbine spokes","Broad aero spokes","Smooth aero disc","Crossed fine spokes"],
	"body":["Factory finish","Low street splitter and sills","Sport splitter and sills","Compact club extensions","Subtle touring extensions","Track splitter and sills","Long endurance extensions","Dark splitter and sills","Blade-shaped extensions","Swept extensions","Wide splitter and sills","Split side extensions","Deep GT extensions","Slim aero extensions","Dark low-profile extensions","Race splitter and sills"]}
const FORKLIFT_LABELS: Dictionary = {"hood":"Engine cover", "aero":"Rear guard", "rims":"Wheel covers", "body":"Cabin frame"}
const FORKLIFT_OPTIONS: Dictionary = {
	"hood":[["stock","Original"],["fork_vent","Louvred steel"],["fork_rib","Pressed ribs"],["fork_twin","Twin vent lid"],["fork_scoop","Rear intake lid"],["fork_louvre","Split louvres"],["fork_split","Service split lid"],["fork_dome","Crowned steel"],["fork_fan","Screened vent"],["fork_cross","Service panel lid"],["fork_flush","Flush service lid"],["fork_armour","Reinforced lid"],["fork_channel","Channelled steel"],["fork_race","Side vent lid"]],
	"aero":[["stock","Original"],["fork_bar","Pressed steel guard"],["fork_wrap","Corner guard"],["fork_twin","Twin rail guard"],["fork_low","Low impact guard"],["fork_bow","Swept guard"],["fork_step","Service step guard"],["fork_mesh","Service grille guard"],["fork_roller","Dock buffers"],["fork_plate","Counterweight shield"],["fork_cage","Box section guard"],["fork_arc","Rolled tube guard"],["fork_rib","Ribbed buffers"],["fork_tow","Clevis guard"]],
	"rims":[["stock","Original"],["fork_disc","Pressed steel"],["fork_ring","Rolled rim"],["fork_spoke","Six vent steel"],["fork_three","Three vent cast"],["fork_four","Four vent cast"],["fork_five","Five vent cast"],["fork_eight","Eight vent steel"],["fork_turbine","Cooling vent steel"],["fork_mesh","Perforated steel"],["fork_dish","Recessed steel"],["fork_bolt","Split rim"],["fork_slots","Oval vent steel"],["fork_star","Five rib cast"]],
	"body":[["stock","Original"],["fork_rail","Round hoop frame"],["fork_plate","Pressed pillar frame"],["fork_twin","Rear cantilever frame"],["fork_canted","Swept frame"],["fork_round","Barrel roof frame"],["fork_cross","Crossbeam frame"],["fork_canopy","Weather canopy"],["fork_lattice","Diamond roof frame"],["fork_arch","Vaulted frame"],["fork_sport","Wedge frame"],["fork_mesh","Screen roof frame"],["fork_heavy","Heavy duty frame"],["fork_safari","Sun shade frame"]]}
const FORKLIFT_DESCRIPTIONS: Dictionary = {
	"hood":["Factory engine cover","Formed steel lid with an inset cooling bank","Pressed stiffeners around a recessed cooling panel","Paired inset vents in a single formed lid","Shallow rear cooling inlet in a crowned steel lid","Two recessed louvre banks with a centre bridge","Split panel shoulders and a narrow service channel","Gently crowned lid with a rear cooling slot","Recessed longitudinal cooling grille","Two inset cooling panels with a service divider","Low lid with a flush latch and rear vent","Inset cooling bank and protected panel edges","Four recessed longitudinal cooling channels","Low formed lid with paired cooling channels"],
	"aero":["Factory counterweight bumper","Shaped steel impact beam on bolted mounting shoes","Contoured bumper with replaceable corner buffers","Joined upper and lower impact rails","Low rubber-faced counterweight protection","Formed beam following the counterweight corners","Recessed anti-slip service step in the bumper","Protected recessed service grille","Paired rubber buffers on a shaped bumper","Formed painted shield with a rolled edge","Closed beam with reinforced capped ends","Continuous curved steel protection tube","Replaceable ribbed rubber impact pads","Supported towing clevis with a captive pin"],
	"rims":["Factory pressed steel wheel","Dished steel face with a raised hub and rolled lip","Formed outer rim surrounding the factory hub","Six cooling apertures in a dished steel face","Three broad openings in a substantial cast face","Four rounded openings in a cast wheel face","Five rounded openings around a bolted hub","Eight narrow cooling apertures in pressed steel","Ten cooling apertures with a rolled outer flange","Twelve small ventilation openings","Recessed dish with a raised bolted hub","Bolted split rim with a visible flange seam","Eight broad oval cooling apertures","Five compact openings in a reinforced cast face"],
	"body":["Factory overhead guard","Round transverse hoops joined by slim roof ties","Broad tapered rear pillars and painted roof blades","Twin rear goosenecks carry an open-front roof","Rearward-swept pillars and a sloping longitudinal roof","Long curved side arches carry a rounded barrel roof","Low roof with crossed braces and painted corner haunches","Full overhanging painted roof with deep rain gutters","Slim straight pillars beneath an open diamond roof lattice","High transverse roof arches above low side rails","Tapered wedge roof with three broad longitudinal slats","Fine metal roof screen on a light alloy-coloured frame","Deep painted roof rails and broad rear pillar haunches","Extended pale front shade above an open rear roof"]}
const HOVER_LABELS: Dictionary = {"hood":"Bow", "aero":"Rear wing", "rims":"Fans", "body":"Side sponsons"}
const HOVER_OPTIONS: Dictionary = {
	"hood":[["stock","Original"],["hover_blade","Blade bow"],["hover_twin","Twin bow"],["hover_shield","Shield bow"],["hover_arrow","Arrow bow"],["hover_delta","Delta bow"],["hover_channel","Channel bow"],["hover_crest","Crest bow"],["hover_split","Split bow"],["hover_jet","Jet bow"],["hover_enduro","Endurance bow"]],
	"aero":[["stock","Original"],["hover_low","Low wing"],["hover_twin","Twin wing"],["hover_swept","Swept wing"],["hover_delta","Delta wing"],["hover_raised","Raised wing"],["hover_split","Split wing"],["hover_enduro","Endurance wing"],["hover_arc","Arc wing"],["hover_sport","Sport wing"],["hover_gt","GT wing"]],
	"rims":[["stock","Original"],["hover_bright","Polished nacelles"],["hover_twin","Twin-ring nacelles"],["hover_guard","Armoured nacelles"],["hover_turbine","Turbine nacelles"],["hover_scythe","Scythe nacelles"],["hover_paddle","Classic propulsors"],["hover_jet","Jet nacelles"],["hover_fan","Sport nacelles"],["hover_carbon","Carbon nacelles"],["hover_race","Race nacelles"]],
	"body":[["stock","Original"],["hover_sport","Sport sponsons"],["hover_twin","Twin sponsons"],["hover_guard","Guard sponsons"],["hover_blade","Blade sponsons"],["hover_delta","Delta sponsons"],["hover_channel","Channel sponsons"],["hover_enduro","Endurance sponsons"],["hover_swept","Swept sponsons"],["hover_jet","Jet sponsons"],["hover_gt","GT sponsons"]]}
const HOVER_DESCRIPTIONS: Dictionary = {
	"hood":["Factory finish","Blade bow","Twin bow","Shield bow","Arrow bow","Delta bow","Channel bow","Crest bow","Split bow","Jet bow","Endurance bow"],
	"aero":["Factory finish","Low wing","Twin wing","Swept wing","Delta wing","Raised wing","Split wing","Endurance wing","Arc wing","Sport wing","GT wing"],
	"rims":["Factory finish","Polished nacelles","Twin-ring nacelles","Armoured nacelles","Turbine nacelles","Scythe nacelles","Classic propulsors","Jet nacelles","Sport nacelles","Carbon nacelles","Race nacelles"],
	"body":["Factory finish","Sport sponsons","Twin sponsons","Guard sponsons","Blade sponsons","Delta sponsons","Channel sponsons","Endurance sponsons","Swept sponsons","Jet sponsons","GT sponsons"]}
const KART_LABELS: Dictionary = {"hood":"Nose","aero":"Rear bumper","rims":"Rims","body":"Side pods"}
const KART_OPTIONS: Dictionary = {
	"hood":[["stock","Original"],["sprint","Sprint nose"],["enduro","Endurance nose"],["wedge","Wedge nose"],
		["arrow","Arrow nose"],["split","Channel nose"],["shield","Shield nose"],["retro","Rounded nose"],["mohawk","Mohawk nose"]],
	"aero":[["stock","Original"],["loop","Wraparound bumper"],["blade","Wide rear bumper"],["twin","Twin rear bumper"],
		["oval","Oval bumper"],["cage","Cross brace bumper"],["panel","Slotted bumper"],["chevron","Chevron bumper"]],
	"rims":[["stock","Original"],["three","Three spoke"],["six","Split six"],["disc","Disc wheel"],
		["turbine","Turbine wheel"],["mesh","Cross mesh wheel"],["dish","Deep dish wheel"],["star","Five point wheel"]],
	"body":[["stock","Original"],["sprint","Sprint pods"],["enduro","Endurance pods"],["wedge","Wedge pods"],
		["blade","Blade pods"],["channel","Channel pods"],["rounded","Rounded pods"],["box","Box pods"],["mohawk","Mohawk pods"]]}
const KART_DESCRIPTIONS: Dictionary = {
	"hood":["Factory finish","Low broad nose with a narrow fairing","Raised nose with a broad fairing","Angular nose with a tapered fairing",
		"Pointed nose with a raised centre spine","Twin shoulders around a recessed channel","Broad flat shield with squared shoulders","Rounded bumper with a slender fairing","Swept fins along a sculpted centre fairing"],
	"aero":["Factory finish","Moulded bumper with swept ends","Broad low bumper on twin stays","Two bumper rails on twin stays",
		"Closed oval rail with a centre badge","Tubular frame with diagonal cross braces","Moulded shield with two open slots","Angled bumper with a low centre"],
	"rims":["Factory finish","Three broad magnesium spokes","Six paired magnesium spokes","Recessed solid magnesium face",
		"Nine swept solid turbine blades","Crossed bronze spokes with an open centre","Deep bowl with a rolled outer lip","Five broad forged spokes"],
	"body":["Factory finish","Low side pods with short returns","Deep side pods with raised shoulders","Tapered side pods with angular shoulders",
		"Low sharp shoulders and a thin trailing edge","Deep channel between raised shoulders","Smooth rounded capsule side pods","Squared side pods with broad flat sides","Sculpted side pods with swept crest fins"]}

static func supported(id: String) -> bool:
	return id in KIT_CARS

static func options(category: String, id: String = "compact") -> Array:
	return (ELECTRIC_OPTIONS if id=="electric" else FORKLIFT_OPTIONS if id=="forklift" else HOVER_OPTIONS if id=="hovercraft" else KART_OPTIONS if id=="kart" else OPTIONS).get(category,[]) if supported(id) else []

static func label(category: String, id: String = "compact") -> String:
	return str((FORKLIFT_LABELS if id=="forklift" else HOVER_LABELS if id=="hovercraft" else KART_LABELS if id=="kart" else LABELS).get(category,""))

static func description(category: String, option: String, id: String = "compact") -> String:
	var choices: Array = options(category,id)
	for index: int in range(choices.size()):
		if choices[index][0]==option: return (ELECTRIC_DESCRIPTIONS if id=="electric" else FORKLIFT_DESCRIPTIONS if id=="forklift" else HOVER_DESCRIPTIONS if id=="hovercraft" else KART_DESCRIPTIONS if id=="kart" else DESCRIPTIONS)[category][index]
	return ""

static func defaults() -> Dictionary:
	return {"version":VERSION,"hood":"stock","aero":"stock","rims":"stock","body":"stock"}

static func valid(value: Variant, id: String = "") -> bool:
	if not value is Dictionary or value.size() != 5 or value.get("version") != VERSION: return false
	# A conditional [id] is an untyped Array, even beside typed KIT_CARS.
	# Keep both validation paths typed without aborting save/sync admission.
	var cars: Array[String] = []
	if id.is_empty(): cars.assign(KIT_CARS)
	else: cars.append(id)
	for category: String in CATEGORIES:
		if not value.get(category) is String: return false
		var found: bool = false
		for car: String in cars:
			for option: Array in options(category,car):
				if value[category] == option[0]: found = true
		if not supported(id) and not id.is_empty(): found = value[category]=="stock"
		if not found: return false
	return true

static func for_car(settings: Dictionary, id: String) -> Dictionary:
	var collection: Variant = settings.get("vehicle_customisation",{})
	var value: Variant = collection.get(id,{}) if collection is Dictionary else {}
	if not supported(id) or not valid(value,id): return defaults()
	var normalized: Dictionary = value.duplicate(true)
	normalized.version = VERSION
	return normalized

static func valid_collection(value: Variant) -> bool:
	if not value is Dictionary or value.size() > KIT_CARS.size(): return false
	for id: Variant in value:
		if not id is String or not supported(id) or not valid(value[id],id): return false
	return true
