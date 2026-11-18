---
name: Image Classifier
description: Material 3 photo recognition with a restrained purple accent.
colors:
  seed: '#6750A4'
rounded:
  preview: '16dp'
  primary-control: '16dp'
  secondary-control: '12dp'
spacing:
  compact: '8dp'
  related: '12dp'
  section: '24dp'
  wide-gutter: '32dp'
---

## Overview

Operate mode: let the user choose a photo and understand ranked matches. Preserve
the existing purple identity and familiar camera/gallery flow. Use native
Material 3 components and Roboto, with system-selected light/dark themes.

## Colors

`AppTheme.forBrightness` is the source of truth. Generate semantic color roles
from the seed using `ColorScheme.fromSeed`. Use on-surface for body text,
on-surface-variant for secondary copy, primary for the main action and best
match, and error for failures. Do not place raw colors inside screen components.

## Typography

Use Material text roles: headline-large for the screen's task, headline-small
for the best match, title-medium for supporting groups, body-large/medium for
content, and body-small for metadata. All roles follow system text scaling.
Confidence numerals use tabular figures.

## Layout

24dp phone gutters, 32dp wider gutters, a 1040dp maximum content width. At 700dp,
photo and predictions become two columns. Keep camera/gallery actions visible
below a scrollable content region. Large accessibility text stacks those actions.
Use SafeArea for system insets; do not lock orientation.

## Elevation & Depth

Use tonal surface roles rather than custom shadows. Only the photo has a subtle
outline; avoid nested cards and decoration around each result.

## Shapes

16dp preview and button corners. Use consistent rounded Material icons.

## Components

Show one main match and two alternatives, with genuine percentages and linear
confidence meters. Explain uncertain matches without presenting confidence as
accuracy. Loading is a labeled linear indicator, errors include recovery,
and picking is disabled during initialization or inference. Clear resets both
the photo and its results. The information sheet explains offline operation,
category coverage, and score interpretation.

## Do's and Don'ts

Honor dark mode, text scaling, safe areas, and 48dp touch targets. Preserve full
photos in the preview. Use restrained 180ms result transitions and respect the
system's disabled-animation preference. Do not add decorative gradients,
unnecessary navigation, or fabricated model-performance claims.
