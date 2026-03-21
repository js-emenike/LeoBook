# LeoBook Design System v3.0

> **Dart SDK**: 3.8.1 · **Flutter**: ≥3.22 · **Font**: DM Sans (GoogleFonts) · **Palette**: UI Inspiration (Night) · **Updated**: 2026-03-21

---

## 1. Color Palette

All tokens in `lib/core/constants/app_colors.dart`.

| Token | Hex | Role |
|---|---|---|
| `primary` (coloured) | `#775CDF` | Purple accent — CTAs, active elements, sliders |
| `primaryLight` | `#8B6FE8` | Hover tint |
| `primaryDark` | `#6247C5` | Pressed / on-tap |
| `secondary` | `#8B5B8C` | Secondary button fill |
| `success` | `#1CDB2F` | Correct predictions, availability dots |
| `warning` | `#F5CB3E` | Countdown timers, caution states |
| `error` / `liveRed` | `#EB3333` | Error / live match pulse |
| `accentPrimary` | `#B9C0FF` | Links and accent text |
| `accentSecondary` | `#B5C89C` | Secondary accent fills |
| `neutral900` (globe) | `#1C1B20` | Scaffold background |
| `neutral800` (island) | `#24232A` | Cards, modals, bottom sheets |
| `neutral700` (on_island) | `#313038` | Nav bars, borders, elevated elements |
| `neutral600` (on_island_hover) | `#3B3A42` | Hover states |
| `textPrimary` | `#FFFFFF` | Headings, body text on dark |
| `textSecondary` | `#E2E2E2` | Secondary body text |
| `textTertiary` | `#9F9F9F` | Captions, disabled, hints |
| `divider` | `#24232A` | Dividers / dark |
| `dividerLight` | `#303030` | Dividers / light |
| `surfaceCard` | `#24232A` | Card background = island |

---

## 2. Typography Scale

All in `lib/core/theme/leo_typography.dart`. Font: **DM Sans** via `GoogleFonts.dmSans()`.

| Style | Size (sp) | Weight | UI Inspiration Name |
|---|---|---|---|
| `displayLarge` | 40 | 700 | Title XL |
| `displayMedium` | 36 | 700 | — |
| `displaySmall` | 32 | 700 | — |
| `headlineLarge` | 28 | 700 | — |
| `headlineMedium` | 24 | 700 | Title L |
| `headlineSmall` | 20 | 700 | Title M |
| `titleLarge` | 18 | 700 | Title S |
| `titleMedium` | 17 | 500 | — |
| `titleSmall` | 14 | 500 | — |
| `bodyLarge` | 17 | 400 | Body |
| `bodyMedium` | 14 | 400 | Subhead (regular) |
| `bodySmall` | 12 | 400 | Caption |
| `labelLarge` | 14 | 700 | Subhead (bold) |
| `labelMedium` | 12 | 500 | Caption (medium) |
| `labelSmall` | 11 | 500 | Micro labels |

---

## 3. Spacing Grid

Base unit: **4dp**. All in `lib/core/constants/spacing_constants.dart`.

| Token | dp | Semantic use |
|---|---|---|
| `xs` | 4 | Icon gaps, micro spacing |
| `sm` | 8 | Tight padding, row gaps |
| `md` | 12 | Input content padding |
| `lg` | 16 | Standard padding |
| `xl` | 20 | Section gaps |
| `xl2` | 24 | Button horizontal padding |
| `xl3` | 32 | Card vertical spacing |
| `xl4` | 48 | Touch targets |
| `xl5–xl8` | 64–128 | Page-level spacing |
| `cardPadding` | 16 | `GlassCard` default padding |
| `cardRadius` | 16 | Card border radius |
| `borderRadius` | 12 | Input / button radius |
| `chipRadius` | 100 | Pill / stadium |
| `componentGap` | 16 | Column gaps between components |
| `screenPadding` | 20 | Horizontal screen margins |
| `sectionGap` | 32 | Between page sections |
| `touchTarget` | 48 | Min tap area (WCAG 2.5.5) |
| `iconSize` | 24 | Standard icon |

---

## 4. Responsive Breakpoints

`lib/core/constants/responsive_constants.dart`

| DeviceType | Width | Behaviour |
|---|---|---|
| `mobile` | < 480dp | Single-column, compact |
| `tablet` | 480–767dp | Two-column, larger type |
| `desktop` | ≥ 1024dp | Sidebar nav, multi-column |

```dart
final type = Responsive.of(context); // → DeviceType
final fontSize = Responsive.sp(context, 14); // fluid, clamped 0.65×–1.6×
```

---

## 5. Component Gallery

### LeoButton — `shared/buttons/leo_button.dart`

| Param | Type | Default |
|---|---|---|
| `label` | `String` | required |
| `onPressed` | `VoidCallback?` | required (null = disabled) |
| `variant` | `LeoButtonVariant` | `primary` |
| `size` | `LeoButtonSize` | `medium` |
| `leadingIcon` | `Widget?` | null |
| `isLoading` | `bool` | false |
| `fullWidth` | `bool` | false |

```dart
LeoButton(label: 'View Prediction', onPressed: () {});
LeoButton(label: 'Filter', variant: LeoButtonVariant.secondary, isLoading: true, onPressed: null);
```

---

### GlassCard — `shared/cards/glass_card.dart`

```dart
GlassCard(
  onTap: () => openDetail(match),
  child: Column(children: [
    Text(match.homeTeam, style: LeoTypography.titleMedium),
    LeoBadge(label: 'LIVE', variant: LeoBadgeVariant.live),
  ]),
);
```

