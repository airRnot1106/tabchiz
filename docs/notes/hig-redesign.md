# HIG redesign of the main screen (iOS 26)

The main screen was redesigned to follow the iOS 26 Human Interface Guidelines and Liquid Glass. The domain rules
(Workspace, nearest place, five tabs, shared region, request budget) are unchanged. This note records what was off
before, the two layouts compared in the real app, the choice, and the guideline behind each decision.

HIG pages were read as JSON from `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json`.
API names were checked against the iPhoneSimulator 26.5 SDK swiftinterface and MapKit headers.

## What was off before

1. The tab chips were custom capsules with thick colored strokes on an opaque bar under the status bar. They clipped the
   third chip mid-word and did not use Liquid Glass or a system control.
2. The add button was a hand-drawn circle with a custom stroke, not a system button style.
3. The selected and nearest places were hand-drawn badges with bordered label boxes ("直線 … m"), and the other places
   became hand-drawn dots. None of it was a system marker, and the text used fixed point sizes, so it ignored Dynamic
   Type.
4. Tab colors were hard-coded RGB values with no dark or increased-contrast variants.
5. The off-screen indicators were custom colored circles and pills with fixed 11 pt and 15 pt text.
6. The "このエリアで再検索" button used `.borderedProminent` with a black tint.
7. Every place had a required display priority and clustered only with its own tab. Markers of different tabs piled on
   top of each other in dense areas, and a tap selected whichever marker was on top (the reported wrong-place bug).
8. The selection was shown only on the map. There was no place card or list, so a pair a few meters apart was hard to
   read and the distance labels overlapped.
9. There was no user-location button, no scale, and no search field: adding a tab went through a separate modal sheet.
10. System strings were English ("Close", "Cancel", "Legal") because the project had no Japanese development region.

## Variants compared

Both variants ran in the real app behind a DEBUG launch argument, on the same bundled fixture
(`-UITestFixture -SeedTabs スーパー,ジム,カフェ`, five tabs with `薬局,公園` added), in light, dark and
accessibility XXXL text. Both shared the new map layer: system balloon markers, clusters across all tabs, a muted map,
and a list to pick from when a cluster cannot be split.

- A, Maps style: a nonmodal sheet that always rests over the map with detents collapsed (search field only), medium
  and large. It holds the system search field, the tabs as a layer list with switches, the selected place with the
  nearest place of each other tab, and the places of a cluster to pick from.
- B, floating Liquid Glass: glass capsules for the tabs in a `GlassEffectContainer`, a glass add button, and a glass
  card at the bottom for the selection, over a full-screen map.

Observations from the screenshots:

- Both answer "which gym is nearest to supermarket X" with the same map drawing and the same list of nearest places.
- B keeps more of the map visible, which A gives up at the medium detent.
- B truncated badly at accessibility XXXL: the place names in the card were cut to two characters, the distance
  became "直線 13…", the tab strip showed one capsule, and the add button overlapped its label. A wrapped every line and
  scrolled.
- B's add button glass merged with the last capsule, and the capsule text showed through it ("力フェ" with a "+" on it).
- B put five colored symbols on glass controls. A keeps the color in the content layer (the list rows and the markers).
- B needed a second modal sheet to add or edit a tab. A edits in place with the sheet's search field.

## Choice: A

A follows the guidelines below more closely and holds up at large text sizes. B was deleted.

- Sheets: "In iOS and iPadOS, a sheet can be either modal or nonmodal. When a nonmodal sheet is onscreen, people use its
  functionality to affect the parent view without dismissing the sheet."
  https://developer.apple.com/design/human-interface-guidelines/sheets
  The sheet uses `presentationBackgroundInteraction(.enabled(upThrough: .medium))` and `interactiveDismissDisabled()`.
- Sheets: "In an iPhone app, consider supporting the medium detent to allow progressive disclosure of the sheet's
  content." and "Include a grabber in a resizable sheet." The detents are collapsed, `.medium` and `.large`, and the
  system draws the grabber.
- Maps: "The system presents the full callout style place card in a popover style in iPadOS and macOS, and as a sheet
  in iOS." https://developer.apple.com/design/human-interface-guidelines/maps
  The selection detail is a sheet state, the same place a Maps place card takes on iPhone.
- Materials: "Use Liquid Glass effects sparingly." and "Don't use Liquid Glass in the content layer."
  https://developer.apple.com/design/human-interface-guidelines/materials
  The sheet gets Liquid Glass from the system. The only custom glass is the "このエリアを検索" button
  (`.buttonStyle(.glass)`). The off-screen indicators are informational, so they use `.regularMaterial`.
- Color: "Apply color sparingly to the Liquid Glass material, and to symbols or text on the material."
  https://developer.apple.com/design/human-interface-guidelines/color
- Searching: "If search is important, give it a primary position in your app or view."
  https://developer.apple.com/design/human-interface-guidelines/searching
  The sheet's top is a system `.searchable` field, and presets appear as suggestions.
- Typography: "Keep text truncation to a minimum as font size increases."
  https://developer.apple.com/design/human-interface-guidelines/typography

## Map layer decisions

- Markers are `MKMarkerAnnotationView` in the tab's color with the tab's SF Symbol. Maps: "The default annotation marker
  has a red tint and a white pin icon. You can change the tint to match the color scheme of your app."
- The selected place uses MapKit's own selected marker (enlarged balloon). Maps: "Clearly identify elements that people
  select." Other places stay as translucent markers in the background.
- Places of all tabs cluster together, so markers of different tabs no longer cover each other. Maps: "Cluster
  overlapping points of interest to improve map legibility. ... As people zoom in on a map, clusters expand to
  progressively reveal individual points of interest." A cluster takes the tab's color when all members belong to one
  tab, and gray when they come from several.
- Tapping a cluster zooms in until it splits. When its places are within 25 m, or the map already shows less than
  150 m, the sheet lists the places instead and the person picks one. This fixes the wrong-place bug: a tap never lands
  on one of several stacked markers.
- The map uses the muted emphasis style. Maps: "The muted style ... is great if you have a lot of information-rich
  content that you want to stand out against the map."
- The Apple logo and legal link sit 10 pt above the collapsed sheet. Maps: "if your app lets people pull up a custom card
  from the bottom of the screen, place the Apple logo and legal link 10 points above the lowest resting position of the
  card." The medium sheet covers them, which the same section allows ("It's fine when parts of your interface
  temporarily cover the logo and link").
- The map shows the system user-tracking button (`showsUserTrackingButton`) and the scale while zooming. Rotation stays
  off because the off-screen indicators assume north is up, so the compass never appears.

## Tab colors

System colors adapt to Dark Mode and Increase Contrast. Color: "When possible, use system colors, which already define
variants for all these contexts." The stored `TabColor` cases are unchanged, so saved tabs keep their colors:

| Stored case | System color |
| --- | --- |
| orange | systemOrange |
| skyBlue | systemCyan |
| bluishGreen | systemGreen |
| vermillion | systemPink |
| reddishPurple | systemPurple |

Blue is left out because the map draws water, transit lines and the user's location in blue. Pink was taken over red
because red sits close to orange on the map. The five stayed distinguishable in the light and dark screenshots. Each tab
also has its own SF Symbol, following Color: "Avoid relying solely on color to differentiate between objects".

## Not done

- Rotation and the compass stay off (see above).
- The overview at the default zoom shows several large gray clusters in the dense center. This is what clustering
  across tabs costs. The per-tab color is visible again after one or two cluster taps, and the selection answers the
  question regardless.
- The fixture has no data for 薬局 and 公園, so the five-tab screenshot shows those layers with 0 results.
