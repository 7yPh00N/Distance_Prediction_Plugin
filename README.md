# Installation

1. Extract the `cstrike` folder from the ZIP file to your game's root directory (usually: `\Half-Life\`)

2. Open the `plugins.ini` file (located in: `\cstrike\addons\amxmodx\configs\`)

3. Add the following line to the file: `distance_prediction.amxx`

4. Save the file and restart your game

# Commands

- `/dps` - Open Plugin Settings Menu

- `/dp` `/distpred` - Enable/Disable Plugin

- `/sonar` - Enable/Disable Sonar

- `/rtpredhud` - Enable/Disable Real-Time Prediction HUD

- `/bestpredhud` - Enable/Disable Best Predicted Distance HUD

- `/landingpred` - Enable/Disable Landing Area Prediction

- `/ljpred` - Long Jump

- `/hjpred` - High Jump

- `/cjpred` - Count Jump

- `/scjpred` - Stand-Up Count Jump

- `/dcjpred` - Double Count Jump

- `/wjpred` - Weird Jump

- `/sbjpred` - Stand-Up Bhop Jump

- `/bjpred` - Bhop Jump

- `/ldjpred` - Ladder Jump

# Configs

## \cstrike\addons\amxmodx\configs\

- `distance_prediction.ini`

- `distance_prediction_server.ini`

- `distance_prediction_thresholds.ini`

# Changelog

## V1.4.0 (Coming Soon)

### 2026.04.25

1. Improved distance prediction feature

- Introduced `vertical velocity` & `gravitational acceleration` to improve calculation accuracy

2. Added support for public servers (`distance_prediction_server 2`)

- Added observer pattern

- Added `Chinese` support (`menu_language 2`)

- Added HUD channel customization feature (`hud_best_channel 4`)

- Improved sonar feature

3. Added `LDJ` (ladder jump)

4. Fixed some overflow bugs

## V1.3.0

### 2026.04.15

1. Added sonar feature

2. Added 13 new plugin commands

3. Refactored config file read/write methods

## V1.2.0

### 2026.04.05

1. Improved landing area prediction feature

- Added toggle (`ON`/`OFF`)

- Added color selection feature

- Fixed some bugs
  
2. Improved real-time display feature (distance prediction)

- Added hold time adjustment feature

## V1.1.5_beta

### 2026.03.31

1. Added landing area prediction feature

## V1.1.0 

### 2026.03.28

1. Added plugin settings menu (`/dps`)

2. Added plugin toggle (`ON`/`OFF`)

3. Added `SBJ` & `BJ` (jump types)

4. Added HUD color selection feature

5. Added HUD position adjustment feature

## V1.0.5_beta 
### 2026.03.24

1. Added best predicted distance statistics feature

2. Improved detection logic for jump start time

## V1.0.0
### 2026.03.15

1. Added `LJ/HJ/WJ/CJ/DCJ/SCJ` distance prediction feature

- Added real-time display feature
