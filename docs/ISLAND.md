# The island

A small reward for keeping the app up to date: every month in which you stay within your limits you plant something
on an island. Each year is a new island; the old ones stay, and together they make an archipelago.

## Rules

### One plant per month

A closed month earns a plant when both are true:

1. **Within the limits.** The total spent in the categories that have a monthly limit is not more than the sum of
   those limits. One category over its limit does not cost the month if the others make up for it; that category
   already has its own warnings.
2. **Recorded well.** See below: not recording would otherwise look like saving.

There must be at least one limit. Without limits nothing can be planted, and the island says so and invites you to
set one.

A month over the limits plants nothing, and nothing is taken away. A month is evaluated when you plant, not at
midnight of the last day, so receipts added on the 1st or 2nd of the next month still count. An eligible month stays
plantable until you choose: if you do not open the app in February, in March you find two plants to place.

### Which limits count

The limits that count for a month are the ones in force at the end of the 5th day. Changes made from the 1st to the
5th count for the current month; later changes count from the next month, and the app says so when you change a limit.
This way a limit cannot be raised on the 28th to save the month.

The app keeps a copy of the limits of each month ("snapshot"). Limits only change inside the app, so it is enough to
take the copy before any change made after the 5th, and on start-up for months whose 5th has passed without a copy.

In the month in which the island arrives with an update, nobody knew about the rule, so the limits at the first
start-up count.

### Recorded well

The recording rhythm is modelled as a Poisson process with rate λ (records per day). For month M:

- History: the records in the 90 days before M, counted from the day of the first record ever (days before you used
  the app do not count). With N records over T days, the estimate is the **prudent** one,
  λ = max(0, (N − 2√N) / T): with little data it is well below the mean, so the check is lenient; overestimating λ
  is the only harmful mistake (it would deny the plant to someone who records normally).
- Only the days of M from the first record ever are considered.
- **Count:** the records in M must be at least half of the expected ones, λ × days considered. Half, because saving
  can also mean going out less.
- **Gaps:** no run of days without records longer than G, where G = ln(3000·λ) / λ, kept between 5 and 14 days (14
  when λ = 0). With this G, a gap that long happens by chance less than once in a hundred normal months.

| Rhythm | Longest gap |
|---|---|
| 2 a day | 5 days |
| 1 a day | 8 days |
| 1 every 2 days or less | 14 days |

The date of the expense counts, not when it was entered: recording all the week's receipts on Sunday is fine. A
month without any record is never recorded well. With no history (the first month) only the 14-day gap remains.

### The gift

When the island first appears (with the update, or on a new install) the previous month gets a plant as a gift, to
show how it works, with no checks. Except in January: the previous month would belong to last year's island.

## Islands

- One island per calendar year. Its slots are the months of that year from the first month of the island: the gift
  month, or the current month when there is no gift. A full year has 12 slots; the first island is usually smaller
  (opened in November 2026: October as a gift, November, December, so 3 slots).
- You choose the plant from the whole catalog, repeats allowed, and the slot it goes in.
- Empty slots are meadow, sand or stones, never holes: more plants only make the island greener.
- **Reward at the centre.** When the year is over and more than half of its slots are planted (7 of 12; 2 of 3 in a
  first island of 3), something special appears at the centre. A surprise, different every year, in order:
  lighthouse, fountain, small temple, statue, obelisk, then again. All 12 planted is the complete island.
- Besides the slots, every island has lanterns that light up at night, a few rocks and a path.

## Look

- **Natural colours** for every plant. Each species is a set of parameters on one of seven base shapes drawn in code
  (round-crowned tree, fruit tree, conifer, palm, shrub, flower, succulent); no images, the APK does not grow. The
  month of planting is the seed of small variations, so two olive trees are never identical. Plants appear adult.
- **Day and night follow the theme**: light theme, the island by day; dark theme, by night, with darker sea, dimmer
  plants and the lanterns lit. With the system theme many phones switch to dark at sunset, so the island follows the
  real time on its own.
- **The moon** follows the real phases, computed on the phone from the 29.53-day synodic month and a known new moon.
  Visible at night.
- **Seasons** of the northern hemisphere (the southern one would need the position): leaves, flowers and fruits follow
  the month. The almond blossoms in February, the maple turns red in autumn, deciduous trees are bare in winter. The
  catalog shows each plant at its best, with when it flowers.

### Catalog

| Base shape | Plants |
|---|---|
| Round-crowned tree | oak, olive, maple, birch, weeping willow, stone pine |
| Fruit tree | lemon, orange, apple, cherry, almond, fig |
| Conifer | fir, cypress |
| Palm | date palm, dwarf fan palm |
| Shrub | lavender, rosemary, oleander, hydrangea, bougainvillea |
| Flower | sunflower, poppy, daisy, tulip, rose, iris |
| Succulent | prickly pear, agave, aloe, cactus |

New species are a new entry in the catalog, and can be announced in "what's new".

## In the app

- A plant icon in the Summary bar, left of the painting's (i) (next to the settings when the (i) is hidden), with a
  dot when there is something to plant. It opens the island of the current year; swiping goes to older islands.
- Planting: choose the plant, then tap a free slot.
- Changing a limit after the 5th shows a note: for the island it counts from the next month.

## Data

- `plantings`: month (yyyymm), plant key, slot, gift flag, planted at.
- `limit_snapshots`: month (yyyymm), limits as JSON (category id to cents).
- Settings: `island_start` (first month of the first island) and `island_gift` (the gift month, if any).
- Both tables are in the backup and in the encrypted database like the rest. Whether a month is eligible, the islands,
  their slots and the reward are computed, not stored.
