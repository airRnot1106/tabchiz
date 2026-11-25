# Drawing several tabs on one map

Observations from a throwaway MapKit prototype that drew three result sets (25 places each) on one map, to answer
"which gym is nearest to supermarket X?". Its fixture, screenshots and logs were removed because they held Apple Map
Data. Seconds are one person's reading time from the screenshots, not a timed study.

## Display

- Overlaying all layers on one map is the only option that shows two layers at once. Small multiples (one short map
  per tab) and switching between layers cannot answer a question across tabs.
- At a zoom that fits all 75 places, the dense center becomes a pile of about 40 overlapping markers, and MapKit hides
  the colliding titles: only about 6 isolated markers had labels.
- The question gets answered by computing the nearest place and drawing it, not by reading an overlay. An overlay
  alone needs a 250-700 m zoom and still leaves the distance to a guess.
- Drawing the pair with a straight line and dimming the other places with opacity did not help: dimmed markers still
  covered X and the label. Drawing the other places as 9 pt dots let X, the line and the gym stand out within about
  1 s. A camera fitted to the pair was the clearest view. MapKit then hid the titles of X and the gym because they
  collided with the label, so the place card has to name them.

## Clustering

- With a `clusteringIdentifier` per tab and the default `displayPriority`, clusters and pins of different tabs collide
  and MapKit hides the lower-priority view: about 22 of 25 cafes disappeared with no count. One identifier for all
  tabs had the same bug: the counts added up to about 35 of 75.
- With `displayPriority = .required` on every pin and cluster, nothing is hidden and the counts add up. Every marker
  view therefore sets it before MapKit can hide it.
- One cluster for all tabs is the least cluttered view, but it merges X and its gym into one marker, so it is good for
  "where is everything" and bad for comparing tabs.

## Off-screen indicators

- An arrow with a distance per tab is readable in the tab's color, but when every tab already has places on screen it
  adds noise, can cover markers at the screen edge, and can point past a closer place that is visible. It helps only
  for a tab with no place on screen.
