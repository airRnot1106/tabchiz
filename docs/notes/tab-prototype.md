# Tab interaction prototype

Question: can Tabchiz feel like Google Maps open in several browser tabs, plus one overview a browser cannot give?
A throwaway prototype held three independent map tabs (スーパー, ジム, カフェ; 25 places each) and an overview derived
from them, and an XCUITest driver ran one script per variant while the simulator recorded video. The prototype, its
videos and its fixture were removed because the fixture held Apple Map Data. Seconds below are XCUITest wall clock
from the first gesture to the last state. XCUITest waits about 2 s after each gesture, so read them as ratios between
variants. No person was timed.

## Safari on iOS 26.5, for reference

- The page shows one glass address capsule with a back button on its left and a "…" button on its right. There is no
  visible tab button and no tab count.
- Grid: "…" > "すべてのタブ" > card is 3 taps. Dragging up from the address capsule opens the grid in 1 gesture.
  (`XCUIElement.swipeUp()` on the capsule was taken as a tap. A press-and-drag of 350 pt worked.)
- A horizontal swipe on the address capsule moves to the neighbouring tab, 1 gesture per neighbour. Small dots at the
  bottom corners hint at neighbours.
- The grid shows two columns of page snapshots with favicon, title and a close button. Bottom: "+", the tab group
  picker and a checkmark to leave.

## Decision 1: tab switching

Script: スーパー → カフェ → ジム → スーパー. Every tab kept its own camera in all three variants, and a pan made in one
tab was still there after visiting another.

| variant | gestures | seconds | what worked | what broke |
| --- | --- | --- | --- | --- |
| bar | 3 taps | 4.5 | Names and colors of all tabs always visible. 1 tap to any tab. Map panning untouched. | Three capsules fill the width at 3 tabs. |
| grid | 6 taps | 12.2 | Thumbnails show each tab's own camera and places. Scales to many tabs. | 2 taps per switch. The map does not show which tabs exist. SwiftUI `Map` thumbnails show an empty tile grid for a moment every time the grid opens. |
| swipe | 4 swipes | 8.2 | 1 swipe to a neighbour, with the map sliding along. | A horizontal drag on the map pans the map and never switches the tab, even a flick from the screen edge. Switching works only on the bottom strip. Reaching tab N costs N−1 swipes. |

Choice: bar. Fewest gestures, no hidden state, no gesture conflict.

## Decision 2: entering and leaving the overview

| variant | gestures in / out | seconds in+out | what worked | what broke |
| --- | --- | --- | --- | --- |
| item in the bar | 1 tap / 1 tap | 4.3 | "全体" is a labelled item in the same control, highlighted while active. One control shows the whole mode. | Takes a slot in the bar. |
| card in the grid | 2 taps / 2 taps | 9.9 | The overview card reads as "everything". | 2 taps each way. |
| last page of swipe | 3 swipes / 3 swipes | 12.4 | Nothing beyond the swipe variant. | Cost grows with the number of tabs. |
| glass button | 1 tap / 1 tap | 4.4 | Same place on every tab. Toggles back to the tab you came from. | Icon only. In the overview the bar shows no selected tab and the button turns into "×": two controls for one mode. |
| pinch | 2 pinches / 2 pinches | 9.9 | Feels like zooming out of one tab into everything. | Not discoverable. Two ordinary zoom-outs crossed the threshold by accident, and zooming into the overview threw the user back into a tab. MapKit reports the pinch only when the region change ends, so the switch is a jump after the fingers lift. |

Thresholds used for pinch: enter above 0.11 degrees of latitude, leave below 0.012 degrees.

Choice: an item of the bar. It is the only variant where one control shows the mode completely.

## Decision 3: pins in the overview

The camera fits all 75 places.

| variant | where is each tab concentrated? | which tab is a place in the dense center? | seconds | notes |
| --- | --- | --- | --- | --- |
| cluster per tab | Yes | Yes, by color and count | about 3 | 36 marks of two kinds overlap. Bubbles of different tabs land on the same spot, so they are shifted by tab (`centerOffset`). |
| donut cluster for all tabs | Only partly: shares have to be added up across donuts | Shows that all tabs are there, not which place is which | about 5 | Cleanest image, 15 marks. A tap on a mixed donut cannot pick a tab. |
| no clustering | Yes, fastest | In the core, dots cover each other | 1–2 | 75 dots of 13 pt, tap targets far below 44 pt. |
| cluster per tab, singles as dots | Yes, with less clutter | Yes | about 2 | Smaller dots cluster less, so more singles stay. |

Light and dark gave the same answers. System orange, cyan and green stayed distinct on both map styles.

Choice: cluster per tab, with single places drawn as dots. A cluster then belongs to exactly one tab, which makes the
jump below well defined.

## Jumping from the overview

- Pin or dot → tab: 1 tap, landing in that tab on the place with its card and a back button.
- Cluster of one tab → tab: 1 tap, landing on that tab's results with the camera on the cluster's places.
- Mixed donut → no tab to jump to. The overview zooms instead until the donut splits.
- Back after a jump returned to the results page, but the camera stayed on the jumped place.

## What the data shape needed

`Browser { tabs; mode }`, `MapTab { id; color; camera; page; history }`, `Page = blank | results | place` and a derived
overview held. Four additions came out of it:

1. The overview mode has to remember which tab was active.
2. Back wants the camera per page, so each history entry stores its camera.
3. A place page needs the results around it, which come from the latest results entry in the history.
4. The overview has a camera of its own, so it reopens where it was left.

## API limits found

- `MKMapView` inside a paging `TabView` takes every horizontal drag, including one from the screen edge.
- A Liquid Glass capsule without a `contentShape` lets drags through to the map below.
- Per-tab clustering needs `displayPriority = .required` on every view and still stacks bubbles of different tabs on
  the same coordinate.
- A continuous pinch-to-overview transition would need a gesture recognizer next to the map's.
- XCUITest: a pinch on the window starts its fingers on the chrome and only pans the map. The accessibility tree lists
  stale cluster views, so cluster counts read from it are unreliable.
- `@State var b = Browser()` built the model twice at launch.
