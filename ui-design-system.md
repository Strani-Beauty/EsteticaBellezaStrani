# UI DESIGN SYSTEM - Concrete Polishing App

This document defines the official UI standard for the entire application.

All screens must follow this system.

--------------------------------------------------

# 1. DESIGN TOKENS (GLOBAL SYSTEM)

Defines the base design rules used across the entire application.

- Colors
- Typography
- Spacing
- Borders
- Shadows
- Buttons
- Cards
- Inputs
- Layout structure
- Navigation rules

--------------------------------------------------


# 2. BASE SCREENS (STITCH REFERENCES)

These screens define the reusable UI patterns for the system.

--------------------------------------------------

## 2.1 Login Screen (Authentication Layout)

Purpose:
Used for login and authentication flows.

This section contains the full design tokens exported from Stitch.
They define the visual system for this screen and the global UI style.

Reference:

---
name: Industrial Precision
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#574235'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#8b7263'
  outline-variant: '#dec1af'
  surface-tint: '#964900'
  primary: '#964900'
  on-primary: '#ffffff'
  primary-container: '#f57c00'
  on-primary-container: '#572800'
  inverse-primary: '#ffb786'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#5f5e5e'
  on-tertiary: '#ffffff'
  tertiary-container: '#9e9d9d'
  on-tertiary-container: '#353535'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdcc6'
  primary-fixed-dim: '#ffb786'
  on-primary-fixed: '#311300'
  on-primary-fixed-variant: '#723600'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is engineered for the heavy-duty environment of concrete polishing management. It prioritizes **reliability, industrial strength, and operational productivity** above all else. Drawing from a **Modern Industrial** aesthetic, the system utilizes high-contrast interfaces and rigid structures to ensure functionality in challenging on-site conditions, such as high-glare sunlight or when operators are wearing gloves.

The visual language is rooted in Material Design 3 but stripped of all decorative "flair." It is a utilitarian framework designed to reduce cognitive load during complex project management and equipment tracking. Every element is sized for accessibility, ensuring the UI remains legible and interactable in a high-intensity workspace.

## Colors

The palette is inspired by safety equipment and industrial machinery.

