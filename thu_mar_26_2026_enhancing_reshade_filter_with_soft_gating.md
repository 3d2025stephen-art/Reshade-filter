# Copilot Chat Conversation Export: Enhancing Reshade filter with soft gating

**User:** @3d2025stephen-art
**Thread URL:** https://github.com/copilot/c/4dd3e667-d1b0-4898-88d6-9204473acf40

## @3d2025stephen-art

Where can i edit the color of ref in my reshade if its not the yellow i want to control?

## Copilot

If you want to control **a different target color than “yellow”**, you edit the **hue center** used by the mask. In your current ReShade v3, that’s inside `selective_yellow_weight()` here:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float center = 1.0 / 6.0; // yellow
```

### 1) Quick manual edit (hard-coded)
Change `center` to the hue you want (hue is in **0..1**):

Common targets:
- **Red:** `0.0` (and also near `1.0`)
- **Orange:** `0.0833` (30° / 360)
- **Yellow:** `0.1667` (60° / 360)
- **Green:** `0.3333` (120° / 360)
- **Cyan:** `0.5` (180° / 360)
- **Blue:** `0.6667` (240° / 360)
- **Magenta:** `0.8333` (300° / 360)

So for green control, for example:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float center = 1.0 / 3.0; // green
```

This is the simplest change.

---

## 2) Better: add a slider “Target Hue”
So you can pick any color without editing code.

Add this uniform near your yellow mask controls:

```hlsl name=BluePivot-HSLW v3 pastel.fx
uniform float TargetHue <
    ui_label = "Target Hue (0=Red, 0.166=Yellow, 0.333=Green, 0.667=Blue)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 1.0 / 6.0;
```

Then in `selective_yellow_weight()` replace the hard-coded center:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float center = TargetHue;
```

### Important note (red wrap-around)
Hue wraps at 0/1. Your current band uses:
```hlsl
abs((h - center) * 6.0)
```
This **does not wrap**, so targeting reds near 0 can be less accurate.

If you want the slider to work perfectly for *any* hue (especially red), use circular distance:

Add helper:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}
```

Then change the band line inside `selective_yellow_weight()` to:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float d = hue_dist01(h, center);
float band = max(1.0 - (d * 6.0), 0.0);
```

Now `TargetHue` works reliably for all colors.

---

### Which do you want?
- **Quick hard-code** (one target color, simplest), or
- **TargetHue slider** (fully flexible), and do you care about **perfect red wrap-around**?

## @3d2025stephen-art

i dont care for the red we can stay behold 0 in a safe slider 0.03 is good red without too much yellow? The target hue slider seems perfect if guided about true hexadecimal reading at side maybe

## Copilot

You can do that: keep it simple (no wrap fix), and make the slider “safe” by avoiding 0.0. Then add a **UI hint** showing handy hue values and also allow picking by **hex** via an optional `TargetColor` picker that drives the hue for you.

ReShade can’t dynamically display “the hex of the current slider value” in the UI, but we *can*:
- put a **static guide** in the label (common hue stops), and/or
- provide a **color picker** (RGB) and convert it to hue internally (this feels like “hex picking”).

Below is a clean implementation that gives you both:

## 1) Add these uniforms
Put near your mask controls:

```hlsl name=BluePivot-HSLW v3 pastel.fx
uniform float TargetHue <
    ui_label = "Target Hue (guide: 0.03~Red, 0.083=Orange, 0.166=Yellow, 0.333=Green, 0.5=Cyan, 0.666=Blue, 0.833=Magenta)";
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

uniform bool UseTargetColorPicker <
    ui_label = "Use Target Color Picker (overrides Target Hue)";
    ui_type  = "checkbox";
> = false;

uniform float3 TargetColorRGB <
    ui_label = "Target Color (pick by RGB/hex)";
    ui_type  = "color";
> = float3(1.0, 1.0, 0.0); // default yellow
```

Notes:
- `ui_min=0.03` keeps you away from exact 0 red, like you wanted.
- The color picker usually lets you enter **hex** in ReShade’s UI (depends on overlay build), and at minimum you can paste RGB.

## 2) Add a helper: RGB → Hue
Place this near `rgb_hue01` (we’ll reuse similar logic but return hue from an arbitrary RGB):

```hlsl name=BluePivot-HSLW v3 pastel.fx
float rgb_to_hue01(float3 c)
{
    c = saturate(c);

    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;

    if (d < 1e-6)
        return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}
```

## 3) Use it in `selective_yellow_weight()`
Change:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float center = 1.0 / 6.0; // yellow
```

to:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float center = UseTargetColorPicker ? rgb_to_hue01(TargetColorRGB) : TargetHue;
```

That’s it—now you can:
- use the slider for “quick hue moves” (safe away from red wrap)
- or check the box and pick a **target color by RGB/hex**, and the shader will target that hue.

### Practical guidance (your “0.03 red” idea)
- `TargetHue = 0.03` tends to hit “red-ish” while staying away from orange/yellow spill.
- For “gold” you’d move toward `0.10–0.14`.
- For “pure yellow” around `0.166`.

If you want, I can also add a second slider like **Hue Width** (instead of the current fixed `* 6.0` band) so targeting non-yellow colors can be wider/narrower without messing with `YellowMaskTightness`.

## @3d2025stephen-art

Yhe slider can be froma a safe cold red to a the safe warm 0.03 so. Is the hue width slider good for antibanding?

## Copilot

Hue width helps **selectivity**, not banding. It can *reduce the perception* of “steppy” transitions by making the mask broader/softer, but true anti-banding is more about **softness/dither** (or working in higher precision / avoiding hard powers).

That said, adding a Hue Width control is still a very good idea because it lets you:
- target **cold red → warm red** with a *wider* range without accidentally catching yellow
- make the mask less “knife-edge” (often feels less banded)

### 1) Safe “red-only” slider range
If you want the slider to only live in red territory, set it to something like:

- cold-ish red around **0.97**
- warm red around **0.03**

But because your hue distance currently does **not wrap**, you can’t make a single continuous slider that goes 0.97 → 0.03 smoothly without implementing wrap logic.

So you have two clean options:

**Option A (no wrap logic, simplest):** keep only warm reds
```hlsl
ui_min = 0.03; ui_max = 0.12;
```
This is “safe warm reds” (0.03) moving toward orange-ish red (0.08–0.12).

**Option B (recommended): add hue wrap distance** so you can safely cover cold→warm red.
If you’re okay with one helper function, this is the correct solution and it also makes Hue Width behave nicely.

### 2) Add Hue Width + Hue Softness (best for smoothness)
Add these uniforms:

```hlsl name=BluePivot-HSLW v3 pastel.fx
uniform float HueWidth <
    ui_label = "Hue Width (band size)";
    ui_type  = "slider";
    ui_min = 0.5; ui_max = 6.0;
> = 2.5;

uniform float HueSoftness <
    ui_label = "Hue Softness (anti-edge)";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.5;
```

- **HueWidth**: how wide the band is (bigger = broader selection)
- **HueSoftness**: softens the band edge (this is the part that helps “anti-banding feel”)

### 3) (Recommended) Implement proper circular hue distance
Add this helper:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}
```

### 4) Update the band computation in `selective_yellow_weight()`
Replace your current band:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float band = max(1.0 - abs((h - center) * 6.0), 0.0); // triangular band
float sw_y = curve(band);
```

with this width/softness version:

```hlsl name=BluePivot-HSLW v3 pastel.fx
// HueWidth: larger => wider selection. Think of it as "how many hue segments".
float d = hue_dist01(h, center);

// Convert distance to a 0..1 band with adjustable width.
// When HueWidth=6, this is close to your original "* 6.0" behavior.
float band = saturate(1.0 - d * HueWidth);

// Soften the edge a bit (reduces harsh transitions / banding feel)
band = pow(max(band, 1e-6), 1.0 / max(1e-3, (1.0 + HueSoftness)));

float sw_y = curve(band);
```

Now you can set:
- `TargetHue` to span almost all (e.g. 0.03..0.97) and red will work because distance wraps
- `HueWidth` to tune how isolated the color is
- `HueSoftness` to keep transitions gentle

### Does this “anti-band”?
- It **reduces harsh edges** (so it *looks* less banded).
- If you still see banding in skies/gradients, the real fix is adding a tiny **dither** before applying strong powers (or reducing tightness/power).

If you want, tell me whether you’re seeing banding mostly in:
1) the **mask edge** (color transitions), or
2) inside **smooth gradients** (sky/skin),
and I’ll suggest the best minimal anti-banding tweak (usually a tiny noise dither applied to the mask before pow).

## @3d2025stephen-art

I will not ad for now any antibanding despite my filter seem really compatible let keep this option as a side implementation maybe , i wll add later if possible

## Copilot

Understood—then keep it simple for now.

### Minimal safe setup (no wrap, no width, no anti-banding)
If your goal is just “warm reds only” and avoid accidentally hitting yellow, do this:

- Keep the `TargetHue` slider **only in the safe warm-red range**:

```hlsl name=BluePivot-HSLW v3 pastel.fx
uniform float TargetHue <
    ui_label = "Target Hue (warm reds: 0.03=red, 0.06=red-orange, 0.10=orange)";
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.12;
> = 0.03;
```

- In `selective_yellow_weight()`, replace:

```hlsl
float center = 1.0 / 6.0; // yellow
```

with:

```hlsl name=BluePivot-HSLW v3 pastel.fx
float center = TargetHue;
```

That gives you exactly what you asked: a **safe red-only target** without needing any extra anti-banding code.

Whenever you’re ready later, you can add (in this order):
1) hue wrap distance (for cold↔warm red sweep)
2) hue width slider
3) optional edge softness / dither

If you want, paste the section where you want the `TargetHue` inserted and I’ll show the precise placement so it doesn’t conflict with your existing uniforms.

## @3d2025stephen-art

Can we make foldable all the sliders group from "yellow -white slider" to "pastel softness slider" adding the hue controls inside? And renaming as "hue blue inject" the "yellow blue inject" feature

## Copilot

Yes to both parts:

1) **Foldable group** for everything from **Yellow→White** through **PastelSoftness**, and place the **Hue target controls inside that same group**.
2) Rename **Yellow Blue Inject** → **Hue Blue Inject** (label + internal variable names if you want).

ReShade supports collapsible groups via the `ui_category` and `ui_category_closed` annotations on uniforms. Put the same `ui_category` on each uniform you want inside the fold, and add `ui_category_closed = true` to the *first* (or all) of them to make it default-collapsed.

Below is a patch you can drop into your file.

---

## A) Add the hue target slider (warm-red safe) and fold everything into one category

### 1) Add this uniform near your yellow controls
Put it right above `YellowToWhite` (or anywhere in that block):

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform float TargetHue <
    ui_label = "Target Hue (0.03=warm red ... 0.12=orange)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.12;
> = 1.0 / 6.0;
```

Notes:
- Default `1.0/6.0` is yellow; if you want default warm red, set `= 0.03;`.
- Category name is what shows as the fold header.

### 2) Add `ui_category` to these existing uniforms
For each of the following uniforms, add:

`ui_category = "HUE / Pastel Controls";`

to their annotation blocks:

- `YellowToWhite`
- `YellowToBlack`
- `YellowMaskBoost`
- `YellowMaskTightness`
- `PastelBias`
- `PastelChroma`
- `PastelValue`
- `PastelSoftness`

Example (one of them):

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform float YellowToWhite <
    ui_label = "Hue → White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;
```

I also renamed the *label* from “Yellow → White” to **“Hue → White”** since it’s no longer strictly yellow once TargetHue exists.

---

## B) Make `selective_yellow_weight()` use TargetHue
Change:

```hlsl
float center = 1.0 / 6.0; // yellow
```

to:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float center = TargetHue;
```

So the mask targets whatever hue you set.

---

## C) Rename “Yellow Blue Inject” feature to “Hue Blue Inject”

### 1) Rename the UI labels (minimum change, safest)
Just change labels:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform bool EnableYellowBlueInject <
    ui_label = "Enable Hue Blue Inject";
    ui_type  = "checkbox";
> = false;

uniform float YellowBlueInject <
    ui_label = "Hue Blue Inject ( -remove ... +add )";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;
```

This keeps code working without renaming variables.

### 2) Optional (cleaner): rename variables too
If you want the internal names consistent, rename:
- `EnableYellowBlueInject` → `EnableHueBlueInject`
- `YellowBlueInject` → `HueBlueInject`

If you do that, also update the 2 places they’re referenced in the shader.

---

## One small UX note (from your screenshot)
Once you add `TargetHue`, “Yellow Mask Boost/Tightness” are really “Hue Mask Boost/Tightness”. You may want to rename the labels too:

- “Yellow Mask Boost” → “Hue Mask Boost”
- “Yellow Mask Tightness” → “Hue Mask Tightness”

No functional change—just clarity.

---

If you want, I can output your full file with these edits applied end-to-end (same filename), but confirm one detail first: **should TargetHue default to yellow (0.1667) or warm red (0.03)?**

## @3d2025stephen-art

yes the filter becoms hue based, however i will keep the yellow version as default hue setup this can be the most useful, can you make the file with all the new goodies?

## Copilot

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
// Reshade: BluePivot-HSLW v3 pastel v35 (Hue-based UI grouping update)
//
// Implemented (from this chat):
// - Stable target-hue detection from ORIGINAL sample (c0) using selective_yellow_weight()
// - Multi DebugMode (Off/Overlay/Beauty/Yellow/Gate/Final)
// - Pastel bias (signed) to boost/protect creamy near-white hues
// - Optional Hue Blue Inject (checkbox + signed slider) [renamed in UI]
// - Soft gate shaping remains (AlphaGatePower), and gate is used as a smooth multiplier
// - Two tonal sliders: Hue -> White AND Hue -> Black (hue-only, soft, polyvalent)
// - Foldable group ("HUE / Pastel Controls") for TargetHue through PastelSoftness
//
// Notes:
// - Default TargetHue remains yellow (1/6)
// - Tonal Hue->White/Black is separate from optional Hue Blue Inject (stylistic)

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R↔Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G↔Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan ↔ Magenta)";
    ui_type = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
// TargetHue is the "group header" by setting ui_category_closed=true here.

uniform float TargetHue <
    ui_label = "Target Hue (0.166=Yellow default, 0.03=warm red, 0.333=green, 0.666=blue)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

// ---- Hue tonal correction (polyvalent) ----
uniform float YellowToWhite <
    ui_label = "Hue → White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue → Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

// Selective Hue mask controls
uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

// ---- Pastel bias (signed) ----
uniform float PastelBias <
    ui_label = "Pastel Bias ( -protect creams ... +boost creams )";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- Red/Green -> gate ----
uniform float RedToAlpha <
    ui_label = "Red → Alpha (gate weight)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform float GreenToAlpha <
    ui_label = "Green → Alpha (gate weight)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform float AlphaGatePower <
    ui_label = "Alpha Gate Power";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 4.0;
> = 1.5;

uniform float PreserveWhites <
    ui_label = "Preserve Whites (fade near white)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.75;

// ---- Optional blue injection style (renamed in UI) ----
uniform bool EnableYellowBlueInject <
    ui_label = "Enable Hue Blue Inject";
    ui_type  = "checkbox";
> = false;

uniform float YellowBlueInject <
    ui_label = "Hue Blue Inject ( -remove ... +add )";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform bool WorkInLinear <
    ui_label = "Work In Linear (recommended)";
    ui_type = "checkbox";
> = true;

// ---- Debug ----
uniform int DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0";
    ui_min = 0; ui_max = 5;
> = 0;

uniform float DebugOverlayStrength <
    ui_label = "DEBUG Overlay Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.65;

uniform float DebugGamma <
    ui_label = "DEBUG Gamma (mask visibility)";
    ui_type = "slider";
    ui_min = 0.4; ui_max = 2.2;
> = 0.85;


// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float curve(float x) { return x * x * (3.0 - 2.0 * x); } // smoothstep-like

// Very small RGB->Hue (0..1) helper (ok for masks)
float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float scalar = mx - mn;
    float cmy_scalar = 0.5 * scalar;

    float h = rgb_hue01(saturate(c));
    float center = TargetHue; // was: 1.0/6.0 (yellow)
    float band = max(1.0 - abs((h - center) * 6.0), 0.0); // triangular band (no wrap)
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;

    w_y = saturate(w_y * chromaBoost);
    w_y = pow(w_y, hueTightness);
    return saturate(w_y);
}


// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    // Sample original
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    // 1) Hue mask from ORIGINAL (stable)
    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    // 1b) Pastel bias on hue mask (signed)
    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    // 2) Main color shaping
    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float b = c.b;
    c.r += pivot * b * 0.5;
    c.g -= pivot * b * 0.5;

    // 3) Gate (smooth)
    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    // 4) Highlight protection / fade near white
    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    // 5) Final strength terms (computed once for debug consistency)
    float yStrength = saturate(yellowMask * gate * fadeWhite);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    // --- DEBUG ---
    if (DebugMode != 0)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (DebugMode == 1)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear)
                outc = linear_to_srgb(outc);

            return float4(outc, 1.0);
        }
        else if (DebugMode == 2)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear)
                masks = linear_to_srgb(masks);

            return float4(masks, 1.0);
        }
        else if (DebugMode == 3)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 4)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else // DebugMode == 5
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
    }

    // 6) Apply hue tonal correction (soft, hue-only)
    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    // 7) Optional: Hue Blue Inject (signed)
    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear)
        c = linear_to_srgb(c);

    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```

## @3d2025stephen-art

how wide can be the hue cover of my filter around the frequency i choose?

## Copilot

In your current file, the hue coverage is defined entirely by this line in `selective_yellow_weight()`:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float band = max(1.0 - abs((h - center) * 6.0), 0.0); // triangular band (no wrap)
```

### What that means (in plain numbers)
- The mask is **non-zero** when:

\[
|h-center| < \frac{1}{6} \approx 0.1667
\]

So the filter covers roughly:
- **±0.1667 hue** around your chosen `TargetHue`
- i.e. total width ≈ **0.3333 of the hue wheel**
- that’s about **120°** of hue (since 0..1 maps to 0..360°)

### Where it’s strongest
It peaks at the center (value 1), then falls linearly to 0 at the edges (a triangle), then you smooth it a bit with `curve()`.

### What makes it feel tighter/wider in practice
Even though the geometric band is fixed at ±1/6, you effectively change “usable width” with:

- `YellowMaskTightness` (the `pow(w_y, hueTightness)`):
  - **higher** tightness = effectively **narrower**
  - **lower** tightness = effectively **wider**

- `YellowMaskBoost`:
  - doesn’t change the band’s mathematical width, but can make weak colors inside the band show up more.

### Important limitation (since you chose “no wrap”)
Because it uses `abs(h-center)` (not circular distance), if `TargetHue` is near 0.03 or 0.97, the band **does not wrap across 0/1**. So you won’t cover “the other side of red” unless you add the wrap-distance version later.

### If you want a direct “Hue Width” slider later
We’d replace the `* 6.0` with a parameter:
- `HueWidth = 6.0` matches current behavior
- larger = narrower (edges closer)
- smaller = wider

But as-is: **your maximum coverage is fixed at ~120°**, and the “practical” width is mainly controlled by `YellowMaskTightness`.

## @3d2025stephen-art

this is efficient but i noticed the darker colors arent influenced can make a switch or slider to influence different luminances?

## Copilot

Yes. Right now dark colors get hit less for two main reasons:

1) Your mask is **chroma-weighted**: `w_y = sw_y * cmy_scalar`, and `cmy_scalar` (≈ chroma) is usually small in shadows.
2) Your gate + preserve whites can also reduce strength depending on settings.

A good solution is to add a **luminance response control** that can *boost shadows*, *limit to highlights*, or *apply everywhere*. Do it as an extra multiplier on `yStrength`.

Below is a simple, safe implementation: a **Shadows/Mids/Highlights bias slider** plus a softness control.

## Add these uniforms (near PreserveWhites)
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform float LumaFocus <
    ui_label = "Luma Focus ( -shadows ... 0=all ... +highlights )";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float LumaSoftness <
    ui_label = "Luma Softness";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 1.0;
> = 0.35;

uniform float LumaBoost <
    ui_label = "Luma Boost";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 4.0;
> = 1.0;
```

## Add this helper (optional, but neat) near helpers
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float luma_focus_weight(float lum, float focus, float softness)
{
    // lum: 0..1
    // focus: -1 shadows, 0 all, +1 highlights
    // softness: edge smoothness
    float s = max(softness, 1e-4);

    // Two ramps:
    // - shadows ramp is high at low lum, fades out as lum rises
    float w_shadows = 1.0 - smoothstep(0.0, s, lum);

    // - highlights ramp is high at high lum, fades in as lum rises
    float w_high = smoothstep(1.0 - s, 1.0, lum);

    // focus blends between them; at focus=0 return 1
    float a = saturate(abs(focus));
    float w = (focus < 0.0) ? w_shadows : w_high;
    return lerp(1.0, w, a);
}
```

## Apply it where you compute `yStrength`
Find this line:

```hlsl
float yStrength = saturate(yellowMask * gate * fadeWhite);
```

Replace with:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float yStrength = saturate(yellowMask * gate * fadeWhite);

// Luma focus: let user decide if the hue effect targets shadows or highlights
float lum0 = luminance_rec709(c0); // use original for stability
float lumaW = luma_focus_weight(saturate(lum0), LumaFocus, LumaSoftness);
yStrength = saturate(yStrength * lumaW * LumaBoost);
```

### How to use it
- **Default:** `LumaFocus = 0` → no change (applies everywhere)
- **Boost shadows:** set `LumaFocus = -0.6` and `LumaBoost = 2.0`
- **Only highlights:** set `LumaFocus = +0.8` and maybe `LumaBoost = 1.5`
- **Softer transitions:** increase `LumaSoftness`

### Optional “switch” instead of always-on
If you prefer a checkbox, add:
```hlsl
uniform bool EnableLumaFocus < ui_label="Enable Luma Focus"; ui_type="checkbox"; > = false;
```
and wrap the luma multiply.

If you want, I can integrate this into your foldable “HUE / Pastel Controls” category as well (it fits nicely there), or keep it separate as “Luminance Controls”.

