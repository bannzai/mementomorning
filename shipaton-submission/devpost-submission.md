# Memento Morning

English submission draft, prepared on September 17, 2026. Comments identify the maker's remaining checks before submission; this is not a claim that all submission requirements have been completed.

## One-line summary

An iPhone alarm that asks what matters today—and turns your answers into a journal of your life.

## What it does

Each morning begins with one question: “If today were your last day, what would you want to do?” The question appears over the front camera, so you can answer while looking at yourself. Finishing the recording completes your answer; text input is also available. An evening reflection brings you back to what you said that morning.

The answers accumulate in a journal. Answered mornings also become physical dots in the home-screen background that settle together and respond to the phone's tilt, with a separate monthly calendar for revisiting dates. After seven answered mornings, “Seven Mornings” brings those answers onto one page and lets you share them as an image.

The alarm uses iOS 26 AlarmKit. Its stop intent checks whether today's answer exists and schedules a follow-up when needed, subject to the user's snooze setting and plan. Completing an answer removes that morning's remaining alarms. iOS still owns its system stop controls; this is a follow-up mechanism, not an unbypassable lock. The free plan limits follow-ups, while Premium can enable unlimited follow-ups.

Journal data is stored locally with SwiftData. Video answers are saved in Photos, where the user's own iCloud Photos settings may apply. Speech transcription requests on-device recognition only; when permission or on-device support is unavailable, the text can be edited manually. The app does not send answer content to its own server. RevenueCat handles purchase-related communication separately.

## Why I built it

I started with a simple idea: an alarm that asks what I would want to do if today were my last day. I chose the name Memento Morning on August 13, 2026, combining memento mori with the beginning of a day. I wanted the answer to outlast the alarm: the lasting product is the journal that forms as those mornings add up.

That led to a quiet visual direction, without celebratory badges or confetti. The moment is between the person and their own answer. Seven answers together, or a pile of mornings on a screen, can make the passage of time tangible without turning it into a score.

<!-- TODO(bannzai): Confirm this first-person account against your own motivation. Add a specific personal experience only if it is true; the idea record establishes the concept and naming, not a personal history of regret or changed habits. Source: https://github.com/bannzai/ideamemo/issues/187 -->

## How it uses RevenueCat

The app uses the RevenueCat iOS SDK with a custom SwiftUI paywall. It loads monthly, yearly, and lifetime packages from its offering, displays store-provided localized prices, and uses RevenueCat for purchasing and restoring purchases. Access is controlled through the `premium` entitlement, including the alarm follow-up limit and older journal entries.

The yearly plan has a seven-day introductory free trial for eligible customers. Monthly and lifetime purchases have no trial. The paywall checks the customer's introductory-offer eligibility before displaying trial copy. It appears at the end of onboarding and can also be reached through the journal's “See every morning” prompt for older history or by selecting unlimited follow-ups.

<!-- TODO(bannzai): Complete the production purchase/restore verification tracked in issue #163 before submitting. A RevenueCat Test Store demonstration is not evidence of a successful production transaction. -->

## Target awards and judging evidence

The primary target is the RevenueCat Design Award. Most Viral App is a secondary, conditional target. Criteria below paraphrase the official rules checked on September 17, 2026:

https://revenuecat-shipaton-2026.devpost.com/rules

### RevenueCat Design Award

**Innovative ideas:** The criterion considers distinctive technology, design, interactions, or animation. Memento Morning joins waking up, speaking to your own reflection, and revisiting that answer at night in one daily sequence. AlarmKit follow-ups connect the alarm to the answer; on-device transcription connects the spoken moment to a readable journal. The morning-question, journal, and evening-reflection screens make that sequence visible.

**Aesthetics:** The criterion considers visual and interaction craft. The design uses a dark background, warm light dots, restrained typography, and soft recording haptics. The dots use SpriteKit physics and CoreMotion rather than a static progress counter. Seven Mornings and its serif share card keep attention on the user's words. These are deliberate choices for a quiet morning ritual, not evidence of measured wellbeing outcomes.

### Most Viral App (Noise) — conditional secondary target

**Virality:** The criterion requires evidence that content distributed through Noise gained substantial attention. No verified Noise campaign, viral post, or attributable results are available in this draft. The share-card feature is implemented, but it is not evidence of virality.

**Scalability:** The criterion considers whether a creative format can be repeated at larger distribution volumes. A single-answer card and a Seven Mornings card provide repeatable formats with different personal answers. Both are rendered in the app and exported through the system share sheet. This establishes a reusable format; scaled distribution has not been demonstrated.

**Conversion relevance:** The criterion considers whether the creative communicates why someone would want the app. The cards place the question, the answer or answers, and Memento Morning's name together, so the journaling concept is visible in the shared image. Whether that message produces downloads remains unmeasured.

<!-- TODO(bannzai): Before selecting Most Viral App, confirm Noise was used during the event and supply actual post URLs, dated results, and the account email in the private submission field. Do not commit a personal email here. If Noise participation cannot be evidenced, omit this secondary category from the submitted entry. -->

## Traction and measured results

