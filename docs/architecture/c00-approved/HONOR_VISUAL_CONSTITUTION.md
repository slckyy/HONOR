> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# HONOR Visual Constitution

This is a production requirement, not decorative guidance.

## Brand character
HONOR must feel luxurious, bespoke, expensive, glossy, reflective, black-diamond, black-and-gold, cinematic, bold, and precise. It should feel closer to a high-end physical instrument or editorial luxury object than a generic SaaS dashboard.

## Material language
Use a controlled system of:
- obsidian and piano black;
- smoked reflective black glass;
- black-diamond facets used sparingly;
- liquid metallic gold with layered tones, not flat yellow;
- champagne-gold highlights;
- warm ivory for high-readability text where useful;
- believable specular highlights and controlled reflections;
- subtle micro-texture/noise;
- precision-machined edges;
- restrained depth.

Gold must be represented through tonal ramps/specular behavior, not `#FFD700` sprayed across the UI.

## Typography
Frozen family direction:
- UI/body: **Manrope** (open-source via a vetted distributable source/Next font loader).
- Editorial/display accents: **Bodoni Moda** used selectively.
- Numbers/metrics favor tabular numeral features where supported.

No default browser/system font stack as primary identity. No unauthorized commercial font packaging.

## Layout
- iPhone portrait is the primary design canvas, desktop is an expansion.
- Primary action and review controls sit in thumb-reachable zones.
- Dense financial/analytics views use progressive disclosure rather than tiny text.
- Cards are not repeated generic rounded rectangles; use editorial groupings, machined panels, dividers, insets, rails, and intentional surface hierarchy.
- Avoid cookie-cutter left sidebar desktop layouts.

## Prohibited production patterns
- default browser controls;
- generic Tailwind cards;
- stock SaaS dashboard grids;
- arbitrary gray palettes;
- same default radius everywhere;
- generic glassmorphism haze;
- random gradients;
- emoji as product icons;
- flat yellow masquerading as gold;
- generic loading spinner/skeleton defaults;
- ordinary unstyled selects;
- ChatGPT-style message list as Polli's primary UI;
- obvious templates;
- cheap RGB/neon gaming treatment.

## Motion constitution
Motion must be weighted, smooth, deliberate, inertial, restrained, and physically coherent.

Every interactive control has meaningful states: idle, pressed, loading, success, warning, error, disabled. Motion communicates state/causality; it is not confetti.

`Generate Tomorrow` is the signature control:
- visually reads as precision hardware;
- press has small weighted travel/compression;
- state transition shows energy transfer/progress rather than generic spinner;
- haptics are suggested where web platform safely supports them, but never required for understanding;
- reduced-motion mode replaces spatial/continuous effects with short opacity/state changes.

## iPhone requirements
- CSS `env(safe-area-inset-*)` respected on every edge.
- Dynamic Island/notch danger area accounted for; no critical controls under it.
- Minimum primary touch target 44×44 CSS px; important thumb actions larger.
- Portrait acceptance at representative widths: 320, 375/390, 393, 430 CSS px and current Safari behavior.
- PWA manifest/installability, standalone display, icons, theme/background colors.
- Offline shell for navigation and safe cached read-only state.
- Clear reconnect/retry states; no silent failed mutation.
- VoiceOver names/roles/states and logical focus order.
- Contrast targets WCAG AA minimum for normal content; decorative gold may not carry essential meaning alone.
- Reduced motion and transparent fallback visuals.
- Avoid sustained high-cost shaders when app is backgrounded/low power; cap rendering resolution/device pixel ratio as needed.

## Polli visual constitution
Polli is an abstract realtime luminous intelligence orb, not a face/avatar.

Primary implementation: Three.js/WebGL/WebGPU-capable custom shader or equivalent real-time rendering. It must **not** be a PNG/GIF/pre-rendered MP4 and not a simple CSS radial-gradient circle.

Material: obsidian/black-diamond shell with internal gold refraction/energy, restrained caustic-like motion, subtle surrounding light influence.

Frozen states:
- `IDLE` — slow internal breathing, near-still.
- `LISTENING` — mic amplitude gently opens/reacts; gold energy gathers toward input side.
- `THINKING` — deeper internal refraction/structured circulation, no frantic spinner.
- `TOOL_EXECUTION` — brief precise rings/facets/linked metric glints indicating external work.
- `SPEAKING` — output amplitude modulates surface/internal light coherently.
- `SUCCESS` — controlled warm resolve/pulse.
- `ERROR/OFFLINE` — energy collapses/dims with clear accessible text/state; no alarming flashing.

Mic/output amplitude input must be smoothed. Shader performance degrades gracefully: static/generated CSS/SVG fallback retaining material hierarchy and state, not a generic circle.

Transcript is secondary. Live contextual metric cards may surface beside/below the orb when Polli calls finance/performance tools.

## Loading/error states
Use domain-specific state text and material transitions. Example: a render row shows stage (`Transcribing`, `Planning cuts`, `Mixing audio`, `QC`) and durable progress where meaningful. Generic skeleton screens are not the final production default.

## Acceptance bar
A builder must test actual screenshots/video on iPhone-sized viewports and document visual QA. “Black background + yellow text” fails this constitution even if technically functional.