## @3d2025stephen-art

Does this exist in the Reshade ui to make stepped sliders? for the sorted frequencies this seems a good option

## Copilot

ReShade’s built-in UI metadata is pretty limited: you get `ui_type` (slider/combo/drag/color/checkbox), `ui_min/max`, and (in newer builds) sometimes `ui_step` is supported, but it’s **not consistently supported across all ReShade versions/overlays**. So:

- **If your ReShade build supports it:** you can try `ui_step = ...` on a slider.
- **If it doesn’t:** the reliable way is to use a **combo** (discrete stepped choices) and map the selection to values in code.

## Option 1: Try `ui_step` (fast, may or may not work)
Example:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform float TargetHue <
    ui_label = "Target Hue (stepped)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
    ui_step = 0.01; // may be ignored depending on ReShade version
> = 1.0 / 6.0;
```

If you move the slider and it still feels continuous, your build is ignoring `ui_step`.

## Option 2 (recommended): “Sorted frequencies” via combo presets (always works)
Make a combo like “Red / Orange / Yellow / Green / Cyan / Blue / Magenta”, plus a “Custom” mode that uses the slider.

### Add a selector
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform int HuePreset <
    ui_label = "Hue Preset";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items = "Custom\0Red (warm)\0Orange\0Yellow\0Green\0Cyan\0Blue\0Magenta\0";
    ui_min = 0; ui_max = 7;
> = 0;
```

Keep your existing `TargetHue` slider as “Custom Hue”.

### Then in `selective_yellow_weight()` choose the center
Replace `float center = TargetHue;` with:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float center = TargetHue;

if (HuePreset == 1) center = 0.03;       // warm red
else if (HuePreset == 2) center = 1.0/12.0; // ~0.0833 orange
else if (HuePreset == 3) center = 1.0/6.0;  // ~0.1667 yellow
else if (HuePreset == 4) center = 1.0/3.0;  // ~0.3333 green
else if (HuePreset == 5) center = 0.5;      // cyan
else if (HuePreset == 6) center = 2.0/3.0;  // ~0.6667 blue
else if (HuePreset == 7) center = 5.0/6.0;  // ~0.8333 magenta
```

Now you have true “stepped frequencies” with no dependence on ReShade slider step support.

## Option 3: Quantize the slider in code (also always works)
If you want the UI to look continuous but behave stepped, you can quantize:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float center = TargetHue;
float stepSize = 0.01; // 1% of hue wheel
center = floor(center / stepSize + 0.5) * stepSize;
```

This gives you “stepped behavior” even if the UI doesn’t snap.

---

If you tell me which parameter you want stepped (TargetHue? HueWidth later? LumaFocus?), I can show the cleanest implementation for your file layout (combo presets vs quantized slider).

## @3d2025stephen-art

target hue stepped in degree like 20, 50, 110, 190, 230, 310, 340. This empathy is accurate and intuitive so this seems useful and for the LUma focus, modular from dark colors to pastels with 5 luma sections tickable switches seem nice, 

## Copilot

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
// --- Additions for stepped Target Hue + modular 5-zone Luma Focus ---
// Drop these into your existing file (replaces/extends the TargetHue system and adds luma zones).
// This is written to be compatible with your current structure and keeps default behavior = yellow-ish.

// ==================== UI: HUE / Pastel Controls (foldable) ====================

// Replace your current TargetHue uniform with these TWO controls:
// 1) HuePresetSteps: discrete degrees (your list)
// 2) TargetHue: only used when HuePresetSteps == Custom (optional)

uniform int HuePresetSteps <
    ui_label = "Target Hue Preset (degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "combo";
    ui_items = "Custom (slider)\00020°\00050°\000110°\000190°\000230°\000310°\000340°\0";
    ui_min = 0; ui_max = 7;
> = 2; // 50° default (close to yellow). Set to 0 to default to the slider.

uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

// ==================== UI: LUMA ZONES (modular) ====================
// 5 tickable sections (checkboxes) + a softness for blending between zones.
// Default: all zones enabled (behavior ~unchanged), with mild softness.

uniform bool LumaZone1_Shadows <
    ui_label = "Luma Zone 1: Shadows (0-20%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone2_Darks <
    ui_label = "Luma Zone 2: Darks (20-40%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone3_Mids <
    ui_label = "Luma Zone 3: Mids (40-60%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone4_Lights <
    ui_label = "Luma Zone 4: Lights (60-80%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone5_Highlights <
    ui_label = "Luma Zone 5: Highlights (80-100%)";
    ui_type  = "checkbox";
> = true;

uniform float LumaZoneSoftness <
    ui_label = "Luma Zone Softness";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 0.20;
> = 0.04;

uniform float LumaZoneBoost <
    ui_label = "Luma Zone Boost";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 4.0;
> = 1.0;

// ==================== HELPERS: add these near your helpers ====================

float hue_center_from_preset(int preset, float fallbackHue)
{
    // Returns hue in 0..1. Your specified degrees:
    // 20, 50, 110, 190, 230, 310, 340
    // preset indices:
    // 0 = Custom
    // 1..7 map to list order
    if (preset == 1) return 20.0 / 360.0;
    if (preset == 2) return 50.0 / 360.0;
    if (preset == 3) return 110.0 / 360.0;
    if (preset == 4) return 190.0 / 360.0;
    if (preset == 5) return 230.0 / 360.0;
    if (preset == 6) return 310.0 / 360.0;
    if (preset == 7) return 340.0 / 360.0;
    return fallbackHue;
}

float bandpass01(float x, float a, float b, float s)
{
    // Smooth band-pass: 1 inside [a,b], fades out with softness s.
    // a,b in 0..1, s in 0..0.2-ish
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight(float lum, float softness)
{
    // 5 zones: [0-0.2], [0.2-0.4], [0.4-0.6], [0.6-0.8], [0.8-1]
    float w = 0.0;
    if (LumaZone1_Shadows)   w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)     w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)      w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)    w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights)w += bandpass01(lum, 0.8, 1.0, softness);

    // Normalize so "all enabled" ~= 1.0
    // (because with softness, overlaps can sum >1)
    return saturate(w);
}

// ==================== PATCH 1: selective_yellow_weight() center ====================
// In your selective_yellow_weight(), replace:
//   float center = TargetHue;
// with:

//   float center = hue_center_from_preset(HuePresetSteps, TargetHue);

// ==================== PATCH 2: apply luma zones to yStrength ====================
// In PS_BluePivotHSLW_v3(), after you compute:
//   float yStrength = saturate(yellowMask * gate * fadeWhite);
// add:

//   float lum0 = luminance_rec709(c0); // original for stability
//   float lumaW = luma_zone_weight(saturate(lum0), LumaZoneSoftness);
//   yStrength = saturate(yStrength * lumaW * LumaZoneBoost);

// Then keep the rest (whiteStrength/blackStrength/injectStrength) as-is but derived from the new yStrength.
```

### How this behaves

#### Stepped Target Hue (degrees)
- You get a **combo** with exactly: **20°, 50°, 110°, 190°, 230°, 310°, 340°**
- Default `HuePresetSteps = 2` picks **50°** (close to yellow and very usable)
- If you pick **Custom (slider)**, it uses your existing `TargetHue` slider

If you want “default = classic yellow”, set:
- `HuePresetSteps = 0` (custom) and `TargetHue = 1.0/6.0`, **or**
- add a “60°” entry to the combo.

#### Luma sections (5 checkboxes)
- You can force the effect into **shadows only**, or **mid only**, or “dark+mid”, etc.
- `LumaZoneSoftness` controls the blending at the zone boundaries.
- `LumaZoneBoost` is a global gain after zoning (helpful when you disable many zones and want strength back).

### Quick note about your goal (“darker colors aren’t influenced”)
This luma zoning will let you *include shadows*, but the chroma-weighted mask can still be low in very dark regions. If you later want “true shadow activation”, the next step is a **Shadow Chroma Boost** (lift chromaScalar based on low luminance). I didn’t add that here since you asked for modular luma switches first.

If you want, I can now merge these changes into your full file (end-to-end) so you can paste one complete `.fx` without manual edits.

## @3d2025stephen-art

is there a way to make the Ui show a color name when the slider hover the frequency then interact the hue width for this detection?

## Copilot

ReShade can’t do true “tooltips on hover” or dynamically display a computed **color name** for a slider value. The UI metadata is static (labels/categories/items), and shaders can’t send strings back to the UI.

What you *can* do (practical alternatives):

## 1) Use a Combo (best UX): names + degrees + width presets
Since you already like stepped degrees, the most user-friendly approach is to encode the name directly in the combo item text, e.g. “50° (Warm Yellow)”.

Example:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform int HuePresetSteps <
    ui_label = "Target Hue (named)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20°  (Amber)\0"
        "50°  (Warm Yellow)\0"
        "110° (Yellow-Green)\0"
        "190° (Cyan)\0"
        "230° (Sky Blue)\0"
        "310° (Magenta)\0"
        "340° (Hot Pink)\0";
    ui_min = 0; ui_max = 7;
> = 2;
```

This gives you the “name appears when you hover/select” experience (because the name is always visible in the dropdown list).

## 2) “Interact Hue Width” with the preset (automatic width per hue)
Yes—this is easy and works well. You can make Hue Width be:
- manual (slider), **or**
- auto (a width chosen per preset)

### Add width controls
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;
```

### Add a helper to pick width by preset
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float hue_width_from_preset(int preset, float fallback)
{
    // Tuned examples (you can adjust):
    // - warm hues often need tighter width to avoid spill into skin/yellow
    // - cyan/blue can be a bit wider
    if (preset == 1) return 7.5; // 20° amber (tighter-ish)
    if (preset == 2) return 7.0; // 50° warm yellow
    if (preset == 3) return 6.5; // 110° yellow-green
    if (preset == 4) return 5.5; // 190° cyan (wider)
    if (preset == 5) return 5.5; // 230° sky blue
    if (preset == 6) return 6.0; // 310° magenta
    if (preset == 7) return 6.5; // 340° hot pink
    return fallback;
}
```

### Use it inside `selective_yellow_weight()`
Replace your band line:

```hlsl
float band = max(1.0 - abs((h - center) * 6.0), 0.0);
```

with:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;
float band = max(1.0 - abs((h - center) * width), 0.0);
```

This keeps your “triangle band” model but makes the width parameterized and optionally preset-driven.

### Important note (red wrap again)
This still uses `abs(h-center)` (no wrap). For your chosen presets (20°, 50°, 110°, 190°, 230°, 310°, 340°) it’s *mostly fine*, but 340° is close to wrap. If you notice weirdness near that preset, the fix is the `hue_dist01()` wrap-distance version later.

## 3) Optional: show a “color swatch” instead of a name
ReShade can show a color picker control (`ui_type="color"`). You can’t tie it live to the hue slider automatically in UI, but you *can* offer a “TargetColorRGB” picker as an alternate input. That’s the closest to “visual name”.

---

### What I’d implement for best usability
- Keep your **named preset combo** (solves “color name” request)
- Add **AutoHueWidth** + **HueWidth (manual)** as above

If you want, tell me whether you prefer:
- HueWidth to live inside the **foldable “HUE / Pastel Controls”**, or
- in a separate category like **“HUE Detection”**.

## @3d2025stephen-art

yes this is the best option to not make interactive data, ty

## Copilot

Got it. The clean “best UX without interactive UI data” setup is:

1) **Named Hue preset combo** (your degrees + names)
2) **Hue Width** slider
3) **Auto Hue Width** checkbox (optional, preset-driven)

Here are the exact snippets to paste in.

### 1) Replace/define the Hue preset UI (named)
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform int HuePresetSteps <
    ui_label = "Target Hue (named presets)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20°  (Amber)\0"
        "50°  (Warm Yellow)\0"
        "110° (Yellow-Green)\0"
        "190° (Cyan)\0"
        "230° (Sky Blue)\0"
        "310° (Magenta)\0"
        "340° (Hot Pink)\0";
    ui_min = 0; ui_max = 7;
> = 2;

uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;
```

### 2) Add Hue Width + Auto Width
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;
```

### 3) Add helpers (near your helpers section)
```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float hue_center_from_preset(int preset, float fallbackHue)
{
    if (preset == 1) return 20.0 / 360.0;
    if (preset == 2) return 50.0 / 360.0;
    if (preset == 3) return 110.0 / 360.0;
    if (preset == 4) return 190.0 / 360.0;
    if (preset == 5) return 230.0 / 360.0;
    if (preset == 6) return 310.0 / 360.0;
    if (preset == 7) return 340.0 / 360.0;
    return fallbackHue;
}

float hue_width_from_preset(int preset, float fallback)
{
    // Feel free to tune these. Higher = narrower selection.
    if (preset == 1) return 7.5; // Amber
    if (preset == 2) return 7.0; // Warm Yellow
    if (preset == 3) return 6.5; // Yellow-Green
    if (preset == 4) return 5.5; // Cyan
    if (preset == 5) return 5.5; // Sky Blue
    if (preset == 6) return 6.0; // Magenta
    if (preset == 7) return 6.5; // Hot Pink
    return fallback;
}
```

### 4) Update `selective_yellow_weight()` to use them
Replace the center + band lines:

```hlsl
float center = TargetHue;
float band = max(1.0 - abs((h - center) * 6.0), 0.0);
```

with:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float center = hue_center_from_preset(HuePresetSteps, TargetHue);

float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;
float band = max(1.0 - abs((h - center) * width), 0.0);
```

That gives you exactly what you want: **named frequency presets** (no interactive text needed) and HueWidth that can either be **manual** or **smart per preset**.

Whenever you want later, we can add the hue-wrap fix (only matters near 340°/red side), but you can ignore it if it looks fine in practice.

## @3d2025stephen-art

Some antibanding will add only one slider?

## Copilot

Yes—if you want **one** “anti-banding” slider, the cleanest single-control approach in ReShade is to add **micro-dither** to the *mask strength* (or to the final mix factor) before applying strong `pow()`/tight blends. One slider can control the dither amplitude.

This won’t change your color design; it just breaks up quantization steps in smooth gradients.

## Add one slider
Place near Debug or near the HUE/Pastel group:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
uniform float AntiBanding <
    ui_label = "Anti-Banding (dither)";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.15;
```

## Add a tiny hash noise helper (no textures)
Put in HELPERS:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
float hash12(float2 p)
{
    // Simple stable screen-space noise [0..1]
    float h = dot(p, float2(127.1, 311.7));
    return frac(sin(h) * 43758.5453123);
}
```

## Apply it at the best place (to `yStrength`)
Right after you compute:

```hlsl
float yStrength = saturate(yellowMask * gate * fadeWhite);
```

add:

```hlsl name=BluePivot-HSLW_Version35 -PINK.fx
if (AntiBanding > 0.0)
{
    // noise in [-0.5..+0.5]
    float n = hash12(uv * BUFFER_SIZE) - 0.5;

    // amplitude: tiny. scale down hard so slider feels safe.
    float amp = AntiBanding * (1.0 / 255.0) * 6.0; // ~0..0.0235
    yStrength = saturate(yStrength + n * amp);
}
```

### How to use
- Start around **0.10–0.25**
- If you see sparkle/grain: lower it
- If banding persists in skies: raise slightly

### Why this works with only one slider
Banding is usually from smooth gradients + hard mask edges/curves. A tiny dither:
- decorrelates the thresholding
- hides steps without needing multiple controls

If you prefer the dither to affect only the *mask* (not the gate/whites), we can instead apply it to `yellowMask` only—but `yStrength` is usually the most effective single place.

## @3d2025stephen-art

I prefer to not add this antibanding so the user can see the pure preformances of my color filter, this will stay a good concept to rework the filter later as antibanding explusive with less sliders foccusing only that, like this we will dispose of all the filters values to refine on this target then i will rework the labelling on purpose

## Copilot

That’s a solid call. Keeping the main shader “pure” makes it easier to judge the real color math, and an anti-banding variant is best as a separate **exclusive pass** (or separate technique) so users don’t conflate grain with the look.

If you later decide to ship an **AntiBanding-exclusive** edition while preserving all your tuning values, the clean structure is:

- **Same uniforms** (so presets transfer 1:1)
- Add **one** antibanding control (or even fixed, no UI)
- Implement it as either:
  1) a **separate technique** in the same `.fx` file (users enable one or the other), or  
  2) a **separate `.fx` file** (most foolproof for “exclusive”)

### Recommended: separate technique (keeps one file)
- `technique BluePivot_HSLW_v3_Pastel` (pure)
- `technique BluePivot_HSLW_v3_Pastel_AntiBand` (same shader + dither)

That way you can compare instantly in ReShade and keep performance expectations clear.

Whenever you’re ready, tell me which “exclusive” approach you prefer (second technique vs separate file), and whether you want antibanding applied to:
- the **final strength** (`yStrength`) (most effective), or
- the **hue mask only** (least intrusive to gate/tonal logic).

## @3d2025stephen-art

hopefully both concept being since the same shader if i make complementary they will not fail each other, the compatibility will be the most of my experiments i guess

## Copilot

Yes—if both concepts share the same core shader and parameters, they’ll stay compatible as long as you keep a few rules. Here’s the safest way to make them “complementary” without breaking each other.

## Best pattern: one core function + two techniques
Put all your color logic in **one** function (your current `PS_BluePivotHSLW_v3` body), then have:

- **Technique A (Pure):** calls the core function with no dithering
- **Technique B (AntiBand):** calls the same core function but adds a small dither to `yStrength` (or mask) before applying white/black/inject

This guarantees:
- identical behavior when AntiBand = 0
- presets remain compatible
- you can A/B instantly and users won’t accidentally “stack” them if they only enable one technique

### The one rule that prevents failure
**Never enable both techniques at the same time**, because post-process passes stack. If both are enabled you’ll double-apply the effect (even if one is “pure”).

To make it hard to mess up, you can:
- name them clearly: `(... PURE)` and `(... ANTIBAND)`
- put a comment: “Enable only one technique”

## Compatibility rules (so experiments don’t drift)
1) **Keep uniforms identical** between variants  
   Don’t rename parameters between pure and antiband versions.

2) **Keep mask math identical**; only modify a single point  
   e.g. `yStrength = saturate(yStrength + noise * amp);`

3) **Use stable noise**  
   Screen-space hash from `uv` (stable across frames), not time-based. That avoids shimmering.

4) **Make antiband strength default to 0 (or absent)**  
   So if someone toggles the antiband technique, it’s still predictable.

## Alternative: complementary but non-stacking (single technique switch)
If you prefer a single technique, you can add:
- `uniform bool EnableAntiBanding` (checkbox)
and branch in shader. That avoids the “both enabled” issue entirely, but you said you’d rather keep the main filter pure—so I’d only do this if you want simplicity.

## If you want, I can structure your file for this
I can rewrite your `.fx` so it has:
- a shared function `ApplyBluePivotHSLW(...)`
- two pixel shaders or a single pixel shader with a compile-time define
- two techniques: PURE + ANTIBAND

Tell me which form you prefer:
1) **Two techniques** (PURE / ANTIBAND) with no extra UI in PURE, or  
2) **One technique** with a checkbox to enable antibanding.

## @3d2025stephen-art

yes not al colors need antimabing but my tool can handle the pastel well enough for some green or purple , neon colors by amount of black in the tint, the debanding will not control the alpha but the gamma for red and green rgb i think

## Copilot

Debanding/anti-banding is best kept **independent of your alpha/gate logic**. If you apply it to the gate or to alpha, you can change *where* the effect applies (not just how smooth it looks). So your instinct is right: debanding should not “control the alpha”.

A clearer way to think about it:

- **Gate / alpha** decides *where* the effect applies.
- **Debanding** should only break up *quantization steps* in smooth gradients, ideally at the *very last stage* of the effect strength (or in the color output), not in the gate.

### What “gamma for red and green” would do (and why it’s risky)
If you add a gamma/power shaping on **R/G channels** to fight banding, it’s no longer just debanding:
- it changes the color science (hue/chroma balance)
- it can shift neon behavior and skin tones
- it can interact with your `RedGain/GreenGain` and the blue pivot

So I would *not* recommend “gamma for red and green RGB” as the debanding method unless you intentionally want a stylistic curve.

### The two safe debanding targets (pick one later)
If you make an AntiBand exclusive variant later, pick **one** of these approaches:

#### A) Dither only the final strength (recommended)
Add tiny noise to `yStrength` **after**:
- hue mask
- pastel bias
- gate
- preserve whites
- luma zones (if you add them)

This does **not** change the selection logic; it only softens “steps” at boundaries and in smooth gradients where `yStrength` is slowly varying.

Effect: minimal look change, minimal risk.

#### B) Dither only the output (least intrusive to selection)
Add very small dither to the final `c` (RGB) before output (especially in sRGB output).
This reduces visible banding in gradients even when your mask is stable.

Effect: can add faint grain; but doesn’t affect where the effect applies.

### Why “not all colors need antibanding” is true
Banding usually shows up in:
- smooth gradients (sky, fog, bloom falloff)
- low-chroma midtones
- compressed output (8-bit capture)

Neon colors with strong chroma often hide banding naturally, and your “yellow→black tint control” can also add enough contrast texture to mask it.

### Best compatibility design for your experiments
When you do it later, keep:
- **PURE** technique = unchanged math
- **ANTIBAND** technique = identical math + 1 final-stage deband step (A or B)

Both use the same uniforms so presets stay compatible.

If you want, tell me which you’d prefer for your future ANTIBAND variant:
- **A) dither `yStrength`** (most effective for mask-edge stepping), or
- **B) dither final `c`** (general gradient debanding, doesn’t touch selection at all).

## @3d2025stephen-art

i tested to reimplement a 6th debug mode, the early version i used in my filter which is very good, but i failed my fx wont load now

## Copilot

Likely the file doesn’t compile because of a **brace/else chain mismatch** in the DebugMode block. In your pasted code, you added `DebugMode == 6`, but the structure around the final `else // DebugMode == 5` makes it easy to break the `if / else if / else` chain.

### The safest fix
Rewrite the Debug block so **each mode is an `else if`**, and make `DebugMode == 5` and `DebugMode == 6` explicit (no “catch-all else”).

