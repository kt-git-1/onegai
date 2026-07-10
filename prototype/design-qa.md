# Design QA

## Comparison Target

- Source visual truth: `/Users/kaito/workspace/onegai/docs/design/onegai_priority1_local_preview_locked.png`
- Implementation: `http://localhost:4173/`
- Viewport: 393 x 852
- Theme: light
- Compared states: onboarding 1, registration / login, home own bank normal, charin result
- Additional checked states: all 18 Priority 1 screens, email form valid/invalid, profile emoji optional, invite waiting, request selection, charin confirmation, reward filters, record stamp popover

## Evidence

- Full source board: `/Users/kaito/workspace/onegai/docs/design/onegai_priority1_local_preview_locked.png`
- Onboarding implementation: `/Users/kaito/workspace/onegai/prototype/onboarding1.png`
- Auth comparison: `/Users/kaito/workspace/onegai/prototype/compare-auth.png`
- Home comparison after fixes: `/Users/kaito/workspace/onegai/prototype/compare-home-final.png`
- Charin comparison after fixes: `/Users/kaito/workspace/onegai/prototype/compare-charin-final.png`

Focused comparison was required for auth, home, and charin because the full 18-screen source board is too small to assess typography, mascot placement, card spacing, and result-screen hierarchy.

## Findings

No actionable P0, P1, or P2 findings remain.

### Fonts and typography

- The implementation uses the confirmed iOS system-font direction with Japanese system fallbacks.
- Heading, body, caption, button, and large-number hierarchy follow the visual-foundation tokens.
- Letter spacing is 0. Large balances use tabular numbers.
- No clipping or unintended wrapping was found at 393 x 852.

### Spacing and layout rhythm

- Phone frame is fixed at 393 x 852 across all screens.
- Screen margins, card padding, section gaps, fixed CTA placement, and bottom navigation remain inside the frame.
- All 18 screens report 393 px document width with no horizontal overflow.
- Home and charin preserve the source composition while applying the approved higher-fidelity spacing scale.

### Colors and visual tokens

- Background, surface, primary, heart, text, border, success, error, and overlay values map to the approved visual-foundation tokens.
- Primary CTA text uses dark brown rather than white, matching the approved direction.
- State colors include text or icons and are not the only state signal.

### Image quality and asset fidelity

- The supplied cleaned piggy-bank PNG is used directly in every mascot placement.
- Transparency, aspect ratio, and crop are preserved. No CSS or SVG substitute is used for the mascot.
- UI icons use one consistent icon library. Emoji remain only where the product specification defines user content icons.

### Copy and content

- App name, onboarding copy, invite wording, charin result, reward labels, and navigation labels match the canonical wireframe specification.
- Profile emoji is optional and the CTA depends only on a valid non-empty name.

### States and interactions

- Onboarding navigation updates the selected screen.
- Email registration validation enables the CTA only when all values are valid.
- Request charin opens confirmation and returns to home after the result state.
- Charin result auto-returns after 1.8 seconds and continues the undo toast on home.
- Home target states, invite expiry, reward filters, ticket tabs, and stamp popover are available in the prototype.
- Browser console warning/error check: none.

### Accessibility and viewport

- Inputs have visible labels and focus borders.
- Buttons and icon controls use semantic elements and accessible labels where the visible icon has no text.
- Primary touch targets meet the 44 pt minimum.
- Every screen was checked for controls or text outside the 393 x 852 viewport; none were found.

## Comparison History

### Iteration 1

- P2: Home contained internal review-state controls that were not part of the source UI.
- P2: Charin result contained a visible `ホームへ` button even though the confirmed behavior is automatic return.

Fixes:

- Moved home state controls to the desktop-only review rail.
- Removed the visible home button and implemented automatic return after 1.8 seconds.

### Iteration 2

- Post-fix evidence: `compare-home-final.png` and `compare-charin-final.png`.
- No actionable P0, P1, or P2 mismatch remains.

## Follow-up Polish

- P3: Dynamic Type at accessibility sizes should be validated again when the screens are implemented in SwiftUI.
- P3: The final animation timing and haptic/audio treatment require native-device verification.

final result: passed
