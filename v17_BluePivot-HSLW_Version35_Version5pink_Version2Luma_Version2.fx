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
    ui_min = -0.5; ui_max = 0.5;
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
        "280° (Purple)\0"
        "310° (Magenta)\0"
        "340° (Hot Pink)\0";
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

// ---------- 2) Add hue wrap-distance helper ----------
// Add this near your helpers (e.g., above selective_yellow_weight):

float hue_dist01(float h, float center)
{
    float d = abs(h - center);
    return min(d, 1.0 - d);
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