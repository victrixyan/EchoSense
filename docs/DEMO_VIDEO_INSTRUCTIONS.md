# EchoSense Phase 5: Demo Video Instructions

## Overview
This document provides a complete workflow for recording a 2-3 minute demonstration video showcasing EchoSense's real-time dementia care response system on the iOS Simulator.

**Target:** Professional, polished demo suitable for:
- Patient care stakeholder presentation
- Academic/clinical publication
- Investor/funding review
- Open-source community showcase

---

## Pre-Production Checklist

### Equipment & Software
```
☑ macOS (Apple Silicon preferred for smooth simulator)
☑ Xcode 16.0+ with iOS 18.0 simulator
☑ QuickTime Player (for screen recording)
    OR FFmpeg (for advanced editing)
    OR ScreenFlow Pro (for polish)
☑ Audio recording app (Voice Memos)
☑ Text editor for narration notes
☑ ~1 hour total time (30min setup, 20min recording, 10min editing)
```

### App State
```
☑ MainViewModel.swift updated with Phase 5 inference loop
☑ MainView.swift redesigned with green/teal minimalist UI
☑ DemoTestHarness.swift with synthetic biomarkers ready
☑ medgemma-1.5-4b.mlpackage in /exports/models/
☑ App tested and verified "Ready" shows on startup
```

### Simulator Readiness
```
☑ iPhone 15 Pro simulator booted
☑ Microphone permission pre-granted in Settings
☑ Model loads in <3 seconds
☑ CPU not throttled (check Activity Monitor)
☑ ~4GB RAM available
```

---

## Recording Setup

### Option 1: QuickTime Screen Recording (Recommended, Simple)

**Step 1: Launch QuickTime**
```bash
open /Applications/QuickTime\ Player.app
```

**Step 2: Start Screen Recording**
1. Click: File > New Screen Recording
2. Select microphone: Built-in Microphone (or USB headset)
3. Click: Options
   - ☑ Show mouse clicks: ON (helps viewers follow along)
   - Resolution: 1920x1080 or native simulator resolution
4. Select: Simulator window
5. Click: **Record**
6. Status bar shows recording indicator (red dot)

**Step 3: Record Narration While Simultaneously**
- Record audio using separate app (Voice Memos)
- OR narrate while recording screen (sync later in post-production)

**Step 4: Stop Recording**
- Press: Return key
- OR Click: Stop button in recording dialog
- Save file to: `/tmp/echosense_demo_raw.mov`

### Option 2: FFmpeg (Advanced, Higher Quality)

```bash
# List available inputs
ffmpeg -f avfoundation -list_devices short -i ""

# Record simulator screen + audio
ffmpeg -f avfoundation \
  -i "Simulator:default" \
  -vcodec libx264 \
  -preset fast \
  -crf 20 \
  -pix_fmt yuv420p \
  -y \
  /tmp/echosense_demo_raw.mp4

# Stop: Ctrl+C when done
```

### Option 3: ScreenFlow Pro (Most Polished)

1. **Launch ScreenFlow**
2. **File > New Screen Recording**
3. **Select Area:** Simulator window
4. **Click:** Record
5. **Narrator:** Narrate while recording (ScreenFlow has built-in audio)
6. **File > Export > MP4** (ProRes codec for best quality)

---

## Recording Sequence (2-3 minutes)

### [PART A] INTRO & APP LAUNCH (0:00-0:20)

**Narration (spoken softly, professional):**
> "EchoSense is a real-time dementia care response system using acoustic biomarkers and Large Language Models to support caregivers. This demo shows the Phase 5 interface with smooth real-time animations responding to patient vocal patterns."

**Actions:**
1. Show simulator home screen briefly (2 seconds)
2. Tap EchoSense app icon
3. Show app loading:
   - Model initializing spinner (3-5 seconds)
   - Green "Ready" indicator appears
4. Wait for stable UI (total 8-10 seconds from launch)

**Expected UI:**
```
[Green circle] EchoSense - Ready
[Agitation bar] Calm ─────────── Agitation (0/10, blue)
[Trend section] (empty, awaiting audio)
[Start Recording button] (ready to tap)
```

---

### [PART B] PATIENT CONTEXT SETUP (0:20-0:35)

**Narration:**
> "First, we set the patient context. In clinical use, this includes demographics, medical history, and care preferences."

**Actions:**
1. Tap: Patient Context text field
2. Type (slowly, so viewers read along): 
   ```
   "Mary, 82 years old, retired nurse, 
   enjoys gardening and family visits, 
   early stage dementia with occasional 
   word-finding difficulty"
   ```
   (Total ~30 characters per second for readability)