Replace your entire DebugMode handling block with the version below.

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
    // --- DEBUG ---
    if (DebugMode != 0)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (DebugMode == 1)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear)
                outc = linear_to_srgb(outc);

            return float4(outc, 1.0);
        }
        else if (DebugMode == 2)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear)
                masks = linear_to_srgb(masks);

            return float4(masks, 1.0);
        }
        else if (DebugMode == 3)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 4)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 6)
        {
            // Classic debug: show hueMask in R, gate in G, B=0
            float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);

            if (WorkInLinear)
                dbg = linear_to_srgb(dbg);

            return float4(dbg, 1.0);
        }

        // Fallback if DebugMode has an unexpected value
        // (Shouldn't happen due to ui_max=6)
        float3 fallback = c0;
        if (WorkInLinear) fallback = linear_to_srgb(fallback);
        return float4(fallback, 1.0);
    }
```

### Why your version likely failed
This part is the issue:

```hlsl
else // DebugMode == 5
{
   ...
}
else // DebugMode == 6
{
   ...
}
```

Only **one** `else` can follow an `if` chain. The second `else` makes the shader fail to compile, so ReShade won’t load it.

### How to confirm (fast)
Open ReShade → **Log** tab (or the `ReShade.log` file) and you’ll see an error like:
- `error X3000: syntax error: unexpected token 'else'`
or
- `error: mismatched braces`

If you paste the compile error line from the log, I can pinpoint it exactly—but the replacement block above should fix it immediately.

## @3d2025stephen-art

thanks, this works and i noticed the beauty mask debug is very close with the one i added, but i prefered the Y2R Gate2G i added is smooth to debug some gradients zones of the video, what difference with the beauty mask debug?

## Copilot

Beauty Masks (DebugMode=2) and your **Y2R Gate2G** (DebugMode=6) are showing *related* data, but at different stages and with different “view transforms”, so they feel different on gradients.

### What Beauty Masks shows (DebugMode = 2)
In your code it outputs:

- **R = yv = pow(saturate(yellowMask), DebugGamma)**
- **G = gv = pow(saturate(gate), DebugGamma)**
- **B = fv = pow(finalViz, DebugGamma)** where `finalViz` includes tonal strengths + inject

So it’s a “3-in-1 diagnostic”:
- **Red channel:** hue mask coverage only
- **Green channel:** gate coverage only
- **Blue channel:** “final influence” coverage (what will actually drive tone/inject), *including* Yellow→White/Black + Blue Inject

It’s great when you want to see **why** something is affected: mask vs gate vs final.

Why it can feel less smooth:
- it applies `pow(..., DebugGamma)` (contrast shaping)
- it’s a composite view (three different meanings at once)
- blue channel is *finalViz*, which can have sharper transitions (max + inject)

### What your Y2R Gate2G shows (DebugMode = 6)
You output:

- **R = yellowMask** (raw)
- **G = gate** (raw)
- **B = 0**

No `DebugGamma`, no `finalViz`, no overlay mixing.

Why it feels smoother on gradients:
- it’s **linear mapping** of the masks (unless you add gamma yourself)
- no extra shaping/contrast expansion
- you’re looking at *two base signals only*, not the final composed influence

### Practical difference in what they help you debug
Use **Beauty Masks** when:
- you need to diagnose “why is this changing?” (mask vs gate vs final strength)
- you’re tuning `YellowToWhite/Black` or `EnableHueBlueInject` and want to see their contribution (blue channel)

Use **Y2R Gate2G** when:
- you want a **clean, smooth, readable gradient** of the two key drivers
- you’re tuning hue detection (`TargetHue`, MaskBoost/Tightness, PastelBias) and gate (`RedToAlpha`, `GreenToAlpha`, `AlphaGatePower`) without “final” complexity

### If you want Beauty Masks to behave like your smooth mode
A small tweak (optional) is to apply `DebugGamma` only when you want it, or add a `DebugGamma=1` default. But honestly: keeping both modes is useful—Mode 2 for “full analysis”, Mode 6 for “smooth field inspection”.

If you want, I can also make Mode 6 use `DebugGamma` *optionally* (still smoother than Beauty Masks because it won’t include `finalViz`).

## @3d2025stephen-art

No needs i guess keeping oth like this is good feature, so for a good visualization of gradients if my filter has a antibanding version the existant debugs can be converted on purpose to keep the feeling othis filter, like a pair of tool well intuitive?

## Copilot

Yes—your current debug modes are already a strong “instrument panel”, and they can stay intuitive even if you later add an antibanding variant, as long as you follow one guiding principle:

**Debug should visualize the *pre-antiband* signals (the real math), not the dithered result.**

That keeps the “feeling” and meaning consistent between PURE and ANTIBAND versions.

## How to pair them intuitively (PURE + ANTIBAND)
If you make an antibanding technique later, you’ll likely introduce one extra signal, e.g.:

- `yStrength_raw` (what you have now)
- `yStrength_ab` (after dither/deband step)

### Recommended mapping for your existing debug modes
Keep your debug modes exactly as they are, but base them on:

- **Hue Mask Only (Mode 3):** always show `yellowMask` (raw)
- **Gate Only (Mode 4):** always show `gate` (raw)
- **Final Only (Mode 5):** show `finalViz_raw` (computed from `yStrength_raw`)
- **Y2R Gate2G (Mode 6):** show `yellowMask` (R) + `gate` (G) raw

This way, when you turn on antibanding, the debug view still describes the *true selection and strength design*, not the noise.

## Optional: one extra debug mode for antiband inspection (if you ever want it)
You don’t need it now, but the most intuitive addition later would be:

- **Mode 7: “AntiBand Delta”**
  - shows `abs(yStrength_ab - yStrength_raw)` as grayscale
  - or shows `yStrength_raw` in R and `yStrength_ab` in G

That lets you verify antibanding is “just smoothing” and not shifting the region.

## Why this works as a “paired tool”
- PURE and ANTIBAND feel like the same filter (same mask/gate logic)
- Debug always means the same thing
- You can still debug gradients (Mode 6 is perfect for that) without the dither confusing your read

## Naming/UX tip for later
If you ship two techniques:
- `BluePivot_HSLW_v3_Pastel (PURE)`
- `BluePivot_HSLW_v3_Pastel (ANTIBAND)`

and keep debug identical, users immediately understand they’re paired variants.

When you’re ready to do the antiband version, tell me which approach you prefer (dither `yStrength` vs dither final RGB), and I can show how to structure it so **all debug modes remain “pure” by design**.

## @3d2025stephen-art

please add the luma and combo i fear to fail if i implement

## Copilot

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
// Reshade: BluePivot-HSLW v3 pastel v35 (Hue-based UI grouping update)
//
// Implemented (from this chat):
// - Stable target-hue detection from ORIGINAL sample (c0) using selective_yellow_weight()
// - Multi DebugMode (Off/Overlay/Beauty/Yellow/Gate/Final)
// - Pastel bias (signed) to boost/protect creamy near-white hues
// - Optional Hue Blue Inject (checkbox + signed slider) [renamed in UI]
// - Soft gate shaping remains (AlphaGatePower), and gate is used as a smooth multiplier
// - Two tonal sliders: Hue -> White AND Hue -> Black (hue-only, soft, polyvalent)
// - Foldable group ("HUE / Pastel Controls") for TargetHue through PastelSoftness
// - DebugMode 6: Y2R Gate2G (smooth gradients debug)
//
// NEW in this revision (requested):
// - Named hue preset combo (degrees) + optional Auto Hue Width + manual Hue Width
// - Modular 5-zone luminance (luma) focus via checkboxes + softness + boost
//
// Notes:
// - Default TargetHue remains yellow (1/6) and HuePresetSteps defaults to "Custom (slider)".
// - Hue preset combo + width only affects hue detection band; all other behavior unchanged.
// - Luma zones only modulate final yStrength (hueMask * gate * fadeWhite) and do not change the masks themselves.

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R↔Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G↔Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan ↔ Magenta)";
    ui_type = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
// We keep TargetHue as the "group header" by setting ui_category_closed=true here.

uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1 (0.166=Yellow default)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

uniform int HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20°  (Amber)\0"
        "50°  (Warm Yellow)\0"
        "110° (Yellow-Green)\0"
        "190° (Cyan)\0"
        "230° (Sky Blue)\0"
        "310° (Magenta)\0"
        "340° (Hot Pink)\0";
    ui_min = 0; ui_max = 7;
> = 0;

uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;

// ---- Hue tonal correction (polyvalent) ----
uniform float YellowToWhite <
    ui_label = "Hue → White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue → Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

// Selective Hue mask controls
uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

// ---- Pastel bias (signed) ----
uniform float PastelBias <
    ui_label = "Pastel Bias ( -protect creams ... +boost creams )";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- LUMA ZONES (modular checkboxes) ----
uniform bool LumaZone1_Shadows <
    ui_label = "Luma Zone 1: Shadows (0-20%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone2_Darks <
    ui_label = "Luma Zone 2: Darks (20-40%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone3_Mids <
    ui_label = "Luma Zone 3: Mids (40-60%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone4_Lights <
    ui_label = "Luma Zone 4: Lights (60-80%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone5_Highlights <
    ui_label = "Luma Zone 5: Highlights (80-100%)";
    ui_type  = "checkbox";
> = true;

uniform float LumaZoneSoftness <
    ui_label = "Luma Zone Softness";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 0.20;
> = 0.04;

uniform float LumaZoneBoost <
    ui_label = "Luma Zone Boost";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 4.0;
> = 1.0;

// ---- Red/Green -> gate ----
uniform float RedToAlpha <
    ui_label = "Red → Alpha (gate weight)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform float GreenToAlpha <
    ui_label = "Green → Alpha (gate weight)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform float AlphaGatePower <
    ui_label = "Alpha Gate Power";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 4.0;
> = 1.5;

uniform float PreserveWhites <
    ui_label = "Preserve Whites (fade near white)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.75;

// ---- Optional blue injection style (renamed in UI) ----
uniform bool EnableYellowBlueInject <
    ui_label = "Enable Hue Blue Inject";
    ui_type  = "checkbox";
> = false;

uniform float YellowBlueInject <
    ui_label = "Hue Blue Inject ( -remove ... +add )";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform bool WorkInLinear <
    ui_label = "Work In Linear (recommended)";
    ui_type = "checkbox";
> = true;

// ---- Debug ----
uniform int DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0";
    ui_min = 0; ui_max = 6;
> = 0;

uniform float DebugOverlayStrength <
    ui_label = "DEBUG Overlay Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.65;

uniform float DebugGamma <
    ui_label = "DEBUG Gamma (mask visibility)";
    ui_type = "slider";
    ui_min = 0.4; ui_max = 2.2;
> = 0.85;


// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float curve(float x) { return x * x * (3.0 - 2.0 * x); } // smoothstep-like

// Very small RGB->Hue (0..1) helper (ok for masks)
float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float hue_center_from_preset(int preset, float fallbackHue)
{
    if (preset == 1) return 20.0 / 360.0;
    if (preset == 2) return 50.0 / 360.0;
    if (preset == 3) return 110.0 / 360.0;
    if (preset == 4) return 190.0 / 360.0;
    if (preset == 5) return 230.0 / 360.0;
    if (preset == 6) return 310.0 / 360.0;
    if (preset == 7) return 340.0 / 360.0;
    return fallbackHue;
}

float hue_width_from_preset(int preset, float fallback)
{
    // Higher = narrower selection (because band uses: 1 - |h-center| * width)
    if (preset == 1) return 7.5; // Amber
    if (preset == 2) return 7.0; // Warm Yellow
    if (preset == 3) return 6.5; // Yellow-Green
    if (preset == 4) return 5.5; // Cyan
    if (preset == 5) return 5.5; // Sky Blue
    if (preset == 6) return 6.0; // Magenta
    if (preset == 7) return 6.5; // Hot Pink
    return fallback;
}

float bandpass01(float x, float a, float b, float s)
{
    // Smooth band-pass: 1 inside [a,b], fades at edges with softness s.
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight(float lum, float softness)
{
    // 5 zones: [0-0.2], [0.2-0.4], [0.4-0.6], [0.6-0.8], [0.8-1]
    float w = 0.0;
    if (LumaZone1_Shadows)    w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)      w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)       w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)     w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights) w += bandpass01(lum, 0.8, 1.0, softness);

    return saturate(w);
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float scalar = mx - mn;
    float cmy_scalar = 0.5 * scalar;

    float h = rgb_hue01(saturate(c));

    float center = hue_center_from_preset(HuePresetSteps, TargetHue);
    float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;

    // Triangular band (no wrap)
    float band = max(1.0 - abs((h - center) * width), 0.0);
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;

    w_y = saturate(w_y * chromaBoost);
    w_y = pow(w_y, hueTightness);
    return saturate(w_y);
}


// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    // Sample original
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    // 1) Hue mask from ORIGINAL (stable)
    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    // 1b) Pastel bias on hue mask (signed)
    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    // 2) Main color shaping
    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float b = c.b;
    c.r += pivot * b * 0.5;
    c.g -= pivot * b * 0.5;

    // 3) Gate (smooth)
    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    // 4) Highlight protection / fade near white
    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    // 5) Final strength terms (computed once for debug consistency)
    float yStrength = saturate(yellowMask * gate * fadeWhite);

    // Luma zone modulation (modular)
    float lum0 = luminance_rec709(c0); // original for stability
    float lumaW = luma_zone_weight(saturate(lum0), LumaZoneSoftness);
    yStrength = saturate(yStrength * lumaW * LumaZoneBoost);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    // --- DEBUG ---
    if (DebugMode != 0)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (DebugMode == 1)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear)
                outc = linear_to_srgb(outc);

            return float4(outc, 1.0);
        }
        else if (DebugMode == 2)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear)
                masks = linear_to_srgb(masks);

            return float4(masks, 1.0);
        }
        else if (DebugMode == 3)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 4)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 6)
        {
            // Classic debug: show hueMask in R, gate in G, B=0
            float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);
            if (WorkInLinear) dbg = linear_to_srgb(dbg);
            return float4(dbg, 1.0);
        }

        float3 fallback = c0;
        if (WorkInLinear) fallback = linear_to_srgb(fallback);
        return float4(fallback, 1.0);
    }

    // 6) Apply hue tonal correction (soft, hue-only)
    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    // 7) Optional: Hue Blue Inject (signed)
    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear)
        c = linear_to_srgb(c);

    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```

## @3d2025stephen-art

this works the level is source of truth, each hue has the perfect inluence, but i noticed only my red/green rgb and blue/magenta balance are able to change the blue and violet, why both arent editable by our pass filters do we need a purple blue btween sky blue and magenta ? the white and black controls can be useful there too

## Copilot

Your pass *can* affect blue/violet with **Hue → White/Black** and **Hue Blue Inject**, but only **if the hue mask actually selects those pixels**.

Right now there are two reasons it often *doesn’t* (so it feels like only the global RGB + pivot affect blues/purples):

## 1) Your hue band does **not wrap** (important for magenta / hot pink)
Your selection uses:

```hlsl
abs(h - center)
```

Hue is circular (0 == 1). Without wrap-distance, hues near **340°** (0.944) and **magenta-ish** can behave strangely, and anything near the 0/1 boundary can fall outside the band even if it’s “close” perceptually.

This is the #1 fix for reliable purple/magenta selection.

### Fix: circular hue distance (recommended)
Add this helper:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}
```

Then in `selective_yellow_weight()` replace:

```hlsl
float band = max(1.0 - abs((h - center) * width), 0.0);
```

with:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
float d = hue_dist01(h, center);
float band = max(1.0 - (d * width), 0.0);
```

After this, your presets like **310° (Magenta)** and **340° (Hot Pink)** will actually “grab” the intended range.

## 2) Your preset list skips a true “violet / purple” anchor
You currently have:
- 230° Sky Blue
- 310° Magenta

But violet/purple often sits around **260°–290°** depending on content:
- ~**270°** = classic “violet”
- ~**280°** = purple leaning magenta
- ~**250°** = deep blue-ish purple

So yes: adding a **Purple/Violet preset between Sky Blue and Magenta** is useful and intuitive.

### Add one preset (example: 280° “Purple”)
Update `ui_items` to include it:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
ui_items =
    "Custom (slider)\0"
    "20°  (Amber)\0"
    "50°  (Warm Yellow)\0"
    "110° (Yellow-Green)\0"
    "190° (Cyan)\0"
    "230° (Sky Blue)\0"
    "280° (Purple)\0"
    "310° (Magenta)\0"
    "340° (Hot Pink)\0";
ui_min = 0; ui_max = 8;
```

Then update `hue_center_from_preset()` mapping:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
if (preset == 6) return 280.0 / 360.0; // Purple
if (preset == 7) return 310.0 / 360.0; // Magenta
if (preset == 8) return 340.0 / 360.0; // Hot Pink
```

And update `hue_width_from_preset()` accordingly (shift indices, add one value).

## Why white/black controls “can be useful there too”
They absolutely can—once the hue mask correctly selects purple/blue pixels:
- **Hue → White** will pastelize/lift violets (nice for anime/neon grading)
- **Hue → Black** will deepen/punch blues/purples (good for neon sign contrast)

## What I recommend you do next (minimal + high impact)
1) **Implement hue wrap distance** (the 3-line change above). This alone usually makes magenta/pink selection finally “work”.
2) Add **one Purple preset** (280° is a good starting point).
3) Optionally tune AutoHueWidth for purple (often slightly narrower than cyan/blue to avoid spill).

If you want, I can provide the exact full updated blocks (combo + both helper functions) with the correct new indices so you can paste without hunting for every place that needs changing.

## @3d2025stephen-art

ok

## Copilot

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
// ==================== PATCH: add Hue Wrap + add 280° Purple preset ====================
// Copy/paste these edits into your current working file.

// ---------- 1) Update HuePresetSteps UI (add Purple) ----------
// Replace your current HuePresetSteps uniform with this one (note ui_max=8 and the new item):

uniform int HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20°  (Amber)\0"
        "50°  (Warm Yellow)\0"
        "110° (Yellow-Green)\0"
        "190° (Cyan)\0"
        "230° (Sky Blue)\0"
        "280° (Purple)\0"
        "310° (Magenta)\0"
        "340° (Hot Pink)\0";
    ui_min = 0; ui_max = 8;
> = 0;


// ---------- 2) Add hue wrap-distance helper ----------
// Add this near your helpers (e.g., above selective_yellow_weight):

float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}


// ---------- 3) Update hue_center_from_preset for new indices ----------
// Replace your existing hue_center_from_preset with:

float hue_center_from_preset(int preset, float fallbackHue)
{
    if (preset == 1) return 20.0 / 360.0;   // Amber
    if (preset == 2) return 50.0 / 360.0;   // Warm Yellow
    if (preset == 3) return 110.0 / 360.0;  // Yellow-Green
    if (preset == 4) return 190.0 / 360.0;  // Cyan
    if (preset == 5) return 230.0 / 360.0;  // Sky Blue
    if (preset == 6) return 280.0 / 360.0;  // Purple
    if (preset == 7) return 310.0 / 360.0;  // Magenta
    if (preset == 8) return 340.0 / 360.0;  // Hot Pink
    return fallbackHue; // Custom slider
}


// ---------- 4) Update hue_width_from_preset for new indices ----------
// Replace your existing hue_width_from_preset with:

float hue_width_from_preset(int preset, float fallback)
{
    // Higher = narrower selection (because band uses: 1 - dist * width)
    if (preset == 1) return 7.5; // Amber
    if (preset == 2) return 7.0; // Warm Yellow
    if (preset == 3) return 6.5; // Yellow-Green
    if (preset == 4) return 5.5; // Cyan
    if (preset == 5) return 5.5; // Sky Blue
    if (preset == 6) return 6.2; // Purple (slightly tighter than cyan/blue)
    if (preset == 7) return 6.0; // Magenta
    if (preset == 8) return 6.5; // Hot Pink
    return fallback;
}


// ---------- 5) Update selective_yellow_weight() to use wrap distance ----------
// In selective_yellow_weight(), replace this line:
//
//   float band = max(1.0 - abs((h - center) * width), 0.0);
//
// with these two lines:

    float d = hue_dist01(h, center);
    float band = max(1.0 - (d * width), 0.0);

// ==================== END PATCH ====================
```

After this:
- The **Purple** preset appears between Sky Blue and Magenta.
- Magenta/Hot Pink (near the 0/1 boundary) will select correctly because hue distance wraps.
- Your **Hue → White / Hue → Black** should now reliably work on purple/blue/violet areas once selected.

If you want a second purple option later (e.g. **260° Violet** vs **280° Purple**), you can add another preset the same way.

## @3d2025stephen-art

i found that we didnt think to synchronize the luma for each color, i mean we split the levels for the color mask but we didnt distribute the parsimony, yellow is sensitive tot he mid high so we can prohibit, as well each color has some sensitive levels to avoid, can we add a list of luma for each i can rework along the time to prohibit the necessary unuseful selections or authorized luma per color?

## Copilot

Yes. The clean way is to add a **per-hue-preset luma “allow list”** (which zones are enabled for that preset), plus an option to either:

- use your **manual 5 checkboxes** (global), or
- use **automatic per-preset luma zones** (so yellow can avoid highlights, cyan can include shadows, etc.)

This keeps your “parsimony” idea: each color gets a sensible luminance distribution, and you can refine it over time.

Below is a safe implementation that won’t break compilation and keeps your current manual zones as-is.

---

## 1) Add one selector: Manual vs Auto (per preset)
Add near the luma controls:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
uniform bool AutoLumaZones <
    ui_label = "Auto Luma Zones (per hue preset)";
    ui_type  = "checkbox";
> = false;
```

- `false` = your current manual checkboxes control luma
- `true` = luma zones are chosen automatically from a table per hue preset

---

## 2) Add a per-preset luma zone table (editable)
We’ll encode the 5 zones as a bitmask:

- bit0 = zone1 shadows
- bit1 = zone2 darks
- bit2 = zone3 mids
- bit3 = zone4 lights
- bit4 = zone5 highlights

Add these uniforms (they can live anywhere in UI; I suggest a separate category like `"Luma Presets"` so it doesn’t clutter):

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
uniform int LumaMask_Custom <
    ui_label = "Luma Mask: Custom preset (bits 1-31)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 31;