---

### LeoBadge — `shared/badges/leo_badge.dart`

| Variant | Colour | Use |
|---|---|---|
| `live` | Red tint + dot | Ongoing match |
| `finished` | Neutral | FT result |
| `scheduled` | Primary tint | Upcoming |
| `prediction` | Secondary tint | Leo prediction |
| `betPlaced` | Success tint | Placed bet |
| `custom` | Caller colours | Freeform |

```dart
LeoBadge(label: "LIVE 34'", variant: LeoBadgeVariant.live);
LeoBadge(label: 'FT', variant: LeoBadgeVariant.finished, size: LeoBadgeSize.small);
```

---

### LeoChip — `shared/chips/leo_chip.dart`

```dart
LeoChip(label: 'Premier League', selected: true, icon: Icons.sports_soccer, onDelete: clearFilter);
```

---

### LeoTextField — `shared/forms/leo_text_field.dart`

```dart
LeoTextField(
  label: 'Email', hint: 'you@example.com',
  keyboardType: TextInputType.emailAddress,
  validator: (v) => v!.contains('@') ? null : 'Invalid email',
);
```

---

### LeoSwitch / LeoCheckbox — `shared/toggles/`

```dart
// Theme toggle
LeoSwitch(
  value: context.watch<ThemeCubit>().isDark,
  onChanged: (_) => context.read<ThemeCubit>().toggleTheme(),
  semanticLabel: 'Toggle dark mode',
);
```

---

## 6. Animation Guidelines

`lib/core/animations/leo_animations.dart`

| Token | Value | Curve | Use case |
|---|---|---|---|
| `LeoDuration.micro` | 100ms | — | Immediate feedback |
| `LeoDuration.short` | 200ms | `smooth` | Press / border transitions |
| `LeoDuration.medium` | 300ms | `gentle` | Fade-in / slide-in |
| `LeoDuration.long` | 500ms | `gentle` | Pulse / shimmer |
| `LeoDuration.xlong` | 800ms | `bouncy` | Page hero entrance |
| `LeoCurve.smooth` | `easeInOutCubic` | — | General transitions |
| `LeoCurve.bouncy` | `easeOutBack` | — | Celebratory |
| `LeoCurve.sharp` | `easeOutExpo` | — | Dismiss / collapse |
| `LeoCurve.gentle` | `easeInOut` | — | Subtle bg animations |

**Stagger pattern:**
```dart
ListView.builder(
  itemBuilder: (ctx, i) => LeoFadeIn(
    delay: Duration(milliseconds: i * 50),
    child: MatchCard(match: matches[i]),
  ),
);
```

---

## 7. Accessibility Checklist

- [x] 7:1 contrast for all `textPrimary` on `neutral900` (AAA)
- [x] 4.5:1 minimum on all interactive elements
- [x] 48×48dp minimum touch targets (`LeoButton`, `LeoChip`)
- [x] `Semantics(button: true)` on all tappable widgets
- [x] `Semantics(toggled:)` on `LeoSwitch`
- [x] `Semantics(checked:)` on `LeoCheckbox`
- [x] `Semantics(label:)` on `MatchCard` (team + status)
- [x] Focus ring (2px `AppColors.primary`) on `LeoTextField`
- [x] Error messages exposed via `liveRegion: true`
- [ ] Team crest `CachedNetworkImage` — add `Semantics(image: true, label:)`
- [ ] Decorative icons — wrap with `ExcludeSemantics`

---

## 8. Migration Guide

```dart
// Color
Color(0xFF1E88E5)  →  AppColors.primary

// Spacing
EdgeInsets.all(16)  →  EdgeInsets.all(SpacingScale.lg)

// Typography
TextStyle(fontSize: 14, fontWeight: FontWeight.w600)  →  LeoTypography.labelLarge

// Card
Container(decoration: BoxDecoration(...))  →  GlassCard(child: ...)

// Button
ElevatedButton(onPressed: f, child: Text('X'))  →  LeoButton(label: 'X', onPressed: f)

// Theme toggle — in main.dart (already wired):
BlocProvider<ThemeCubit>(create: (_) => ThemeCubit())
// In widget:
LeoSwitch(value: context.watch<ThemeCubit>().isDark, onChanged: (_) => context.read<ThemeCubit>().toggleTheme())
```

---

## File Map

| File | Purpose |
|---|---|
| `core/constants/app_colors.dart` | Color tokens + legacy aliases |
| `core/theme/leo_typography.dart` | M3 type scale (Inter) |
| `core/constants/spacing_constants.dart` | 4dp grid + semantic aliases |
| `core/constants/responsive_constants.dart` | Breakpoints + Responsive helpers |
| `core/theme/app_theme_v2.dart` | Dark + Light ThemeData |
| `core/theme/theme_cubit.dart` | ThemeMode Cubit |
| `core/animations/leo_animations.dart` | Duration/Curve tokens + widgets |
| `shared/buttons/leo_button.dart` | Primary button |
| `shared/cards/glass_card.dart` | Glass surface card |
| `shared/badges/leo_badge.dart` | Status badge |
| `shared/chips/leo_chip.dart` | Filter chip |
| `shared/forms/leo_text_field.dart` | Animated input |
| `shared/toggles/leo_switch.dart` | Toggle switch |
| `shared/toggles/leo_checkbox.dart` | Checkbox |

*Last updated: 2026-03-14 — LeoBook Engineering / Materialless LLC*