3. Show completed text field (2 seconds)

**UI State:**
```
✓ Patient context entered
✓ Agitation bar: 0/10 (baseline blue)
✓ Start Recording button: enabled
```

---

### [PART C] CALM BASELINE (0:35-1:00)

**Narration:**
> "Now we'll capture a baseline sample. The patient speaks clearly and calmly about familiar activities. The system analyzes acoustic features: articulation clarity, spectral properties, loudness variation, and phonation patterns."

**Actions:**
1. Click: **Start Recording** button
   - Button changes to "Stop Recording"
   - Timer shows 0:00 and counts up
   - Waveform icon animates subtly
2. Wait 5 seconds (simulating audio capture)
   - Narration: "The microphone captures 16-bit PCM audio at 16 kHz sampling rate, feeding live to the feature extraction pipeline."
3. Click: **Stop Recording** button
4. Show inference spinner (1-2 seconds):
   ```
   [Waveform icon] Analyzing audio...
   ```
5. UI animates to show results:
   - Agitation bar: **2/10 (blue, calm)**
   - Trend: **"Stable and calm"** (soft fade-in animation)
   - Nudges: 
     ```
     💡 Continue current activity
     💡 Offer familiar conversation topics
     ```

**Expected Duration:** ~6-7 seconds after Stop Recording until UI fully settled

**Visual Cues for Viewer:**
- "Notice the agitation bar smoothly interpolates from 0 to 2 over 10 seconds"
- "The trend phrase appears with a soft fade"
- "Suggested interventions are non-intrusive, supportive"

---

### [PART D] ESCALATION SEQUENCE (1:00-1:45)

**Narration:**
> "Now the patient experiences confusion and mild agitation. Perhaps they're asking 'Where am I?' or 'When can I go home?'. The system detects vocal stress markers: increased articulation variability, higher spectral tilt, and more abrupt loudness peaks."

**Actions:**
1. Click: **Start Recording** button (again)
2. Wait 5 seconds (simulating escalated speech sample)
   - Narration: "Spectral tilt increases from 15 dB to 28 dB. Roughness increases 40%. The emotional intensity metric rises."
3. Click: **Stop Recording**
4. Show inference spinner
5. UI animates smoothly:
   - Agitation bar: **animates from 2/10 → 6/10 over 10 seconds** ⭐ (KEY VISUAL)
     - Color shifts: blue → green → yellow → orange **[SMOOTH GRADIENT]**
   - Trend: **"Increasing confusion"** (previous trend fades, new trend fades in)
   - Keywords appear:
     ```
     📍 Memory confusion
     📍 Emotional escalation
     📍 Repetitive questioning
     ```
   - Nudges updated:
     ```
     💡 Use simple, clear language
     💡 Offer calm reassurance
     ```

**Visual Emphasis:**
- "Watch the 10-second smooth animation on the agitation bar — this is intentional UX design"
- "The color coding helps caregivers quickly assess patient state"
- "Keywords are context-specific, extracted from the patient's speech"

---

### [PART E] CRISIS & ESCALATION OVERRIDE (1:45-2:15)

**Narration:**
> "If agitation continues to escalate, the system can trigger escalation mode. At agitation level 7 or higher, the nudges become urgent, displayed with warning icons, and auto-update every 10 seconds instead of 18."

**Actions:**
1. Click: **Start Recording** (third sample)
2. Wait 5 seconds (simulating highly agitated speech)
   - Narration: "The patient is now highly distressed. Vocal parameters show: articulation variability 0.78, spectral tilt 31 dB, loudness peaks 5.6 per second."
3. Click: **Stop Recording**
4. Show inference spinner
5. UI enters **ESCALATION MODE:**
   - Agitation bar: **animates 6/10 → 9/10 over 10 seconds** ⭐
     - Color shifts: orange → red **[URGENT RED]**
   - Panel background tints **light orange/red** (visual alert)
   - Nudges now show ⚠️ icon instead of 💡:
     ```
     ⚠️ Alert caregiver immediately
     ⚠️ Ensure patient safety
     ⚠️ Consider environment change
     ⚠️ Contact clinical supervisor
     ```
   - Nudges now update every **10 seconds** (escalation tempo)

**Critical UI Moment:**
- "The system prioritizes safety. Longer refresh intervals become shorter. Neutral icons become warning icons. This helps caregivers respond faster to deterioration."

---