uniform int LumaMask_20 <
    ui_label = "Luma Mask: 20° Amber";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 14; // zones 2+3+4 (01110)

uniform int LumaMask_50 <
    ui_label = "Luma Mask: 50° Warm Yellow";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 12; // zones 3+4 (01100) avoid deep shadows + top highlights

uniform int LumaMask_110 <
    ui_label = "Luma Mask: 110° Yellow-Green";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 28; // zones 3+4+5 (11100)

uniform int LumaMask_190 <
    ui_label = "Luma Mask: 190° Cyan";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 31; // all

uniform int LumaMask_230 <
    ui_label = "Luma Mask: 230° Sky Blue";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 31; // all

uniform int LumaMask_280 <
    ui_label = "Luma Mask: 280° Purple";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 31; // all

uniform int LumaMask_310 <
    ui_label = "Luma Mask: 310° Magenta";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 30; // zones 2+3+4+5 (11110) avoid extreme shadows

uniform int LumaMask_340 <
    ui_label = "Luma Mask: 340° Hot Pink";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 28; // zones 3+4+5 (11100)
```

These defaults are just starting points—you’ll refine them.

---

## 3) Helpers: read mask and compute weight
Add these helpers near your other helpers:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
int luma_mask_from_preset(int preset)
{
    // preset: 0=Custom, 1=20°, 2=50°, 3=110°, 4=190°, 5=230°, 6=280°, 7=310°, 8=340°
    if (preset == 1) return LumaMask_20;
    if (preset == 2) return LumaMask_50;
    if (preset == 3) return LumaMask_110;
    if (preset == 4) return LumaMask_190;
    if (preset == 5) return LumaMask_230;
    if (preset == 6) return LumaMask_280;
    if (preset == 7) return LumaMask_310;
    if (preset == 8) return LumaMask_340;
    return LumaMask_Custom;
}

bool mask_has_zone(int mask, int zoneIndex) // zoneIndex 0..4
{
    return ((mask >> zoneIndex) & 1) != 0;
}

float luma_zone_weight_masked(float lum, float softness, int mask)
{
    float w = 0.0;

    if (mask_has_zone(mask, 0)) w += bandpass01(lum, 0.0, 0.2, softness);
    if (mask_has_zone(mask, 1)) w += bandpass01(lum, 0.2, 0.4, softness);
    if (mask_has_zone(mask, 2)) w += bandpass01(lum, 0.4, 0.6, softness);
    if (mask_has_zone(mask, 3)) w += bandpass01(lum, 0.6, 0.8, softness);
    if (mask_has_zone(mask, 4)) w += bandpass01(lum, 0.8, 1.0, softness);

    return saturate(w);
}
```

---

## 4) Replace your luma modulation block in the pixel shader
Find:

```hlsl
float lumaW = luma_zone_weight(saturate(lum0), LumaZoneSoftness);
yStrength = saturate(yStrength * lumaW * LumaZoneBoost);
```

Replace with:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
float lumaW = 1.0;

if (AutoLumaZones)
{
    int mask = luma_mask_from_preset(HuePresetSteps);
    lumaW = luma_zone_weight_masked(saturate(lum0), LumaZoneSoftness, mask);
}
else
{
    lumaW = luma_zone_weight(saturate(lum0), LumaZoneSoftness);
}

yStrength = saturate(yStrength * lumaW * LumaZoneBoost);
```

---

## How you’ll tune it over time
- For **yellow**, you can “prohibit” highlights by clearing zone5 bit.
  - example mask: `01110b = 14` (zones 2–4)
- For **magenta/pink**, you can prohibit deep shadows if it causes noise:
  - example mask: `11110b = 30` (zones 2–5)
- For **cyan/sky**, keep all zones if it’s safe.

If you want, I can also add a tiny “legend” comment listing common masks:
- 31 = all
- 28 = 3–5
- 30 = 2–5
- 14 = 2–4
- 12 = 3–4

Say the word and I’ll provide the exact code integrated into your current full file (so you can paste once).

## @3d2025stephen-art

how to do if i have to prohibit too spared zones ?

## Copilot

If you need to prohibit “too spread” zones (e.g. **allow only mids**, or **only a tight band like 40–60%**), you have 3 practical options—two are “policy” (how you set the mask), one is a small extra control.

## 1) Use contiguous-only masks (best discipline, no new code)
Because you’re using 5 zones, “too spread” usually means masks like:
- `10101` (zones 1 + 3 + 5) — scattered
- `10011` (zones 1 + 2 + 5) — scattered

To avoid that, just decide you’ll only use *contiguous* patterns such as:
- `00100` = **mids only** (mask = 4)
- `01100` = **mids+lights** (mask = 12)
- `11100` = **mids+lights+highlights** (mask = 28)
- `01110` = **darks+mids+lights** (mask = 14)
- `00110` = **darks+mids** (mask = 6)

This works today with the bitmask system—no changes.

## 2) Add a “Max gap / enforce contiguity” switch (small code, very effective)
If you want the shader to *automatically* prevent scattered selections, add one checkbox:

- When enabled, it converts any mask into a **filled range** from the first enabled zone to the last enabled zone.

So if you accidentally set `10101` (zones 1 and 3 and 5), it becomes `11111` (all) or, more usefully, it becomes the range from zone1..zone5 (still all). If you set `10010` (zones 2 and 5), it becomes `11110` (zones 2–5). This removes “holes”.

### Add this uniform
```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
uniform bool FillLumaMaskHoles <
    ui_label = "Fill Luma Mask Holes (avoid scattered zones)";
    ui_type  = "checkbox";
> = true;
```

### Add helper to “fill” between min/max set bits
```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
int fill_mask_holes_5(int m)
{
    // m uses only bits 0..4
    int mm = m & 31;
    if (mm == 0) return 0;

    int first = -1;
    int last = -1;

    [unroll] for (int i = 0; i < 5; i++)
    {
        if (((mm >> i) & 1) != 0)
        {
            if (first < 0) first = i;
            last = i;
        }
    }

    // Fill from first..last inclusive
    int outm = 0;
    [unroll] for (int i = 0; i < 5; i++)
    {
        if (i >= first && i <= last) outm |= (1 << i);
    }
    return outm;
}
```

### Use it when you fetch the preset mask
In your `AutoLumaZones` branch:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
int mask = luma_mask_from_preset(HuePresetSteps);
if (FillLumaMaskHoles)
    mask = fill_mask_holes_5(mask);
lumaW = luma_zone_weight_masked(saturate(lum0), LumaZoneSoftness, mask);
```

Now your per-color tuning can’t “skip around” unless you turn that off.

## 3) Replace zones with a single continuous luma window (tightest control)
If you find 5 zones still too coarse, the next step is a **continuous luma range**:
- `LumaMin`
- `LumaMax`
- `LumaSoftness`

That gives perfect “not spread” behavior by design—but it’s more sliders. Since you asked for the per-color list approach, I’d only do this if you later want higher precision.

---

### Which should you choose?
- If you want **no new UI**: just keep masks contiguous manually.
- If you want **fail-safe** against scattered masks: add `FillLumaMaskHoles` (1 checkbox, very worth it).

If you want, I can paste the exact integrated code blocks into your current file version so you don’t have to place them manually.

## @3d2025stephen-art

ye, authorized luma is more useful , this will fit

## Copilot

Agreed—**authorized luma (allow list)** fits your goal best.

If you implement the per-preset luma masks, I strongly recommend adding the single checkbox **“Fill Luma Mask Holes”** so your allowed-luma stays *coherent* (no scattered zones) while you refine over time.

Here are the minimal pieces you need (copy/paste), assuming you already have the per-preset `LumaMask_*` ints and the masked luma weighting function.

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
// ---- Add this UI toggle near your other luma controls ----
uniform bool FillLumaMaskHoles <
    ui_label = "Fill Luma Mask Holes (avoid scattered zones)";
    ui_type  = "checkbox";
> = true;


// ---- Add this helper near your other helpers ----
int fill_mask_holes_5(int m)
{
    int mm = m & 31; // keep bits 0..4
    if (mm == 0) return 0;

    int first = -1;
    int last  = -1;

    [unroll] for (int i = 0; i < 5; i++)
    {
        if (((mm >> i) & 1) != 0)
        {
            if (first < 0) first = i;
            last = i;
        }
    }

    // Fill from first..last inclusive
    int outm = 0;
    [unroll] for (int i = 0; i < 5; i++)
    {
        if (i >= first && i <= last) outm |= (1 << i);
    }

    return outm;
}
```

And in your pixel shader where you compute `lumaW` for the **AutoLumaZones** path:

```hlsl name=BluePivot-HSLW_Version35_Version5pink -Base debug mode6.fx
int mask = luma_mask_from_preset(HuePresetSteps);
if (FillLumaMaskHoles)
    mask = fill_mask_holes_5(mask);

lumaW = luma_zone_weight_masked(saturate(lum0), LumaZoneSoftness, mask);
```

### What you get
- You can “authorize” only the useful luminance regions per hue preset.
- You can still intentionally make a narrow band (e.g. mids only).
- You won’t accidentally create sparse masks like `10101`—they’ll auto-fill to a continuous allowed range (unless you disable the toggle).

If you paste your current file version that includes the per-preset masks, I can return a single fully merged `.fx` so you don’t have to integrate it manually.

## @3d2025stephen-art

this is the latest

## Copilot

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma.fx
// Reshade: BluePivot-HSLW v3 pastel v35 (Hue-based UI grouping update)
//
// Implemented (from this chat):
// - Stable target-hue detection from ORIGINAL sample (c0) using selective_yellow_weight()
// - Multi DebugMode (Off/Overlay/Beauty/Yellow/Gate/Final)
// - Pastel bias (signed) to boost/protect creamy near-white hues
// - Optional Hue Blue Inject (checkbox + signed slider) [renamed in UI]
// - Soft gate shaping remains (AlphaGatePower), and gate is used as a smooth multiplier
// - Two tonal sliders: Hue -> White AND Hue -> Black (hue-only, soft, polyvalent)
// - Foldable group ("HUE / Pastel Controls") for TargetHue through PastelSoftness
// - DebugMode 6: Y2R Gate2G (smooth gradients debug)
//
// NEW in this revision (requested):
// - Named hue preset combo (degrees) + optional Auto Hue Width + manual Hue Width
// - Modular 5-zone luminance (luma) focus via checkboxes + softness + boost
//
// NEW in this revision (requested now):
// - Auto Luma Zones (per hue preset) via per-preset 5-zone bitmasks (authorized luma)
// - Optional "Fill Luma Mask Holes" to avoid sparse/scattered zone selections
//
// Notes:
// - Default TargetHue remains yellow (1/6) and HuePresetSteps defaults to "Custom (slider)".
// - Hue preset combo + width only affects hue detection band; all other behavior unchanged.
// - Luma zones only modulate final yStrength (hueMask * gate * fadeWhite) and do not change the masks themselves.

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R↔Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G↔Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan ↔ Magenta)";
    ui_type = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
// We keep TargetHue as the "group header" by setting ui_category_closed=true here.

uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1 (0.166=Yellow default)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

uniform int HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20°  (Amber)\0"
        "50°  (Warm Yellow)\0"
        "110° (Yellow-Green)\0"
        "190° (Cyan)\0"
        "230° (Sky Blue)\0"
        "310° (Magenta)\0"
        "340° (Hot Pink)\0";
    ui_min = 0; ui_max = 7;
> = 0;

uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;

// ---- Hue tonal correction (polyvalent) ----
uniform float YellowToWhite <
    ui_label = "Hue → White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue → Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

// Selective Hue mask controls
uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

// ---- Pastel bias (signed) ----
uniform float PastelBias <
    ui_label = "Pastel Bias ( -protect creams ... +boost creams )";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- LUMA ZONES (manual checkboxes) ----
uniform bool LumaZone1_Shadows <
    ui_label = "Luma Zone 1: Shadows (0-20%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone2_Darks <
    ui_label = "Luma Zone 2: Darks (20-40%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone3_Mids <
    ui_label = "Luma Zone 3: Mids (40-60%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone4_Lights <
    ui_label = "Luma Zone 4: Lights (60-80%)";
    ui_type  = "checkbox";
> = true;

uniform bool LumaZone5_Highlights <
    ui_label = "Luma Zone 5: Highlights (80-100%)";
    ui_type  = "checkbox";
> = true;

uniform float LumaZoneSoftness <
    ui_label = "Luma Zone Softness";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 0.20;
> = 0.04;

uniform float LumaZoneBoost <
    ui_label = "Luma Zone Boost";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 4.0;
> = 1.0;

// ---- LUMA AUTHORIZATION (per hue preset) ----
uniform bool AutoLumaZones <
    ui_label = "Auto Luma Zones (per hue preset)";
    ui_type  = "checkbox";
> = false;

uniform bool FillLumaMaskHoles <
    ui_label = "Fill Luma Mask Holes (avoid scattered zones)";
    ui_type  = "checkbox";
> = true;

// Bits: zone1=1, zone2=2, zone3=4, zone4=8, zone5=16 (0..31)
uniform int LumaMask_Custom <
    ui_label = "Luma Mask (Custom): bits 0-4";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 31;

uniform int LumaMask_20 <
    ui_label = "Luma Mask (20° Amber)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 14; // zones 2+3+4

uniform int LumaMask_50 <
    ui_label = "Luma Mask (50° Warm Yellow)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 12; // zones 3+4

uniform int LumaMask_110 <
    ui_label = "Luma Mask (110° Yellow-Green)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 28; // zones 3+4+5

uniform int LumaMask_190 <
    ui_label = "Luma Mask (190° Cyan)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 31; // all

uniform int LumaMask_230 <
    ui_label = "Luma Mask (230° Sky Blue)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 31; // all

uniform int LumaMask_310 <
    ui_label = "Luma Mask (310° Magenta)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 30; // zones 2+3+4+5

uniform int LumaMask_340 <
    ui_label = "Luma Mask (340° Hot Pink)";
    ui_type  = "drag";
    ui_min = 0; ui_max = 31;
> = 28; // zones 3+4+5

// ---- Red/Green -> gate ----
uniform float RedToAlpha <
    ui_label = "Red → Alpha (gate weight)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform float GreenToAlpha <
    ui_label = "Green → Alpha (gate weight)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform float AlphaGatePower <
    ui_label = "Alpha Gate Power";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 4.0;
> = 1.5;

uniform float PreserveWhites <
    ui_label = "Preserve Whites (fade near white)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.75;

// ---- Optional blue injection style (renamed in UI) ----
uniform bool EnableYellowBlueInject <
    ui_label = "Enable Hue Blue Inject";
    ui_type  = "checkbox";
> = false;

uniform float YellowBlueInject <
    ui_label = "Hue Blue Inject ( -remove ... +add )";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform bool WorkInLinear <
    ui_label = "Work In Linear (recommended)";
    ui_type = "checkbox";
> = true;

// ---- Debug ----
uniform int DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0";
    ui_min = 0; ui_max = 6;
> = 0;

uniform float DebugOverlayStrength <
    ui_label = "DEBUG Overlay Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.65;

uniform float DebugGamma <
    ui_label = "DEBUG Gamma (mask visibility)";
    ui_type = "slider";
    ui_min = 0.4; ui_max = 2.2;
> = 0.85;


// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float curve(float x) { return x * x * (3.0 - 2.0 * x); } // smoothstep-like

// Very small RGB->Hue (0..1) helper (ok for masks)
float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float hue_center_from_preset(int preset, float fallbackHue)
{
    if (preset == 1) return 20.0 / 360.0;
    if (preset == 2) return 50.0 / 360.0;
    if (preset == 3) return 110.0 / 360.0;
    if (preset == 4) return 190.0 / 360.0;
    if (preset == 5) return 230.0 / 360.0;
    if (preset == 6) return 310.0 / 360.0;
    if (preset == 7) return 340.0 / 360.0;
    return fallbackHue;
}

float hue_width_from_preset(int preset, float fallback)
{
    // Higher = narrower selection (because band uses: 1 - |h-center| * width)
    if (preset == 1) return 7.5; // Amber
    if (preset == 2) return 7.0; // Warm Yellow
    if (preset == 3) return 6.5; // Yellow-Green
    if (preset == 4) return 5.5; // Cyan
    if (preset == 5) return 5.5; // Sky Blue
    if (preset == 6) return 6.0; // Magenta
    if (preset == 7) return 6.5; // Hot Pink
    return fallback;
}

float bandpass01(float x, float a, float b, float s)
{
    // Smooth band-pass: 1 inside [a,b], fades at edges with softness s.
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight(float lum, float softness)
{
    // 5 zones: [0-0.2], [0.2-0.4], [0.4-0.6], [0.6-0.8], [0.8-1]
    float w = 0.0;
    if (LumaZone1_Shadows)    w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)      w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)       w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)     w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights) w += bandpass01(lum, 0.8, 1.0, softness);

    return saturate(w);
}

int luma_mask_from_preset(int preset)
{
    if (preset == 1) return LumaMask_20;
    if (preset == 2) return LumaMask_50;
    if (preset == 3) return LumaMask_110;
    if (preset == 4) return LumaMask_190;
    if (preset == 5) return LumaMask_230;
    if (preset == 6) return LumaMask_310;
    if (preset == 7) return LumaMask_340;
    return LumaMask_Custom;
}

bool mask_has_zone(int mask, int zoneIndex) // zoneIndex 0..4
{
    return ((mask >> zoneIndex) & 1) != 0;
}

int fill_mask_holes_5(int m)
{
    int mm = m & 31;
    if (mm == 0) return 0;

    int first = -1;
    int last  = -1;

    [unroll] for (int i = 0; i < 5; i++)
    {
        if (((mm >> i) & 1) != 0)
        {
            if (first < 0) first = i;
            last = i;
        }
    }

    int outm = 0;
    [unroll] for (int i = 0; i < 5; i++)
    {
        if (i >= first && i <= last) outm |= (1 << i);
    }

    return outm;
}

float luma_zone_weight_masked(float lum, float softness, int mask)
{
    float w = 0.0;

    if (mask_has_zone(mask, 0)) w += bandpass01(lum, 0.0, 0.2, softness);
    if (mask_has_zone(mask, 1)) w += bandpass01(lum, 0.2, 0.4, softness);
    if (mask_has_zone(mask, 2)) w += bandpass01(lum, 0.4, 0.6, softness);
    if (mask_has_zone(mask, 3)) w += bandpass01(lum, 0.6, 0.8, softness);
    if (mask_has_zone(mask, 4)) w += bandpass01(lum, 0.8, 1.0, softness);

    return saturate(w);
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float scalar = mx - mn;
    float cmy_scalar = 0.5 * scalar;

    float h = rgb_hue01(saturate(c));

    float center = hue_center_from_preset(HuePresetSteps, TargetHue);
    float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;

    // Triangular band (no wrap)
    float band = max(1.0 - abs((h - center) * width), 0.0);
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;

    w_y = saturate(w_y * chromaBoost);
    w_y = pow(w_y, hueTightness);
    return saturate(w_y);
}


// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    // Sample original
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    // 1) Hue mask from ORIGINAL (stable)
    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    // 1b) Pastel bias on hue mask (signed)
    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    // 2) Main color shaping
    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float b = c.b;
    c.r += pivot * b * 0.5;
    c.g -= pivot * b * 0.5;

    // 3) Gate (smooth)
    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    // 4) Highlight protection / fade near white
    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    // 5) Final strength terms (computed once for debug consistency)
    float yStrength = saturate(yellowMask * gate * fadeWhite);

    // Luma zone modulation (manual or per-preset authorization)
    float lum0 = luminance_rec709(c0); // original for stability
    float lumaW = 1.0;

    if (AutoLumaZones)
    {
        int mask = luma_mask_from_preset(HuePresetSteps);
        if (FillLumaMaskHoles)
            mask = fill_mask_holes_5(mask);

        lumaW = luma_zone_weight_masked(saturate(lum0), LumaZoneSoftness, mask);
    }
    else
    {
        lumaW = luma_zone_weight(saturate(lum0), LumaZoneSoftness);
    }

    yStrength = saturate(yStrength * lumaW * LumaZoneBoost);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    // --- DEBUG ---
    if (DebugMode != 0)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (DebugMode == 1)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear)
                outc = linear_to_srgb(outc);

            return float4(outc, 1.0);
        }
        else if (DebugMode == 2)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear)
                masks = linear_to_srgb(masks);

            return float4(masks, 1.0);
        }
        else if (DebugMode == 3)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 4)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 6)
        {
            // Classic debug: show hueMask in R, gate in G, B=0
            float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);
            if (WorkInLinear) dbg = linear_to_srgb(dbg);
            return float4(dbg, 1.0);
        }

        float3 fallback = c0;
        if (WorkInLinear) fallback = linear_to_srgb(fallback);
        return float4(fallback, 1.0);
    }

    // 6) Apply hue tonal correction (soft, hue-only)
    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    // 7) Optional: Hue Blue Inject (signed)
    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear)
        c = linear_to_srgb(c);

    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```

## @3d2025stephen-art

the patched file failed to compile when i try to enable, next i tried to debug but i dindt find, i profited to add the missing path i had, can you debug? 

## Copilot

I can, but I need the exact compiler error text (or the file as you currently have it). ReShade will always log *why* it failed.

### 1) Please paste the error from the ReShade log
Open `ReShade.log` (same folder as ReShade) and copy the block around the error, it usually looks like:

- `ERROR: <path>\BluePivot...fx(<line>,<col>): error ...`
- plus a few lines after

Paste that here (even 5–20 lines is enough).

### 2) The most likely compile-break in the patched version
Without the log, the #1 suspect is this function:

```hlsl
bool mask_has_zone(int mask, int zoneIndex)
```

Some ReShade shader compilers/profiles don’t like `bool` returns in helper functions (or implicitly converting bool to float in arithmetic). Easiest fix: make it return `int` or `float` instead of `bool`.

