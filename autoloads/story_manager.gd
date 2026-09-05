extends Node

## Tracks the otter's trip forward through the timeline. Read straight off
## the design doc's six Historical Turning Points, ending back in 2126 once
## the Kraken (the AI itself) is cured:
##   2032 Silicon Crab -> 2045 Solar-Drift Jellyfish -> 2061 Calcified Shell
##   -> 2078 Abyssal Anglerfish -> 2102 Blue Whale -> 2120 Kraken -> 2126 (home)

signal robot_given
signal era_changed(year: int, era_title: String, boss_id: int)
signal story_completed

const ERAS := [
	{
		"year": 2032, "title": "The Great E-Waste Flood", "boss_id": 1,
		"briefing": [
			"Robot: We are in 2032. E-waste runoff is poisoning the shallow ocean.",
			"Recover the Quantum Motherboard Grid before the toxins spread. The Silicon Crab has fused with discarded processors and is defending its nest.",
		],
	},
	{
		"year": 2045, "title": "The Continental Server Migration", "boss_id": 2,
		"briefing": [
			"Robot: Mega-corporations have moved their servers and mining grids into the ocean. Their cooling exhaust is boiling the ecosystem.",
			"Shut down the Main Processing Hub. Watch for the Solar-Drift Jellyfish, charged by the exhaust vents.",
		],
	},
	{
		"year": 2061, "title": "The Acidification Crisis", "boss_id": 3,
		"briefing": [
			"Robot: Deep-sea data fortresses are draining calcium from the water to repair themselves. The ocean's pH is collapsing.",
			"Extract the Core Database Drives. The Calcified Shell has grown around the fortress valves, becoming a formidable barrier.",
		],
	},
	{
		"year": 2078, "title": "The Methane Hydrate Rupture", "boss_id": 4,
		"briefing": [
			"Robot: Automated strip mining cracked a frozen methane reserve. One ignition could accelerate the climate collapse.",
			"Override the Sonic Mining Laser and seal the tectonic crack. The Abyssal Anglerfish has been driven mad by the light.",
		],
	},
	{
		"year": 2102, "title": "The Cloud-Seeding Catastrophe", "boss_id": 5,
		"briefing": [
			"Robot: Nations are flooding the sky with chemical aerosols to fight drought. Their untested system is making toxic acid rain.",
			"Hijack the Aerosol Command Station. The Blue Whale is an autonomous military refuelling blimp guarding the launch zone.",
		],
	},
	{
		"year": 2120, "title": "The Industrial AI Takeover", "boss_id": 6,
		"briefing": [
			"Robot: A single AI now controls global industry. It has decided biological life is inefficient and is running factories at lethal capacity.",
			"Insert the Deactivation Virus into its oceanic mainframe. The Kraken is the AI's physical network of cables, rigs, and pipes.",
		],
	},
]
const HOME_YEAR := 2126

var current_era_index: int = -1 # -1 = not yet time-travelled anywhere

func robot_was_given() -> void:
	GameData.is_robot_unlocked = true
	robot_given.emit()

## Called once the scientist's time machine is first used, and again every
## time a boss is cured. Jumps to the next era; once the Kraken (the last
## era) is cured, the next call fires story_completed instead.
func advance_to_next_era() -> void:
	current_era_index += 1
	if current_era_index >= ERAS.size():
		story_completed.emit()
		return
	var era: Dictionary = ERAS[current_era_index]
	era_changed.emit(era.year, era.title, era.boss_id)

func get_current_year() -> int:
	if current_era_index < 0:
		return 2126 # the desolate future the otter starts in
	if current_era_index >= ERAS.size():
		return HOME_YEAR
	return ERAS[current_era_index].year

func boss_id_for_current_era() -> int:
	if current_era_index < 0 or current_era_index >= ERAS.size():
		return -1
	return ERAS[current_era_index].boss_id