### [PART F] RECOVERY & INTERVENTION (2:15-2:50)

**Narration:**
> "With clinical intervention — perhaps a familiar face, a calming activity, or reassuring communication — the patient begins to settle. The system detects improvement and adjusts feedback accordingly."

**Actions:**
1. Click: **Start Recording** (fourth sample)
2. Wait 5 seconds (simulating calming speech: slower pace, lower pitch, fewer peaks)
3. Click: **Stop Recording**
4. Show inference spinner
5. UI shows **RECOVERY:**
   - Agitation bar: **animates 9/10 → 3/10 over 10 seconds** ⭐
     - Color shifts: red → orange → green → blue **[SMOOTH DOWN-RAMP]**
   - Panel background **returns to neutral white/light gray**
   - Trend: **"Responding well to intervention"** (soft fade)
   - Nudges revert to 💡 icons, become supportive again:
     ```
     💡 Maintain calm approach
     💡 Reinforce with familiarity
     💡 Continue positive engagement
     ```
   - Update tempo returns to **18 seconds** (normal)

**Narrative Closure:**
> "Recovery can take time. The smooth animations here represent a 30-minute real clinical session compressed for demonstration. In practice, caregivers follow these prompts continuously, logged to patient memory for trend analysis every 5 inference cycles."

---

### [PART G] DATA PERSISTENCE (2:50-3:00)

**Narration:**
> "All assessments are saved locally to the device in secure JSON format, ready for caregiver review and clinical analysis."

**Actions:**
1. Click: **Stop Recording** (in QuickTime)
2. Optional: Show Files app
   - Navigate to EchoSense
   - Tap: session_memory.json
   - Show structure (assessments array with timestamps)
3. OR just narrate while showing app settings screen

**Example session_memory.json structure shown:**
```json
{
  "patient_id": "PT-001",
  "session_date": "2026-02-23",
  "assessments": [
    {
      "timestamp": "2026-02-23T14:32:10Z",
      "agitation_score": 2,
      "trend": "stable and calm",
      "response": "Continue current activity"
    },
    {
      "timestamp": "2026-02-23T14:32:28Z",
      "agitation_score": 6,
      "trend": "increasing confusion",
      "response": "Use clear language"
    },
    ...
  ]
}
```

---

## Post-Production (Optional)

### Editing & Polish

**If using QuickTime:**
1. Open recording in QuickTime
2. File > Export > MP4 format
3. Resolution: 1920x1080 or higher
4. Frame rate: 30 fps

**If using FFmpeg to add narration:**
```bash
# Record narration separately (e.g., in Voice Memos, export as .m4a)
# Sync narration with screen recording

ffmpeg \
  -i /tmp/echosense_demo_raw.mp4 \
  -i /tmp/echosense_narration.m4a \
  -vcodec copy \
  -acodec copy \
  -shortest \
  /tmp/echosense_demo_final.mp4
```

**If using ScreenFlow Pro:**
1. Edit > Add Title Slide
2. ScreenFlow > Export > MP4, ProRes codec
3. Resolution: 1920x1080 or 4K
4. Frame rate: 60 fps for smoothness

### Recommended Settings for Final Export

```
Format: MP4 (H.264 codec)
Resolution: 1920x1080 (Full HD)
Frame Rate: 30 fps (standard) or 60 fps (premium)
Bit Rate: 10-15 Mbps (high quality)
Audio: AAC, 256 kbps, stereo
Duration: 2:30 - 3:00 minutes
File Size: ~50-100 MB
```

### Optional Subtitles/Captions

For accessibility, add subtitles:
```
Timing: 0:00-0:20 - App Launch & PCDC Framework
Timing: 0:20-0:35 - Patient Context Setup
Timing: 0:35-1:00 - Calm Baseline State
Timing: 1:00-1:45 - Escalation Detection
Timing: 1:45-2:15 - Crisis Mode & Safety Alerts
Timing: 2:15-2:50 - Recovery & De-escalation
Timing: 2:50-3:00 - Data Persistence
```

---

## Key Visual Moments to Emphasize (Director's Notes)

### 🎬 Shot 1: App Launch
- **Duration:** 3-5 seconds
- **Visual:** Model loading spinner → green "Ready" dot
- **Narration:** "The 2.05 GB medgemma-1.5-4b model quantized to 4-bit loads in under 3 seconds on iPhone 15 Pro."

### 🎬 Shot 2: Calm Baseline
- **Duration:** 6-7 seconds
- **Visual:** Agitation bar smooth animation 0→2/10, blue color
- **Narration:** "Starting with a calm baseline. Acoustic biomarkers are clear and stable."