Here is a safer version (no `bool` type at all):

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma.fx
int mask_has_zone(int mask, int zoneIndex) // returns 0 or 1
{
    return (mask >> zoneIndex) & 1;
}
```

And in `luma_zone_weight_masked`, change the `if` tests to compare against 0:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma.fx
if (mask_has_zone(mask, 0) != 0) w += bandpass01(lum, 0.0, 0.2, softness);
if (mask_has_zone(mask, 1) != 0) w += bandpass01(lum, 0.2, 0.4, softness);
if (mask_has_zone(mask, 2) != 0) w += bandpass01(lum, 0.4, 0.6, softness);
if (mask_has_zone(mask, 3) != 0) w += bandpass01(lum, 0.6, 0.8, softness);
if (mask_has_zone(mask, 4) != 0) w += bandpass01(lum, 0.8, 1.0, softness);
```

### 3) Another common fail: `[unroll] for (int i...)`
Some configurations choke on `[unroll]` or `for` loops in certain shader models. If your log mentions “loop”/“unroll”/“cannot unroll”, we can replace `fill_mask_holes_5()` with a loop-free version (manual bit checks).

But I don’t want to guess—your log will confirm it in one line.

---

### Quick checklist (you can try immediately)
If you want a fast “likely fix” before pasting the log:

1) Replace the `bool mask_has_zone(...)` with the `int` version above.
2) Remove `[unroll]` annotations (leave the loops).

If it still fails, paste the `ReShade.log` error block and I’ll point to the exact line and give you a corrected drop-in patch.

## @3d2025stephen-art

there is no log about, just the header telling this failed to load

## Copilot

The shader itself looks logically fine, so when ReShade shows only “failed to load” with no useful log, it’s usually one of these **hard parser/compat** issues:

1) your file has **non‑ASCII characters** (the `°` symbol in `ui_items`) and the FX parser chokes depending on encoding/build  
2) use of `bool` uniforms / bool return types can fail on some older FXC paths  
3) `[unroll]` + `for (int i...)` sometimes fails depending on shader model/compiler path

The #1 culprit here is the **degree symbol**. ReShade FX files should be saved as ANSI/UTF-8 without BOM, and even then some builds dislike extended characters in `ui_items`.

### Fix plan (most robust)
- Remove `°` from `ui_items` (replace with “deg”)
- Remove `bool` function return (`mask_has_zone`) and avoid bool return type entirely
- Remove `[unroll]` annotations (keep loops) or replace the looped fill with a small no-loop version if needed

Below is a corrected version of your file with those changes applied. Try this exactly (and make sure you save as plain UTF‑8 without BOM, or ANSI).

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
// Reshade: BluePivot-HSLW v3 pastel v35
// Robust compile revision:
// - Removed non-ASCII degree symbols from UI strings (use "deg")
// - Avoided bool return helper (mask_has_zone returns int)
// - Removed [unroll] tags

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan <-> Magenta)";
    ui_type = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1 (0.166=Yellow default)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

uniform int HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20deg  (Amber)\0"
        "50deg  (Warm Yellow)\0"
        "110deg (Yellow-Green)\0"
        "190deg (Cyan)\0"
        "230deg (Sky Blue)\0"
        "280deg (Purple)\0"
        "310deg (Magenta)\0"
        "340deg (Hot Pink)\0";
    ui_min = 0; ui_max = 8;
> = 0;

uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;

uniform float YellowToWhite <
    ui_label = "Hue -> White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue -> Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

uniform float PastelBias <
    ui_label = "Pastel Bias (-protect creams ... +boost creams)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- LUMA ZONES (manual checkboxes) ----
uniform bool LumaZone1_Shadows < ui_label = "Luma Zone 1: Shadows (0-20%)"; ui_type="checkbox"; > = true;
uniform bool LumaZone2_Darks   < ui_label = "Luma Zone 2: Darks (20-40%)";   ui_type="checkbox"; > = true;
uniform bool LumaZone3_Mids    < ui_label = "Luma Zone 3: Mids (40-60%)";    ui_type="checkbox"; > = true;
uniform bool LumaZone4_Lights  < ui_label = "Luma Zone 4: Lights (60-80%)";  ui_type="checkbox"; > = true;
uniform bool LumaZone5_Highlights < ui_label = "Luma Zone 5: Highlights (80-100%)"; ui_type="checkbox"; > = true;

uniform float LumaZoneSoftness < ui_label="Luma Zone Softness"; ui_type="slider"; ui_min=0.0; ui_max=0.20; > = 0.04;
uniform float LumaZoneBoost    < ui_label="Luma Zone Boost";    ui_type="slider"; ui_min=0.0; ui_max=4.0;  > = 1.0;

// ---- LUMA AUTHORIZATION (per hue preset) ----
uniform bool AutoLumaZones <
    ui_label = "Auto Luma Zones (per hue preset)";
    ui_type  = "checkbox";
> = false;

uniform bool FillLumaMaskHoles <
    ui_label = "Fill Luma Mask Holes (avoid scattered zones)";
    ui_type  = "checkbox";
> = true;

// Bits: zone1=1, zone2=2, zone3=4, zone4=8, zone5=16
uniform int LumaMask_Custom < ui_label="Luma Mask (Custom): bits 0-4"; ui_type="drag"; ui_min=0; ui_max=31; > = 31;
uniform int LumaMask_20     < ui_label="Luma Mask (20deg Amber)";      ui_type="drag"; ui_min=0; ui_max=31; > = 14;
uniform int LumaMask_50     < ui_label="Luma Mask (50deg Warm Yellow)";ui_type="drag"; ui_min=0; ui_max=31; > = 12;
uniform int LumaMask_110    < ui_label="Luma Mask (110deg Yellow-Green)"; ui_type="drag"; ui_min=0; ui_max=31; > = 28;
uniform int LumaMask_190    < ui_label="Luma Mask (190deg Cyan)";      ui_type="drag"; ui_min=0; ui_max=31; > = 31;
uniform int LumaMask_230    < ui_label="Luma Mask (230deg Sky Blue)";  ui_type="drag"; ui_min=0; ui_max=31; > = 31;
uniform int LumaMask_280    < ui_label="Luma Mask (280deg Purple)";    ui_type="drag"; ui_min=0; ui_max=31; > = 31;
uniform int LumaMask_310    < ui_label="Luma Mask (310deg Magenta)";   ui_type="drag"; ui_min=0; ui_max=31; > = 30;
uniform int LumaMask_340    < ui_label="Luma Mask (340deg Hot Pink)";  ui_type="drag"; ui_min=0; ui_max=31; > = 28;

// ---- Gate / Whites / Inject / Debug ----
uniform float RedToAlpha < ui_label="Red -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float GreenToAlpha < ui_label="Green -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float AlphaGatePower < ui_label="Alpha Gate Power"; ui_type="slider"; ui_min=0.5; ui_max=4.0; > = 1.5;

uniform float PreserveWhites < ui_label="Preserve Whites (fade near white)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.75;

uniform bool EnableYellowBlueInject < ui_label="Enable Hue Blue Inject"; ui_type="checkbox"; > = false;
uniform float YellowBlueInject < ui_label="Hue Blue Inject (-remove ... +add)"; ui_type="slider"; ui_min=-1.0; ui_max=1.0; > = 0.0;

uniform bool WorkInLinear < ui_label="Work In Linear (recommended)"; ui_type="checkbox"; > = true;

uniform int DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0";
    ui_min = 0; ui_max = 6;
> = 0;

uniform float DebugOverlayStrength < ui_label="DEBUG Overlay Strength"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.65;
uniform float DebugGamma < ui_label="DEBUG Gamma (mask visibility)"; ui_type="slider"; ui_min=0.4; ui_max=2.2; > = 0.85;

// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float curve(float x) { return x * x * (3.0 - 2.0 * x); }

float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}

float hue_center_from_preset(int preset, float fallbackHue)
{
    if (preset == 1) return 20.0 / 360.0;
    if (preset == 2) return 50.0 / 360.0;
    if (preset == 3) return 110.0 / 360.0;
    if (preset == 4) return 190.0 / 360.0;
    if (preset == 5) return 230.0 / 360.0;
    if (preset == 6) return 280.0 / 360.0;
    if (preset == 7) return 310.0 / 360.0;
    if (preset == 8) return 340.0 / 360.0;
    return fallbackHue;
}

float hue_width_from_preset(int preset, float fallback)
{
    if (preset == 1) return 7.5;
    if (preset == 2) return 7.0;
    if (preset == 3) return 6.5;
    if (preset == 4) return 5.5;
    if (preset == 5) return 5.5;
    if (preset == 6) return 6.2;
    if (preset == 7) return 6.0;
    if (preset == 8) return 6.5;
    return fallback;
}

float bandpass01(float x, float a, float b, float s)
{
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight(float lum, float softness)
{
    float w = 0.0;
    if (LumaZone1_Shadows)    w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)      w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)       w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)     w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights) w += bandpass01(lum, 0.8, 1.0, softness);
    return saturate(w);
}

int luma_mask_from_preset(int preset)
{
    if (preset == 1) return LumaMask_20;
    if (preset == 2) return LumaMask_50;
    if (preset == 3) return LumaMask_110;
    if (preset == 4) return LumaMask_190;
    if (preset == 5) return LumaMask_230;
    if (preset == 6) return LumaMask_280;
    if (preset == 7) return LumaMask_310;
    if (preset == 8) return LumaMask_340;
    return LumaMask_Custom;
}

int mask_has_zone(int mask, int zoneIndex) { return (mask >> zoneIndex) & 1; }

int fill_mask_holes_5(int m)
{
    int mm = m & 31;
    if (mm == 0) return 0;

    int first = -1;
    int last  = -1;

    for (int i = 0; i < 5; i++)
    {
        if (((mm >> i) & 1) != 0)
        {
            if (first < 0) first = i;
            last = i;
        }
    }

    int outm = 0;
    for (int i = 0; i < 5; i++)
        if (i >= first && i <= last) outm |= (1 << i);

    return outm;
}

float luma_zone_weight_masked(float lum, float softness, int mask)
{
    float w = 0.0;
    if (mask_has_zone(mask, 0) != 0) w += bandpass01(lum, 0.0, 0.2, softness);
    if (mask_has_zone(mask, 1) != 0) w += bandpass01(lum, 0.2, 0.4, softness);
    if (mask_has_zone(mask, 2) != 0) w += bandpass01(lum, 0.4, 0.6, softness);
    if (mask_has_zone(mask, 3) != 0) w += bandpass01(lum, 0.6, 0.8, softness);
    if (mask_has_zone(mask, 4) != 0) w += bandpass01(lum, 0.8, 1.0, softness);
    return saturate(w);
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float cmy_scalar = 0.5 * (mx - mn);

    float h = rgb_hue01(saturate(c));
    float center = hue_center_from_preset(HuePresetSteps, TargetHue);
    float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;

    float d = hue_dist01(h, center);
    float band = max(1.0 - (d * width), 0.0);
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;
    w_y = saturate(w_y * chromaBoost);
    w_y = pow(w_y, hueTightness);
    return saturate(w_y);
}

// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float bb = c.b;
    c.r += pivot * bb * 0.5;
    c.g -= pivot * bb * 0.5;

    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    float yStrength = saturate(yellowMask * gate * fadeWhite);

    float lum0 = luminance_rec709(c0);
    float lumaW = 1.0;

    if (AutoLumaZones)
    {
        int mask = luma_mask_from_preset(HuePresetSteps);
        if (FillLumaMaskHoles)
            mask = fill_mask_holes_5(mask);

        lumaW = luma_zone_weight_masked(saturate(lum0), LumaZoneSoftness, mask);
    }
    else
    {
        lumaW = luma_zone_weight(saturate(lum0), LumaZoneSoftness);
    }

    yStrength = saturate(yStrength * lumaW * LumaZoneBoost);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    if (DebugMode != 0)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (DebugMode == 1)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear) outc = linear_to_srgb(outc);
            return float4(outc, 1.0);
        }
        else if (DebugMode == 2)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear) masks = linear_to_srgb(masks);
            return float4(masks, 1.0);
        }
        else if (DebugMode == 3)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 4)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (DebugMode == 6)
        {
            float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);
            if (WorkInLinear) dbg = linear_to_srgb(dbg);
            return float4(dbg, 1.0);
        }

        float3 fallback = c0;
        if (WorkInLinear) fallback = linear_to_srgb(fallback);
        return float4(fallback, 1.0);
    }

    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear) c = linear_to_srgb(c);
    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```

### If this still “fails to load” with no log
Then it’s almost always **file encoding** or a **bad character** somewhere. Two checks:

1) Open the `.fx` in a text editor and re-save as **UTF-8 (no BOM)** (or ANSI).
2) Search and remove any remaining non-ASCII characters: `°`, `→`, `↔`, `…` etc.  
   (I removed them from most labels above, but your file may still contain them elsewhere.)

If you want, paste the *first ~50 lines* of your actual `.fx` as saved on disk (including the UI labels), and I’ll point out any characters that can break some ReShade installs.

## @3d2025stephen-art

i used a checker for non asc2 characters, this finds nothing, a functinality can break the compile?

## Copilot

Yes—some *functionality* can break compilation even if the syntax looks valid, and ReShade sometimes only shows “failed to load” when the compiler backend fails early.

In your current file, the **most likely breaker** is this:

### 1) `pow(x, hueTightness)` where `x` can be 0 and `hueTightness` can be < 1
You allow:

```hlsl
YellowMaskTightness ui_min = 0.5;
```

and inside `selective_yellow_weight` you do:

```hlsl
w_y = pow(w_y, hueTightness);
```

If `w_y` becomes **exactly 0** (very common after saturate) and `hueTightness` is **not an integer**, FXC/D3D can sometimes throw “pow domain / invalid” issues on some shader models/drivers. Many drivers tolerate it, some don’t.

**Safe fix:** clamp the base away from 0 before `pow`.

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
w_y = pow(max(w_y, 1e-6), hueTightness);
```

This is a classic “compile/runtime stability” fix for shader pow.

### 2) `int` + loops + bit ops (can be unsupported in some older ReShade/compiler paths)
Your file uses:
- `int` uniforms
- bit shifts `>>`
- loops in `fill_mask_holes_5`
- `int` logic in pixel shader

Most modern ReShade + DX11 is fine, but some environments (older DX9, some Vulkan translation paths, older FXC targets) can fail with integer loops/bit ops.

**Workaround:** avoid int/bitwise logic entirely by using floats for luma masks (5 booleans) or by using 5 floats “enable zone” per preset. That’s heavier UI though.

A middle ground: remove the *hole-fill* function (no loops) first and see if it compiles.

### 3) Duplicate uniform names
This is another silent killer. In your earlier file you had `AutoLumaZones` etc only once, but if you merged patches and accidentally duplicated any `uniform` name (even in comments sometimes people copy blocks twice), compilation can fail.

Quick check: search for these and ensure each appears once:
- `AutoLumaZones`
- `FillLumaMaskHoles`
- `LumaMask_Custom` etc
- `HuePresetSteps`

### Minimal “test” to isolate the culprit (fast)
Do these in order until it loads:

1) **Apply safe pow clamp** (very low-risk, should not change look):
```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
w_y = pow(max(w_y, 1e-6), hueTightness);
```

2) Temporarily comment out the hole filling and masked luma path:
- set `AutoLumaZones` to false permanently (or remove that branch)
- keep only the manual `luma_zone_weight` call
If it compiles then, the issue is in the int/bitmask code path.

3) If still failing, remove **all `int` uniforms** (replace `HuePresetSteps` and DebugMode combos with floats or keep just TargetHue) to test whether your compiler path can handle ints.

---

### Best next step
Since you don’t have log output: paste just the **error context source** by doing a binary search:

- Tell me: does it compile if you revert only the **luma bitmask system** (keep purple + hue wrap)?
- Or does it fail even without that?

If you answer that, I can give you the exact “no-int” authorized-luma version that uses **5 preset checkboxes per hue** (no shifts, no loops, no ints), which will compile on basically every ReShade backend.

## @3d2025stephen-art

failed

## Copilot

The code you posted is syntactically fine, so a “failed to load” with no log strongly suggests a **backend limitation** rather than a typo. The common hard limit is: **your ReShade runtime/compiler path doesn’t support integer uniforms / bitwise ops / loops in the way we’re using them** (this happens more often on DX9, some DX10 paths, some Linux/Vulkan translations, and some older ReShade builds). When that happens, ReShade sometimes won’t emit a helpful compile log.

### Fast proof (one-minute test)
Make this temporary change:

- Set `AutoLumaZones` default to `false` (it already is), **and comment out the entire `if (AutoLumaZones) { ... }` block**, leaving only the manual `luma_zone_weight` path.
- Also comment out these functions (so the compiler can’t even see int/bitwise/loops):
  - `luma_mask_from_preset`
  - `mask_has_zone`
  - `fill_mask_holes_5`
  - `luma_zone_weight_masked`
  - and the `uniform int LumaMask_*` declarations

If it loads after that, we’ve confirmed the cause: **integer/bitmask authorization system is not supported** on your setup.

---

## A version that will compile everywhere (no ints, no bitwise, no loops)
We can still get “authorized luma per color” with **0 bitwise and 0 loops** by using **5 float toggles per preset**, and selecting them with simple `if` chains.

It’s more UI rows, but it’s extremely compatible and stable.

### How it works
- Keep your existing 5 manual luma checkboxes (global).
- Add `AutoLumaZones` checkbox.
- For each hue preset, define 5 “allowed” floats (0/1) like `Allow50_Z3Mids = 1.0`.
- At runtime, build a 5-zone weight by multiplying each zone bandpass by its allow value.

### I need one detail before I generate the full patched file
Which renderer are you running this on?
- DX9 / DX10 / DX11 / DX12 / Vulkan / OpenGL

If you don’t know: tell me the game + API (or what ReShade shows in its overlay at the top).

---

## If you want a quick “minimal change” workaround right now
Temporarily **remove only the hole-fill function** (loops) and keep masks:
- Delete `fill_mask_holes_5`
- Set `FillLumaMaskHoles = false` and remove its usage

If it still fails, then **bitwise/int uniforms themselves** are the problem, and we must go to the float-toggle method.

---

### Why this is happening
Even if HLSL supports ints/bitwise, ReShade may compile through FXC with a target profile that’s stricter, or through a compatibility layer that doesn’t support integer ops well. When it fails very early, ReShade sometimes doesn’t give you line-number logs.

Reply with your renderer/API and I’ll produce the “no-int authorized luma per hue preset” implementation as a complete `.fx` you can paste and it should load.

## @3d2025stephen-art

this is showing D3D9

## Copilot

