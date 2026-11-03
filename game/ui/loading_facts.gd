extends RefCounted
## Short game facts shown while the game is loading.

const FACTS: Array[String] = [
	'Complete every checkpoint to make your lap count.',
	'Your best lap and best race time are tracked separately.',
	'You can replay driving lessons whenever you like.',
	'Free Race lets you discover tracks.',
	'Practice is an untimed drive.',
	'Try the slalom in the parking hall test drive.',
	'Use the marked lane to practise acceleration and braking.',
	'One track. Everyone. A new pick every day.',
	'Compare your best time with other drivers in the daily standings.',
	'Weekly Rivalry awards points for your best verified track times.',
	'You can improve a Rivalry score with another attempt.',
	'In a limited-try challenge, each start uses a try.',
	'In a limited-try challenge, restarting uses a try.',
	'You can create a challenge from a finished race result.',
	'Create your own circuit in the track editor.',
	'Connect the road ends to make one closed lap.',
	'Complete a valid practice lap before publishing your track.',
	'You can return to editing after a practice drive.',
	'Compact is an agile choice for mixed circuits.',
	'Classic has rear-heavy traction for fast exits.',
	'Formula has precise grip on asphalt.',
	'The Go-kart is quick off the line.',
	'The Go-kart has strong grip in tight turns.',
	'Kits are available for the Compact, Go-kart and Hovercraft.',
	'Go-kart kits include noses, rear bumpers, rims and side pods.',
	'You can change car colours in the Garage.',
	'You can add stickers to a car in the Garage.',
	'A dirty car needs washing before changing its appearance.',
	'The hose can rinse fine dust from a car.',
	'Heavy dirt takes a slower wash.',
	'Move and resize your on-screen controls.',
	'Touch steering offers buttons, a slider or a joystick.',
	'You can change the driving camera in Settings.',
	'Rain reduces road grip.',
	'Oil spills coat tyres and reduce grip.',
	'Shallow water adds drag and reduces grip.',
	'Ramps launch the car in their facing direction.',
]

static var _random: RandomNumberGenerator = RandomNumberGenerator.new()
static var _seeded: bool = false

static func random_fact() -> String:
	if not _seeded:
		_random.randomize()
		_seeded = true
	return FACTS[_random.randi_range(0, FACTS.size() - 1)]