- **Primary (Industrial Orange):** Used for primary actions, critical status indicators, and key navigational elements. It provides maximum visibility against neutral backgrounds.
- **Secondary (Deep Black):** Used for headers, side navigation, and high-emphasis text to provide a grounded, authoritative feel.
- **Background & Surface:** A combination of Light Gray (#F5F5F5) for the application canvas and pure White (#FFFFFF) for cards and inputs to create a clear "layering" effect that aids in information hierarchy.
- **Semantic Colors:** Success, Warning, and Error colors follow standard industrial safety conventions, optimized for high-contrast visibility.

## Typography

This design system utilizes **Inter** for its exceptional legibility and systematic feel. The hierarchy is intentionally "top-heavy," using large, bold titles to allow users to quickly identify their context at a glance.

- **Scale:** All font sizes are slightly increased compared to standard web apps to compensate for handheld use in mobile environments.
- **Weight:** Medium (500) and Semi-Bold (600) weights are used frequently for labels to ensure they don't disappear on high-brightness screens.
- **Letter Spacing:** Headlines use a slight negative tracking to appear more compact and "solid," while labels use positive tracking to improve readability at smaller sizes.

## Layout & Spacing

The layout follows a **Fluid Grid** model with a strict 8px base unit rhythm. This ensures alignment across all screen sizes from mobile tablets to desktop dashboards.

- **Desktop:** 12-column grid with 24px gutters and 32px side margins. 
- **Tablet:** 8-column grid with 24px gutters and 24px side margins.
- **Mobile:** 4-column grid with 16px gutters and 16px side margins.

**Touch Targets:** All interactive elements (buttons, checkboxes, chips) must maintain a minimum hit area of 48x48px to accommodate users wearing work gloves.

## Elevation & Depth

To maintain an industrial and functional feel, this design system uses **Tonal Layers** and **Rigid Outlines** rather than soft, ambient shadows.

- **Level 0 (Background):** Light Gray (#F5F5F5) for the main app background.
- **Level 1 (Surface):** White (#FFFFFF) cards and containers with a subtle 1px border (#E0E0E0).
- **Level 2 (Interactive):** Elements like buttons or active cards use a hard, low-blur shadow (2px offset, 4px blur, 10% black) to indicate interactability without looking "ethereal."
- **Focus States:** High-contrast 2px Industrial Orange outlines are required for all focused input fields and buttons to ensure visual clarity.

## Shapes

The shape language is **Soft-Square**. A consistent 8px (0.5rem) corner radius is applied to buttons, cards, and input fields. This provides a modern look that feels approachable but remains structurally disciplined and "engineered."

- **Small Components (Chips/Tags):** 4px radius.
- **Standard Components (Buttons/Inputs/Cards):** 8px radius.
- **Large Components (Modals/Drawers):** 12px-16px top-corner radius for a docked, structural appearance.

## Components

### Buttons
- **Primary:** Industrial Orange background with White text. Heavy 600-weight labels.
- **Secondary:** Deep Black background with White text. Used for secondary critical actions.
- **Outlined:** 2px border in Accent Gray (#424242) for tertiary actions.
- **States:** Hover/Pressed states must show a significant brightness shift (±10%) for immediate feedback.

### Form Fields
- **Input Fields:** Pure white background with a 1px border. On focus, the border thickens to 2px Industrial Orange.
- **Labels:** Always persistent above the field in Label-LG style. No floating labels that disappear.
- **Error States:** 2px Red border with a clear error icon.

### KPI Cards
- Large-format cards for dashboard metrics.
- Top-aligned Primary Orange accent bar (4px height) to denote importance.
- Large Display-LG typography for primary metrics.

### Tables (CRUD)
- High-contrast row headers in Deep Black.
- Alternating row zebra-striping (F5F5F5) for readability.
- "Sticky" headers and action columns for long data sets.

### Navigation
- **Side Drawer:** Deep Black (#212121) background. Active links highlighted with an Industrial Orange left-border indicator and a 10% opacity orange overlay.

--------------------------------------------------

## 2.2 Dashboard Screen (KPI Layout)
Purpose:
Main operational overview of the system.

This section contains the design tokens exported from Stitch for the Dashboard screen.


Reference:

---
name: Industrial Precision
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#574235'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#8b7263'
  outline-variant: '#dec1af'
  surface-tint: '#964900'
  primary: '#964900'
  on-primary: '#ffffff'
  primary-container: '#f57c00'
  on-primary-container: '#572800'
  inverse-primary: '#ffb786'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#5f5e5e'
  on-tertiary: '#ffffff'
  tertiary-container: '#9e9d9d'
  on-tertiary-container: '#353535'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdcc6'
  primary-fixed-dim: '#ffb786'
  on-primary-fixed: '#311300'
  on-primary-fixed-variant: '#723600'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is engineered for the heavy-duty environment of concrete polishing management. It prioritizes **reliability, industrial strength, and operational productivity** above all else. Drawing from a **Modern Industrial** aesthetic, the system utilizes high-contrast interfaces and rigid structures to ensure functionality in challenging on-site conditions, such as high-glare sunlight or when operators are wearing gloves.

The visual language is rooted in Material Design 3 but stripped of all decorative "flair." It is a utilitarian framework designed to reduce cognitive load during complex project management and equipment tracking. Every element is sized for accessibility, ensuring the UI remains legible and interactable in a high-intensity workspace.

## Colors

The palette is inspired by safety equipment and industrial machinery.

- **Primary (Industrial Orange):** Used for primary actions, critical status indicators, and key navigational elements. It provides maximum visibility against neutral backgrounds.
- **Secondary (Deep Black):** Used for headers, side navigation, and high-emphasis text to provide a grounded, authoritative feel.
- **Background & Surface:** A combination of Light Gray (#F5F5F5) for the application canvas and pure White (#FFFFFF) for cards and inputs to create a clear "layering" effect that aids in information hierarchy.
- **Semantic Colors:** Success, Warning, and Error colors follow standard industrial safety conventions, optimized for high-contrast visibility.

## Typography

This design system utilizes **Inter** for its exceptional legibility and systematic feel. The hierarchy is intentionally "top-heavy," using large, bold titles to allow users to quickly identify their context at a glance.

- **Scale:** All font sizes are slightly increased compared to standard web apps to compensate for handheld use in mobile environments.
- **Weight:** Medium (500) and Semi-Bold (600) weights are used frequently for labels to ensure they don't disappear on high-brightness screens.
- **Letter Spacing:** Headlines use a slight negative tracking to appear more compact and "solid," while labels use positive tracking to improve readability at smaller sizes.

## Layout & Spacing

The layout follows a **Fluid Grid** model with a strict 8px base unit rhythm. This ensures alignment across all screen sizes from mobile tablets to desktop dashboards.

- **Desktop:** 12-column grid with 24px gutters and 32px side margins. 
- **Tablet:** 8-column grid with 24px gutters and 24px side margins.
- **Mobile:** 4-column grid with 16px gutters and 16px side margins.

**Touch Targets:** All interactive elements (buttons, checkboxes, chips) must maintain a minimum hit area of 48x48px to accommodate users wearing work gloves.

## Elevation & Depth

To maintain an industrial and functional feel, this design system uses **Tonal Layers** and **Rigid Outlines** rather than soft, ambient shadows.

- **Level 0 (Background):** Light Gray (#F5F5F5) for the main app background.
- **Level 1 (Surface):** White (#FFFFFF) cards and containers with a subtle 1px border (#E0E0E0).
- **Level 2 (Interactive):** Elements like buttons or active cards use a hard, low-blur shadow (2px offset, 4px blur, 10% black) to indicate interactability without looking "ethereal."
- **Focus States:** High-contrast 2px Industrial Orange outlines are required for all focused input fields and buttons to ensure visual clarity.

## Shapes

The shape language is **Soft-Square**. A consistent 8px (0.5rem) corner radius is applied to buttons, cards, and input fields. This provides a modern look that feels approachable but remains structurally disciplined and "engineered."

- **Small Components (Chips/Tags):** 4px radius.
- **Standard Components (Buttons/Inputs/Cards):** 8px radius.
- **Large Components (Modals/Drawers):** 12px-16px top-corner radius for a docked, structural appearance.

## Components

### Buttons
- **Primary:** Industrial Orange background with White text. Heavy 600-weight labels.
- **Secondary:** Deep Black background with White text. Used for secondary critical actions.
- **Outlined:** 2px border in Accent Gray (#424242) for tertiary actions.
- **States:** Hover/Pressed states must show a significant brightness shift (±10%) for immediate feedback.

### Form Fields
- **Input Fields:** Pure white background with a 1px border. On focus, the border thickens to 2px Industrial Orange.
- **Labels:** Always persistent above the field in Label-LG style. No floating labels that disappear.
- **Error States:** 2px Red border with a clear error icon.

### KPI Cards
- Large-format cards for dashboard metrics.
- Top-aligned Primary Orange accent bar (4px height) to denote importance.
- Large Display-LG typography for primary metrics.

### Tables (CRUD)
- High-contrast row headers in Deep Black.
- Alternating row zebra-striping (F5F5F5) for readability.
- "Sticky" headers and action columns for long data sets.

### Navigation
- **Side Drawer:** Deep Black (#212121) background. Active links highlighted with an Industrial Orange left-border indicator and a 10% opacity orange overlay.
--------------------------------------------------

## 2.3 CRUD Screen (List Pattern)
Purpose:
Used for all list modules (clients, users, services, etc.)

This section contains the design tokens exported from Stitch for list and CRUD screens.

Reference:

---
name: Industrial Precision
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#574235'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#8b7263'
  outline-variant: '#dec1af'
  surface-tint: '#964900'
  primary: '#964900'
  on-primary: '#ffffff'
  primary-container: '#f57c00'
  on-primary-container: '#572800'
  inverse-primary: '#ffb786'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#5f5e5e'
  on-tertiary: '#ffffff'
  tertiary-container: '#9e9d9d'
  on-tertiary-container: '#353535'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdcc6'
  primary-fixed-dim: '#ffb786'
  on-primary-fixed: '#311300'
  on-primary-fixed-variant: '#723600'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is engineered for the heavy-duty environment of concrete polishing management. It prioritizes **reliability, industrial strength, and operational productivity** above all else. Drawing from a **Modern Industrial** aesthetic, the system utilizes high-contrast interfaces and rigid structures to ensure functionality in challenging on-site conditions, such as high-glare sunlight or when operators are wearing gloves.

The visual language is rooted in Material Design 3 but stripped of all decorative "flair." It is a utilitarian framework designed to reduce cognitive load during complex project management and equipment tracking. Every element is sized for accessibility, ensuring the UI remains legible and interactable in a high-intensity workspace.

## Colors

The palette is inspired by safety equipment and industrial machinery.

- **Primary (Industrial Orange):** Used for primary actions, critical status indicators, and key navigational elements. It provides maximum visibility against neutral backgrounds.
- **Secondary (Deep Black):** Used for headers, side navigation, and high-emphasis text to provide a grounded, authoritative feel.
- **Background & Surface:** A combination of Light Gray (#F5F5F5) for the application canvas and pure White (#FFFFFF) for cards and inputs to create a clear "layering" effect that aids in information hierarchy.
- **Semantic Colors:** Success, Warning, and Error colors follow standard industrial safety conventions, optimized for high-contrast visibility.

## Typography

This design system utilizes **Inter** for its exceptional legibility and systematic feel. The hierarchy is intentionally "top-heavy," using large, bold titles to allow users to quickly identify their context at a glance.

- **Scale:** All font sizes are slightly increased compared to standard web apps to compensate for handheld use in mobile environments.
- **Weight:** Medium (500) and Semi-Bold (600) weights are used frequently for labels to ensure they don't disappear on high-brightness screens.
- **Letter Spacing:** Headlines use a slight negative tracking to appear more compact and "solid," while labels use positive tracking to improve readability at smaller sizes.

## Layout & Spacing

The layout follows a **Fluid Grid** model with a strict 8px base unit rhythm. This ensures alignment across all screen sizes from mobile tablets to desktop dashboards.

- **Desktop:** 12-column grid with 24px gutters and 32px side margins. 
- **Tablet:** 8-column grid with 24px gutters and 24px side margins.
- **Mobile:** 4-column grid with 16px gutters and 16px side margins.

**Touch Targets:** All interactive elements (buttons, checkboxes, chips) must maintain a minimum hit area of 48x48px to accommodate users wearing work gloves.

## Elevation & Depth

To maintain an industrial and functional feel, this design system uses **Tonal Layers** and **Rigid Outlines** rather than soft, ambient shadows.

- **Level 0 (Background):** Light Gray (#F5F5F5) for the main app background.
- **Level 1 (Surface):** White (#FFFFFF) cards and containers with a subtle 1px border (#E0E0E0).
- **Level 2 (Interactive):** Elements like buttons or active cards use a hard, low-blur shadow (2px offset, 4px blur, 10% black) to indicate interactability without looking "ethereal."
- **Focus States:** High-contrast 2px Industrial Orange outlines are required for all focused input fields and buttons to ensure visual clarity.

## Shapes

The shape language is **Soft-Square**. A consistent 8px (0.5rem) corner radius is applied to buttons, cards, and input fields. This provides a modern look that feels approachable but remains structurally disciplined and "engineered."

- **Small Components (Chips/Tags):** 4px radius.
- **Standard Components (Buttons/Inputs/Cards):** 8px radius.
- **Large Components (Modals/Drawers):** 12px-16px top-corner radius for a docked, structural appearance.

## Components

### Buttons
- **Primary:** Industrial Orange background with White text. Heavy 600-weight labels.
- **Secondary:** Deep Black background with White text. Used for secondary critical actions.
- **Outlined:** 2px border in Accent Gray (#424242) for tertiary actions.
- **States:** Hover/Pressed states must show a significant brightness shift (±10%) for immediate feedback.

### Form Fields
- **Input Fields:** Pure white background with a 1px border. On focus, the border thickens to 2px Industrial Orange.
- **Labels:** Always persistent above the field in Label-LG style. No floating labels that disappear.
- **Error States:** 2px Red border with a clear error icon.

### KPI Cards
- Large-format cards for dashboard metrics.
- Top-aligned Primary Orange accent bar (4px height) to denote importance.
- Large Display-LG typography for primary metrics.

### Tables (CRUD)
- High-contrast row headers in Deep Black.
- Alternating row zebra-striping (F5F5F5) for readability.
- "Sticky" headers and action columns for long data sets.

### Navigation
- **Side Drawer:** Deep Black (#212121) background. Active links highlighted with an Industrial Orange left-border indicator and a 10% opacity orange overlay.

--------------------------------------------------

## 2.4 Form Screen (Data Entry Pattern)

Purpose:
Used for create/edit screens across the system.

This section contains the design tokens exported from Stitch for form and data entry screens.


Reference:

---
name: Industrial Precision
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#574235'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#8b7263'
  outline-variant: '#dec1af'
  surface-tint: '#964900'
  primary: '#964900'
  on-primary: '#ffffff'
  primary-container: '#f57c00'
  on-primary-container: '#572800'
  inverse-primary: '#ffb786'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#5f5e5e'
  on-tertiary: '#ffffff'
  tertiary-container: '#9e9d9d'
  on-tertiary-container: '#353535'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdcc6'
  primary-fixed-dim: '#ffb786'
  on-primary-fixed: '#311300'
  on-primary-fixed-variant: '#723600'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is engineered for the heavy-duty environment of concrete polishing management. It prioritizes **reliability, industrial strength, and operational productivity** above all else. Drawing from a **Modern Industrial** aesthetic, the system utilizes high-contrast interfaces and rigid structures to ensure functionality in challenging on-site conditions, such as high-glare sunlight or when operators are wearing gloves.

The visual language is rooted in Material Design 3 but stripped of all decorative "flair." It is a utilitarian framework designed to reduce cognitive load during complex project management and equipment tracking. Every element is sized for accessibility, ensuring the UI remains legible and interactable in a high-intensity workspace.

## Colors

The palette is inspired by safety equipment and industrial machinery.

- **Primary (Industrial Orange):** Used for primary actions, critical status indicators, and key navigational elements. It provides maximum visibility against neutral backgrounds.
- **Secondary (Deep Black):** Used for headers, side navigation, and high-emphasis text to provide a grounded, authoritative feel.
- **Background & Surface:** A combination of Light Gray (#F5F5F5) for the application canvas and pure White (#FFFFFF) for cards and inputs to create a clear "layering" effect that aids in information hierarchy.
- **Semantic Colors:** Success, Warning, and Error colors follow standard industrial safety conventions, optimized for high-contrast visibility.

## Typography

This design system utilizes **Inter** for its exceptional legibility and systematic feel. The hierarchy is intentionally "top-heavy," using large, bold titles to allow users to quickly identify their context at a glance.

- **Scale:** All font sizes are slightly increased compared to standard web apps to compensate for handheld use in mobile environments.
- **Weight:** Medium (500) and Semi-Bold (600) weights are used frequently for labels to ensure they don't disappear on high-brightness screens.
- **Letter Spacing:** Headlines use a slight negative tracking to appear more compact and "solid," while labels use positive tracking to improve readability at smaller sizes.

## Layout & Spacing

The layout follows a **Fluid Grid** model with a strict 8px base unit rhythm. This ensures alignment across all screen sizes from mobile tablets to desktop dashboards.

- **Desktop:** 12-column grid with 24px gutters and 32px side margins. 
- **Tablet:** 8-column grid with 24px gutters and 24px side margins.
- **Mobile:** 4-column grid with 16px gutters and 16px side margins.

**Touch Targets:** All interactive elements (buttons, checkboxes, chips) must maintain a minimum hit area of 48x48px to accommodate users wearing work gloves.

## Elevation & Depth

To maintain an industrial and functional feel, this design system uses **Tonal Layers** and **Rigid Outlines** rather than soft, ambient shadows.

- **Level 0 (Background):** Light Gray (#F5F5F5) for the main app background.
- **Level 1 (Surface):** White (#FFFFFF) cards and containers with a subtle 1px border (#E0E0E0).
- **Level 2 (Interactive):** Elements like buttons or active cards use a hard, low-blur shadow (2px offset, 4px blur, 10% black) to indicate interactability without looking "ethereal."
- **Focus States:** High-contrast 2px Industrial Orange outlines are required for all focused input fields and buttons to ensure visual clarity.

## Shapes

The shape language is **Soft-Square**. A consistent 8px (0.5rem) corner radius is applied to buttons, cards, and input fields. This provides a modern look that feels approachable but remains structurally disciplined and "engineered."

- **Small Components (Chips/Tags):** 4px radius.
- **Standard Components (Buttons/Inputs/Cards):** 8px radius.
- **Large Components (Modals/Drawers):** 12px-16px top-corner radius for a docked, structural appearance.

## Components

### Buttons
- **Primary:** Industrial Orange background with White text. Heavy 600-weight labels.
- **Secondary:** Deep Black background with White text. Used for secondary critical actions.
- **Outlined:** 2px border in Accent Gray (#424242) for tertiary actions.
- **States:** Hover/Pressed states must show a significant brightness shift (±10%) for immediate feedback.

### Form Fields
- **Input Fields:** Pure white background with a 1px border. On focus, the border thickens to 2px Industrial Orange.
- **Labels:** Always persistent above the field in Label-LG style. No floating labels that disappear.
- **Error States:** 2px Red border with a clear error icon.

### KPI Cards
- Large-format cards for dashboard metrics.
- Top-aligned Primary Orange accent bar (4px height) to denote importance.
- Large Display-LG typography for primary metrics.

### Tables (CRUD)
- High-contrast row headers in Deep Black.
- Alternating row zebra-striping (F5F5F5) for readability.
- "Sticky" headers and action columns for long data sets.

### Navigation
- **Side Drawer:** Deep Black (#212121) background. Active links highlighted with an Industrial Orange left-border indicator and a 10% opacity orange overlay.


# IMPLEMENTATION RULE

All Flutter screens must use these base patterns.

Do NOT create new layouts unless strictly necessary.

Reuse:

- Layout widgets
- Cards
- Buttons
- Input fields
- Table structures

Consistency is more important than creativity.