```hlsl name=BluePivot-HSLW_Version35_Version5pink_V2Luma_V3_2_D3D9Safe.fx
// ReShade: BluePivot-HSLW v3 pastel v35 (D3D9-safe authorized luma)
// Why this file exists:
// - D3D9 FXC paths are often fragile with int uniforms, bitwise ops (>>, &),
//   and loops in pixel shaders.
// - This version removes ALL int uniforms, ALL bitwise ops, and ALL loops.
// - Authorized-luma-per-hue-preset is implemented with float toggles (0/1) per zone.
//
// You keep:
// - Manual LumaZone checkboxes (global)
// - Optional AutoLumaZones (per hue preset) using float allow switches
// - Hue preset combo + optional auto hue width + hue wrap-distance

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan <-> Magenta)";
    ui_type = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1 (0.166=Yellow default)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

// IMPORTANT (D3D9-safe): use float combo, not int combo
uniform float HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20deg  (Amber)\0"
        "50deg  (Warm Yellow)\0"
        "110deg (Yellow-Green)\0"
        "190deg (Cyan)\0"
        "230deg (Sky Blue)\0"
        "280deg (Purple)\0"
        "310deg (Magenta)\0"
        "340deg (Hot Pink)\0";
    ui_min = 0.0; ui_max = 8.0;
> = 0.0;

uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;

uniform float YellowToWhite <
    ui_label = "Hue -> White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue -> Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

uniform float PastelBias <
    ui_label = "Pastel Bias (-protect creams ... +boost creams)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- LUMA ZONES (manual checkboxes, global) ----
uniform bool LumaZone1_Shadows < ui_label="Luma Zone 1: Shadows (0-20%)"; ui_type="checkbox"; > = true;
uniform bool LumaZone2_Darks   < ui_label="Luma Zone 2: Darks (20-40%)";   ui_type="checkbox"; > = true;
uniform bool LumaZone3_Mids    < ui_label="Luma Zone 3: Mids (40-60%)";    ui_type="checkbox"; > = true;
uniform bool LumaZone4_Lights  < ui_label="Luma Zone 4: Lights (60-80%)";  ui_type="checkbox"; > = true;
uniform bool LumaZone5_Highlights < ui_label="Luma Zone 5: Highlights (80-100%)"; ui_type="checkbox"; > = true;

uniform float LumaZoneSoftness < ui_label="Luma Zone Softness"; ui_type="slider"; ui_min=0.0; ui_max=0.20; > = 0.04;
uniform float LumaZoneBoost    < ui_label="Luma Zone Boost";    ui_type="slider"; ui_min=0.0; ui_max=4.0;  > = 1.0;

// ---- LUMA AUTHORIZATION (per hue preset) ----
// D3D9-safe: no bitmasks. We use 5 floats per preset, each 0/1.
uniform bool AutoLumaZones <
    ui_label = "Auto Luma Zones (per hue preset)";
    ui_type  = "checkbox";
> = false;

// Category just to keep the UI tidy
#define LUMA_CAT "LUMA Authorization (per preset)"

// Custom
uniform float LumaAllow_Custom_Z1 < ui_label="Custom allow Z1 Shadows"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_Custom_Z2 < ui_label="Custom allow Z2 Darks";   ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_Custom_Z3 < ui_label="Custom allow Z3 Mids";    ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_Custom_Z4 < ui_label="Custom allow Z4 Lights";  ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_Custom_Z5 < ui_label="Custom allow Z5 High";    ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;

// 20 Amber
uniform float LumaAllow_20_Z1 < ui_label="20deg Amber allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_20_Z2 < ui_label="20deg Amber allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_20_Z3 < ui_label="20deg Amber allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_20_Z4 < ui_label="20deg Amber allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_20_Z5 < ui_label="20deg Amber allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;

// 50 Warm Yellow (mids+lights default)
uniform float LumaAllow_50_Z1 < ui_label="50deg Yellow allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_50_Z2 < ui_label="50deg Yellow allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_50_Z3 < ui_label="50deg Yellow allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_50_Z4 < ui_label="50deg Yellow allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_50_Z5 < ui_label="50deg Yellow allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;

// 110 Yellow-Green
uniform float LumaAllow_110_Z1 < ui_label="110deg Y-G allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_110_Z2 < ui_label="110deg Y-G allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_110_Z3 < ui_label="110deg Y-G allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_110_Z4 < ui_label="110deg Y-G allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_110_Z5 < ui_label="110deg Y-G allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;

// 190 Cyan (all)
uniform float LumaAllow_190_Z1 < ui_label="190deg Cyan allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_190_Z2 < ui_label="190deg Cyan allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_190_Z3 < ui_label="190deg Cyan allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_190_Z4 < ui_label="190deg Cyan allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_190_Z5 < ui_label="190deg Cyan allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;

// 230 Sky Blue (all)
uniform float LumaAllow_230_Z1 < ui_label="230deg Sky allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_230_Z2 < ui_label="230deg Sky allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_230_Z3 < ui_label="230deg Sky allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_230_Z4 < ui_label="230deg Sky allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_230_Z5 < ui_label="230deg Sky allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;

// 280 Purple (all)
uniform float LumaAllow_280_Z1 < ui_label="280deg Purple allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_280_Z2 < ui_label="280deg Purple allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_280_Z3 < ui_label="280deg Purple allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_280_Z4 < ui_label="280deg Purple allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_280_Z5 < ui_label="280deg Purple allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;

// 310 Magenta (avoid deepest shadows by default)
uniform float LumaAllow_310_Z1 < ui_label="310deg Magenta allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_310_Z2 < ui_label="310deg Magenta allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_310_Z3 < ui_label="310deg Magenta allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_310_Z4 < ui_label="310deg Magenta allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_310_Z5 < ui_label="310deg Magenta allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;

// 340 Hot Pink (mids+lights+high default)
uniform float LumaAllow_340_Z1 < ui_label="340deg Pink allow Z1"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_340_Z2 < ui_label="340deg Pink allow Z2"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.0;
uniform float LumaAllow_340_Z3 < ui_label="340deg Pink allow Z3"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_340_Z4 < ui_label="340deg Pink allow Z4"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;
uniform float LumaAllow_340_Z5 < ui_label="340deg Pink allow Z5"; ui_category=LUMA_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.0;

// ---- Gate / Whites / Inject / Debug ----
uniform float RedToAlpha < ui_label="Red -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float GreenToAlpha < ui_label="Green -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float AlphaGatePower < ui_label="Alpha Gate Power"; ui_type="slider"; ui_min=0.5; ui_max=4.0; > = 1.5;

uniform float PreserveWhites < ui_label="Preserve Whites (fade near white)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.75;

uniform bool EnableYellowBlueInject < ui_label="Enable Hue Blue Inject"; ui_type="checkbox"; > = false;
uniform float YellowBlueInject < ui_label="Hue Blue Inject (-remove ... +add)"; ui_type="slider"; ui_min=-1.0; ui_max=1.0; > = 0.0;

uniform bool WorkInLinear < ui_label="Work In Linear (recommended)"; ui_type="checkbox"; > = true;

// D3D9-safe: use float combo for debug mode too (avoid int combo)
uniform float DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0";
    ui_min = 0.0; ui_max = 6.0;
> = 0.0;

uniform float DebugOverlayStrength < ui_label="DEBUG Overlay Strength"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.65;
uniform float DebugGamma < ui_label="DEBUG Gamma (mask visibility)"; ui_type="slider"; ui_min=0.4; ui_max=2.2; > = 0.85;

#undef LUMA_CAT

// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float curve(float x) { return x * x * (3.0 - 2.0 * x); }

float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}

float hue_center_from_preset(float preset, float fallbackHue)
{
    if (preset < 0.5) return fallbackHue;
    if (abs(preset - 1.0) < 0.5) return 20.0 / 360.0;
    if (abs(preset - 2.0) < 0.5) return 50.0 / 360.0;
    if (abs(preset - 3.0) < 0.5) return 110.0 / 360.0;
    if (abs(preset - 4.0) < 0.5) return 190.0 / 360.0;
    if (abs(preset - 5.0) < 0.5) return 230.0 / 360.0;
    if (abs(preset - 6.0) < 0.5) return 280.0 / 360.0;
    if (abs(preset - 7.0) < 0.5) return 310.0 / 360.0;
    return 340.0 / 360.0; // ~8
}

float hue_width_from_preset(float preset, float fallback)
{
    if (preset < 0.5) return fallback;
    if (abs(preset - 1.0) < 0.5) return 7.5;
    if (abs(preset - 2.0) < 0.5) return 7.0;
    if (abs(preset - 3.0) < 0.5) return 6.5;
    if (abs(preset - 4.0) < 0.5) return 5.5;
    if (abs(preset - 5.0) < 0.5) return 5.5;
    if (abs(preset - 6.0) < 0.5) return 6.2;
    if (abs(preset - 7.0) < 0.5) return 6.0;
    return 6.5;
}

float bandpass01(float x, float a, float b, float s)
{
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight_manual(float lum, float softness)
{
    float w = 0.0;
    if (LumaZone1_Shadows)    w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)      w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)       w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)     w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights) w += bandpass01(lum, 0.8, 1.0, softness);
    return saturate(w);
}

void luma_allows_from_preset(float preset, out float a1, out float a2, out float a3, out float a4, out float a5)
{
    // Default: custom
    a1 = LumaAllow_Custom_Z1;
    a2 = LumaAllow_Custom_Z2;
    a3 = LumaAllow_Custom_Z3;
    a4 = LumaAllow_Custom_Z4;
    a5 = LumaAllow_Custom_Z5;

    if (preset < 0.5) return;

    if (abs(preset - 1.0) < 0.5) { a1=LumaAllow_20_Z1;  a2=LumaAllow_20_Z2;  a3=LumaAllow_20_Z3;  a4=LumaAllow_20_Z4;  a5=LumaAllow_20_Z5;  return; }
    if (abs(preset - 2.0) < 0.5) { a1=LumaAllow_50_Z1;  a2=LumaAllow_50_Z2;  a3=LumaAllow_50_Z3;  a4=LumaAllow_50_Z4;  a5=LumaAllow_50_Z5;  return; }
    if (abs(preset - 3.0) < 0.5) { a1=LumaAllow_110_Z1; a2=LumaAllow_110_Z2; a3=LumaAllow_110_Z3; a4=LumaAllow_110_Z4; a5=LumaAllow_110_Z5; return; }
    if (abs(preset - 4.0) < 0.5) { a1=LumaAllow_190_Z1; a2=LumaAllow_190_Z2; a3=LumaAllow_190_Z3; a4=LumaAllow_190_Z4; a5=LumaAllow_190_Z5; return; }
    if (abs(preset - 5.0) < 0.5) { a1=LumaAllow_230_Z1; a2=LumaAllow_230_Z2; a3=LumaAllow_230_Z3; a4=LumaAllow_230_Z4; a5=LumaAllow_230_Z5; return; }
    if (abs(preset - 6.0) < 0.5) { a1=LumaAllow_280_Z1; a2=LumaAllow_280_Z2; a3=LumaAllow_280_Z3; a4=LumaAllow_280_Z4; a5=LumaAllow_280_Z5; return; }
    if (abs(preset - 7.0) < 0.5) { a1=LumaAllow_310_Z1; a2=LumaAllow_310_Z2; a3=LumaAllow_310_Z3; a4=LumaAllow_310_Z4; a5=LumaAllow_310_Z5; return; }
    // else 8
    a1=LumaAllow_340_Z1; a2=LumaAllow_340_Z2; a3=LumaAllow_340_Z3; a4=LumaAllow_340_Z4; a5=LumaAllow_340_Z5;
}

float luma_zone_weight_authorized(float lum, float softness, float preset)
{
    float a1, a2, a3, a4, a5;
    luma_allows_from_preset(preset, a1, a2, a3, a4, a5);

    // clamp sliders just in case user drags to non-0/1
    a1 = saturate(a1); a2 = saturate(a2); a3 = saturate(a3); a4 = saturate(a4); a5 = saturate(a5);

    float w = 0.0;
    w += a1 * bandpass01(lum, 0.0, 0.2, softness);
    w += a2 * bandpass01(lum, 0.2, 0.4, softness);
    w += a3 * bandpass01(lum, 0.4, 0.6, softness);
    w += a4 * bandpass01(lum, 0.6, 0.8, softness);
    w += a5 * bandpass01(lum, 0.8, 1.0, softness);
    return saturate(w);
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float cmy_scalar = 0.5 * (mx - mn);

    float h = rgb_hue01(saturate(c));
    float center = hue_center_from_preset(HuePresetSteps, TargetHue);
    float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;

    float d = hue_dist01(h, center);
    float band = max(1.0 - (d * width), 0.0);
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;
    w_y = saturate(w_y * chromaBoost);
    w_y = pow(max(w_y, 1e-6), hueTightness);
    return saturate(w_y);
}

// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float bb = c.b;
    c.r += pivot * bb * 0.5;
    c.g -= pivot * bb * 0.5;

    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    float yStrength = saturate(yellowMask * gate * fadeWhite);

    float lum0 = luminance_rec709(c0);
    float lumaW = AutoLumaZones
        ? luma_zone_weight_authorized(saturate(lum0), LumaZoneSoftness, HuePresetSteps)
        : luma_zone_weight_manual(saturate(lum0), LumaZoneSoftness);

    yStrength = saturate(yStrength * lumaW * LumaZoneBoost);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    // Debug (float compare)
    if (DebugMode > 0.5)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (abs(DebugMode - 1.0) < 0.5)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear) outc = linear_to_srgb(outc);
            return float4(outc, 1.0);
        }
        if (abs(DebugMode - 2.0) < 0.5)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear) masks = linear_to_srgb(masks);
            return float4(masks, 1.0);
        }
        if (abs(DebugMode - 3.0) < 0.5)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        if (abs(DebugMode - 4.0) < 0.5)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        if (abs(DebugMode - 5.0) < 0.5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        // 6
        float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);
        if (WorkInLinear) dbg = linear_to_srgb(dbg);
        return float4(dbg, 1.0);
    }

    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear) c = linear_to_srgb(c);
    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```

### Why your previous versions fail on D3D9
D3D9 + ReShade commonly fails (sometimes silently) when you combine:
- `uniform int` (esp. combo)
- bitwise operators `>>` / `&`
- `for` loops using `int` in PS
Even if it “should” compile, that toolchain is the least forgiving.

### If this still fails
Then it’s not the luma logic—it’s something more fundamental (include path, ReShade profile, or the sheer number of uniforms). Two quick checks:
1) Confirm the file is in the same folder ReShade scans (`reshade-shaders\Shaders\`).
2) Temporarily comment out the entire **LUMA Authorization (per preset)** uniform block (all those LumaAllow_* sliders). If it then loads, you hit a D3D9 uniform/constant limit and we’ll compress the UI (e.g., only add allow masks for the currently selected preset).

Try this D3D9-safe file first and tell me whether it loads. If it doesn’t, tell me if your *older* non-luma version still loads in the same game/API—then we’ll narrow down whether you’re hitting a constant register limit.

## @3d2025stephen-art

this one loaded well, there is a lot of sliders now...

## Copilot

D3D9 is why: to keep it compiling we had to drop `int` bitmasks, and the fallback (float “allow” per zone) explodes the UI.

Two good ways to reduce sliders while keeping **authorized luma per color**:

## Option A (recommended): “Edit Current Preset Only” (5 sliders total)
Keep only **one set** of 5 sliders (`AllowZ1..AllowZ5`). When you choose a hue preset, those 5 sliders apply to that preset.

Tradeoff: you can’t store different allow-masks for every preset at the same time (unless you manually note values). But for “rework along the time” this is usually fine, and UI stays clean.

**UI becomes:**
- AutoLumaZones (checkbox)
- Allow Z1..Z5 (5 sliders)
- (optional) “Preset Luma Defaults” button isn’t possible in FX, but we can ship good defaults in code comments.

## Option B: Compress each preset to 2 sliders (still per preset)
Instead of 5 zone toggles per preset, use:
- `LumaMin` and `LumaMax` per preset (+ one global softness)
That’s **2 × 9 = 18 sliders** (still big, but much smaller than 45).

This also matches your “parsimony” idea better than discrete zones, because it enforces a contiguous luma band automatically.

---

### What I need from you
Which one do you prefer?

1) **A: 5 sliders total (edit current preset only)**  
2) **B: 2 sliders per preset (min/max)**

If you pick **A**, I’ll modify the loaded D3D9-safe file so:
- It keeps your manual luma checkboxes (for global mode)
- In AutoLumaZones mode it uses only the 5 “Current preset allow” sliders
- No more per-preset slider wall

If you pick **B**, I’ll implement per-preset `LumaMin/LumaMax` with wrap-safe selection and keep softness global.

## @3d2025stephen-art

B is good ty

## Copilot

```hlsl name=BluePivot-HSLW_Version35_Version5pink_V2Luma_V3_2_D3D9Safe_MinMax.fx
// ReShade: BluePivot-HSLW v3 pastel v35 (D3D9-safe authorized luma, Min/Max per hue preset)
//
// Goal:
// - Keep D3D9 compatibility (no int uniforms, no bitwise ops, no loops).
// - Reduce UI spam: replace 5-zone per-preset allow sliders with 2 sliders per preset: LumaMin/LumaMax.
// - LumaMin/LumaMax define an authorized luminance window [0..1], with global softness.
//
// How it behaves:
// - If AutoLumaZones = false: uses your manual 5-zone checkbox system (original behavior).
// - If AutoLumaZones = true : uses per-preset LumaMin/LumaMax (contiguous by design).
//
// Notes:
// - LumaMin > LumaMax is auto-corrected by swapping in shader.
// - Luma window multiplies yStrength (it does NOT change hueMask/gate math).

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan <-> Magenta)";
    ui_type = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1 (0.166=Yellow default)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

// D3D9-safe: float combo
uniform float HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20deg  (Amber)\0"
        "50deg  (Warm Yellow)\0"
        "110deg (Yellow-Green)\0"
        "190deg (Cyan)\0"
        "230deg (Sky Blue)\0"
        "280deg (Purple)\0"
        "310deg (Magenta)\0"
        "340deg (Hot Pink)\0";
    ui_min = 0.0; ui_max = 8.0;
> = 0.0;

uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;

// ---- Hue tonal correction ----
uniform float YellowToWhite <
    ui_label = "Hue -> White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue -> Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

// ---- Hue mask controls ----
uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

// ---- Pastel bias ----
uniform float PastelBias <
    ui_label = "Pastel Bias (-protect creams ... +boost creams)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- LUMA ZONES (manual/global) ----
uniform bool LumaZone1_Shadows < ui_label="Luma Zone 1: Shadows (0-20%)"; ui_type="checkbox"; > = true;
uniform bool LumaZone2_Darks   < ui_label="Luma Zone 2: Darks (20-40%)";   ui_type="checkbox"; > = true;
uniform bool LumaZone3_Mids    < ui_label="Luma Zone 3: Mids (40-60%)";    ui_type="checkbox"; > = true;
uniform bool LumaZone4_Lights  < ui_label="Luma Zone 4: Lights (60-80%)";  ui_type="checkbox"; > = true;
uniform bool LumaZone5_Highlights < ui_label="Luma Zone 5: Highlights (80-100%)"; ui_type="checkbox"; > = true;

uniform float LumaZoneSoftness < ui_label="Luma Softness"; ui_type="slider"; ui_min=0.0; ui_max=0.20; > = 0.04;
uniform float LumaZoneBoost    < ui_label="Luma Boost";    ui_type="slider"; ui_min=0.0; ui_max=4.0;  > = 1.0;

// ---- LUMA AUTHORIZATION (per hue preset, Min/Max) ----
uniform bool AutoLumaZones <
    ui_label = "Auto Luma (per hue preset: Min/Max)";
    ui_type  = "checkbox";
> = false;

#define LUMA_MM_CAT "LUMA Authorized Range (per preset)"

uniform float LumaMin_Custom < ui_label="Custom Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.00;
uniform float LumaMax_Custom < ui_label="Custom Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.00;

uniform float LumaMin_20 < ui_label="20deg Amber Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.20;
uniform float LumaMax_20 < ui_label="20deg Amber Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.80;

uniform float LumaMin_50 < ui_label="50deg Yellow Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.40;
uniform float LumaMax_50 < ui_label="50deg Yellow Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.80;

uniform float LumaMin_110 < ui_label="110deg Y-G Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.40;
uniform float LumaMax_110 < ui_label="110deg Y-G Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.00;

uniform float LumaMin_190 < ui_label="190deg Cyan Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.00;
uniform float LumaMax_190 < ui_label="190deg Cyan Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.00;

uniform float LumaMin_230 < ui_label="230deg Sky Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.00;
uniform float LumaMax_230 < ui_label="230deg Sky Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.00;

uniform float LumaMin_280 < ui_label="280deg Purple Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.00;
uniform float LumaMax_280 < ui_label="280deg Purple Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.00;

uniform float LumaMin_310 < ui_label="310deg Magenta Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.20;
uniform float LumaMax_310 < ui_label="310deg Magenta Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.00;

uniform float LumaMin_340 < ui_label="340deg Pink Luma Min"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.40;
uniform float LumaMax_340 < ui_label="340deg Pink Luma Max"; ui_category=LUMA_MM_CAT; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 1.00;

#undef LUMA_MM_CAT

// ---- Gate / Whites / Inject / Debug ----
uniform float RedToAlpha < ui_label="Red -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float GreenToAlpha < ui_label="Green -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float AlphaGatePower < ui_label="Alpha Gate Power"; ui_type="slider"; ui_min=0.5; ui_max=4.0; > = 1.5;

uniform float PreserveWhites < ui_label="Preserve Whites (fade near white)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.75;

uniform bool EnableYellowBlueInject < ui_label="Enable Hue Blue Inject"; ui_type="checkbox"; > = false;
uniform float YellowBlueInject < ui_label="Hue Blue Inject (-remove ... +add)"; ui_type="slider"; ui_min=-1.0; ui_max=1.0; > = 0.0;

uniform bool WorkInLinear < ui_label="Work In Linear (recommended)"; ui_type="checkbox"; > = true;

// D3D9-safe: float combo
uniform float DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0";
    ui_min = 0.0; ui_max = 6.0;
> = 0.0;

uniform float DebugOverlayStrength < ui_label="DEBUG Overlay Strength"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.65;
uniform float DebugGamma < ui_label="DEBUG Gamma (mask visibility)"; ui_type="slider"; ui_min=0.4; ui_max=2.2; > = 0.85;

// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float curve(float x) { return x * x * (3.0 - 2.0 * x); }

float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}

float hue_center_from_preset(float preset, float fallbackHue)
{
    if (preset < 0.5) return fallbackHue;
    if (abs(preset - 1.0) < 0.5) return 20.0 / 360.0;
    if (abs(preset - 2.0) < 0.5) return 50.0 / 360.0;
    if (abs(preset - 3.0) < 0.5) return 110.0 / 360.0;
    if (abs(preset - 4.0) < 0.5) return 190.0 / 360.0;
    if (abs(preset - 5.0) < 0.5) return 230.0 / 360.0;
    if (abs(preset - 6.0) < 0.5) return 280.0 / 360.0;
    if (abs(preset - 7.0) < 0.5) return 310.0 / 360.0;
    return 340.0 / 360.0; // ~8
}

float hue_width_from_preset(float preset, float fallback)
{
    if (preset < 0.5) return fallback;
    if (abs(preset - 1.0) < 0.5) return 7.5;
    if (abs(preset - 2.0) < 0.5) return 7.0;
    if (abs(preset - 3.0) < 0.5) return 6.5;
    if (abs(preset - 4.0) < 0.5) return 5.5;
    if (abs(preset - 5.0) < 0.5) return 5.5;
    if (abs(preset - 6.0) < 0.5) return 6.2;
    if (abs(preset - 7.0) < 0.5) return 6.0;
    return 6.5;
}

float bandpass01(float x, float a, float b, float s)
{
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight_manual(float lum, float softness)
{
    float w = 0.0;
    if (LumaZone1_Shadows)    w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)      w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)       w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)     w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights) w += bandpass01(lum, 0.8, 1.0, softness);
    return saturate(w);
}

void luma_minmax_from_preset(float preset, out float mn, out float mx)
{
    // default: custom
    mn = LumaMin_Custom; mx = LumaMax_Custom;

    if (preset < 0.5) return;

    if (abs(preset - 1.0) < 0.5) { mn=LumaMin_20;  mx=LumaMax_20;  return; }
    if (abs(preset - 2.0) < 0.5) { mn=LumaMin_50;  mx=LumaMax_50;  return; }
    if (abs(preset - 3.0) < 0.5) { mn=LumaMin_110; mx=LumaMax_110; return; }
    if (abs(preset - 4.0) < 0.5) { mn=LumaMin_190; mx=LumaMax_190; return; }
    if (abs(preset - 5.0) < 0.5) { mn=LumaMin_230; mx=LumaMax_230; return; }
    if (abs(preset - 6.0) < 0.5) { mn=LumaMin_280; mx=LumaMax_280; return; }
    if (abs(preset - 7.0) < 0.5) { mn=LumaMin_310; mx=LumaMax_310; return; }
    // else 8
    mn=LumaMin_340; mx=LumaMax_340;
}

float luma_weight_minmax(float lum, float softness, float preset)
{
    float mn, mx;
    luma_minmax_from_preset(preset, mn, mx);

    mn = saturate(mn);
    mx = saturate(mx);

    // swap if user inverted
    float lo = min(mn, mx);
    float hi = max(mn, mx);

    float ss = max(softness, 1e-6);
    float wL = smoothstep(lo - ss, lo + ss, lum);
    float wR = 1.0 - smoothstep(hi - ss, hi + ss, lum);

    return saturate(wL * wR);
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float cmy_scalar = 0.5 * (mx - mn);

    float h = rgb_hue01(saturate(c));
    float center = hue_center_from_preset(HuePresetSteps, TargetHue);
    float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;

    float d = hue_dist01(h, center);
    float band = max(1.0 - (d * width), 0.0);
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;
    w_y = saturate(w_y * chromaBoost);
    w_y = pow(max(w_y, 1e-6), hueTightness);
    return saturate(w_y);
}

// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float bb = c.b;
    c.r += pivot * bb * 0.5;
    c.g -= pivot * bb * 0.5;

    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    float yStrength = saturate(yellowMask * gate * fadeWhite);

    float lum0 = luminance_rec709(c0);
    float lumaW = AutoLumaZones
        ? luma_weight_minmax(saturate(lum0), LumaZoneSoftness, HuePresetSteps)
        : luma_zone_weight_manual(saturate(lum0), LumaZoneSoftness);

    yStrength = saturate(yStrength * lumaW * LumaZoneBoost);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    if (DebugMode > 0.5)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (abs(DebugMode - 1.0) < 0.5)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear) outc = linear_to_srgb(outc);
            return float4(outc, 1.0);
        }
        if (abs(DebugMode - 2.0) < 0.5)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear) masks = linear_to_srgb(masks);
            return float4(masks, 1.0);
        }
        if (abs(DebugMode - 3.0) < 0.5)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        if (abs(DebugMode - 4.0) < 0.5)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        if (abs(DebugMode - 5.0) < 0.5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }

        float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);
        if (WorkInLinear) dbg = linear_to_srgb(dbg);
        return float4(dbg, 1.0);
    }

    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear) c = linear_to_srgb(c);
    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```

If you want even fewer sliders later: we can drop the per-preset Min/Max UI and instead make **a single global Min/Max**, plus a per-preset *offset* (1 slider each). But this version already cuts the “authorized luma” UI a lot vs the 5-zone-per-preset approach, while staying D3D9-safe.

## @3d2025stephen-art

i am dumb , since we found the dxd9 bug now we can restart from the latest patch we had, because for the Luma feature, we can just add in the color lable what to do, this aware and cheap in code, and to change i just need to rework my labels ,what do you think about?

## Copilot

You’re not dumb—this is exactly the right conclusion for D3D9.

On **D3D9**, anything involving `int` uniforms, bitmasks, and loops is a risk (and you saw it). So yes: **keeping luma as a manual/global control and using labeling + presets guidance per hue** is the cheapest, most stable approach—and it preserves your “pure performance” philosophy.

### What I think is best (D3D9-friendly)
1) **Keep the 5 manual luma zone checkboxes + softness + boost** (the version that already compiles for you).
2) **Do not add per-hue luma automation** in shader code for D3D9.
3) Instead, add “recommendation” into labels / comments, e.g.:
   - Yellow: “Recommended: Mids+Lights (Z3+Z4), avoid Highlights”
   - Magenta: “Recommended: Darks→Highlights (Z2–Z5), avoid deep Shadows”
   - Cyan/Sky: “All zones OK”
4) Optionally: add a single **combo preset** that just sets expectations (not automation), like:
   - `Luma Hint: Yellow-safe / Neon / All` (but it won’t change anything, it’s only a hint—so I’d skip it unless you want it for UX).

### Low-effort improvement that still adds value
You can also add **one extra debug mode** later to visualize luma bands (purely debug), but even that isn’t required.

### If you want: I can help you “rework labels” cleanly
Tell me which hue presets you consider “main” (Yellow, Sky, Purple, Magenta, Pink etc.), and for each one what luma you want to recommend (like `Z3+Z4`, `Z2–Z5`, etc.). I’ll rewrite your UI labels so they:
- stay short
- remain consistent in style
- clearly tell users what to toggle for that hue

No risky code changes, maximum clarity.

If you confirm: should we revert fully to the **last working D3D9-safe baseline** (no per-preset luma) and only update labels + maybe add a “Luma recommendation” comment block at the top?

## @3d2025stephen-art

In this case i will label ex: 20° (Amber Luma zones 3,5), can we expecto to translate the chroma stakes since my modular luma interface? how can i do this?

## Copilot

Yes—you can “translate” your *old per-color luma behavior* into your **modular 5-zone luma interface** by treating each hue preset as having a **recommended luma footprint** and encoding that footprint in the preset label (and optionally a short cheat-sheet comment).

### 1) First: define the zone mapping (your system’s “language”)
Your current luma zones are:

- **Z1** = 0–20% (Shadows)  
- **Z2** = 20–40% (Darks)  
- **Z3** = 40–60% (Mids)  
- **Z4** = 60–80% (Lights)  
- **Z5** = 80–100% (Highlights)

So any “authorized luma” for a color becomes a **set of zones**.

Example: “Yellow is sensitive to mid-high” might mean:
- allow **Z3+Z4**
- forbid **Z5** (to avoid blowing highlights / skin specular)

### 2) Translate “chroma stakes” into luma zones (practical rule)
Chroma problems usually correlate with **value (brightness)**:

- **Banding/contour risk** and “ugly selection” often happens in **smooth bright gradients** → usually **Z4/Z5**
- **Noise / compression mush** often happens in **deep shadows** → **Z1**
- **Most stable color identity** is often in **mids** → **Z3** (and sometimes Z2/Z4)

So when you say “chroma stakes”, you can map it like:
- “This hue gets unstable / dirty in shadows” → remove **Z1** (sometimes Z2)
- “This hue contaminates whites/specular” → remove **Z5**
- “This hue is only useful in midtones” → keep **Z3** only
- “This hue is mostly highlights glow” → keep **Z4+Z5**

### 3) How to label it (simple + consistent)
Use a consistent compact format:

- `20deg (Amber) [Luma: Z3,Z5]`
- or `20deg (Amber) (Luma Z3+Z5)`

I recommend **brackets** because it reads well and stays short.

### 4) How you “do this” inside ReShade UI (no automation)
You can’t dynamically change other sliders from a combo in ReShade FX, so the label is purely guidance. Make it easy to follow by:

- Keeping luma controls near the hue preset (or at least close)
- Naming the luma checkboxes with `Z1..Z5` at the start

Example label changes for the luma checkboxes:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
uniform bool LumaZone3_Mids <
    ui_label = "Z3 Mids (40-60%)";
    ui_type  = "checkbox";
> = true;
```

Do that for all zones so users can match “Z3,Z5” instantly.

### 5) Add a cheat-sheet comment block (best “translation table”)
Put this at the top of your file so you can refine over time:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
// Luma Zones:
// Z1=0-20 (Shadows) | Z2=20-40 (Darks) | Z3=40-60 (Mids) | Z4=60-80 (Lights) | Z5=80-100 (High)
//
// Suggested luma per hue preset (edit over time):
// Amber:  Z3+Z5
// Yellow: Z3+Z4 (avoid Z5)
// Cyan:   Z2+Z3+Z4+Z5 (avoid Z1 if noisy)
// Purple: Z2+Z3+Z4
// Magenta:Z2+Z3+Z4+Z5
// Pink:   Z3+Z4+Z5
```

### If you want, I can rewrite your luma UI labels now
If you tell me your intended recommendations for each preset (just list like: Amber=Z3+Z5, Yellow=Z3+Z4, etc.), I’ll return the exact edited uniform blocks (only labels changed, no risky code) so it remains D3D9-safe.

## @3d2025stephen-art

I dont know what my pastel chroma range can influece, i didnt find much interactivity, can we raise the power of this one and balance the Luma with the hue black, mask boost, thigthtness this is a chroma control? Do you think this make a problable chroma synchronization with my Luma setup per color?

## Copilot

`PastelChroma` in your shader is **not a chroma control for the effect itself**. It only controls *where the “pastel bias” is applied* (i.e., where you boost/protect “creamy” near-whites by modifying the hue mask). That’s why you don’t feel much interaction unless the scene has a lot of **bright + low-chroma** areas.

### What it currently does (why it feels weak)
You compute:

- `chroma0 = max(c0) - min(c0)`  (a simple chroma proxy)
- `pastelChroma = 1 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0)`
  - so it’s ~1 only when chroma0 is **below** `PastelChroma`
- `pastelValue` requires brightness near `PastelValue`
- `pastel = pastelChroma * pastelValue`
- then you do:  
  `yellowMask *= (1 + PastelBias * pastel)`

So: if the pixel isn’t both **bright** and **low chroma**, PastelChroma has almost no effect.

### Is PastelChroma “a chroma control” like mask boost/tightness?
Not really:
- `YellowMaskBoost` and `YellowMaskTightness` shape the **main hue selection** (strong effect).
- `Pastel*` shapes only a **secondary modifier** that biases selection in “creamy” areas.
- `Hue -> Black/White` are **tone operations after selection**.

So PastelChroma isn’t your global chroma synchronization knob.

---

## Yes, you can “raise the power” (without breaking D3D9)
If you want PastelChroma to have clearer impact, the safest way is to add **one multiplier** (or reuse an existing slider) that increases how strongly `pastel` pushes the mask.

### Add a strength/power shaping for pastel
Two common ways:

1) **Multiply pastel before applying bias** (simple gain):
- `pastel = saturate(pastel * PastelStrength);`

2) **Power curve on pastel** (changes rolloff):
- `pastel = pow(saturate(pastel), PastelPower);`
  - `PastelPower < 1` = broader, more sensitive
  - `PastelPower > 1` = tighter, more selective

This will make PastelChroma “feel” more interactive because the pastel term becomes more dominant when it triggers.

---

## About “balancing luma with hue black / mask boost / tightness”
Those are different axes:

- **Luma zones** = *where in brightness* the effect is allowed
- **Hue mask boost/tightness** = *which hues* are selected and how strongly
- **Hue → Black/White** = *what you do* to the selected pixels
- **PastelChroma/Value** = *special-case protection/boost* for near-white low-chroma areas

So you *can* balance them, but it’s not a single “chroma synchronization” system unless you intentionally connect them.

### If you want “probable chroma synchronization” with your luma-per-color setup
The most reliable approach is:

1) Keep your **manual luma zones** as your “where” control per hue (as you planned).
2) Treat `Pastel*` as a **stability filter**:
   - Use it to **reduce wrong selections** in bright near-white areas (or to boost them when desired),
   - but don’t try to make it replace luma selection.

If you try to “tie” luma to chroma too strongly, you can get unstable behavior: bright saturated neon can have high chroma and still be in highlights; pastel can be low chroma and midtone; compression noise can flip chroma estimate.

---

## A better “chroma” control (still D3D9-safe) if you want it
If you really want chroma synchronization, add a *separate* chroma gate on `yStrength`:

- compute `chroma0 = mx0 - mn0`
- apply a range: allow effect only when chroma is within some min/max (or below a max)

That gives you predictable chroma gating that complements luma gating.

But before adding more sliders, I’d first do the **PastelStrength/PastelPower** tweak so you can see whether your current pastel system is enough.

---

If you want, tell me what you want PastelBias to do in practice:
- **A)** protect creams (reduce effect in near-white)
- **B)** boost creams (increase effect in near-white)
- **C)** both, but with more obvious response

…and I’ll propose the smallest D3D9-safe change (1 slider) that makes `PastelChroma` meaningfully interact without messing up your luma-based workflow.

## @3d2025stephen-art

Are my sliders applied in chain, can i mind map this logic?

## Copilot

Yes—your sliders are applied in a *chain* (pipeline). Here’s a mind‑map style view of the logic in the shader you’ve been using (conceptually accurate to your current structure).

```text
INPUT (BackBuffer)
  |
  |-- Sample c0 (original color)
  |     |
  |     +-- (optional) WorkInLinear: convert c0 sRGB -> linear
  |
  |-- Build SELECTION SIGNALS (mostly from ORIGINAL c0)
  |     |
  |     +-- Hue center/width selection
  |     |     - TargetHue or HuePresetSteps (center)
  |     |     - AutoHueWidth / HueWidth (band width)
  |     |     - YellowMaskBoost (scales mask strength)
  |     |     - YellowMaskTightness (pow shaping)
  |     |     => yellowMask   (0..1)
  |     |
  |     +-- Pastel detector (from c0)
  |           - PastelChroma, PastelValue, PastelSoftness define "creamy" area
  |           - PastelBias modifies yellowMask in those areas
  |           => yellowMask_pastel (still 0..1)
  |
  |-- Build WORKING COLOR c (this is what you actually modify)
  |     |
  |     +-- Start c = c0
  |     +-- RedGain, GreenGain multiply channels
  |     +-- BluePivot & BluePivotStrength (uses c.b)
  |           modifies c.r and c.g based on blue amount
  |
  |-- Gate (from MODIFIED c)
  |     |
  |     +-- RedToAlpha, GreenToAlpha mix c.r/c.g
  |     +-- AlphaGatePower shapes it (pow)
  |     => gate (0..1)
  |
  |-- White protection (from MODIFIED c)
  |     |
  |     +-- PreserveWhites fades strength near white using luminance(c)
  |     => fadeWhite (0..1)
  |
  |-- Combine into FINAL STRENGTH
  |     |
  |     +-- yStrength = yellowMask_pastel * gate * fadeWhite
  |     +-- (optional) Luma gating (your manual zones)
  |           - LumaZone1..5 checkboxes + LumaZoneSoftness
  |           - LumaZoneBoost scales result
  |           => yStrength_final (0..1)
  |
  |-- Decide what to DO to selected pixels
  |     |
  |     +-- Hue -> White amount: YellowToWhite * yStrength_final
  |     +-- Hue -> Black amount: YellowToBlack * yStrength_final
  |     +-- Optional Hue Blue Inject:
  |           EnableYellowBlueInject + YellowBlueInject * yStrength_final
  |
  |-- Apply COLOR CHANGES to c
  |     |
  |     +-- c = lerp(c, white, whiteStrength)
  |     +-- c = lerp(c, black, blackStrength)
  |     +-- if BlueInject: c.b += signedInject
  |     +-- saturate
  |
  |-- DEBUG MODES (tap various points in this chain)
  |
OUTPUT
  |
  +-- (optional) linear -> sRGB
  +-- return
```

### Key “chain” takeaways (useful when tuning)
- **Hue mask sliders** (TargetHue / presets / width / boost / tightness) mostly affect **where** the effect is allowed (selection).
- **RedGain/GreenGain/BluePivot** affect the *working color* **before** the gate, so they indirectly affect **gate** and also the final color.
- **Gate sliders** (RedToAlpha/GreenToAlpha/AlphaGatePower) affect **how much** the effect applies in the selected region.
- **PreserveWhites + Luma zones** are *post-selection limiters* (they reduce yStrength).
- **Hue → White/Black / Blue Inject** are the final “actions” applied to `c`.

### Debug modes correspond to chain taps
- Hue mask only = `yellowMask`
- Gate only = `gate`
- Final only = `finalViz` (white/black/inject combined)
- Y2R Gate2G = raw `yellowMask` in R and `gate` in G (great for gradients)

If you want, I can draw this as a shorter “one-page tuning order” (what to adjust first, second, third) based on your typical workflow (yellow -> pink -> magenta, etc.).

## @3d2025stephen-art

let define the pastel choma arent since Luma , only saturation meannings wile the Luma are handled elsewhere,likethis the pastel will be influent as saturation versus the hue controls, is this doable?

## Copilot

Yes, that’s doable, and it’s a good separation of concerns:

- **Luma** (brightness) is handled by your luma zones / preserve whites.
- **PastelChroma** becomes purely a **saturation (chroma) gate/weight**, independent of luma.
- Hue controls still define *which hue*, pastel controls define *which saturation band*.

Right now your pastel term is **(low chroma) AND (high value)**, because you multiply `pastelChroma * pastelValue`. To make pastel be “saturation-only”, you remove the value condition and (optionally) replace it with a true saturation/chroma measure.

## Minimal change: remove the brightness (PastelValue) dependency
Change this block:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
float pastel = saturate(pastelChroma * pastelValue);
```

to:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
float pastel = saturate(pastelChroma); // saturation-only (no luma/value term)
```

Then `PastelBias` will apply based only on “low chroma-ness”, not brightness.

### What this means in practice
- It will now affect **low-saturation areas at any brightness** (even mids/shadows).
- Your **luma zones** will remain the only brightness limiter (plus PreserveWhites).

If that’s what you want, this is the cleanest and cheapest approach.

## Better “saturation meaning”: use HSV-like saturation instead of max-min
`chroma0 = max-min` is OK, but it’s more like “chroma amplitude”. A more “saturation” feel is:

- `sat = (mx - mn) / mx` (HSV saturation), with protection for mx≈0.

Replace:

```hlsl
float chroma0 = mx0 - mn0;
```

with:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
float chroma0 = mx0 - mn0;
float sat0 = chroma0 / max(mx0, 1e-5);
```

and then drive `pastelChroma` from `sat0` instead of `chroma0`:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
float pastelSat = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, sat0);
float pastel = saturate(pastelSat);
```

This usually feels much more like “pastel vs saturated” regardless of brightness.

## Important: keep it stable with your mask
You currently do:

```hlsl
yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));
```

That’s fine for “saturation-only” too:
- PastelBias > 0 boosts low-sat pixels
- PastelBias < 0 protects (reduces) low-sat pixels

## D3D9 note
All of the above changes are D3D9-safe (no ints, no loops, no bitwise).

---

If you tell me which “meaning” you want for PastelChroma:
1) “low chroma amplitude” (mx-min)
2) “HSV saturation” ((mx-min)/mx)

…I’ll give you the exact final replacement block (and recommended default ranges for the slider, because saturation wants smaller defaults than mx-min).

## @3d2025stephen-art

yes this turns the pastel controls as source of truth for the luma controls , this can accuse the hue, later i can refine if this way is the good.  I think the pastel control is for the color only but can we make debug view offering to verify that the luma levels are only for the color we use?

## Copilot

Yes. Add a debug view that shows **the luma gating weight multiplied by the hue mask** (and optionally also the raw luma weight alone). That lets you verify:

- luma gating is **not global** (it only matters where the hue mask is active)
- your luma zones are affecting only the selected color region

### Add 2 debug modes (recommended)
1) **Luma Only**: see the luma mask by itself (helps tune zone boundaries)
2) **Hue∧Luma**: see “authorized luma for this hue” (the important one)

Because you’re on D3D9, keep it simple: no ints/bitwise needed.

---

## 1) Update DebugMode UI to include 2 new items
Change your DebugMode combo to add two entries at the end:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
uniform int DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0Luma Only\0Hue+Luma\0";
    ui_min = 0; ui_max = 8;
> = 0;
```

(If you’re using the D3D9-safe float-combo version, tell me and I’ll rewrite this part for float comparisons instead.)

---

## 2) Compute a `lumaW_raw` and a `lumaW_applied`
Right where you currently compute `lumaW`, keep a copy:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
float lum0 = luminance_rec709(c0);
float lumaW_raw = luma_zone_weight(saturate(lum0), LumaZoneSoftness);

// this is what actually affects yStrength in your shader (after boost)
float lumaW_applied = saturate(lumaW_raw * LumaZoneBoost);
```

Then apply it like:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
yStrength = saturate(yStrength * lumaW_applied);
```

(If you keep your existing `yStrength = ... * lumaW * LumaZoneBoost`, that’s fine too—this just gives named taps for debug.)

---