Memento Morning first became publicly available on September 15, 2026. Version 1.0.1 introduced the approved purchase plans on September 17, 2026, as recorded in the submission preparation issue. These are release milestones, not measured revenue or growth. Downloads, revenue, retention, and conversion have not been measured for this draft, and no estimates are presented.

<!-- TODO(bannzai): On the day before submission, replace this note with actual App Store Connect and RevenueCat measurements, including the reporting period, timezone, source, and extraction date. If a metric is unavailable, say so. Do not infer paid transactions from product approval. Release source: https://github.com/bannzai/mementomorning/issues/166 -->

## Monetization strategy

There are four current choices: free, Premium monthly, Premium yearly, and a one-time lifetime purchase. The free experience includes the alarm, daily answers, limited follow-ups, recent journal history, evening reflection, and Seven Mornings. Premium opens full history and stronger commitment controls, including unlimited follow-ups; lifetime grants Premium without a recurring subscription. The seven-day free trial applies only to the yearly plan and only when eligible.

The reasoning is commitment: a person may choose to pay to make it harder to postpone the answer, while preserving access to their growing journal. The paywall uses localized prices supplied by the store, rather than a currency-specific amount in this submission. The annual export add-on described in the original product plan is not presented here as a currently purchasable product.

## Build story and AI tools

I developed the app with Claude Code. The work is traceable through implementation pull requests, recorded checks, and review-driven fixes. For example, the transcription work includes permission handling and protection against an old recognition result overwriting an edited answer; the dots redesign includes follow-up fixes to scene boundaries and offscreen physics. These records show the iteration, without assigning an invented time saving or percentage of code to AI.

The product direction—one question, a private journal, and a quiet visual language—comes from the project brief. The following dates are repository milestones, not dates on which every behavior was verified on a physical device:

- August 13: the concept and Memento Morning name were recorded in the idea issue: https://github.com/bannzai/ideamemo/issues/187
- August 16: on-device transcription and editable answer text were merged: https://github.com/bannzai/mementomorning/pull/39
- August 23: the earlier life-calendar presentation was redesigned into physical dots and a separate monthly calendar: https://github.com/bannzai/mementomorning/pull/120
- September 16: the 1.0.1 release preparation was merged: https://github.com/bannzai/mementomorning/pull/165

<!-- TODO(bannzai): Confirm the first-person AI-tool account before submitting. The PR records establish changes and verification notes; do not attribute unrecorded prompts, productivity gains, or specific human/AI authorship to them. -->

## Build in public timeline

Not applicable to this draft. On September 17, 2026, the maker confirmed that there had been no prior social posts about the app. The announcement file contains drafts but no publication records. There are no social-post URLs, engagement results, or feedback-driven changes to submit for a Build in Public claim. The repository timeline above is not a substitute for such evidence.

Source: https://github.com/bannzai/mementomorning/issues/163#issuecomment-5710323868

## Testing instructions

1. Install the app from the US App Store link below on an iPhone running iOS 26 or later. Use English for the walkthrough.
2. Complete onboarding and allow alarm access. For a video answer, allow camera, microphone, and Photos access; allow speech recognition for supported on-device transcription. Text input is available as an alternative.
3. At the onboarding paywall, select the yearly plan to start its seven-day free trial if your Apple account is eligible. Monthly and lifetime options do not include a trial. If returning after onboarding, tap “See every morning” in the journal when older history is locked, or select unlimited follow-ups in alarm settings, to reach the paywall. Restore Purchases is available for an existing purchase.
4. Set an alarm one or two minutes ahead. When it fires, enter the morning-question screen, record an answer, and finish the recording. Confirm the answer appears on the home screen and in the journal. The follow-up behavior respects the selected snooze limit and Premium status.
5. Revisit the answer in the journal and calendar, and look at the accumulating dots on the home screen. A new installation has no history: dots accumulate with answered mornings, and Seven Mornings needs seven answered mornings. The populated screenshots supplied with this draft use development sample data to illustrate these later states, not usage metrics. The recording screen uses the simulator's development-only simulated recording mode, and paywall prices come from RevenueCat Test Store.
6. Use the evening reflection to record whether you followed through. Once Seven Mornings is available, open it and use Share to preview its card; sharing publicly is optional.

<!-- TODO(bannzai): Confirm judges can access every Premium feature free of charge through the end of judging. The yearly trial is seven days and account eligibility varies; arrange and privately provide an appropriate promo code if the trial does not cover access. This draft does not claim a code has already been issued. -->

## Links

- Published app: https://apps.apple.com/us/app/memento-morning/id6801673264
- Project website: https://bannzai.github.io/mementomorning/
- Source repository and build history: https://github.com/bannzai/mementomorning
- Demo video: issue #163 marks YouTube publication complete, but its URL has not been supplied in the submission files. No qualifying public video URL is recorded in this draft.
- Other category material: Noise campaign evidence is not yet recorded, so the Most Viral App entry remains conditional.

<!-- TODO(bannzai): Replace the pending demo-video line with the publicly accessible YouTube or Vimeo URL before submission. Then remove editorial notes from the submitted text after resolving their requirements. -->
