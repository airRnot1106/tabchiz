# MapKit search: concurrency, throttling and result shape

Findings from a throwaway prototype that ran MKLocalSearch from the iPhone 17 simulator (iOS 26.5, Debug build, home
network, locale en_JP, language ja-JP) against a 0.02 degree region around one central Tokyo station. The prototype,
its dumps and its logs were removed because they held Apple Map Data, which the Apple Developer Program License
Agreement does not allow an app to store or publish. Only the numbers below were kept.

## Concurrency

Blocks of N concurrent requests (`withTaskGroup`), 8 s apart, in the order 1, 3, 5, 8, 12 and back. Each block moved
the center by 0.0003 degrees and rotated the queries, so no (query, region) pair repeated. 22 of 25 blocks ran before
the host killed the launch process: 139 requests in total.

| N | blocks | wall-clock median (range) ms | per-request median (range) ms | wall / slowest request | errors |
|---|---|---|---|---|---|
| 1 | 5 | 360 (274-1304) | 359 (273-1303) | 1.00 | 0 |
| 3 | 5 | 377 (308-596) | 299 (194-595) | 1.00 | 0 |
| 5 | 4 | 322 (281-477) | 305 (257-476) | 1.00 | 6 loadingThrottled (2 blocks) |
| 8 | 4 | 537 (365-560) | 335 (188-555) | 1.01 | 0 |
| 12 | 4 | 553 (480-867) | 319 (187-860) | 1.01 | 0 |

- All requests of a block started within 10 ms of each other, and the wall-clock equals the slowest request. MapKit
  does not serialize requests on the client.
- The per-request median stays at 300-335 ms. The wall-clock grows with N only because the slowest of N samples sits
  further in the latency tail. The 1303 ms outlier was the first block of a round and looks like a reconnect.
- Three live searches fired together took 262, 307 and 323 ms, 346 ms in total.

## Throttling

The limit is a rate, not a concurrency cap: 50 successful requests in a sliding 60 s window. `RequestBudget` encodes it.

- Both throttle events came when the preceding 60 s held 48 successes: 2 of the 5 requests succeeded and 3 failed.
- N=12 blocks with 17-30 successes in the preceding minute never throttled.
- The error is `MKErrorDomain` code 3 (`loadingThrottled`), userInfo `MKErrorGEOError = -3`. The rejections return in
  2-13 ms, so the client rejects them without a network round trip.
- A single request 10.5 s and 10.8 s after a throttled block succeeded both times, once older requests had left the
  window.
- The budget is enforced on the client by GeoServices. Whether it is per app or per device was not tested.

## Caching

An identical query sent 4 times took 978, 553, 696 and 546 ms with 25 results each time, so no client cache answers
repeats.

## Result shape

| Request | Results | Categories |
|---|---|---|
| natural language "スーパー" | 25 | FoodMarket 22, Bakery 3 |
| natural language "ジム" | 25 | FitnessCenter 19, nil 2, 4 others |
| natural language "カフェ" | 25 | Cafe 23, Restaurant 2 |
| "スーパー" + `.pointOfInterest` + filter `.store` + `regionPriority = .required` | 8 | Store 8, mostly not supermarkets |
| "スーパー" + the same with filter `.foodMarket` | 25 | FoodMarket 25 (21 shared with plain natural language) |
| "ジム" + filter `.fitnessCenter` | 25 | FitnessCenter 25 (18 shared) |
| "カフェ" + filter `.cafe` | 25 | Cafe 25 (16 shared) |
| MKLocalPointsOfInterestRequest, radius 1100 m, `.store` | 50 | all inside one station building |
| MKLocalPointsOfInterestRequest `.foodMarket` | 47 | small stalls around the station |
| MKLocalPointsOfInterestRequest `.fitnessCenter` | 50 | 39 not in the natural language result |
| MKLocalPointsOfInterestRequest `.cafe` | 50 | 47 not in the natural language result |

- A natural language request returns at most 25 items. A points-of-interest request returns at most 50 and favours
  the spot right at the center.
- Filtered natural language results reached 350 m to 1.1 km from the center of a 0.02 degree region.
- Over 22 other queries the counts were 25, except 本屋 (22-23), ホテル (1) and 図書館 (1).
- Over 355 items: `identifier` 353, `alternateIdentifiers` 9 (never equal to `identifier`), `pointOfInterestCategory`
  353, `phoneNumber` 315, `url` 307. The two items without an identifier both came from a points-of-interest request,
  which is why `PlaceID` falls back to the name and the rounded coordinate.
- The iOS 26 `address.fullAddress` and `address.shortAddress` were present on all 355 items,
  `addressRepresentations.cityWithContext` on 139 (an empty string otherwise). `MKAddressRepresentations.regionCode`
  does not exist in the iOS 26.5 SDK.
- `SearchPreset` maps コンビニ to `.foodMarket` because filtering it as `.store` finds nothing, and leaves 病院 out
  because the hospital filter drops every clinic.