## 3) Add the new debug branches
Inside your debug section, add two cases:

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2.fx
else if (DebugMode == 7)
{
    // Luma Only (grayscale)
    float lv = pow(saturate(lumaW_raw), DebugGamma);
    float3 m = lv.xxx;
    if (WorkInLinear) m = linear_to_srgb(m);
    return float4(m, 1.0);
}
else if (DebugMode == 8)
{
    // Hue+Luma: shows luma gating only where hue mask exists
    // (this is the "proof" luma is only meaningful for the selected hue)
    float hv = saturate(yellowMask);
    float lv = saturate(lumaW_raw);

    float hl = pow(saturate(hv * lv), DebugGamma); // AND visualization
    float3 m = hl.xxx;

    if (WorkInLinear) m = linear_to_srgb(m);
    return float4(m, 1.0);
}
```

### How to read it
- **Luma Only**: shows which luma zones are enabled globally.
- **Hue+Luma**: shows where the effect *can* happen after luma is considered:
  - White = hue matches AND luma allowed
  - Dark = either hue doesn’t match or luma isn’t allowed
  - If you switch TargetHue presets, this view should “follow” that hue.

---

## Important note about your statement (“pastel becomes source of truth for luma”)
If you made pastel saturation-only (no brightness term), pastel is **not** controlling luma anymore. Luma is still entirely controlled by:
- `LumaZone*` + `LumaZoneSoftness`
- `PreserveWhites` (separate luma fade)

But pastel can *change where the hue mask is strong*, which can feel like it influences luma indirectly (because it changes selection strength).

The **Hue+Luma debug mode** makes that relationship visible.

---

If you tell me whether your current working file is the **int DebugMode** version or the **float DebugMode** D3D9-safe version, I’ll give you the exact debug code with the right comparisons so it compiles on your setup.

## @3d2025stephen-art

can we normalize my version for dxd9 with the new features?

## Copilot

Yes — but to “normalize for D3D9” we must remove/avoid the things that silently break DX9 compilation:

- `uniform int` (especially combos)
- bitwise ops (`>>`, `&`)
- `for` loops / `[unroll]`
- sometimes `bool` return helpers

So the D3D9-normalized version will keep your **new hue preset + hue wrap** and keep **manual luma zones**, but it must **drop the per-preset luma bitmask system** (AutoLumaZones + masks + hole filling). We’ll also convert `HuePresetSteps` and `DebugMode` to **float combos**.

Below is a D3D9-safe “normalized” full file based on your latest posted one, with:
- Hue preset combo (float) including Purple
- Hue wrap distance (works for magenta/pink)
- Manual luma zones (works)
- Debug modes expanded with **Luma Only** and **Hue+Luma** to verify luma applies only to selected hue
- Removed: `AutoLumaZones`, `FillLumaMaskHoles`, `LumaMask_*`, bitwise, loops

If you later want “authorized luma per preset” on D3D9, use the Min/Max per preset approach (Option B) we already built; it’s safe.

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Version2_D3D9Normalized.fx
// Reshade: BluePivot-HSLW v3 pastel v35 (D3D9 Normalized)
//
// D3D9 safety changes:
// - No int uniforms (HuePresetSteps + DebugMode are float combos)
// - No bitwise ops / loops (removed per-preset luma bitmask feature)
// - Added debug views: Luma Only, Hue+Luma
//
// Features preserved:
// - Stable hue mask from original sample (c0)
// - Hue preset combo + AutoHueWidth + manual HueWidth
// - Hue wrap distance (magenta/pink safe)
// - Pastel bias (signed) for creamy/near-white behavior
// - Manual 5-zone luma gating + softness + boost
// - Hue -> White / Hue -> Black
// - Optional Hue Blue Inject

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan <-> Magenta)";
    ui_type = "slider";
    ui_min = -0.5; ui_max = 0.5;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1 (0.166=Yellow default)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

// D3D9-safe: float combo
uniform float HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20deg  (Amber)\0"
        "50deg  (Warm Yellow)\0"
        "110deg (Yellow-Green)\0"
        "190deg (Cyan)\0"
        "230deg (Sky Blue)\0"
        "280deg (Purple)\0"
        "310deg (Magenta)\0"
        "340deg (Hot Pink)\0";
    ui_min = 0.0; ui_max = 8.0;
> = 0.0;

uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;

// ---- Hue tonal correction ----
uniform float YellowToWhite <
    ui_label = "Hue -> White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue -> Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

// Selective Hue mask controls
uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

// ---- Pastel bias (signed) ----
uniform float PastelBias <
    ui_label = "Pastel Bias (-protect creams ... +boost creams)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- LUMA ZONES (manual) ----
uniform bool LumaZone1_Shadows < ui_label="Z1 Shadows (0-20%)"; ui_type="checkbox"; > = true;
uniform bool LumaZone2_Darks   < ui_label="Z2 Darks (20-40%)";   ui_type="checkbox"; > = true;
uniform bool LumaZone3_Mids    < ui_label="Z3 Mids (40-60%)";    ui_type="checkbox"; > = true;
uniform bool LumaZone4_Lights  < ui_label="Z4 Lights (60-80%)";  ui_type="checkbox"; > = true;
uniform bool LumaZone5_Highlights < ui_label="Z5 High (80-100%)"; ui_type="checkbox"; > = true;

uniform float LumaZoneSoftness <
    ui_label = "Luma Softness";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 0.20;
> = 0.04;

uniform float LumaZoneBoost <
    ui_label = "Luma Boost";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 4.0;
> = 1.0;

// ---- Red/Green -> gate ----
uniform float RedToAlpha < ui_label="Red -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float GreenToAlpha < ui_label="Green -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;

uniform float AlphaGatePower <
    ui_label = "Alpha Gate Power";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 4.0;
> = 1.5;

uniform float PreserveWhites <
    ui_label = "Preserve Whites (fade near white)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.75;

// ---- Optional blue injection style ----
uniform bool EnableYellowBlueInject < ui_label="Enable Hue Blue Inject"; ui_type="checkbox"; > = false;

uniform float YellowBlueInject <
    ui_label = "Hue Blue Inject (-remove ... +add)";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform bool WorkInLinear < ui_label="Work In Linear (recommended)"; ui_type="checkbox"; > = true;

// ---- Debug (D3D9-safe: float combo) ----
uniform float DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items =
        "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0Luma Only\0Hue+Luma\0";
    ui_min = 0.0; ui_max = 8.0;
> = 0.0;

uniform float DebugOverlayStrength < ui_label="DEBUG Overlay Strength"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.65;
uniform float DebugGamma < ui_label="DEBUG Gamma (mask visibility)"; ui_type="slider"; ui_min=0.4; ui_max=2.2; > = 0.85;


// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float curve(float x) { return x * x * (3.0 - 2.0 * x); }

float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}

float hue_center_from_preset(float preset, float fallbackHue)
{
    if (preset < 0.5) return fallbackHue;
    if (abs(preset - 1.0) < 0.5) return 20.0 / 360.0;
    if (abs(preset - 2.0) < 0.5) return 50.0 / 360.0;
    if (abs(preset - 3.0) < 0.5) return 110.0 / 360.0;
    if (abs(preset - 4.0) < 0.5) return 190.0 / 360.0;
    if (abs(preset - 5.0) < 0.5) return 230.0 / 360.0;
    if (abs(preset - 6.0) < 0.5) return 280.0 / 360.0;
    if (abs(preset - 7.0) < 0.5) return 310.0 / 360.0;
    return 340.0 / 360.0; // ~8
}

float hue_width_from_preset(float preset, float fallback)
{
    if (preset < 0.5) return fallback;
    if (abs(preset - 1.0) < 0.5) return 7.5;
    if (abs(preset - 2.0) < 0.5) return 7.0;
    if (abs(preset - 3.0) < 0.5) return 6.5;
    if (abs(preset - 4.0) < 0.5) return 5.5;
    if (abs(preset - 5.0) < 0.5) return 5.5;
    if (abs(preset - 6.0) < 0.5) return 6.2;
    if (abs(preset - 7.0) < 0.5) return 6.0;
    return 6.5;
}

float bandpass01(float x, float a, float b, float s)
{
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight(float lum, float softness)
{
    float w = 0.0;
    if (LumaZone1_Shadows)    w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)      w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)       w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)     w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights) w += bandpass01(lum, 0.8, 1.0, softness);
    return saturate(w);
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float cmy_scalar = 0.5 * (mx - mn);

    float h = rgb_hue01(saturate(c));
    float center = hue_center_from_preset(HuePresetSteps, TargetHue);
    float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;

    float d = hue_dist01(h, center);
    float band = max(1.0 - (d * width), 0.0);
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;
    w_y = saturate(w_y * chromaBoost);
    w_y = pow(max(w_y, 1e-6), hueTightness); // safer pow
    return saturate(w_y);
}


// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    // Hue mask from ORIGINAL (stable)
    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    // Pastel bias (as you currently have it: low-chroma AND bright)
    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    // Main color shaping
    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float b = c.b;
    c.r += pivot * b * 0.5;
    c.g -= pivot * b * 0.5;

    // Gate
    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    // Preserve whites
    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    float yStrength = saturate(yellowMask * gate * fadeWhite);

    // Luma gating (manual)
    float lum0 = luminance_rec709(c0);
    float lumaW_raw = luma_zone_weight(saturate(lum0), LumaZoneSoftness);
    float lumaW_applied = saturate(lumaW_raw * LumaZoneBoost);

    yStrength = saturate(yStrength * lumaW_applied);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    // --- DEBUG ---
    if (DebugMode > 0.5)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (abs(DebugMode - 1.0) < 0.5)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear) outc = linear_to_srgb(outc);
            return float4(outc, 1.0);
        }
        if (abs(DebugMode - 2.0) < 0.5)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear) masks = linear_to_srgb(masks);
            return float4(masks, 1.0);
        }
        if (abs(DebugMode - 3.0) < 0.5)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        if (abs(DebugMode - 4.0) < 0.5)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        if (abs(DebugMode - 5.0) < 0.5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        if (abs(DebugMode - 6.0) < 0.5)
        {
            float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);
            if (WorkInLinear) dbg = linear_to_srgb(dbg);
            return float4(dbg, 1.0);
        }
        if (abs(DebugMode - 7.0) < 0.5)
        {
            float lv = pow(saturate(lumaW_raw), DebugGamma);
            float3 m = lv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        // 8: Hue+Luma
        {
            float hl = pow(saturate(yellowMask * lumaW_raw), DebugGamma);
            float3 m = hl.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
    }

    // Apply hue tonal correction (soft, hue-only)
    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    // Optional: Hue Blue Inject (signed)
    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear) c = linear_to_srgb(c);
    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```

If you want, I can also “normalize” your pastel behavior to be saturation-only (remove `PastelValue` dependency) in this D3D9-normalized file—but I left it as your current implementation for now.

## @3d2025stephen-art

This version is demonstrating i didnt choose the good way to control the luma, i will see later but i guess my approach of pastels controling the luma better not control directly some luma levels, my guessing we did bad to implement this patch, can we make a normalized version without patch? 

## Copilot

```hlsl name=BluePivot-HSLW_Version35_Version5pink_Version2Luma_Normalized_NoAutoLuma_NoBitmask_D3D9.fx
// Reshade: BluePivot-HSLW v3 pastel v35 (D3D9 normalized, no AutoLuma patch)
//
// This is a "normalized" rollback of your last posted file:
// - Keeps: Hue preset combo + hue wrap, manual luma zones, pastel system, debug system, inject, etc.
// - Removes: AutoLumaZones + FillLumaMaskHoles + LumaMask_* + all bitwise/loop helpers used by that patch.
// - D3D9 normalization: HuePresetSteps + DebugMode are float combos (avoids DX9 int combo issues).
//
// Result:
// - Your luma control is ONLY the 5 manual luma zone checkboxes + softness + boost (simple + predictable).
// - Pastel controls do NOT directly control luma; they only bias the hue mask as before.

#include "ReShade.fxh"

// -------------------- UI --------------------

uniform float RedGain <
    ui_label = "Red Gain (R<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float GreenGain <
    ui_label = "Green Gain (G<->Black)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

uniform float BluePivot <
    ui_label = "Blue Pivot (Cyan <-> Magenta)";
    ui_type = "slider";
    ui_min = -0.5; ui_max = 0.5;
> = 0.0;

uniform float BluePivotStrength <
    ui_label = "Blue Pivot Strength";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 1.0;

// ---- HUE / Pastel Controls (foldable) ----
uniform float TargetHue <
    ui_label = "Target Hue (Custom) 0..1 (0.166=Yellow default)";
    ui_category = "HUE / Pastel Controls";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.03; ui_max = 0.97;
> = 1.0 / 6.0;

// D3D9-safe: float combo
uniform float HuePresetSteps <
    ui_label = "Target Hue Preset (named degrees)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "combo";
    ui_items =
        "Custom (slider)\0"
        "20deg  (Amber)\0"
        "50deg  (Warm Yellow)\0"
        "110deg (Yellow-Green)\0"
        "190deg (Cyan)\0"
        "230deg (Sky Blue)\0"
        "280deg (Purple)\0"
        "310deg (Magenta)\0"
        "340deg (Hot Pink)\0";
    ui_min = 0.0; ui_max = 8.0;
> = 0.0;

uniform bool AutoHueWidth <
    ui_label = "Auto Hue Width (per preset)";
    ui_category = "HUE / Pastel Controls";
    ui_type = "checkbox";
> = true;

uniform float HueWidth <
    ui_label = "Hue Width (manual)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 1.0; ui_max = 12.0;
> = 6.0;

// ---- Hue tonal correction ----
uniform float YellowToWhite <
    ui_label = "Hue -> White";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

uniform float YellowToBlack <
    ui_label = "Hue -> Black";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
> = 0.0;

// Selective Hue mask controls
uniform float YellowMaskBoost <
    ui_label = "Hue Mask Boost";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 8.0;
> = 4.0;

uniform float YellowMaskTightness <
    ui_label = "Hue Mask Tightness";
    ui_category = "HUE / Pastel Controls";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 3.0;
> = 1.2;

// ---- Pastel bias (signed) ----
uniform float PastelBias <
    ui_label = "Pastel Bias (-protect creams ... +boost creams)";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.25;

uniform float PastelChroma <
    ui_label = "Pastel Chroma Range";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.01; ui_max = 0.40;
> = 0.16;

uniform float PastelValue <
    ui_label = "Pastel Brightness (V) Threshold";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.70;

uniform float PastelSoftness <
    ui_label = "Pastel Softness";
    ui_category = "HUE / Pastel Controls";
    ui_type  = "slider";
    ui_min = 0.001; ui_max = 0.40;
> = 0.12;

// ---- LUMA ZONES (manual checkboxes only) ----
uniform bool LumaZone1_Shadows < ui_label="Z1 Shadows (0-20%)"; ui_type="checkbox"; > = true;
uniform bool LumaZone2_Darks   < ui_label="Z2 Darks (20-40%)";   ui_type="checkbox"; > = true;
uniform bool LumaZone3_Mids    < ui_label="Z3 Mids (40-60%)";    ui_type="checkbox"; > = true;
uniform bool LumaZone4_Lights  < ui_label="Z4 Lights (60-80%)";  ui_type="checkbox"; > = true;
uniform bool LumaZone5_Highlights < ui_label="Z5 High (80-100%)"; ui_type="checkbox"; > = true;

uniform float LumaZoneSoftness <
    ui_label = "Luma Softness";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 0.20;
> = 0.04;

uniform float LumaZoneBoost <
    ui_label = "Luma Boost";
    ui_type  = "slider";
    ui_min = 0.0; ui_max = 4.0;
> = 1.0;

// ---- Red/Green -> gate ----
uniform float RedToAlpha < ui_label="Red -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;
uniform float GreenToAlpha < ui_label="Green -> Alpha (gate weight)"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.5;

uniform float AlphaGatePower <
    ui_label = "Alpha Gate Power";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 4.0;
> = 1.5;

uniform float PreserveWhites <
    ui_label = "Preserve Whites (fade near white)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.75;

// ---- Optional blue injection ----
uniform bool EnableYellowBlueInject < ui_label="Enable Hue Blue Inject"; ui_type="checkbox"; > = false;

uniform float YellowBlueInject <
    ui_label = "Hue Blue Inject (-remove ... +add)";
    ui_type  = "slider";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform bool WorkInLinear < ui_label="Work In Linear (recommended)"; ui_type="checkbox"; > = true;

// ---- Debug (D3D9-safe: float combo) ----
uniform float DebugMode <
    ui_label = "DEBUG Mode";
    ui_type = "combo";
    ui_items = "Off\0Overlay\0Beauty Masks\0Hue Mask Only\0Gate Only\0Final Only\0Y2R Gate2G\0";
    ui_min = 0.0; ui_max = 6.0;
> = 0.0;

uniform float DebugOverlayStrength < ui_label="DEBUG Overlay Strength"; ui_type="slider"; ui_min=0.0; ui_max=1.0; > = 0.65;
uniform float DebugGamma < ui_label="DEBUG Gamma (mask visibility)"; ui_type="slider"; ui_min=0.4; ui_max=2.2; > = 0.85;


// -------------------- HELPERS --------------------

float3 srgb_to_linear(float3 c)
{
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, 2.4);
    return lerp(hi, lo, step(c, 0.04045));
}

float3 linear_to_srgb(float3 c)
{
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(hi, lo, step(c, 0.0031308));
}

float luminance_rec709(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float curve(float x) { return x * x * (3.0 - 2.0 * x); }

float rgb_hue01(float3 c)
{
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 1e-6) return 0.0;

    float h;
    if (mx == c.r)      h = (c.g - c.b) / d;
    else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
    else                h = 4.0 + (c.r - c.g) / d;

    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
}

float hue_center_from_preset(float preset, float fallbackHue)
{
    if (preset < 0.5) return fallbackHue;
    if (abs(preset - 1.0) < 0.5) return 20.0 / 360.0;
    if (abs(preset - 2.0) < 0.5) return 50.0 / 360.0;
    if (abs(preset - 3.0) < 0.5) return 110.0 / 360.0;
    if (abs(preset - 4.0) < 0.5) return 190.0 / 360.0;
    if (abs(preset - 5.0) < 0.5) return 230.0 / 360.0;
    if (abs(preset - 6.0) < 0.5) return 280.0 / 360.0;
    if (abs(preset - 7.0) < 0.5) return 310.0 / 360.0;
    return 340.0 / 360.0;
}

float hue_width_from_preset(float preset, float fallback)
{
    if (preset < 0.5) return fallback;
    if (abs(preset - 1.0) < 0.5) return 7.5;
    if (abs(preset - 2.0) < 0.5) return 7.0;
    if (abs(preset - 3.0) < 0.5) return 6.5;
    if (abs(preset - 4.0) < 0.5) return 5.5;
    if (abs(preset - 5.0) < 0.5) return 5.5;
    if (abs(preset - 6.0) < 0.5) return 6.2;
    if (abs(preset - 7.0) < 0.5) return 6.0;
    return 6.5;
}

float bandpass01(float x, float a, float b, float s)
{
    float ss = max(s, 1e-6);
    float inL = smoothstep(a - ss, a + ss, x);
    float inR = 1.0 - smoothstep(b - ss, b + ss, x);
    return saturate(inL * inR);
}

float luma_zone_weight(float lum, float softness)
{
    float w = 0.0;
    if (LumaZone1_Shadows)    w += bandpass01(lum, 0.0, 0.2, softness);
    if (LumaZone2_Darks)      w += bandpass01(lum, 0.2, 0.4, softness);
    if (LumaZone3_Mids)       w += bandpass01(lum, 0.4, 0.6, softness);
    if (LumaZone4_Lights)     w += bandpass01(lum, 0.6, 0.8, softness);
    if (LumaZone5_Highlights) w += bandpass01(lum, 0.8, 1.0, softness);
    return saturate(w);
}

float selective_yellow_weight(float3 c, float chromaBoost, float hueTightness)
{
    float mn = min(c.r, min(c.g, c.b));
    float mx = max(c.r, max(c.g, c.b));
    float cmy_scalar = 0.5 * (mx - mn);

    float h = rgb_hue01(saturate(c));
    float center = hue_center_from_preset(HuePresetSteps, TargetHue);
    float width = AutoHueWidth ? hue_width_from_preset(HuePresetSteps, HueWidth) : HueWidth;

    float d = hue_dist01(h, center);
    float band = max(1.0 - (d * width), 0.0);
    float sw_y = curve(band);

    float w_y = sw_y * cmy_scalar;
    w_y = saturate(w_y * chromaBoost);
    w_y = pow(max(w_y, 1e-6), hueTightness);
    return saturate(w_y);
}


// -------------------- PASS --------------------

texture BackBufferTex : COLOR;
sampler BackBufferSam { Texture = BackBufferTex; };

float4 PS_BluePivotHSLW_v3(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 c0 = tex2D(BackBufferSam, uv).rgb;
    float3 c  = c0;

    if (WorkInLinear)
    {
        c0 = srgb_to_linear(c0);
        c  = c0;
    }

    float yellowMask = selective_yellow_weight(c0, YellowMaskBoost, YellowMaskTightness);

    float mn0 = min(c0.r, min(c0.g, c0.b));
    float mx0 = max(c0.r, max(c0.g, c0.b));
    float chroma0 = mx0 - mn0;

    float pastelChroma = 1.0 - smoothstep(PastelChroma, PastelChroma + PastelSoftness, chroma0);
    float pastelValue  = smoothstep(PastelValue, PastelValue + PastelSoftness, mx0);
    float pastel = saturate(pastelChroma * pastelValue);

    yellowMask = saturate(yellowMask * (1.0 + PastelBias * pastel));

    c.r *= RedGain;
    c.g *= GreenGain;

    float pivot = BluePivot * BluePivotStrength;
    float b = c.b;
    c.r += pivot * b * 0.5;
    c.g -= pivot * b * 0.5;

    float wsum = max(1e-5, (RedToAlpha + GreenToAlpha));
    float gate = (RedToAlpha * c.r + GreenToAlpha * c.g) / wsum;
    gate = saturate(pow(saturate(gate), AlphaGatePower));

    float lum = luminance_rec709(c);
    float fadeWhite = lerp(1.0, saturate(1.0 - lum), PreserveWhites);

    float yStrength = saturate(yellowMask * gate * fadeWhite);

    float lum0 = luminance_rec709(c0);
    float lumaW = luma_zone_weight(saturate(lum0), LumaZoneSoftness);

    yStrength = saturate(yStrength * lumaW * LumaZoneBoost);

    float whiteStrength = yStrength * saturate(YellowToWhite);
    float blackStrength = yStrength * saturate(YellowToBlack);

    float injectStrength = 0.0;
    if (EnableYellowBlueInject)
        injectStrength = yStrength * abs(YellowBlueInject);

    if (DebugMode > 0.5)
    {
        float finalViz = saturate(max(whiteStrength, blackStrength) + injectStrength);

        float yv = pow(saturate(yellowMask), DebugGamma);
        float gv = pow(saturate(gate), DebugGamma);
        float fv = pow(finalViz, DebugGamma);

        if (abs(DebugMode - 1.0) < 0.5)
        {
            float3 base = c0;

            float3 colHue   = float3(1.0, 0.92, 0.10);
            float3 colGate  = float3(0.10, 0.95, 1.00);
            float3 colFinal = float3(1.00, 0.20, 0.85);

            float3 overlay =
                colHue   * yv * 0.75 +
                colGate  * gv * 0.55 +
                colFinal * fv * 1.10;

            float3 outc = lerp(base, saturate(base + overlay), DebugOverlayStrength);

            if (WorkInLinear) outc = linear_to_srgb(outc);
            return float4(outc, 1.0);
        }
        else if (abs(DebugMode - 2.0) < 0.5)
        {
            float3 masks = float3(yv, gv, fv);
            masks = saturate(masks);
            masks = masks * (0.85 + 0.15 * masks);

            if (WorkInLinear) masks = linear_to_srgb(masks);
            return float4(masks, 1.0);
        }
        else if (abs(DebugMode - 3.0) < 0.5)
        {
            float3 m = yv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (abs(DebugMode - 4.0) < 0.5)
        {
            float3 m = gv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else if (abs(DebugMode - 5.0) < 0.5)
        {
            float3 m = fv.xxx;
            if (WorkInLinear) m = linear_to_srgb(m);
            return float4(m, 1.0);
        }
        else
        {
            float3 dbg = float3(saturate(yellowMask), saturate(gate), 0.0);
            if (WorkInLinear) dbg = linear_to_srgb(dbg);
            return float4(dbg, 1.0);
        }
    }

    c = lerp(c, 1.0.xxx, saturate(whiteStrength));
    c = lerp(c, 0.0.xxx, saturate(blackStrength));

    if (EnableYellowBlueInject && (YellowBlueInject != 0.0))
    {
        float signedInject = (YellowBlueInject >= 0.0) ? injectStrength : -injectStrength;
        c.b += signedInject;
    }

    c = saturate(c);

    if (WorkInLinear) c = linear_to_srgb(c);
    return float4(c, 1.0);
}

technique BluePivot_HSLW_v3_Pastel
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_BluePivotHSLW_v3;
    }
}
```