### 🎬 Shot 3: Escalation Lerp (HERO SHOT ⭐)
- **Duration:** 15 seconds (but lean on the 10s bar animation)
- **Visual:** Agitation bar smoothly lerps 2→6/10, color gradient blue→green→orange
- **Key:** SLOW DOWN during this shot, let viewers see the smooth 10-second animation
- **Narration:** "Notice the smooth color transition. The system detects increasing vocal stress in real-time."

### 🎬 Shot 4: Crisis Mode
- **Duration:** 12-15 seconds
- **Visual:** Agitation bar animates 6→9/10 RED, panel tints orange, warning icons appear
- **Narration:** "At agitation level 7+, the system enters escalation mode, prioritizing quick caregiver response."

### 🎬 Shot 5: Recovery (SECOND HERO SHOT ⭐)
- **Duration:** 15 seconds (stretch the lerp animation)
- **Visual:** Agitation bar animates 9→3/10, smooth color down-ramp red→blue, panel returns to white
- **Narration:** "With intervention, the patient settles. The system adjusts feedback to support ongoing calm."

---

## Audio/Narration Script

### Full Narration (Read at moderate pace, ~120 words per minute)

```
[0:00-0:20] APP LAUNCH
"EchoSense is a real-time dementia care response system using acoustic
biomarkers and Large Language Models to support caregivers. This demo
shows the Phase 5 interface with smooth real-time animations responding
to patient vocal patterns. The 2.05 gigabyte medgemma model quantized
to 4-bit loads in under 3 seconds on iPhone 15 Pro."

[0:20-0:35] PATIENT CONTEXT
"First, we set patient context—demographics, history, and preferences.
In clinical practice, this is configured during initial assessment."

[0:35-1:00] CALM BASELINE
"We capture a calm baseline sample. The patient speaks clearly about
familiar activities. The system extracts nine acoustic biomarkers:
articulation clarity, spectral tilt, loudness, intensity, and others.
Watch the agitation bar smoothly animate from 0 to 2 out of 10."

[1:00-1:45] ESCALATION
"The patient now experiences confusion and mild agitation. Perhaps
asking 'Where am I?' You can see vocal stress markers increase. Spectral
tilt rises from 15 to 28 decibels. The system detects this in real-time
and adapts. Notice the agitation bar smoothly lerps from 2 to 6 over
10 seconds with a soft color gradient from blue through green to orange.
Keywords emerge: 'Memory confusion,' 'Escalation.' Suggested responses
become more direct: 'Use clear language,' 'Offer reassurance.'"

[1:45-2:15] CRISIS MODE
"As vocal distress continues to escalate, the system enters escalation
mode at agitation level 7 or higher. Warning icons replace lightbulbs.
The update interval shortens from 18 seconds to 10 seconds for faster
response. You see: 'Alert caregiver immediately.' This design prioritizes
safety and clinical responsiveness."

[2:15-2:50] RECOVERY
"With caregiver intervention—perhaps a familiar activity or reassuring
communication—the patient begins to settle. The system detects improvement.
Watch the bar animate smoothly back down from 9 back to 3 out of 10.
The color gradient reverses: red through orange to green to blue.
Suggested responses revert to supportive: 'Maintain calm approach.'
All assessments log automatically to patient memory for longitudinal analysis."

[2:50-3:00] CLOSING
"EchoSense seamlessly integrates acoustic science, modern AI, and
human-centered design to support dementia care at the point of care.
Thank you."
```

---

## Recording Session Checklist

### Before You Hit Record

```
App & Infrastructure:
  ☑ Model loads and shows "Ready" indicator
  ☑ Patient context field is active
  ☑ Start Recording button is clickable
  ☑ Inference returns results in <2 seconds

Simulator:
  ☑ iPhone 15 Pro booted
  ☑ Microphone permission pre-granted
  ☑ No other apps consuming significant CPU
  ☑ At least 4GB RAM available

Recording Equipment:
  ☑ QuickTime (or ScreenFlow) is open
  ☑ Audio input selected (built-in mic or external)
  ☑ Recording destination set: /tmp/echosense_demo_raw.***
  ☑ Simulator window is in focus and fully visible
  ☑ Simulator resolution is 1920x1080 or higher

Workspace:
  ☑ Lighting is even (avoid glare on screen)
  ☑ Microphone is positioned ~ 6 inches away
  ☑ No background noise (turn off: Slack notifications, Messages, etc.)
  ☑ Phone on silent mode
```

### During Recording

```
Pacing:
  ☑ Speak clearly and deliberately
  ☑ Pause 2-3 seconds between major sections
  ☑ Read narration from prepared script (printed or second monitor)
  ☑ Slow down during key visual moments (agitation bar lerps)

UI Interaction:
  ☑ Tap buttons with deliberate, visible motion
  ☑ Type slowly so viewers can read patient context
  ☑ Allow 1-2 seconds delay after each action for inference
  ☑ Wait for UI animations to complete before proceeding

Technical:
  ☑ Monitor CPU in Activity Monitor (should stay <70%)
  ☑ Check audio levels (green, not red clipping)
  ☑ If simulator lags, pause and close other apps
```

### After Recording

```
File Management:
  ☑ Save raw recording to: /tmp/echosense_demo_raw.mov (or .mp4)
  ☑ Create backup copy: /Users/victrixyan/EchoSense/exports/demo_video/
  ☑ Verify file size >50MB (indicates good quality)
  ☑ Verify duration 2:30-3:00 minutes

Quality Check:
  ☑ Audio level: -12dB to -6dB (not clipping)
  ☑ Visual clarity: No pixelation, bars smooth
  ☑ Narration: Clear, audible, correct pacing
  ☑ UI animations: All 10-second lerps visible
  ☑ No dropped frames or stutters
```

---

## Delivery & Sharing

### File Outputs

**Final deliverable structure:**
```
/Users/victrixyan/EchoSense/exports/demo_video/
├── echosense_phase5_demo.mp4 (final, polished)
├── echosense_phase5_demo_raw.mov (unedited backup)
├── NARRATION_SCRIPT.txt (plain text)
├── DEMO_VIDEO_NOTES.md (this file)
└── THUMBNAIL.png (optional: screenshot from key moment)
```

### Sharing Options

**YouTube/Academic:**
- Format: MP4, 1080p, 30fps
- Title: "EchoSense Phase 5: Real-Time Dementia Care AI Demo"
- Description: [See template below]
- Tags: dementia, ai, healthcare, audio-biomarkers, mhealth

**Stakeholder Presentations:**
- Format: MP4, compressed for email (<50MB)
- Delivery: Slack, Drive link, or embedded in presentation

**Publication/Preprint:**
- Format: MP4 or MOV, high quality
- Supplementary material: Include narration transcript
- Caption: "Supplementary Video 1: EchoSense Phase 5 Real-Time Demo"

### YouTube Description Template

```
EchoSense Phase 5: Real-Time Dementia Care Response System

This video demonstrates the Phase 5 iOS interface of EchoSense, a 
machine learning system supporting caregivers in detecting and 
responding to vocal changes in dementia patients.

Key Features:
- Real-time audio biomarker extraction (9 acoustic features)
- 2.05 GB quantized LLM inference (<2 seconds)
- Smooth 10-second UI animations for caregiver perception
- Escalation detection and safety prioritization
- Local data persistence for longitudinal care

Technical Stack:
- iOS 18 (Swift/SwiftUI)
- CoreML (medgemma-1.5-4b 4-bit quantized)
- OpenSMILE (acoustic feature extraction)
- PCDC Framework (Patient-Centered Dementia Care)

Timestamps:
0:00 App Launch & Model Load
0:20 Patient Context Setup
0:35 Calm Baseline Assessment
1:00 Escalation Detection
1:45 Crisis Mode & Escalation Override
2:15 Recovery & De-escalation
2:50 Data Persistence
3:00 Closing

Citation:
[Will update with preprint/publication link]

Contact:
[Include contact information for inquiries]
```

---

## Troubleshooting Demo Issues

### Problem: Simulator Freezes During Recording
**Solution:**
- Pause recording (don't stop)
- Wait 10 seconds for simulator to unfreeze
- Resume recording
- In post-production, cut out freeze (splice videos)

### Problem: Inference Takes >3 Seconds
**Solution:**
- Restart simulator
- Check Activity Monitor (CPU should be <70% during inference)
- If still slow: record multiple takes and use fastest inference time
- Consider recording on iPhone 15 Pro hardware (if available) instead of simulator

### Problem: Audio Narration Out of Sync
**Solution:**
- Re-record narration separately using Voice Memos
- Use FFmpeg to sync narration with screen recording (see section above)
- Or use ScreenFlow Pro which handles audio sync natively

### Problem: UI Animations Don't Appear Smooth
**Solution:**
- Ensure simulator is set to 60fps rendering in Xcode settings
- Verify no other apps consuming CPU
- Record at native simulator resolution (avoid scaling)
- In post-production, ensure export is at minimum 30fps

### Problem: Green "Ready" Indicator Doesn't Load
**Solution:**
- App requires model download on first launch (may take >10 seconds)
- Record with patience and slow narration during loading
- Or pre-load model by running app 15 minutes before recording

---

## Final Checklist Before Publishing

```
Content:
  ☑ All narration is clear and audible
  ☑ All UI animations complete (10-second bar lerps visible)
  ☑ Patient context is legible
  ☑ All four scenarios show (calm, escalation, crisis, recovery)
  ☑ Key moments highlighted (agitation bar color changes)
  ☑ No sensitive patient data visible

Technical:
  ☑ Video is 1920x1080 or higher
  ☑ Frame rate is 30fps or higher
  ☑ Audio is stereo, 256kbps or higher
  ☑ Duration is 2:30-3:00 minutes
  ☑ File size is 50-200MB (not compressed artifacts)
  ☑ No dropped frames or stutters

Branding:
  ☑ EchoSense color scheme is accurate (green/teal)
  ☑ Logo appears in header section
  ☑ Professional narration tone
  ☑ No background distractions

Uploads:
  ☑ File uploaded to /exports/demo_video/
  ☑ Backup copy saved locally
  ☑ YouTube/sharing link tested
  ☑ Metadata (title, description, tags) complete
```

---

## Version Control for Demo

Once published, maintain version history:

```
echosense_phase5_demo_v1.0.mp4
  Date: 2026-02-23
  Duration: 2:45
  Resolution: 1920x1080
  Notes: Initial release with full narration

echosense_phase5_demo_v1.1.mp4
  Date: 2026-02-25
  Duration: 2:45
  Resolution: 1920x1080
  Notes: Added captions, improved narration sync

echosense_phase5_demo_v2.0.mp4
  Date: 2026-03-15
  Duration: 3:00
  Resolution: 4K
  Notes: Hardware recording (faster inference), professional color grading
```

---

## Success Criteria

Your demo video is ready for publication when:

✅ **Visual**: All UI elements animate smoothly, colors match branding
✅ **Audio**: Narration is clear, technical terms pronounced correctly
✅ **Content**: All four scenarios (calm → escalation → crisis → recovery) shown
✅ **Duration**: 2:30-3:00 minutes (professional conference standard)
✅ **Technical**: 1080p+ resolution, 30fps+, <200MB file size
✅ **Accuracy**: Reflects actual Phase 5 implementation without special effects
✅ **Accessibility**: Captions or transcript provided
✅ **Branding**: EchoSense green/teal colors and logo visible throughout

---

## Next Steps

After completing the demo video:

1. **Upload to YouTube** (with privacy set to "Unlisted" until ready)
2. **Embed in documentation:** README.md, project website
3. **Share with stakeholders:** Care facilities, researchers, collaborators
4. **Archive in project:** `/exports/demo_video/echosense_phase5_demo_FINAL.mp4`
5. **Update README** with demo video link and timestamp references

---

## Appendix: Advanced Recording Techniques

### Slow-Motion Playback for Key Moments

If your editor supports variable frame rates, slow down the agitation bar animation moment 25-50%to emphasize the smooth color transition:

```bash
# Using FFmpeg to slow down 0:35-1:00 section to 0.75x speed
ffmpeg -i echosense_demo_raw.mp4 \
  -vf "select='between(t,35,60)',setpts=N/(FRAME_RATE/0.75)/TB" \
  -af "atempo=0.75" \
  slow_section.mp4
```

### Color Grading (Optional Polish)

If using ScreenFlow Pro or Final Cut Pro:
- **Warm slightly:** +5% in shadows, -2% in highlights (matches green/teal branding)
- **Saturation:** +8% to make green/teal colors pop
- **Contrast:** +3% for UI clarity
- **Curves:** Lift shadows to 20% (clinical, not dark/moody)

### Split-Screen Comparison (Advanced)

If comparing two scenarios side-by-side:
```bash
ffmpeg -i calm_scenario.mp4 -i escalated_scenario.mp4 \
  -filter_complex "[0:v]scale=960:1080[left];
                   [1:v]scale=960:1080[right];
                   [left][right]hstack=inputs=2[v]" \
  -map "[v]" \
  -c:v libx264 \
  comparison.mp4
```

---

**Good luck with your demo! The smooth animations should impress. Let us know how it goes. 🎬**
